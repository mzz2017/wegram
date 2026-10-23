import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import SwiftSignalKit
import SettingsUI
import TelegramCore
import DeviceAccess
import UserNotifications

final class WegramNotificationsController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var settings: (GlobalNotificationSettingsSet, InAppNotificationSettings)?
    private let foregroundDisposable = MetaDisposable()
    private var permission: WegramNotificationPermission = .unknown
    private var permissionGeneration = 0
    private var presentationDisposable: Disposable?
    private let settingsDisposable = MetaDisposable()
    private let saveDisposable = MetaDisposable()
    private let content = WegramNotificationsContentView()
    private let titleButton = UIButton(type: .custom)
    private let backButton = ASButtonNode()
    private let moreButton = ASButtonNode()

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.Settings.MoreNotificationSettings"
        self.titleButton.addAction(UIAction(handler: { [weak self] _ in self?.morePressed() }), for: .touchUpInside)
        self.navigationItem.titleView = self.titleButton
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.moreButton.addTarget(self, action: #selector(self.morePressed), forControlEvents: .touchUpInside)
        self.content.change = { [weak self] field, value in self?.change(field, value: value) }
        self.content.openPermission = { [weak self] in self?.openPermission() }
        self.attemptNavigation = { [weak self] _ in !(self?.content.submitting ?? false) }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.settingsDisposable.set((combineLatest(
            context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.globalNotifications)),
            context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
        ) |> deliverOnMainQueue).startStrict(next: { [weak self] global, local in
            guard let self else { return }
            self.settings = (global?.get(GlobalNotificationSettings.self)?.effective ?? .defaultSettings, local.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) ?? .defaultSettings)
            self.updatePresentation()
        }))
        self.foregroundDisposable.set((context.sharedContext.applicationBindings.applicationInForeground |> deliverOnMainQueue).startStrict(next: { [weak self] foreground in
            if foreground { self?.refreshPermission() }
        }))
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.settingsDisposable.dispose()
        self.saveDisposable.dispose()
        self.foregroundDisposable.dispose()
    }

    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.titleButton.setTitle(chinese ? "新消息通知" : "Message Notifications", for: .normal)
        self.titleButton.setTitleColor(control, for: .normal)
        self.titleButton.accessibilityHint = chinese ? "打开通知分类、例外与铃声设置" : "Open notification categories, exceptions and sounds"
        self.titleButton.isEnabled = !self.content.submitting
        self.titleButton.sizeToFit()
        self.titleButton.bounds.size.height = 44
        let image = wegramNavigationBackArrowImage(color: control)
        self.backButton.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: 0, bottom: (44 - size.height) / 2, right: 44 - size.width)
        self.backButton.isUserInteractionEnabled = !self.content.submitting
        let backItem = UIBarButtonItem(customDisplayNode: self.backButton)
        backItem?.target = self
        backItem?.action = #selector(self.backPressed)
        backItem?.accessibilityLabel = data.strings.Common_Back
        backItem?.isEnabled = !self.content.submitting
        self.navigationItem.leftBarButtonItem = backItem
        // The visible way to the full Telegram page; the title tap does the same.
        self.moreButton.setImage(WegramIcon.chatMore.image()?.withTintColor(control, renderingMode: .alwaysOriginal), for: .normal)
        self.moreButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        self.moreButton.accessibilityLabel = chinese ? "更多通知设置" : "More Notification Settings"
        self.moreButton.isUserInteractionEnabled = !self.content.submitting
        let moreItem = UIBarButtonItem(customDisplayNode: self.moreButton)
        moreItem?.accessibilityLabel = self.moreButton.accessibilityLabel
        moreItem?.target = self
        moreItem?.action = #selector(self.morePressed)
        moreItem?.isEnabled = !self.content.submitting
        self.navigationItem.rightBarButtonItem = moreItem
        self.content.update(dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, chinese: chinese)
        if let settings = self.settings { self.content.load(global: settings.0, local: settings.1) }
        self.content.load(permission: self.permission)
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.refreshPermission()
    }

    private func refreshPermission() {
        self.permissionGeneration += 1
        let generation = self.permissionGeneration
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let permission = WegramNotificationPermission(status: settings.authorizationStatus, alerts: settings.alertSetting)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.permissionGeneration == generation else { return }
                self.permission = permission
                self.updatePresentation()
            }
        }
    }

    private func openPermission() {
        guard !self.content.submitting, self.permission != .unknown else { return }
        if self.permission == .notDetermined {
            self.content.submitting = true
            self.updatePresentation()
            DeviceAccess.authorizeAccess(to: .notifications, registerForNotifications: { [weak self] completion in
                guard let self else { return }
                self.context.sharedContext.applicationBindings.registerForNotifications(completion)
            }, { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.content.submitting = false
                    self.refreshPermission()
                    self.updatePresentation()
                }
            })
        } else {
            self.context.sharedContext.applicationBindings.openSettings()
        }
    }

    private func change(_ field: WegramNotificationToggle, value: Bool) {
        guard self.settings != nil, !self.content.submitting else { return }
        self.content.submitting = true
        self.updatePresentation()
        var save: Signal<Void, NoError> = .complete()
        if field.affectsGlobal {
            save = updateGlobalNotificationSettingsInteractively(postbox: self.context.account.postbox, { field.applying(value, to: $0) })
        }
        if field.affectsLocal {
            save = save |> then(updateInAppNotificationSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { field.applying(value, to: $0) }))
        }
        // Completion means the original local transactions committed. The upstream
        // synchronization worker remains responsible for server delivery and retry.
        self.saveDisposable.set((save |> deliverOnMainQueue).startStrict(completed: { [weak self] in
            guard let self else { return }
            self.content.submitting = false
            self.updatePresentation()
        }))
    }
    @objc private func morePressed() {
        guard !self.content.submitting else { return }
        self.push(notificationsAndSoundsController(context: self.context, exceptionsList: nil))
    }
    @objc private func backPressed() {
        guard !self.content.submitting else { return }
        self.dismiss()
    }
}
