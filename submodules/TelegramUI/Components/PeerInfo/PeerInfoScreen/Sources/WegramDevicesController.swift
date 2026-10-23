import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit
import SettingsUI

final class WegramDevicesController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private let contextsDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private let removeDisposable = MetaDisposable()
    private let updateDisposable = MetaDisposable()
    private var activeSessions: ActiveSessionsContext?
    private var webSessions: WebSessionsContext?
    private var sessions: [RecentAccountSession] = []
    private let content = WegramDevicesContentView()
    private let titleButton = UIButton(type: .custom)
    private let backButton = ASButtonNode()
    private let editButton = ASButtonNode()
    private let doneButton = WegramNameSaveButton()
    private weak var confirmationController: ViewController?
    private lazy var doneNode: ASDisplayNode = {
        let node = ASDisplayNode(viewBlock: { [button = self.doneButton] in button })
        node.style.preferredSize = CGSize(width: 64, height: 44)
        return node
    }()

    init(context: AccountContext, contexts: Signal<(ActiveSessionsContext, Int, WebSessionsContext)?, NoError>) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.Settings.MoreDeviceSettings"
        self.titleButton.addAction(UIAction(handler: { [weak self] _ in self?.openMore() }), for: .touchUpInside)
        self.navigationItem.titleView = self.titleButton
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.editButton.addTarget(self, action: #selector(self.editPressed), forControlEvents: .touchUpInside)
        self.doneButton.addAction(UIAction(handler: { [weak self] _ in self?.editPressed() }), for: .touchUpInside)
        self.content.open = { [weak self] id in self?.open(id: id) }
        self.content.remove = { [weak self] id in self?.requestRemove(id: id, completion: {}) }
        self.attemptNavigation = { [weak self] _ in !(self?.content.busy ?? false) }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        // The page is pushed immediately and owns the wait, so dismissing it cannot cause a late push.
        self.contextsDisposable.set((contexts |> filter { $0 != nil } |> take(1) |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            guard let self, let (active, _, web) = value else { return }
            self.activeSessions = active
            self.webSessions = web
            active.loadMore()
            self.stateDisposable.set((active.state |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                guard let self else { return }
                self.sessions = state.sessions.sorted { $0.activityDate > $1.activityDate }
                let rows = self.sessions.map { session -> WegramDeviceRow in
                    let name = !session.deviceModel.isEmpty ? session.deviceModel : (!session.platform.isEmpty ? session.platform : session.appName)
                    return WegramDeviceRow(id: session.hash, name: name.isEmpty ? (self.chinese ? "未知设备" : "Unknown Device") : name, passwordPending: session.flags.contains(.passwordPending))
                }
                self.content.load(rows: rows, loading: state.isLoadingMore)
                self.updatePresentation()
            }))
            self.updatePresentation()
        }))
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.contextsDisposable.dispose()
        self.stateDisposable.dispose()
        self.removeDisposable.dispose()
        self.updateDisposable.dispose()
    }
    private var chinese: Bool { self.presentationData.strings.baseLanguageCode.hasPrefix("zh") }
    private func updatePresentation() {
        let data = self.presentationData
        let color = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.titleButton.setTitle(self.chinese ? "登录设备管理" : "Logged-in Devices", for: .normal)
        self.titleButton.setTitleColor(color, for: .normal)
        self.titleButton.accessibilityHint = self.chinese ? "打开完整设备、网页授权与自动退出设置" : "Open all devices, website authorizations and automatic logout settings"
        self.titleButton.isEnabled = self.activeSessions != nil && !self.content.busy
        self.titleButton.sizeToFit()
        self.titleButton.bounds.size.height = 44
        let image = wegramNavigationBackArrowImage(color: color)
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
        self.editButton.setTitle(data.strings.Common_Edit, with: Font.regular(17), with: color, for: .normal)
        self.editButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        self.editButton.isUserInteractionEnabled = !self.content.busy
        self.doneButton.setTitle(data.strings.Common_Done, for: .normal)
        self.doneButton.accessibilityLabel = data.strings.Common_Done
        self.doneButton.isEnabled = !self.content.busy
        let editing = self.content.table.isEditing
        let edit = UIBarButtonItem(customDisplayNode: editing ? self.doneNode : self.editButton)
        edit?.target = self
        edit?.action = #selector(self.editPressed)
        edit?.accessibilityLabel = editing ? data.strings.Common_Done : data.strings.Common_Edit
        edit?.isEnabled = !self.content.busy
        self.navigationItem.rightBarButtonItem = self.content.hasEditableDevices ? edit : nil
        self.content.update(dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, chinese: self.chinese)
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
    private func openMore() {
        guard !self.content.busy, self.confirmationController == nil, let active = self.activeSessions, let web = self.webSessions else { return }
        self.push(recentSessionsController(context: self.context, activeSessionsContext: active, webSessionsContext: web, websitesOnly: false))
    }
    private func open(id: Int64) {
        guard !self.content.busy, self.confirmationController == nil, let session = self.sessions.first(where: { $0.hash == id }), let active = self.activeSessions else { return }
        let controller = RecentSessionScreen(context: self.context, subject: .session(session), updateAcceptSecretChats: { [weak self] value in
            self?.updateDisposable.set(active.updateSessionAcceptsSecretChats(session, accepts: value).startStrict())
        }, updateAcceptIncomingCalls: { [weak self] value in
            self?.updateDisposable.set(active.updateSessionAcceptsIncomingCalls(session, accepts: value).startStrict())
        }, remove: { [weak self] completion in self?.requestRemove(id: id, completion: completion) })
        self.push(controller)
    }
    private func requestRemove(id: Int64, completion: @escaping () -> Void) {
        guard !self.content.busy, self.confirmationController == nil, let session = self.sessions.first(where: { $0.hash == id }), !session.isCurrent else { return }
        let alert = recentSessionTerminationController(context: self.context, confirmed: { [weak self] in
            guard let self, !self.content.busy, let active = self.activeSessions, self.sessions.contains(where: { $0.hash == id && !$0.isCurrent }) else { return }
            completion()
            self.content.busy = true
            self.updatePresentation()
            self.removeDisposable.set((active.remove(hash: id) |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else { return }
                self.content.busy = false
                self.updatePresentation()
                self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }, completed: { [weak self] in
                guard let self else { return }
                self.content.busy = false
                self.context.sharedContext.updateNotificationTokensRegistration()
                self.updatePresentation()
            }))
        })
        self.confirmationController = alert
        self.present(alert, in: .window(.root))
    }
    @objc private func editPressed() {
        guard !self.content.busy else { return }
        self.content.setEditing(!self.content.table.isEditing)
        self.updatePresentation()
    }
    @objc private func backPressed() {
        guard !self.content.busy else { return }
        self.dismiss()
    }
}
