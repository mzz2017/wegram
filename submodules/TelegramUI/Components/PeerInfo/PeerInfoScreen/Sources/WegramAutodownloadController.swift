import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import SwiftSignalKit
import SettingsUI

final class WegramAutodownloadController: ViewController {
    private let cellular: Bool
    private var network: MediaAutoDownloadNetworkType { self.cellular ? .cellular : .wifi }
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private let settingsDisposable = MetaDisposable()
    private let saveDisposable = MetaDisposable()
    private var settings: MediaAutoDownloadSettings?
    private let content = WegramMediaSettingsContentView()
    private let titleButton = UIButton(type: .custom)
    private let backButton = ASButtonNode()

    init(context: AccountContext, cellular: Bool) {
        self.cellular = cellular
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.content.automaticDownload = true
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.Autodownload.MoreSettings"
        self.titleButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, !self.content.busy else { return }
            self.push(autodownloadMediaConnectionTypeController(context: self.context, connectionType: self.cellular ? .cellular : .wifi))
        }), for: .touchUpInside)
        self.navigationItem.titleView = self.titleButton
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.content.open = { [weak self] field in self?.open(field) }
        self.content.change = { [weak self] field, value in if field == .master { self?.change(value: value) } }
        self.attemptNavigation = { [weak self] _ in !(self?.content.busy ?? false) }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.settingsDisposable.set((context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, SharedDataKeys.autodownloadSettings]) |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            guard let self else { return }
            var settings = data.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) ?? .defaultSettings
            if let remote = data.entries[SharedDataKeys.autodownloadSettings]?.get(AutodownloadSettings.self) {
                settings = settings.updatedWithAutodownloadSettings(remote)
            }
            self.settings = settings
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
        self.titleButton.setTitle(self.cellular ? (chinese ? "移动网络" : "Mobile Data") : "Wi-Fi", for: .normal)
        self.titleButton.setTitleColor(control, for: .normal)
        self.titleButton.accessibilityHint = chinese ? "打开下载预设、Stories 与完整下载设置" : "Open download presets, Stories and full download settings"
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
        var summaries: [WegramMediaSetting: String] = [:]
        if let settings = self.settings {
            let categories = effectiveAutodownloadCategories(settings: settings, networkType: self.network)
            for (field, category, type) in [(WegramMediaSetting.photos, categories.photo, AutomaticDownloadCategory.photo), (.videos, categories.video, .video), (.files, categories.file, .file)] {
                summaries[field] = automaticDownloadCategorySummary(strings: data.strings, decimalSeparator: data.dateTimeFormat.decimalSeparator, category: category, type: type)
            }
        }
        self.content.loadAutomaticDownload(enabled: self.settings?.connectionSettings(for: self.network).enabled, summaries: summaries, voiceInfo: data.strings.AutoDownloadSettings_VoiceMessagesInfo)
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
        guard !self.content.busy, self.settings?.connectionSettings(for: self.network).enabled == true else { return }
        let category: AutomaticDownloadCategory
        switch field {
        case .photos: category = .photo
        case .videos: category = .video
        case .files: category = .file
        default: return
        }
        self.push(autodownloadMediaCategoryController(context: self.context, connectionType: self.cellular ? .cellular : .wifi, category: category, wegramStyle: true))
    }
    private func change(value: Bool) {
        guard self.settings != nil, !self.content.busy else { return }
        self.content.busy = true
        self.updatePresentation()
        let network = self.network
        self.saveDisposable.set((updateMediaDownloadSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { settings in
            return WegramMediaSetting.master.applying(value, to: settings, network: network)
        }) |> deliverOnMainQueue).startStrict(completed: { [weak self] in
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
