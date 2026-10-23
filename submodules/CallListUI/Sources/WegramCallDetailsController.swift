import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import AvatarNode
import PeerInfoUI
import ItemListUI
import SwiftSignalKit
import LocalizedPeerData

final class WegramCallDetailsController: ViewController {
    private let context: AccountContext
    private var peer: EnginePeer
    private let messages: [EngineMessage]
    private var presentationData: PresentationData
    private let content = WegramCallDetailsView()
    private let avatar = AvatarNode(font: avatarPlaceholderFont(size: 26))
    private let recordsNode = WegramCallDetailsRecordsNode()
    private var presentationDisposable: Disposable?
    private var peerDisposable: Disposable?
    private let message: () -> Void
    private let call: () -> Void
    private let fullDetails: () -> ViewController?
    private var openedFallback = false
    private var validLayout: ContainerViewLayout?

    init(context: AccountContext, peer: EnginePeer, messages: [EngineMessage], message: @escaping () -> Void, call: @escaping () -> Void, fullDetails: @escaping () -> ViewController?) {
        self.context = context
        self.peer = peer
        self.messages = messages
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.message = message
        self.call = call
        self.fullDetails = fullDetails
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "•••", style: .plain, target: self, action: #selector(self.morePressed))
        self.content.open = { [weak self] action in
            guard let self, self.view.window != nil, !self.content.isHidden, Self.supports(peer: self.peer, messages: self.messages) else { return }
            switch action {
            case .profile: self.morePressed()
            case .message: self.message()
            case .call: self.call()
            }
        }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self else { return }
            self.presentationData = data
            self.updatePresentation()
        })
        self.peerDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id)) |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self, let peer else { return }
            self.peer = peer
            self.updatePresentation()
        })
    }
    static func supports(peer: EnginePeer, messages: [EngineMessage]) -> Bool {
        guard case let .user(user) = peer, user.botInfo == nil, !user.isDeleted,
              !user.flags.contains(.isSupport), user.restrictionInfo == nil,
              !peer.isScam, !peer.isFake, !peer.isVerified, !messages.isEmpty else { return false }
        return messages.allSatisfy { message in
            message.media.contains { media in
                guard let action = media as? TelegramMediaAction, case .phoneCall = action.action else { return false }
                return true
            }
        }
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { self.presentationDisposable?.dispose(); self.peerDisposable?.dispose() }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.view.addSubview(self.content)
        self.content.avatarHost.addSubnode(self.avatar)
        self.content.recordsHost.addSubnode(self.recordsNode)
        self.recordsNode.heightChanged = { [weak self] height in
            guard let self, let layout = self.validLayout else { return }
            self.content.updateLayout(recordsHeight: height, bottomInset: max(layout.intrinsicInsets.bottom, layout.safeInsets.bottom))
        }
        self.displayNodeDidLoad()
        self.updatePresentation()
    }
    private func updatePresentation() {
        let chinese = self.presentationData.strings.baseLanguageCode.hasPrefix("zh")
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = chinese ? "通话详情" : "Call Details"
        self.navigationItem.rightBarButtonItem?.accessibilityLabel = self.presentationData.strings.Common_More
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)), transition: .immediate)
        guard self.isNodeLoaded else { return }
        self.content.isHidden = !Self.supports(peer: self.peer, messages: self.messages)
        if self.content.isHidden {
            if self.view.window != nil, !self.openedFallback, let controller = self.fullDetails() {
                self.openedFallback = true
                self.replace(with: controller)
            }
            return
        }
        self.displayNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.content.update(name: self.peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), username: self.peer.addressName, messageTitle: self.presentationData.strings.Conversation_SendMessage, callTitle: self.presentationData.strings.Notification_CallBack, dark: self.presentationData.theme.overallDarkAppearance, fontSize: self.presentationData.listsFontSize.itemListBaseFontSize)
        self.avatar.setPeer(context: self.context, theme: self.presentationData.theme, peer: self.peer, clipStyle: .none, displayDimensions: CGSize(width: 64, height: 64))
        self.avatar.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        self.avatar.updateSize(size: CGSize(width: 64, height: 64))
        if let layout = self.validLayout { self.containerLayoutUpdated(layout, transition: .immediate) }
    }
    @objc private func morePressed() {
        guard self.isNodeLoaded, self.view.window != nil else { return }
        if let controller = self.fullDetails() { (self.navigationController as? NavigationController)?.pushViewController(controller) }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updatePresentation()
    }
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.validLayout = layout
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let width = max(0, layout.size.width - layout.safeInsets.left - layout.safeInsets.right)
        self.content.frame = CGRect(x: layout.safeInsets.left, y: top, width: width, height: max(0, layout.size.height - top))
        self.recordsNode.update(presentationData: self.presentationData, messages: self.messages, width: width)
        self.content.updateLayout(recordsHeight: self.recordsNode.bounds.height, bottomInset: max(layout.intrinsicInsets.bottom, layout.safeInsets.bottom))
    }
}
