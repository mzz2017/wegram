import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import SwiftSignalKit
import SettingsUI

final class WegramMediaSettingsController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private let settingsDisposable = MetaDisposable()
    private let saveDisposable = MetaDisposable()
    private var settings: (GeneratedMediaStoreSettings, VoiceCallSettings, AutodownloadSettings)?
    private let content = WegramMediaSettingsContentView()
    private let titleButton = UIButton(type: .custom)
    private let backButton = ASButtonNode()

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.Media.MoreSettings"
        self.titleButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, !self.content.busy else { return }
            self.push(dataAndStorageController(context: self.context))
        }), for: .touchUpInside)
        self.navigationItem.titleView = self.titleButton
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.content.open = { [weak self] field in self?.open(field) }
        self.content.change = { [weak self] field, value in self?.change(field, value: value) }
        self.attemptNavigation = { [weak self] _ in !(self?.content.busy ?? false) }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.settingsDisposable.set((context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings, ApplicationSpecificSharedDataKeys.voiceCallSettings, SharedDataKeys.autodownloadSettings]) |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            guard let self else { return }
            self.settings = (
                data.entries[ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings]?.get(GeneratedMediaStoreSettings.self) ?? .defaultSettings,
                data.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings]?.get(VoiceCallSettings.self) ?? .defaultSettings,
                data.entries[SharedDataKeys.autodownloadSettings]?.get(AutodownloadSettings.self) ?? .defaultSettings
            )
            self.updatePresentation()
        }))
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.settingsDisposable.dispose()
        self.saveDisposable.dispose()
    }
    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.titleButton.setTitle(chinese ? "照片、视频、文件与通话" : "Photos, Videos, Files & Calls", for: .normal)
        self.titleButton.setTitleColor(control, for: .normal)
        self.titleButton.accessibilityHint = chinese ? "打开后台下载、录音、代理与更多数据设置" : "Open background downloads, recording, proxy and more data settings"
        self.titleButton.isEnabled = !self.content.busy
        self.titleButton.sizeToFit()
        self.titleButton.bounds.size.height = 44
        let image = wegramNavigationBackArrowImage(color: control)
        self.backButton.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: 0, bottom: (44 - size.height) / 2, right: 44 - size.width)
        self.backButton.isUserInteractionEnabled = !self.content.busy
        let back = UIBarButtonItem(customDisplayNode: self.backButton)
        back?.target = self
        back?.action = #selector(self.backPressed)
        back?.accessibilityLabel = data.strings.Common_Back
        back?.isEnabled = !self.content.busy
        self.navigationItem.leftBarButtonItem = back
        self.content.update(dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, chinese: chinese)
        var lessData: Bool?
        var scope = ""
        if let settings = self.settings {
            let effective = effectiveDataSaving(for: settings.1, autodownloadSettings: settings.2)
            lessData = effective != .never
            switch effective {
            case .never: scope = chinese ? "省流量已关闭" : "Data saving is off"
            case .cellular: scope = chinese ? "当前仅移动网络省流量" : "Currently saves data on mobile networks only"
            case .always: scope = chinese ? "当前在所有网络下省流量" : "Currently saves data on all networks"
            case .default: scope = chinese ? "使用默认通话设置" : "Uses the default call settings"
            }
        }
        self.content.load(editedPhotos: self.settings?.0.storeEditedPhotos, lessCallData: lessData, callScope: scope)
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        if self.isNodeLoaded { self.displayNode.backgroundColor = self.content.backgroundColor }
    }
    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.view.addSubview(self.content)
        self.updatePresentation()
        self.displayNodeDidLoad()
    }
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.content.table.contentInset.bottom = layout.intrinsicInsets.bottom
        self.content.table.verticalScrollIndicatorInsets.bottom = layout.intrinsicInsets.bottom
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top)))
    }
    private func open(_ field: WegramMediaSetting) {
        guard !self.content.busy else { return }
        switch field {
        case .cellular, .wifi:
            self.push(WegramAutodownloadController(context: self.context, cellular: field == .cellular))
        case .privateChats, .groups, .channels:
            let type: AutomaticSaveIncomingPeerType = field == .privateChats ? .privateChats : (field == .groups ? .groups : .channels)
            self.push(saveIncomingMediaController(context: self.context, scope: .peerType(type), wegramStyle: true))
        case .editedPhotos, .calls, .master, .photos, .videos, .files: break
        }
    }
    private func change(_ field: WegramMediaSetting, value: Bool) {
        guard self.settings != nil, !self.content.busy, (field == .editedPhotos || field == .calls) else { return }
        self.content.busy = true
        self.updatePresentation()
        let save: Signal<Void, NoError>
        if field == .editedPhotos {
            save = updateGeneratedMediaStoreSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { field.applying(value, to: $0) })
        } else {
            save = updateVoiceCallSettingsSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { field.applying(value, to: $0) })
        }
        self.saveDisposable.set((save |> deliverOnMainQueue).startStrict(completed: { [weak self] in
            guard let self else { return }
            self.content.busy = false
            self.updatePresentation()
        }))
    }
    @objc private func backPressed() {
        guard !self.content.busy else { return }
        self.dismiss()
    }
}
