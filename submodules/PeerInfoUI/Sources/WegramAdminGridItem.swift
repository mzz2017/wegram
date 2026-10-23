import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import AvatarNode
import EmojiStatusComponent
import ComponentFlow

final class WegramAdminGridItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let peers: [EnginePeer]
    let members: [WegramAdminGridView.Member]
    let canAdd: Bool
    let editing: Bool
    let title: String
    let info: String
    let sectionId: ItemListSectionId
    let open: (WegramAdminGridView.Action) -> Void
    init(context: AccountContext, presentationData: ItemListPresentationData, peers: [EnginePeer], members: [WegramAdminGridView.Member], canAdd: Bool, editing: Bool, title: String, info: String, sectionId: ItemListSectionId, open: @escaping (WegramAdminGridView.Action) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.peers = peers
        self.members = members
        self.canAdd = canAdd
        self.editing = editing
        self.title = title
        self.info = info
        self.sectionId = sectionId
        self.open = open
    }
    private func layout(_ params: ListViewItemLayoutParams) -> ListViewItemNodeLayout {
        ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: WegramAdminGridView.measure(members: self.members, canAdd: self.canAdd, editing: self.editing, fontSize: self.presentationData.fontSize.baseDisplaySize, info: self.info, width: params.width)), insets: .zero)
    }
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        Queue.mainQueue().async {
            let node = WegramAdminGridItemNode()
            let layout = self.layout(params)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            completion(node, { (nil, { _ in node.update(item: self, size: layout.contentSize) }) })
        }
    }
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let node = node() as? WegramAdminGridItemNode else { return }
            let layout = self.layout(params)
            completion(layout, { _ in node.update(item: self, size: layout.contentSize) })
        }
    }
}

private final class WegramAdminGridItemNode: ListViewItemNode {
    private let content = WegramAdminGridView()
    private var avatars: [Int64: AvatarNode] = [:]
    private var badges: [(Int64, ComponentHostView<Empty>, EmojiStatusComponent)] = []
    private var animationsVisible: Bool {
        if case let .visible(fraction, _) = self.visibility { return fraction > 0.01 }
        return false
    }
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            if case let .visible(_, rect) = self.visibility { self.content.visibleRect = rect } else { self.content.visibleRect = .null }
            let wasVisible: Bool
            if case let .visible(fraction, _) = oldValue { wasVisible = fraction > 0.01 } else { wasVisible = false }
            guard wasVisible != self.animationsVisible else { return }
            for (_, view, component) in self.badges {
                let _ = view.update(transition: .immediate, component: AnyComponent(component.withVisibleForAnimations(self.animationsVisible)), environment: {}, containerSize: CGSize(width: 16, height: 16))
            }
        }
    }
    init() {
        super.init(layerBacked: false)
        self.content.visibleRect = .null
        self.view.addSubview(self.content)
    }
    func update(item: WegramAdminGridItem, size: CGSize) {
        self.badges.removeAll()
        self.content.frame = CGRect(origin: .zero, size: size)
        self.content.releaseAvatar = { [weak self] id, _ in
            self?.avatars.removeValue(forKey: id)?.removeFromSupernode()
            self?.badges.removeAll(where: { $0.0 == id })
        }
        self.content.configureAvatar = { [weak self] id, host in
            guard let self, let peer = item.peers.first(where: { $0.id.toInt64() == id }) else { return }
            let avatar = AvatarNode(font: avatarPlaceholderFont(size: 20))
            avatar.cornerRadius = 4
            avatar.clipsToBounds = true
            self.avatars[id] = avatar
            host.addSubnode(avatar)
            avatar.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, clipStyle: .none, displayDimensions: CGSize(width: 48, height: 48))
            avatar.frame = CGRect(x: 0, y: 0, width: 48, height: 48)
            avatar.updateSize(size: CGSize(width: 48, height: 48))
            var badges: [EmojiStatusComponent.Content] = []
            if peer.isVerified {
                badges.append(.verified(fillColor: item.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .compact))
            } else if !peer.isScam && !peer.isFake {
                if let status = peer.emojiStatus {
                    badges.append(.animation(content: .customEmoji(fileId: status.fileId), size: CGSize(width: 20, height: 20), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(2)))
                } else if peer.isPremium && !PremiumConfiguration.with(appConfiguration: item.context.currentAppConfiguration.with { $0 }).isPremiumDisabled {
                    badges.append(.premium(color: item.presentationData.theme.list.itemAccentColor))
                }
            }
            if let fileId = peer.verificationIconFileId {
                badges.append(.animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 32, height: 32), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(0)))
            }
            for (index, badge) in badges.enumerated() {
                let view = ComponentHostView<Empty>()
                view.isUserInteractionEnabled = false
                let component = EmojiStatusComponent(context: item.context, animationCache: item.context.animationCache, animationRenderer: item.context.animationRenderer, content: badge, isVisibleForAnimations: self.animationsVisible, action: nil, emojiFileUpdated: nil)
                let size = view.update(transition: .immediate, component: AnyComponent(component), environment: {}, containerSize: CGSize(width: 16, height: 16))
                view.frame = CGRect(x: index == 0 ? 32 : 0, y: 32, width: size.width, height: size.height)
                host.addSubview(view)
                self.badges.append((id, view, component))
            }
        }
        self.content.open = item.open
        self.content.update(members: item.members, canAdd: item.canAdd, editing: item.editing, title: item.title, info: item.info, addTitle: item.presentationData.strings.Channel_Management_AddModerator, editTitle: item.presentationData.strings.Common_Edit, doneTitle: item.presentationData.strings.Common_Done, dark: item.presentationData.theme.overallDarkAppearance, fontSize: item.presentationData.fontSize.baseDisplaySize)
        self.content.layoutIfNeeded()
    }
}
