import UIKit
import AsyncDisplayKit
import Display
import PresentationDataUtils
import AccountContext
import TelegramPresentationData
import TelegramCore
import AvatarNode
import SwiftSignalKit
import SettingsUI

final class WegramBlockedController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let blockedPeers: BlockedPeersContext
    private var peers: [EnginePeer] = []
    private var avatars: [ObjectIdentifier: AvatarNode] = [:]
    private var loading = true
    private var canLoadMore = true
    private weak var menu: ActionSheetController?
    private let addDisposable = MetaDisposable()
    private var presentationDisposable: Disposable?
    private let stateDisposable = MetaDisposable()
    private let saveDisposable = MetaDisposable()
    private let content = WegramBlockedContentView()
    private let titleButton = UIButton(type: .custom)
    private let backButton = ASButtonNode()

    init(context: AccountContext, blockedPeers: BlockedPeersContext) {
        self.blockedPeers = blockedPeers
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.Settings.MoreBlockedActions"
        self.titleButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, !self.content.busy else { return }
            self.openMenu()
        }), for: .touchUpInside)
        self.navigationItem.titleView = self.titleButton
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.content.open = { [weak self] id in self?.open(id) }
        self.content.remove = { [weak self] id in self?.remove(id) }
        self.content.loadMore = { [weak self] in self?.blockedPeers.loadMore() }
        self.content.configureAvatar = { [weak self] id, host in
            guard let self, let peer = self.peers.first(where: { $0.id.toInt64() == id }) else { return }
            let key = ObjectIdentifier(host)
            let avatar = self.avatars[key] ?? AvatarNode(font: avatarPlaceholderFont(size: 16))
            self.avatars[key] = avatar
            avatar.cornerRadius = 4
            avatar.clipsToBounds = true
            if avatar.view.superview !== host { host.addSubview(avatar.view) }
            avatar.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            avatar.updateSize(size: CGSize(width: 40, height: 40))
            avatar.setPeer(context: self.context, theme: self.presentationData.theme, peer: peer, clipStyle: .none, displayDimensions: CGSize(width: 40, height: 40))
        }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.stateDisposable.set((blockedPeers.state |> deliverOnMainQueue).startStrict(next: { [weak self] state in
            guard let self else { return }
            self.peers = state.peers.compactMap { $0.peer.map(EnginePeer.init) }
            self.loading = state.isLoadingMore
            self.canLoadMore = state.canLoadMore
            self.updatePresentation()
        }))
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.stateDisposable.dispose()
        self.saveDisposable.dispose()
        self.addDisposable.dispose()
    }

    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.titleButton.setTitle(chinese ? "通讯录黑名单" : "Blocked Users", for: .normal)
        self.titleButton.setTitleColor(control, for: .normal)
        self.titleButton.accessibilityHint = chinese ? "打开添加和编辑黑名单操作" : "Open block and edit actions"
        self.titleButton.isEnabled = !self.content.busy
        self.titleButton.sizeToFit()
        self.titleButton.bounds.size.height = 44
        let image = wegramNavigationBackArrowImage(color: control)
        self.backButton.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: 0, bottom: (44 - size.height) / 2, right: 44 - size.width)
        self.backButton.isUserInteractionEnabled = true
        let backItem = UIBarButtonItem(customDisplayNode: self.backButton)
        backItem?.target = self
        backItem?.action = #selector(self.backPressed)
        backItem?.accessibilityLabel = data.strings.Common_Back
        backItem?.isEnabled = true
        self.navigationItem.leftBarButtonItem = backItem
        self.content.update(dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, chinese: chinese)
        self.content.removeTitle = data.strings.BlockedUsers_Unblock
        self.content.load(rows: self.peers.map { WegramBlockedRow(id: $0.id.toInt64(), name: $0.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder), username: $0.addressName) }, loading: self.loading, canLoadMore: self.canLoadMore)
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
        self.content.table.contentInset.bottom = layout.insets(options: [.input]).bottom
        self.content.table.verticalScrollIndicatorInsets.bottom = layout.insets(options: [.input]).bottom
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top)))
    }

    private func open(_ id: Int64) {
        guard !self.content.busy, let peer = self.peers.first(where: { $0.id.toInt64() == id }) else { return }
        self.content.endEditing(true)
        if let controller = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) { self.push(controller) }
    }
    private func remove(_ id: Int64) {
        guard !self.content.busy, let peer = self.peers.first(where: { $0.id.toInt64() == id }) else { return }
        self.content.busy = true
        self.updatePresentation()
        self.saveDisposable.set((self.blockedPeers.remove(peerId: peer.id) |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
            guard let self else { return }
            self.content.busy = false
            self.updatePresentation()
            self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }, completed: { [weak self] in
            self?.content.busy = false
            self?.updatePresentation()
        }))
    }
    private func openMenu() {
        guard !self.content.busy, self.menu == nil else { return }
        self.content.endEditing(true)
        let strings = self.presentationData.strings
        let sheet = ActionSheetController(theme: ActionSheetControllerTheme(wegramTheme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize))
        self.menu = sheet
        sheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.BlockedUsers_BlockUser, action: { [weak self, weak sheet] in
                    sheet?.dismissAnimated()
                    guard let self else { return }
                    self.push(blockedPeerSelectionController(context: self.context, blockedPeersContext: self.blockedPeers, actionDisposable: self.addDisposable))
                }),
                ActionSheetButtonItem(title: strings.Common_Edit, action: { [weak self, weak sheet] in
                    sheet?.dismissAnimated()
                    guard let self else { return }
                    self.push(blockedPeersController(context: self.context, blockedPeersContext: self.blockedPeers, forceEdit: true))
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strings.Common_Cancel, action: { [weak sheet] in sheet?.dismissAnimated() })])
        ])
        self.present(sheet, in: .window(.root))
    }
    @objc private func backPressed() {
        self.dismiss()
    }
}
