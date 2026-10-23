import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import AccountContext
import ChatListSearchItemHeader
import PeerOnlineMarkerNode

private func callListNeighbors(item: ListViewItem, neighbors: ListViewItemNeighbors) -> ItemListNeighbors {
    // A private duplicate of the same-named helper in CallListCallItem.swift, differing only in
    // the item type it groups. As there, the `item as? ItemListItem` branch is unreachable today
    // and preserved rather than pruned.
    let topNeighbor: ItemListNeighbor
    if let topDescriptor = neighbors.previous {
        if let item = item as? ItemListItem, let topItem = topDescriptor.base(ItemListNeighborFacet.self) {
            if topItem.sectionId != item.sectionId {
                topNeighbor = .otherSection(topItem.requestsNoInset ? .none : .full)
            } else {
                topNeighbor = .sameSection(alwaysPlain: topItem.isAlwaysPlain)
            }
        } else {
            if item is CallListGroupCallItem && topDescriptor.base(HeaderNeighborFacet.self)?.headerFamily == .callListGroupCall {
                topNeighbor = .sameSection(alwaysPlain: false)
            } else {
                topNeighbor = .otherSection(.full)
            }
        }
    } else {
        topNeighbor = .none
    }
    
    let bottomNeighbor: ItemListNeighbor
    if let bottomDescriptor = neighbors.next {
        if let item = item as? ItemListItem, let bottomItem = bottomDescriptor.base(ItemListNeighborFacet.self) {
            if bottomItem.sectionId != item.sectionId {
                bottomNeighbor = .otherSection(bottomItem.requestsNoInset ? .none : .full)
            } else {
                bottomNeighbor = .sameSection(alwaysPlain: bottomItem.isAlwaysPlain)
            }
        } else {
            if item is CallListGroupCallItem && bottomDescriptor.base(HeaderNeighborFacet.self)?.headerFamily == .callListGroupCall {
                bottomNeighbor = .sameSection(alwaysPlain: false)
            } else {
                bottomNeighbor = .otherSection(.full)
            }
        }
    } else {
        bottomNeighbor = .none
    }
    
    return ItemListNeighbors(top: topNeighbor, bottom: bottomNeighbor)
}

class CallListGroupCallItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let context: AccountContext
    let style: ItemListStyle
    let peer: EnginePeer
    let isActive: Bool
    let editing: Bool
    let interaction: CallListNodeInteraction
    
    let selectable: Bool = true
    let headerAccessoryItem: ListViewAccessoryItem?
    let header: ListViewItemHeader?

    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable(HeaderNeighborDescriptor(headerId: self.header?.id, headerFamily: .callListGroupCall))
    }
    
    init(presentationData: ItemListPresentationData, context: AccountContext, style: ItemListStyle, peer: EnginePeer, isActive: Bool, editing: Bool, interaction: CallListNodeInteraction) {
        self.presentationData = presentationData
        self.context = context
        self.style = style
        self.peer = peer
        self.isActive = isActive
        self.editing = editing
        self.interaction = interaction
        
        self.headerAccessoryItem = nil
        self.header = ChatListSearchItemHeader(type: .activeVoiceChats, theme: presentationData.theme, strings: presentationData.strings)
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = CallListGroupCallItemNode()
            let makeLayout = node.asyncLayout()
            let (first, last, firstWithHeader) = CallListGroupCallItem.mergeType(item: self, neighbors: neighbors)
            let (nodeLayout, nodeApply) = makeLayout(self, params, first, last, firstWithHeader, callListNeighbors(item: self, neighbors: neighbors))
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        nodeApply(synchronousLoads).1(false)
                    })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? CallListGroupCallItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (first, last, firstWithHeader) = CallListGroupCallItem.mergeType(item: self, neighbors: neighbors)
                    let (nodeLayout, apply) = layout(self, params, first, last, firstWithHeader, callListNeighbors(item: self, neighbors: neighbors))
                    var animated = true
                    if case .None = animation {
                        animated = false
                    }
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(false).1(animated)
                        })
                    }
                }
            }
        }
    }
    
    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.interaction.openGroupCall(self.peer.id)
    }
    
    static func mergeType(item: CallListGroupCallItem, neighbors: ListViewItemNeighbors) -> (first: Bool, last: Bool, firstWithHeader: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if neighbors.previous != nil {
            if let header = item.header {
                if let previousItem = neighbors.previous?.base(HeaderNeighborFacet.self), previousItem.headerFamily == .callListGroupCall {
                    firstWithHeader = header.id != previousItem.headerId
                } else {
                    firstWithHeader = true
                }
            }
        } else {
            first = true
            firstWithHeader = item.header != nil
        }
        if neighbors.next != nil {
            if let header = item.header {
                if let nextItem = neighbors.next?.base(HeaderNeighborFacet.self), nextItem.headerFamily == .callListGroupCall {
                    last = header.id != nextItem.headerId
                } else {
                    last = true
                }
            }
        } else {
            last = true
        }
        return (first, last, firstWithHeader)
    }
}

private let avatarFont = avatarPlaceholderFont(size: 16.0)

class CallListGroupCallItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let indicatorNode: VoiceChatIndicatorNode
    private let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let joinButtonNode: HighlightableButtonNode
    private let joinTitleNode: TextNode
    private let joinBackgroundNode: ASImageNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    private var layoutParams: (CallListGroupCallItem, ListViewItemLayoutParams, Bool, Bool, Bool)?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.indicatorNode = VoiceChatIndicatorNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.titleNode = TextNode()
        
        self.joinButtonNode = HighlightableButtonNode()
        self.joinButtonNode.hitTestSlop = .zero
        
        self.joinTitleNode = TextNode()
        self.joinTitleNode.isUserInteractionEnabled = false
        self.joinTitleNode.isAccessibilityElement = false
        self.joinBackgroundNode = ASImageNode()
        self.joinBackgroundNode.isUserInteractionEnabled = false
        self.joinBackgroundNode.isAccessibilityElement = false
        self.joinButtonNode.addSubnode(self.joinBackgroundNode)
        self.joinButtonNode.addSubnode(self.joinTitleNode)
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.indicatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.joinButtonNode)
        self.addSubnode(self.accessibilityArea)
        
        self.joinButtonNode.addTarget(self, action: #selector(self.joinPressed), forControlEvents: .touchUpInside)
        
        self.accessibilityArea.activate = { [weak self] in
            guard let item = self?.layoutParams?.0 else {
                return false
            }
            item.interaction.openGroupCall(item.peer.id)
            return true
        }
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        if let (item, _, _, _, _) = self.layoutParams {
            let (first, last, firstWithHeader) = CallListGroupCallItem.mergeType(item: item, neighbors: neighbors)
            self.layoutParams = (item, params, first, last, firstWithHeader)
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, first, last, firstWithHeader, callListNeighbors(item: item, neighbors: neighbors))
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            nodeApply(false).1(false)
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                if self.backgroundNode.supernode != nil {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.backgroundNode)
                } else {
                    self.insertSubnode(self.highlightedBackgroundNode, at: 0)
                }
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    func asyncLayout() -> (_ item: CallListGroupCallItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> (Signal<Void, NoError>?, (Bool) -> Void)) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeJoinTitleLayout = TextNode.asyncLayout(self.joinTitleNode)
        let currentItem = self.layoutParams?.0
        
        return { [weak self] item, params, first, last, firstWithHeader, neighbors in
            var updatedTheme: PresentationTheme?
            
            var updatedJoinBackground: UIImage?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
                updatedJoinBackground = generateStretchableFilledCircleImage(diameter: 10.0, color: item.presentationData.theme.list.itemCheckColors.fillColor)
            }
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            let editingOffset: CGFloat
            if item.editing {
                editingOffset = 16.0
            } else {
                editingOffset = 0.0
            }
            
            let leftInset: CGFloat = 68 + params.leftInset + editingOffset
            
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    insets = itemListNeighborsPlainInsets(neighbors)
                case .blocks:
                    itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            var titleAttributedString: NSAttributedString?
            
            let titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            
            titleAttributedString = NSAttributedString(string: item.peer.compactDisplayTitle, font: titleFont, textColor: titleColor)
            
            let (joinTitleLayout, joinTitleApply) = makeJoinTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.VoiceChat_PanelJoin, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: WegramGroupCallRowLayout.joinTextMaxWidth(width: params.width, safeLeft: params.leftInset, safeRight: params.rightInset, editingOffset: editingOffset), height: CGFloat.infinity), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: WegramGroupCallRowLayout.titleMaxWidth(width: params.width, safeLeft: params.leftInset, safeRight: params.rightInset, editingOffset: editingOffset, joinTextWidth: joinTitleLayout.size.width, active: item.isActive), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let measuredLayout = WegramGroupCallRowLayout(width: params.width, safeLeft: params.leftInset, safeRight: params.rightInset, editingOffset: editingOffset, revealOffset: 0, titleSize: titleLayout.size, joinTextSize: joinTitleLayout.size, active: item.isActive)
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: measuredLayout.height), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            let contentSize = nodeLayout.contentSize
            
            return (nodeLayout, { [weak self] synchronousLoads in
                if let strongSelf = self {
                    let peer = item.peer
                    var overrideImage: AvatarNodeImageOverride?
                    if peer.isDeleted {
                        overrideImage = .deletedIcon
                    }
                    strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, clipStyle: .none, synchronousLoad: synchronousLoads, displayDimensions: CGSize(width: 40, height: 40))
                    
                    return (strongSelf.avatarNode.ready, { [weak strongSelf] animated in
                        if let strongSelf = strongSelf {
                            strongSelf.layoutParams = (item, params, first, last, firstWithHeader)
                            
                            let revealOffset = strongSelf.revealOffset
                            let rowLayout = WegramGroupCallRowLayout(width: params.width, safeLeft: params.leftInset, safeRight: params.rightInset, editingOffset: editingOffset, revealOffset: revealOffset, titleSize: titleLayout.size, joinTextSize: joinTitleLayout.size, active: item.isActive)
                            
                            let transition: ContainedViewLayoutTransition
                            if animated {
                                transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                            } else {
                                transition = .immediate
                            }
                            
                            if let _ = updatedTheme {
                                strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                                strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                                strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                                strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                            }
                            
                            switch item.style {
                                case .plain:
                                    if strongSelf.backgroundNode.supernode == nil {
                                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                                    }
                                    if strongSelf.topStripeNode.supernode != nil {
                                        strongSelf.topStripeNode.removeFromSupernode()
                                    }
                                    if !last && strongSelf.bottomStripeNode.supernode == nil {
                                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 1)
                                    } else if last && strongSelf.bottomStripeNode.supernode != nil {
                                        strongSelf.bottomStripeNode.removeFromSupernode()
                                    }
                                    
                                    transition.updateFrameAdditive(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset - params.rightInset, height: separatorHeight)))
                                case .blocks:
                                    if strongSelf.backgroundNode.supernode == nil {
                                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                                    }
                                    if strongSelf.topStripeNode.supernode == nil {
                                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                                    }
                                    if strongSelf.bottomStripeNode.supernode == nil {
                                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                                    }
                                    switch neighbors.top {
                                        case .sameSection(false):
                                            strongSelf.topStripeNode.isHidden = true
                                        default:
                                            strongSelf.topStripeNode.isHidden = false
                                    }
                                    let bottomStripeInset: CGFloat
                                    switch neighbors.bottom {
                                        case .sameSection(false):
                                            bottomStripeInset = leftInset
                                        default:
                                            bottomStripeInset = 0.0
                                    }
                                    
                                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                                    transition.updateFrameAdditive(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width - bottomStripeInset - params.rightInset, height: separatorHeight)))
                            }
                            
                            let avatarFrame = rowLayout.avatar
                            strongSelf.avatarNode.cornerRadius = 4
                            strongSelf.avatarNode.clipsToBounds = true
                            transition.updateFrameAdditive(node: strongSelf.avatarNode, frame: avatarFrame)
                            strongSelf.avatarNode.updateSize(size: avatarFrame.size)
                            
                            strongSelf.indicatorNode.color = item.presentationData.theme.chatList.checkmarkColor
                            transition.updateFrameAdditive(node: strongSelf.indicatorNode, frame: rowLayout.indicator)
                            
                            let _ = titleApply()
                            transition.updateFrameAdditive(node: strongSelf.titleNode, frame: rowLayout.title)
                            
                            let joinButtonFrame = rowLayout.join
                            transition.updateFrameAdditive(node: strongSelf.joinButtonNode, frame: joinButtonFrame)
                            
                            transition.updateAlpha(node: strongSelf.joinButtonNode, alpha: item.isActive ? 0.0 : 1.0)
                            strongSelf.joinButtonNode.isUserInteractionEnabled = !item.isActive
                            strongSelf.joinButtonNode.isAccessibilityElement = !item.isActive
                            
                            if let image = updatedJoinBackground {
                                strongSelf.joinBackgroundNode.image = image
                            }
                            transition.updateFrameAdditive(node: strongSelf.joinBackgroundNode, frame: rowLayout.joinBackground)
                            
                            let _ = joinTitleApply()
                            transition.updateFrameAdditive(node: strongSelf.joinTitleNode, frame: rowLayout.joinText)
                            
                            var topHighlightInset: CGFloat = (first || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                            topHighlightInset -= nodeLayout.insets.top
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                            
                            strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                            
                            strongSelf.accessibilityArea.accessibilityTraits = .button
                            strongSelf.accessibilityArea.accessibilityLabel = titleAttributedString?.string
                            strongSelf.accessibilityArea.frame = CGRect(x: 0, y: 0, width: item.isActive ? contentSize.width : max(0, rowLayout.join.minX), height: contentSize.height)
                            strongSelf.accessibilityArea.accessibilityValue = item.isActive ? (item.presentationData.strings.baseLanguageCode.hasPrefix("zh") ? "当前通话" : "Current Call") : nil
                            
                            strongSelf.joinButtonNode.accessibilityLabel = item.presentationData.strings.VoiceChat_PanelJoin
                        }
                    })
                } else {
                    return (nil, { _ in })
                }
            })
        }
    }
    
    override func layoutHeaderAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        let bounds = self.bounds
        accessoryItemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -29.0), size: CGSize(width: bounds.size.width, height: 29.0))
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.3, removeOnCompletion: false)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let (item, _, _, _, _) = self.layoutParams {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
    
    @objc private func joinPressed() {
        if let item = self.layoutParams?.0, !item.isActive {
            item.interaction.openGroupCall(item.peer.id)
        }
    }
}

public extension ListViewItemHeaderFamily {
    static let callListGroupCall = ListViewItemHeaderFamily("callListGroupCall")
}
