import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import TelegramCore
import SwiftSignalKit
import SettingsUI

final class WegramPrivacyController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var settings: AccountPrivacySettings?
    private var presentationDisposable: Disposable?
    private let settingsDisposable = MetaDisposable()
    private let content = WegramPrivacyContentView()
    private let blockedPeers: BlockedPeersContext
    private let requestPublicPhotoSetup: (@escaping (UIImage?) -> Void) -> Void
    private let requestPublicPhotoRemove: (@escaping () -> Void) -> Void
    private let titleButton = UIButton(type: .custom)
    private let backButton = ASButtonNode()
    private let moreButton = ASButtonNode()

    init(context: AccountContext, requestPublicPhotoSetup: @escaping (@escaping (UIImage?) -> Void) -> Void, requestPublicPhotoRemove: @escaping (@escaping () -> Void) -> Void) {
        self.blockedPeers = BlockedPeersContext(account: context.account, subject: .blocked)
        self.requestPublicPhotoSetup = requestPublicPhotoSetup
        self.requestPublicPhotoRemove = requestPublicPhotoRemove
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.Settings.MorePrivacySettings"
        self.titleButton.addAction(UIAction(handler: { [weak self] _ in self?.openMore() }), for: .touchUpInside)
        self.navigationItem.titleView = self.titleButton
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.moreButton.addTarget(self, action: #selector(self.morePressed), forControlEvents: .touchUpInside)
        self.content.open = { [weak self] destination in self?.open(destination) }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.settingsDisposable.set((context.engine.privacy.requestAccountPrivacySettings() |> deliverOnMainQueue).startStrict(next: { [weak self] settings in
            self?.settings = settings
            self?.updatePresentation()
        }))
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.settingsDisposable.dispose()
    }

    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.titleButton.setTitle(chinese ? "隐私" : "Privacy", for: .normal)
        self.titleButton.setTitleColor(control, for: .normal)
        self.titleButton.accessibilityHint = chinese ? "打开完整隐私与安全设置" : "Open full privacy and security settings"
        self.titleButton.sizeToFit()
        self.titleButton.bounds.size.height = 44
        let image = wegramNavigationBackArrowImage(color: control)
        self.backButton.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: 0, bottom: (44 - size.height) / 2, right: 44 - size.width)
        let backItem = UIBarButtonItem(customDisplayNode: self.backButton)
        backItem?.target = self
        backItem?.action = #selector(self.backPressed)
        backItem?.accessibilityLabel = data.strings.Common_Back
        self.navigationItem.leftBarButtonItem = backItem
        // The visible way to the full Telegram page; the title tap does the same.
        self.moreButton.setImage(WegramIcon.chatMore.image()?.withTintColor(control, renderingMode: .alwaysOriginal), for: .normal)
        self.moreButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        self.moreButton.accessibilityLabel = chinese ? "更多隐私设置" : "More Privacy Settings"
        let moreItem = UIBarButtonItem(customDisplayNode: self.moreButton)
        moreItem?.accessibilityLabel = self.moreButton.accessibilityLabel
        moreItem?.target = self
        moreItem?.action = #selector(self.morePressed)
        self.navigationItem.rightBarButtonItem = moreItem
        self.content.update(dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, chinese: chinese)
        if let settings = self.settings {
            self.content.load(values: [
                .phone: stringForSelectiveSettings(strings: data.strings, settings: settings.phoneNumber),
                .groups: stringForSelectiveSettings(strings: data.strings, settings: settings.groupInvitations),
                .presence: stringForSelectiveSettings(strings: data.strings, settings: settings.presence),
                .forwards: stringForSelectiveSettings(strings: data.strings, settings: settings.forwards)
            ])
        }
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
        self.content.contentInset.bottom = layout.intrinsicInsets.bottom
        self.content.verticalScrollIndicatorInsets.bottom = layout.intrinsicInsets.bottom
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top)))
    }

    private func openMore() {
        self.push(privacyAndSecurityController(context: self.context, initialSettings: self.settings, updatedSettings: { [weak self] settings in
            guard let self, let settings else { return }
            self.settingsDisposable.set(nil)
            self.settings = settings
            self.updatePresentation()
        }, blockedPeersContext: self.blockedPeers, requestPublicPhotoSetup: self.requestPublicPhotoSetup, requestPublicPhotoRemove: self.requestPublicPhotoRemove))
    }

    private func open(_ destination: WegramPrivacyDestination) {
        if destination == .blocked {
            self.push(WegramBlockedController(context: self.context, blockedPeers: self.blockedPeers))
            return
        }
        if destination == .system {
            self.context.sharedContext.applicationBindings.openSettings()
            return
        }
        guard let settings = self.settings else { return }
        let kind: SelectivePrivacySettingsKind
        let current: SelectivePrivacySettings
        switch destination {
        case .phone: kind = .phoneNumber; current = settings.phoneNumber
        case .groups: kind = .groupInvitations; current = settings.groupInvitations
        case .presence: kind = .presence; current = settings.presence
        case .forwards: kind = .forwards; current = settings.forwards
        case .blocked, .system: return
        }
        self.push(selectivePrivacySettingsController(context: self.context, kind: kind, current: current,
            phoneDiscoveryEnabled: destination == .phone ? settings.phoneDiscoveryEnabled : nil,
            globalSettings: destination == .presence ? settings.globalSettings : nil,
            updated: { [weak self] updated, _, discovery, global in
                guard let self, var latest = self.settings else { return }
                switch destination {
                case .phone:
                    latest.phoneNumber = updated
                    if let discovery { latest.phoneDiscoveryEnabled = discovery }
                case .groups: latest.groupInvitations = updated
                case .presence:
                    latest.presence = updated
                    if let global { latest.globalSettings = global }
                case .forwards: latest.forwards = updated
                case .blocked, .system: return
                }
                // The original editor owns requests. This is its optimistic display
                // callback, not confirmation of a committed server privacy change.
                self.settings = latest
                self.updatePresentation()
            }))
    }
    @objc private func morePressed() {
        self.openMore()
    }
    @objc private func backPressed() {
        self.dismiss()
    }
}
