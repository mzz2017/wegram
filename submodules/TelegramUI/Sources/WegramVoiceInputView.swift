import UIKit
import Display

enum WegramVoiceInputState: Equatable {
    case idle, requesting, recording, recognizing, result(String), failure(String)
}

private final class WegramDictationButton: UIButton {
    var activate: () -> Void = {}
    override func accessibilityActivate() -> Bool { self.activate(); return true }
}

final class WegramVoiceInputView: UIView {
    let transcript = UITextView()
    let status = UILabel()
    let cancelButton = UIButton(type: .custom)
    let acceptButton = UIButton(type: .custom)
    let retryButton = UIButton(type: .custom)
    private let microphone = WegramDictationButton(type: .custom)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private(set) var state: WegramVoiceInputState = .idle
    var begin: () -> Void = {}
    var finish: (Bool) -> Void = { _ in }
    var cancel: () -> Void = {}
    var accept: (String) -> Void = { _ in }
    var retry: () -> Void = {}
    private var holding = false
    private var chinese = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        for child in [self.transcript, self.status, self.microphone, self.cancelButton, self.acceptButton, self.retryButton, self.spinner] { self.addSubview(child) }
        self.transcript.isEditable = false
        self.transcript.isSelectable = true
        self.transcript.backgroundColor = .clear
        self.status.textAlignment = .center
        self.status.numberOfLines = 2
        self.microphone.layer.cornerRadius = 32
        self.microphone.setImage(UIImage(systemName: "mic.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 26)), for: .normal)
        self.microphone.tintColor = .white
        self.microphone.backgroundColor = UIColor(rgb: 0x07c160)
        self.microphone.accessibilityIdentifier = "Wegram.Dictation.Record"
        self.microphone.activate = { [weak self] in
            guard let self, self.available else { return }
            if self.state == .recording { self.finish(false) }
            else if self.state == .idle { self.begin() }
        }
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
        press.minimumPressDuration = 0
        self.microphone.addGestureRecognizer(press)
        self.cancelButton.addAction(UIAction { [weak self] _ in guard let self, self.available else { return }; self.cancel() }, for: .touchUpInside)
        self.acceptButton.addAction(UIAction { [weak self] _ in
            guard let self, self.available, case let .result(text) = self.state, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            self.accept(text)
        }, for: .touchUpInside)
        self.retryButton.addAction(UIAction { [weak self] _ in
            guard let self, self.available, !self.retryButton.isHidden else { return }
            self.retry()
        }, for: .touchUpInside)
        self.acceptButton.layer.cornerRadius = 6
        self.spinner.hidesWhenStopped = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var available: Bool { !self.isHidden && self.alpha > 0 && self.isUserInteractionEnabled }

    func update(state: WegramVoiceInputState, dark: Bool, chinese: Bool, fontSize: CGFloat) {
        self.state = state
        self.chinese = chinese
        self.backgroundColor = UIColor(rgb: dark ? 0x202020 : 0xf7f7f7)
        let color = UIColor(rgb: dark ? 0xd0d0d0 : 0x181818)
        self.status.textColor = UIColor(rgb: dark ? 0x999999 : 0x666666)
        self.status.font = Font.regular(fontSize * 14 / 17)
        self.transcript.font = Font.regular(fontSize)
        self.transcript.textColor = color
        self.cancelButton.setTitle(chinese ? "取消" : "Cancel", for: .normal)
        self.retryButton.setTitle(chinese ? "重新输入" : "Try Again", for: .normal)
        self.acceptButton.setTitle(chinese ? "使用文字" : "Use Text", for: .normal)
        for button in [self.cancelButton, self.retryButton, self.acceptButton] {
            button.titleLabel?.font = Font.regular(fontSize * 15 / 17)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.setTitleColor(button === self.acceptButton ? .white : color, for: .normal)
        }
        self.acceptButton.backgroundColor = UIColor(rgb: 0x07c160)
        self.acceptButton.isHidden = true
        self.retryButton.isHidden = true
        self.microphone.isHidden = false
        self.transcript.text = nil
        self.spinner.stopAnimating()
        switch state {
        case .idle: self.status.text = chinese ? "按住说话" : "Hold to Talk"
        case .requesting: self.status.text = chinese ? "正在请求录音与语音识别权限" : "Requesting microphone and speech recognition access"
        case .recording: self.status.text = chinese ? "松开完成，上滑取消" : "Release to finish, slide up to cancel"
        case .recognizing:
            self.status.text = chinese ? "正在识别…" : "Recognizing…"
            self.spinner.startAnimating()
            self.microphone.isHidden = true
        case let .result(text):
            self.transcript.text = text
            self.status.text = nil
            self.microphone.isHidden = true
            self.acceptButton.isHidden = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            self.retryButton.isHidden = false
        case let .failure(text):
            self.status.text = text
            self.microphone.isHidden = true
            self.retryButton.isHidden = false
        }
        self.microphone.accessibilityLabel = state == .recording ? (chinese ? "结束语音输入" : "Finish Dictation") : (chinese ? "开始语音输入" : "Start Dictation")
        self.setNeedsLayout()
    }

    func handlePress(_ phase: UIGestureRecognizer.State, cancelRequested: Bool = false) {
        guard self.available else { return }
        switch phase {
        case .began:
            guard self.state == .idle else { return }
            self.holding = true
            self.begin()
        case .changed:
            if self.holding { self.status.text = cancelRequested ? (self.chinese ? "松开取消" : "Release to Cancel") : (self.chinese ? "松开完成，上滑取消" : "Release to finish, slide up to cancel") }
        case .ended, .cancelled, .failed:
            guard self.holding else { return }
            self.holding = false
            self.finish(cancelRequested || phase != .ended)
        default: break
        }
    }

    @objc private func pressed(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: self.microphone)
        self.handlePress(gesture.state, cancelRequested: point.y < -40 || !self.microphone.bounds.insetBy(dx: -30, dy: -30).contains(point))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let height = self.bounds.height
        let footerHeight = max(44, ceil((self.cancelButton.titleLabel?.font.lineHeight ?? 18) * 2) + 8)
        let footerY = max(0, height - footerHeight - 8)
        let statusHeight = ceil((self.status.font?.lineHeight ?? 17) * 2) + 4
        let microphoneY = max(8, min((height - 64) / 2 - 12, footerY - statusHeight - 80))
        self.transcript.frame = CGRect(x: 20, y: 8, width: max(0, width - 40), height: max(0, footerY - 20))
        self.microphone.frame = CGRect(x: floor((width - 64) / 2), y: microphoneY, width: 64, height: 64)
        self.status.frame = CGRect(x: 20, y: self.microphone.frame.maxY + 8, width: max(0, width - 40), height: max(0, min(statusHeight, footerY - self.microphone.frame.maxY - 8)))
        self.spinner.center = CGPoint(x: width / 2, y: self.microphone.frame.midY)
        let buttonWidth = max(44, min(88, (width - 40) / 3))
        self.cancelButton.frame = CGRect(x: 12, y: footerY, width: buttonWidth, height: footerHeight)
        self.retryButton.frame = CGRect(x: (width - buttonWidth) / 2, y: footerY, width: buttonWidth, height: footerHeight)
        self.acceptButton.frame = CGRect(x: max(0, width - 12 - buttonWidth), y: footerY, width: buttonWidth, height: footerHeight)
    }
}
