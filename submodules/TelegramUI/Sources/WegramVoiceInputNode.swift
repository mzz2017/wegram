import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatInputNode
import ChatPresentationInterfaceState
import DeviceAccess
import ConvertOpusToAAC
import Speech

/// Keeps conversion alive until its writer finishes, so cancellation cannot recreate a deleted temp file.
private final class WegramDictationJob {
    private let source = EngineTempBox.shared.tempFile(fileName: "dictation.ogg")
    private let output = EngineTempBox.shared.tempFile(fileName: "dictation.m4a")
    private let conversion = MetaDisposable()
    private var task: SFSpeechRecognitionTask?
    private var cancelled = false
    private var converting = false
    private var finished = false
    private let completion: (String?) -> Void

    init(data: Data, recognizer: SFSpeechRecognizer, completion: @escaping (String?) -> Void) {
        self.completion = completion
        do { try data.write(to: URL(fileURLWithPath: self.source.path), options: .atomic) }
        catch { self.finish(nil); return }
        self.converting = true
        let path = self.output.path
        self.conversion.set((convertOpusToAAC(sourcePath: self.source.path, allocateTempFile: { path }) |> take(1) |> deliverOnMainQueue).start(next: { [self] result in
            self.converting = false
            self.conversion.set(nil)
            guard !self.cancelled, let result else { self.finish(nil); return }
            let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: result))
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request.shouldReportPartialResults = false
            if #available(iOS 16.0, *) { request.addsPunctuation = true }
            self.task = recognizer.recognitionTask(with: request) { [self] result, error in
                DispatchQueue.main.async { [self] in
                    guard !self.finished else { return }
                    if let result, result.isFinal { self.finish(result.bestTranscription.formattedString) }
                    else if error != nil { self.finish(nil) }
                }
            }
        }))
    }

    func cancel() {
        self.cancelled = true
        self.task?.cancel()
        if !self.converting { self.finish(nil) }
    }

    private func finish(_ text: String?) {
        guard !self.finished else { return }
        self.finished = true
        self.task?.cancel()
        self.task = nil
        EngineTempBox.shared.dispose(self.source)
        EngineTempBox.shared.dispose(self.output)
        if !self.cancelled { self.completion(text) }
    }
}

final class WegramVoiceInputNode: ChatInputNode {
    private let context: AccountContext
    private let locale: Locale
    private let content = WegramVoiceInputView()
    private let scroll = UIScrollView()
    private let presentController: (ViewController) -> Void
    private let acceptText: (String) -> Bool
    var isCurrent: () -> Bool = { false }
    private var presentationData: PresentationData
    private var state: WegramVoiceInputState = .idle
    private var generation = 0
    private var recorder: ManagedAudioRecorder?
    private var recognizer: SFSpeechRecognizer?
    private let recorderDisposable = MetaDisposable()
    private let permissionDisposable = MetaDisposable()
    private let recordingDisposable = MetaDisposable()
    private let dataDisposable = MetaDisposable()
    private var job: WegramDictationJob?
    private var timeout: Foundation.Timer?
    private var backgroundObserver: NSObjectProtocol?
    private var didRecord = false

    init(context: AccountContext, language: String, presentationData: PresentationData, present: @escaping (ViewController) -> Void, acceptText: @escaping (String) -> Bool) {
        self.context = context
        self.locale = Locale(identifier: language)
        self.presentationData = presentationData
        self.presentController = present
        self.acceptText = acceptText
        super.init()
        self.view.addSubview(self.scroll)
        self.scroll.addSubview(self.content)
        self.scroll.alwaysBounceVertical = false
        self.content.begin = { [weak self] in self?.begin() }
        self.content.finish = { [weak self] cancel in self?.finish(cancel: cancel) }
        self.content.cancel = { [weak self] in
            guard let self else { return }
            self.cancelResources()
            self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId { state in (.text, state.interfaceState.messageActionsState.closedButtonKeyboardMessageId) }
        }
        self.content.retry = { [weak self] in self?.cancelResources() }
        self.content.accept = { [weak self] text in
            guard let self, self.active else { return }
            if !self.acceptText(text) { self.fail("当前聊天暂时不能输入文字。", "Text cannot be inserted into the current chat.") }
        }
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.cancelResources(preserveResult: true) }
        self.refresh()
    }

    private var active: Bool { self.isCurrent() && self.isNodeLoaded && self.view.window != nil && !self.context.isFrozen }

    deinit {
        self.recorder?.stop()
        self.recorderDisposable.dispose()
        self.permissionDisposable.dispose()
        self.recordingDisposable.dispose()
        self.dataDisposable.dispose()
        self.job?.cancel()
        self.timeout?.invalidate()
        if let observer = self.backgroundObserver { NotificationCenter.default.removeObserver(observer) }
    }

    override func didExitHierarchy() {
        super.didExitHierarchy()
        self.cancelResources(preserveResult: true)
    }

    func cancelResources(preserveResult: Bool = false) {
        let previous = self.state
        self.generation += 1
        self.timeout?.invalidate()
        self.timeout = nil
        self.recorder?.stop()
        self.recorder = nil
        self.recorderDisposable.set(nil)
        self.permissionDisposable.set(nil)
        self.recordingDisposable.set(nil)
        self.dataDisposable.set(nil)
        self.job?.cancel()
        self.job = nil
        if preserveResult, case .result = previous { self.state = previous }
        else { self.state = .idle }
        self.refresh()
    }

    private func fail(_ chinese: String, _ english: String) {
        self.cancelResources()
        self.state = .failure(self.presentationData.strings.baseLanguageCode.hasPrefix("zh") ? chinese : english)
        self.refresh()
    }

    private func begin() {
        guard self.active, self.state == .idle else { return }
        self.generation += 1
        let generation = self.generation
        self.state = .requesting
        self.refresh()
        var requested = false
        self.permissionDisposable.set((self.context.sharedContext.hasOngoingCall.get() |> deliverOnMainQueue).start(next: { [weak self] ongoing in
            guard let self, self.active, self.generation == generation else { return }
            if ongoing {
                if case .result = self.state { self.cancelResources(preserveResult: true) }
                else { self.fail("通话中不能开始语音输入。", "Dictation is unavailable during a call.") }
                return
            }
            guard !requested else { return }
            requested = true
            var deniedGeneration: Int?
            DeviceAccess.authorizeAccess(to: .microphone(.audio), presentationData: self.presentationData, present: { [weak self] controller, _ in
                guard let self, self.active, self.generation == deniedGeneration else { return }
                self.presentController(controller)
            }, openSettings: self.context.sharedContext.applicationBindings.openSettings, { [weak self] allowed in
                guard let self, self.active, self.generation == generation else { return }
                guard allowed else {
                    self.fail("请允许麦克风访问后重试。", "Allow microphone access and try again.")
                    // DeviceAccess presents its denial explanation after invoking this completion.
                    deniedGeneration = self.generation
                    return
                }
                SFSpeechRecognizer.requestAuthorization { [weak self] status in
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.active, self.generation == generation else { return }
                        guard status == .authorized, let recognizer = SFSpeechRecognizer(locale: self.locale), recognizer.isAvailable else {
                            self.fail("当前语言的语音识别不可用，请检查系统权限。", "Speech recognition is unavailable. Check the selected language and system permission.")
                            return
                        }
                        self.recognizer = recognizer
                        self.startRecorder(generation: generation)
                    }
                }
            })
        }))
    }

    private func startRecorder(generation: Int) {
        self.recorderDisposable.set((self.context.sharedContext.mediaManager.audioRecorder(resumeData: nil, beginWithTone: false, pauseMusicOnRecording: self.context.sharedContext.currentMediaInputSettings.with { $0.pauseMusicOnRecording }, applicationBindings: self.context.sharedContext.applicationBindings, beganWithTone: { _ in }) |> take(1) |> deliverOnMainQueue).start(next: { [weak self] recorder in
            guard let self, self.active, self.generation == generation else { recorder?.stop(); return }
            guard let recorder else { self.fail("录音启动失败，请重试。", "Recording could not start. Try again."); return }
            self.recorder = recorder
            self.didRecord = false
            self.state = .recording
            self.refresh()
            self.recordingDisposable.set((recorder.recordingState |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self, self.generation == generation, self.state == .recording else { return }
                switch state {
                case let .recording(duration, _):
                    self.didRecord = true
                    if duration >= 59 { self.finish(cancel: false) }
                case .paused where !self.didRecord: break
                default: self.fail("录音已中断，请重试。", "Recording was interrupted. Try again.")
                }
            }))
            recorder.start()
            self.timeout = Foundation.Timer.scheduledTimer(withTimeInterval: 65, repeats: false) { [weak self] _ in self?.finish(cancel: false) }
        }))
    }

    private func finish(cancel: Bool) {
        if cancel || self.state == .requesting { self.cancelResources(); return }
        guard self.active else { self.cancelResources(); return }
        guard self.state == .recording, let recorder = self.recorder, let recognizer = self.recognizer else { return }
        let generation = self.generation
        self.state = .recognizing
        self.refresh()
        self.timeout?.invalidate()
        self.recordingDisposable.set(nil)
        recorder.stop()
        self.dataDisposable.set((recorder.takenRecordedData() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self, self.active, self.generation == generation else { return }
            self.recorder = nil
            guard let data, data.duration >= 0.3, !data.compressedData.isEmpty else { self.fail("说话时间太短，请重试。", "The recording was too short. Try again."); return }
            self.job = WegramDictationJob(data: data.compressedData, recognizer: recognizer, completion: { [weak self] text in
                guard let self, self.active, self.generation == generation else { return }
                self.timeout?.invalidate()
                self.timeout = nil
                self.job = nil
                guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { self.fail("未能识别文字，请重新输入。", "No speech was recognized. Try again."); return }
                self.state = .result(text)
                self.refresh()
            })
        }))
        self.timeout = Foundation.Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in self?.fail("识别超时，请重试。", "Recognition timed out. Try again.") }
    }

    private func refresh() {
        self.content.update(state: self.state, dark: self.presentationData.theme.overallDarkAppearance, chinese: self.presentationData.strings.baseLanguageCode.hasPrefix("zh"), fontSize: self.presentationData.chatFontSize.baseDisplaySize)
    }

    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, layoutMetrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool) -> (CGFloat, CGFloat) {
        if !isVisible || self.context.isFrozen { self.cancelResources() }
        let height = max(0, min(maximumHeight, 240 + bottomInset))
        self.scroll.frame = CGRect(x: leftInset, y: 0, width: max(0, width - leftInset - rightInset), height: max(0, height - bottomInset))
        let contentHeight = max(240, self.scroll.bounds.height)
        self.content.frame = CGRect(x: 0, y: 0, width: self.scroll.bounds.width, height: contentHeight)
        self.scroll.contentSize = self.content.bounds.size
        self.presentationData = self.presentationData.withUpdated(theme: interfaceState.theme)
        self.refresh()
        self.backgroundColor = self.content.backgroundColor
        return (height, 0)
    }
}
