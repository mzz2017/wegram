import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import PeerInfoUI
import InviteLinksUI
import SwiftSignalKit

final class WegramGroupManagementController: ViewController {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private let requestsContext: PeerInvitationImportersContext?
    private let fullDetails: () -> ViewController?
    private var peer: EnginePeer?
    private var pendingRequests: Int
    private var presentationData: PresentationData
    private let content = WegramGroupManagementView()
    private let titleLabel = UILabel()
    private var presentationDisposable: Disposable?
    private let peerDisposable = MetaDisposable()
    private let requestsDisposable = MetaDisposable()
    private var hadPeer = false
    private var openedFallback = false

    init(context: AccountContext, peerId: EnginePeer.Id, pendingRequests: Int, requestsContext: PeerInvitationImportersContext?, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, fullDetails: @escaping () -> ViewController?) {
        self.context = context
        self.peerId = peerId
        self.pendingRequests = max(0, pendingRequests)
        self.requestsContext = requestsContext
        self.updatedPresentationData = updatedPresentationData
        self.fullDetails = fullDetails
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleLabel.font = wegramNavigationTitleFont
        self.titleLabel.textAlignment = .center
        self.titleLabel.accessibilityTraits = .header
        self.navigationItem.titleView = self.titleLabel
        self.content.open = { [weak self] action in self?.open(action) }
        self.presentationDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData) |> deliverOnMainQueue).start(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        if let requestsContext {
            self.requestsDisposable.set((requestsContext.state |> deliverOnMainQueue).start(next: { [weak self] state in
                self?.pendingRequests = max(0, Int(state.count))
                self?.updatePresentation()
            }))
        }
        self.peerDisposable.set((context.account.viewTracker.peerView(peerId, updateData: true) |> deliverOnMainQueue).start(next: { [weak self] view in
            guard let self else { return }
            self.peer = view.peers[self.peerId].map(EnginePeer.init)
            if self.peer != nil { self.hadPeer = true }
            if self.requestsContext == nil, let count = (view.cachedData as? CachedGroupData)?.inviteRequestsPending ?? (view.cachedData as? CachedChannelData)?.inviteRequestsPending {
                self.pendingRequests = max(0, Int(count))
            }
            self.updatePresentation()
        }))
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.peerDisposable.dispose()
        self.requestsDisposable.dispose()
    }
    private var isCurrent: Bool {
        self.isNodeLoaded && self.view.window != nil && (self.navigationController as? NavigationController)?.topViewController === self
    }
    private var actions: [WegramGroupManagementAction] {
        wegramGroupManagementActions(peer: self.peer, pendingRequests: self.pendingRequests)
    }
    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.view.addSubview(self.content)
        self.displayNodeDidLoad()
        self.updatePresentation()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updatePresentation()
    }
    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        self.title = chinese ? "群管理" : "Group Management"
        self.titleLabel.text = self.title
        self.titleLabel.textColor = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        guard self.isNodeLoaded else { return }
        let actions = self.actions
        self.content.isHidden = self.hadPeer && actions.isEmpty
        if self.content.isHidden {
            if self.isCurrent, !self.openedFallback, let controller = self.fullDetails() {
                self.openedFallback = true
                self.replace(with: controller)
            }
            return
        }
        self.content.update(actions: actions, pendingRequests: self.pendingRequests, dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, chinese: chinese)
        self.displayNode.backgroundColor = self.content.backgroundColor
    }
    private func open(_ action: WegramGroupManagementAction) {
        guard self.isCurrent, !self.content.isHidden, self.actions.contains(action) else { return }
        if action == .more {
            if let controller = self.fullDetails() { self.push(controller) }
            return
        }
        if self.context.isFrozen {
            self.push(self.context.sharedContext.makeAccountFreezeInfoScreen(context: self.context))
            return
        }
        switch action {
        case .administrators: self.push(channelAdminsController(context: self.context, updatedPresentationData: self.updatedPresentationData, peerId: self.peerId, usesWegramAppearance: true))
        case .permissions: self.push(channelPermissionsController(context: self.context, updatedPresentationData: self.updatedPresentationData, peerId: self.peerId))
        case .requests: self.push(inviteRequestsController(context: self.context, updatedPresentationData: self.updatedPresentationData, peerId: self.peerId, existingContext: self.requestsContext))
        case .more: break
        }
    }
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: max(0, layout.size.width - layout.safeInsets.left - layout.safeInsets.right), height: max(0, layout.size.height - top)))
        self.content.table.contentInset.bottom = max(layout.safeInsets.bottom, layout.intrinsicInsets.bottom)
    }
}
