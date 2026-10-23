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
import AnimatedAvatarSetNode

private func callDurationString(strings: PresentationStrings, duration: Int32) -> String {
    if duration < 60 {
        return strings.Call_ShortSeconds(duration)
    } else {
        return strings.Call_ShortMinutes(duration / 60)
    }
}

private func callListNeighbors(item: ListViewItem, neighbors: ListViewItemNeighbors) -> ItemListNeighbors {
    // NOTE: the `item as? ItemListItem` branch is unreachable today — neither CallListCallItem nor
    // CallListGroupCallItem conforms to ItemListItem, and those are the only callers. Preserved
    // verbatim rather than pruned: removing it is a behavior claim, not a refactor.
    let topNeighbor: ItemListNeighbor
    if let topDescriptor = neighbors.previous {
        if let item = item as? ItemListItem, let topItem = topDescriptor.base(ItemListNeighborFacet.self) {
            if topItem.sectionId != item.sectionId {
                topNeighbor = .otherSection(topItem.requestsNoInset ? .none : .full)
            } else {
                topNeighbor = .sameSection(alwaysPlain: topItem.isAlwaysPlain)
            }
        } else {
            if item is CallListCallItem && topDescriptor.base(HeaderNeighborFacet.self)?.headerFamily == .callListCall {
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
            if item is CallListCallItem && bottomDescriptor.base(HeaderNeighborFacet.self)?.headerFamily == .callListCall {
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

class CallListCallItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let context: AccountContext
    let style: ItemListStyle
    let topMessage: EngineMessage
    let messages: [EngineMessage]
    let editing: Bool
    let revealed: Bool
    let interaction: CallListNodeInteraction
    
    let selectable: Bool = true
    let headerAccessoryItem: ListViewAccessoryItem?
    let header: ListViewItemHeader?

    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable(HeaderNeighborDescriptor(headerId: self.header?.id, headerFamily: .callListCall))
    }
    
    init(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, context: AccountContext, style: ItemListStyle, topMessage: EngineMessage, messages: [EngineMessage], editing: Bool, revealed: Bool, displayHeader: Bool, interaction: CallListNodeInteraction) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.context = context
        self.style = style
        self.topMessage = topMessage
        self.messages = messages
        self.editing = editing
        self.revealed = revealed
        self.interaction = interaction
        
        self.headerAccessoryItem = nil
        if displayHeader {
            self.header = ChatListSearchItemHeader(type: .recentCalls, theme: presentationData.theme, strings: presentationData.strings)
        } else {
            self.header = nil
        }
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = CallListCallItemNode()
            let makeLayout = node.asyncLayout()
            let (first, last, firstWithHeader) = CallListCallItem.mergeType(item: self, neighbors: neighbors)
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
            if let nodeValue = node() as? CallListCallItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (first, last, firstWithHeader) = CallListCallItem.mergeType(item: self, neighbors: neighbors)
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
        self.interaction.call(self.topMessage)
    }
    
    static func mergeType(item: CallListCallItem, neighbors: ListViewItemNeighbors) -> (first: Bool, last: Bool, firstWithHeader: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if neighbors.previous != nil {
            if let header = item.header {
                if let previousItem = neighbors.previous?.base(HeaderNeighborFacet.self), previousItem.headerFamily == .callListCall {
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
                if let nextItem = neighbors.next?.base(HeaderNeighborFacet.self), nextItem.headerFamily == .callListCall {
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
private let multipleAvatarFont = avatarPlaceholderFont(size: 12.0)

class CallListCallItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let containerNode: ASDisplayNode
    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    private let avatarNode: AvatarNode
    
    private var conferenceAvatarListContext: AnimatedAvatarSetContext?
    private var conferenceAvatarListNode: AnimatedAvatarSetNode?

    private let titleNode: TextNode
    private var credibilityIconNode: ASImageNode?
    private let statusNode: TextNode
    private let dateNode: TextNode
    private let typeIconNode: ASImageNode
    private let infoButtonNode: HighlightableButtonNode
    
    var editableControlNode: ItemListEditableControlNode?
    
    private let accessibilityArea: AccessibilityAreaNode
    
    private var layoutParams: (CallListCallItem, ListViewItemLayoutParams, Bool, Bool, Bool)?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.containerNode = ASDisplayNode()
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.titleNode = TextNode()
        self.statusNode = TextNode()
        self.dateNode = TextNode()
        
        self.typeIconNode = ASImageNode()
        self.typeIconNode.isLayerBacked = true
        self.typeIconNode.displayWithoutProcessing = true
        self.typeIconNode.displaysAsynchronously = false
        
        self.infoButtonNode = HighlightableButtonNode()
        self.infoButtonNode.hitTestSlop = .zero
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        self.containerNode.addSubnode(self.typeIconNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.statusNode)
        self.containerNode.addSubnode(self.dateNode)
        self.containerNode.addSubnode(self.infoButtonNode)
        self.addSubnode(self.accessibilityArea)
        
        self.infoButtonNode.addTarget(self, action: #selector(self.infoPressed), forControlEvents: .touchUpInside)
        
        self.accessibilityArea.activate = { [weak self] in
            guard let item = self?.layoutParams?.0 else {
                return false
            }
            item.interaction.call(item.topMessage)
            return true
        }
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        if let (item, _, _, _, _) = self.layoutParams {
            let (first, last, firstWithHeader) = CallListCallItem.mergeType(item: item, neighbors: neighbors)
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
    
    func asyncLayout() -> (_ item: CallListCallItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> (Signal<Void, NoError>?, (Bool) -> Void)) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeDateLayout = TextNode.asyncLayout(self.dateNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let currentItem = self.layoutParams?.0
        
        return { [weak self] item, params, first, last, firstWithHeader, neighbors in
            var updatedTheme: PresentationTheme?
            var updatedInfoIcon = false
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
                
                updatedInfoIcon = true
            }
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let statusFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            let dateFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 12.0 / 17.0))
            let multipleAvatarDiameter = min(30.0, floor(item.presentationData.fontSize.itemListBaseFontSize * 30.0 / 17.0))
            
            let editingOffset: CGFloat
            var editableControlSizeAndApply: (CGFloat, (CGFloat) -> ItemListEditableControlNode)?
            if item.editing {
                let sizeAndApply = editableControlLayout(item.presentationData.theme, false)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0
            } else {
                editingOffset = 0.0
            }
            
            let widthLayout = WegramCallRowLayout(width: params.width, height: 72, safeLeft: params.leftInset, safeRight: params.rightInset, editingOffset: editingOffset, revealOffset: 0, editing: item.editing)
            let leftInset = widthLayout.textLeft
            
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let separatorRightInset: CGFloat = params.rightInset
            
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
            var statusAttributedString: NSAttributedString?
            
            var statusAccessibilityString = ""
            
            var titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            var hasMissed = false
            var hasIncoming = false
            var hasOutgoing = false
            var isVideo = false
            
            var hadDuration = false
            var callDuration: Int32?
            
            var isConference = false
            var conferenceIsDeclined = false
            
            let _ = isConference
            let _ = conferenceIsDeclined

            var conferenceAvatars: [EnginePeer] = []
            
            for message in item.messages {
                inner: for media in message.media {
                    if let action = media as? TelegramMediaAction {
                        if case let .phoneCall(_, discardReason, duration, video) = action.action {
                            isVideo = video
                            if message.flags.contains(.Incoming) {
                                hasIncoming = true
                                
                                if let discardReason = discardReason, case .missed = discardReason {
                                    titleColor = item.presentationData.theme.list.itemDestructiveColor
                                    hasMissed = true
                                }
                            } else {
                                hasOutgoing = true
                            }
                            if callDuration == nil && !hadDuration {
                                hadDuration = true
                                callDuration = duration
                            } else {
                                callDuration = nil
                            }
                        } else if case let .conferenceCall(conferenceCall) = action.action {
                            isConference = true

                            if let peer = message.peers[message.id.peerId], !conferenceAvatars.contains(where: { $0.id == peer.id }) {
                                conferenceAvatars.append(EnginePeer(peer))
                            }

                            for id in conferenceCall.otherParticipants {
                                if let peer = message.peers[id], !conferenceAvatars.contains(where: { $0.id == peer.id }) {
                                    conferenceAvatars.append(EnginePeer(peer))
                                }
                            }
                            
                            isVideo = conferenceCall.flags.contains(.isVideo)
                            if message.flags.contains(.Incoming) {
                                hasIncoming = true
                                let missedTimeout: Int32
                                #if DEBUG && false
                                missedTimeout = 5
                                #else
                                missedTimeout = 30
                                #endif
                                let currentTime = Int32(Date().timeIntervalSince1970)
                                if conferenceCall.flags.contains(.isMissed) {
                                    titleColor = item.presentationData.theme.list.itemDestructiveColor
                                    conferenceIsDeclined = true
                                } else if message.timestamp < currentTime - missedTimeout {
                                    titleColor = item.presentationData.theme.list.itemDestructiveColor
                                    hasMissed = true
                                }
                            } else {
                                hasOutgoing = true
                            }
                            if callDuration == nil && !hadDuration {
                                hadDuration = true
                                callDuration = conferenceCall.duration
                            } else {
                                callDuration = nil
                            }
                        }
                        break inner
                    }
                }
            }
            
            if let peer = item.topMessage.peers[item.topMessage.id.peerId] {
                if conferenceAvatars.count > 1 {
                    var peersString = ""
                    for peer in conferenceAvatars {
                        if !peersString.isEmpty {
                            peersString.append(", ")
                        }
                        if peer.id == item.context.account.peerId {
                            peersString += item.presentationData.strings.DialogList_You
                        } else {
                            peersString += peer.compactDisplayTitle
                        }
                    }
                    titleAttributedString = NSAttributedString(string: peersString, font: titleFont, textColor: titleColor)
                } else if let user = peer as? TelegramUser {
                    if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                        let string = NSMutableAttributedString()
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: lastName, font: titleFont, textColor: titleColor))
                        if item.messages.count > 1 {
                            string.append(NSAttributedString(string: " (\(item.messages.count))", font: titleFont, textColor: titleColor))
                        }
                        titleAttributedString = string
                    } else if let firstName = user.firstName, !firstName.isEmpty {
                        titleAttributedString = NSAttributedString(string: firstName, font: titleFont, textColor: titleColor)
                    } else if let lastName = user.lastName, !lastName.isEmpty {
                        titleAttributedString = NSAttributedString(string: lastName, font: titleFont, textColor: titleColor)
                    } else {
                        titleAttributedString = NSAttributedString(string: item.presentationData.strings.User_DeletedAccount, font: titleFont, textColor: titleColor)
                    }
                } else if let group = peer as? TelegramGroup {
                    titleAttributedString = NSAttributedString(string: group.title, font: titleFont, textColor: titleColor)
                } else if let channel = peer as? TelegramChannel {
                    titleAttributedString = NSAttributedString(string: channel.title, font: titleFont, textColor: titleColor)
                }
                
                if hasMissed {
                    statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallMissedShort, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                    statusAccessibilityString = isVideo ? item.presentationData.strings.Call_VoiceOver_VideoCallMissed : item.presentationData.strings.Call_VoiceOver_VoiceCallMissed
                } else if hasIncoming && hasOutgoing {
                    statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallOutgoingShort + ", " + item.presentationData.strings.Notification_CallIncomingShort, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                    statusAccessibilityString = isVideo ? (item.presentationData.strings.Call_VoiceOver_VideoCallOutgoing + ", " + item.presentationData.strings.Call_VoiceOver_VideoCallIncoming) : (item.presentationData.strings.Call_VoiceOver_VoiceCallOutgoing + ", " + item.presentationData.strings.Call_VoiceOver_VoiceCallIncoming)
                } else if hasIncoming {
                    if let callDuration = callDuration, callDuration != 0 {
                        statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallTimeFormat(item.presentationData.strings.Notification_CallIncomingShort, callDurationString(strings: item.presentationData.strings, duration: callDuration)).string, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                        statusAccessibilityString = item.presentationData.strings.Notification_CallTimeFormat(isVideo ? item.presentationData.strings.Call_VoiceOver_VideoCallIncoming : item.presentationData.strings.Call_VoiceOver_VoiceCallIncoming, callDurationString(strings: item.presentationData.strings, duration: callDuration)).string
                        
                    } else {
                        statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallIncomingShort, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                        statusAccessibilityString = isVideo ? item.presentationData.strings.Call_VoiceOver_VideoCallIncoming : item.presentationData.strings.Call_VoiceOver_VoiceCallIncoming
                    }
                } else {
                    if let callDuration = callDuration, callDuration != 0 {
                        statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallTimeFormat(item.presentationData.strings.Notification_CallOutgoingShort, callDurationString(strings: item.presentationData.strings, duration: callDuration)).string, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                        statusAccessibilityString = item.presentationData.strings.Notification_CallTimeFormat(isVideo ? item.presentationData.strings.Call_VoiceOver_VideoCallOutgoing : item.presentationData.strings.Call_VoiceOver_VoiceCallOutgoing, callDurationString(strings: item.presentationData.strings, duration: callDuration)).string
                    } else {
                        statusAttributedString = NSAttributedString(string: item.presentationData.strings.Notification_CallOutgoingShort, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                        statusAccessibilityString = isVideo ? item.presentationData.strings.Call_VoiceOver_VideoCallOutgoing : item.presentationData.strings.Call_VoiceOver_VoiceCallOutgoing
                    }
                }
            }
            
            var t = Int(item.topMessage.timestamp)
            var timeinfo = tm()
            localtime_r(&t, &timeinfo)
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            let dateText = stringForRelativeTimestamp(strings: item.presentationData.strings, relativeTimestamp: item.topMessage.timestamp, relativeTo: timestamp, dateTimeFormat: item.dateTimeFormat)
            
            let outgoingVoiceIcon = PresentationResourcesCallList.outgoingIcon(item.presentationData.theme)
            let outgoingVideoIcon = PresentationResourcesCallList.outgoingVideoIcon(item.presentationData.theme)
            let infoIcon = PresentationResourcesCallList.infoButton(item.presentationData.theme)
            let outgoingIcon = isVideo ? outgoingVideoIcon : outgoingVoiceIcon
            let typeIconWidth: CGFloat = hasOutgoing ? (outgoingIcon?.size.width ?? 0) : 0
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: item.context.currentAppConfiguration.with { $0 })
            var currentCredibilityIconImage: UIImage?
            if let peer = item.topMessage.peers[item.topMessage.id.peerId], peer.id != item.context.account.peerId {
                if peer.isScam {
                    currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(item.presentationData.theme, strings: item.presentationData.strings, type: .regular)
                } else if peer.isFake {
                    currentCredibilityIconImage = PresentationResourcesChatList.fakeIcon(item.presentationData.theme, strings: item.presentationData.strings, type: .regular)
                } else if peer.isVerified {
                    currentCredibilityIconImage = PresentationResourcesChatList.verifiedIcon(item.presentationData.theme)
                } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                    currentCredibilityIconImage = PresentationResourcesChatList.premiumIcon(item.presentationData.theme)
                }
            }
            
            var additionalTitleInset: CGFloat = 0.0
            if let currentCredibilityIconImage = currentCredibilityIconImage {
                additionalTitleInset += 3.0 + currentCredibilityIconImage.size.width
            }
            let (dateLayout, dateApply) = makeDateLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: dateText, font: dateFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: widthLayout.dateMaxWidth(credibilityWidth: additionalTitleInset), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: widthLayout.titleWidth(dateWidth: dateLayout.size.width, credibilityWidth: additionalTitleInset), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: widthLayout.statusWidth(typeIconWidth: typeIconWidth), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: WegramCallRowLayout.height(titleHeight: titleLayout.size.height, statusHeight: statusLayout.size.height)), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            let contentSize = nodeLayout.contentSize
            
            return (nodeLayout, { [weak self] synchronousLoads in
                if let strongSelf = self {
                    if let peer = item.topMessage.peers[item.topMessage.id.peerId] {
                        var overrideImage: AvatarNodeImageOverride?
                        if peer.isDeleted {
                            overrideImage = .deletedIcon
                        }
                        strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: EnginePeer(peer), overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, clipStyle: .none, synchronousLoad: synchronousLoads, displayDimensions: CGSize(width: 40, height: 40))
                    }
                    
                    return (strongSelf.avatarNode.ready, { [weak strongSelf] animated in
                        if let strongSelf = strongSelf {
                            strongSelf.layoutParams = (item, params, first, last, firstWithHeader)
                            
                            let revealOffset = strongSelf.revealOffset
                            let rowLayout = WegramCallRowLayout(width: params.width, height: contentSize.height, safeLeft: params.leftInset, safeRight: params.rightInset, editingOffset: editingOffset, revealOffset: revealOffset, editing: item.editing)
                            
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
                            
                            if let editableControlSizeAndApply = editableControlSizeAndApply {
                                let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: 0.0), size: CGSize(width: editableControlSizeAndApply.0, height: nodeLayout.contentSize.height))
                                if strongSelf.editableControlNode == nil {
                                    let editableControlNode = editableControlSizeAndApply.1(nodeLayout.contentSize.height)
                                    editableControlNode.tapped = {
                                        if let strongSelf = self {
                                            strongSelf.setRevealOptionsOpened(true, animated: true)
                                            strongSelf.revealOptionsInteractivelyOpened()
                                        }
                                    }
                                    strongSelf.editableControlNode = editableControlNode
                                    strongSelf.addSubnode(editableControlNode)
                                    editableControlNode.frame = editableControlFrame
                                    transition.animatePosition(node: editableControlNode, from: CGPoint(x: -editableControlFrame.size.width / 2.0, y: editableControlFrame.midY))
                                    editableControlNode.alpha = 0.0
                                    transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                                } else {
                                    strongSelf.editableControlNode?.frame = editableControlFrame
                                }
                            } else if let editableControlNode = strongSelf.editableControlNode {
                                var editableControlFrame = editableControlNode.frame
                                editableControlFrame.origin.x = -editableControlFrame.size.width
                                strongSelf.editableControlNode = nil
                                transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                                transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                                    editableControlNode?.removeFromSupernode()
                                })
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
                                    transition.updateFrameAdditive(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset - separatorRightInset, height: separatorHeight)))
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
                                            strongSelf.bottomStripeNode.isHidden = false
                                        default:
                                            bottomStripeInset = 0.0
                                            strongSelf.bottomStripeNode.isHidden = false
                                    }
                                
                                    
                                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                                    transition.updateFrameAdditive(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width - bottomStripeInset - separatorRightInset, height: separatorHeight)))
                            }
                            
                    
                            let avatarFrame = rowLayout.avatar
                            strongSelf.avatarNode.cornerRadius = 4
                            strongSelf.avatarNode.clipsToBounds = true
                            transition.updateFrameAdditive(node: strongSelf.avatarNode, frame: avatarFrame)
                            strongSelf.avatarNode.updateSize(size: avatarFrame.size)

                            if conferenceAvatars.count > 1 {
                                strongSelf.avatarNode.isHidden = true

                                let conferenceAvatarListContext: AnimatedAvatarSetContext
                                if let current = strongSelf.conferenceAvatarListContext {
                                    conferenceAvatarListContext = current
                                } else {
                                    conferenceAvatarListContext = AnimatedAvatarSetContext()
                                    strongSelf.conferenceAvatarListContext = conferenceAvatarListContext
                                }
                                let conferenceAvatarListNode: AnimatedAvatarSetNode
                                if let current = strongSelf.conferenceAvatarListNode {
                                    conferenceAvatarListNode = current
                                } else {
                                    conferenceAvatarListNode = AnimatedAvatarSetNode()
                                    strongSelf.conferenceAvatarListNode = conferenceAvatarListNode
                                    strongSelf.containerNode.addSubnode(conferenceAvatarListNode)
                                }
                                let avatarListContents = conferenceAvatarListContext.update(peers: Array(conferenceAvatars.prefix(3)), animated: false)
                                let avatarListSize = conferenceAvatarListNode.update(context: item.context, content: avatarListContents, itemSize: CGSize(width: CGFloat(multipleAvatarDiameter), height: CGFloat(multipleAvatarDiameter)), customSpacing: multipleAvatarDiameter - 8.0, font: multipleAvatarFont, animated: false, synchronousLoad: synchronousLoads)
                                conferenceAvatarListNode.frame = CGRect(origin: CGPoint(x: avatarFrame.minX + floor((avatarFrame.width - avatarListSize.width) / 2.0), y: avatarFrame.minY + floor((avatarFrame.height - avatarListSize.height) / 2.0)), size: avatarListSize)
                            } else {
                                strongSelf.avatarNode.isHidden = false
                                
                                strongSelf.conferenceAvatarListContext = nil
                                if let conferenceAvatarListNode = strongSelf.conferenceAvatarListNode {
                                    strongSelf.conferenceAvatarListNode = nil
                                    conferenceAvatarListNode.removeFromSupernode()
                                }
                            }
                            
                            let _ = titleApply()
                            let titleFrame = rowLayout.title(size: titleLayout.size)
                            transition.updateFrameAdditive(node: strongSelf.titleNode, frame: titleFrame)
                            
                            let _ = statusApply()
                            let statusFrame = rowLayout.status(size: statusLayout.size, titleHeight: titleLayout.size.height, typeIconWidth: typeIconWidth)
                            transition.updateFrameAdditive(node: strongSelf.statusNode, frame: statusFrame)
                            
                            if let currentCredibilityIconImage = currentCredibilityIconImage {
                                let iconNode: ASImageNode
                                if let current = strongSelf.credibilityIconNode {
                                    iconNode = current
                                } else {
                                    iconNode = ASImageNode()
                                    iconNode.isLayerBacked = true
                                    iconNode.displaysAsynchronously = false
                                    iconNode.displayWithoutProcessing = true
                                    strongSelf.credibilityIconNode = iconNode
                                    strongSelf.containerNode.addSubnode(iconNode)
                                }
                                iconNode.image = currentCredibilityIconImage
                                transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floorToScreenPixels(titleFrame.midY - currentCredibilityIconImage.size.height / 2.0) - UIScreenPixel), size: currentCredibilityIconImage.size))
                            } else if let credibilityIconNode = strongSelf.credibilityIconNode {
                                strongSelf.credibilityIconNode = nil
                                credibilityIconNode.removeFromSupernode()
                            }
                            
                            let _ = dateApply()
                            transition.updateFrameAdditive(node: strongSelf.dateNode, frame: rowLayout.date(size: dateLayout.size, titleHeight: titleLayout.size.height))
                            
                            if let outgoingIcon = outgoingIcon {
                                if strongSelf.typeIconNode.image !== outgoingIcon {
                                    strongSelf.typeIconNode.image = outgoingIcon
                                }
                                transition.updateFrameAdditive(node: strongSelf.typeIconNode, frame: rowLayout.typeIcon(size: outgoingIcon.size, statusFrame: statusFrame))
                            }
                            strongSelf.typeIconNode.isHidden = !hasOutgoing
                            
                            if let infoIcon = infoIcon {
                                if updatedInfoIcon {
                                    strongSelf.infoButtonNode.setImage(infoIcon, for: [])
                                }
                                strongSelf.infoButtonNode.contentEdgeInsets = UIEdgeInsets(top: (44 - infoIcon.size.height) * 0.5, left: (44 - infoIcon.size.width) * 0.5, bottom: (44 - infoIcon.size.height) * 0.5, right: (44 - infoIcon.size.width) * 0.5)
                            }
                            transition.updateFrameAdditive(node: strongSelf.infoButtonNode, frame: rowLayout.info)
                            strongSelf.infoButtonNode.isUserInteractionEnabled = !item.editing
                            strongSelf.infoButtonNode.isAccessibilityElement = !item.editing
                            transition.updateAlpha(node: strongSelf.infoButtonNode, alpha: item.editing ? 0.0 : 1.0)
                            
                            var topHighlightInset: CGFloat = (first || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                            topHighlightInset -= nodeLayout.insets.top
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                            strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: strongSelf.backgroundNode.frame.size)
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                            
                            strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                            
                            strongSelf.accessibilityArea.accessibilityLabel = titleAttributedString?.string
                            if let peer = item.topMessage.peers[item.topMessage.id.peerId] {
                                if peer.isScam {
                                    strongSelf.accessibilityArea.accessibilityLabel = (titleAttributedString?.string ?? "") + ", " + item.presentationData.strings.Message_ScamAccount
                                } else if peer.isFake {
                                    strongSelf.accessibilityArea.accessibilityLabel = (titleAttributedString?.string ?? "") + ", " + item.presentationData.strings.Message_FakeAccount
                                }
                            }
                            strongSelf.accessibilityArea.accessibilityValue = statusAccessibilityString + "\n" + dateText
                            strongSelf.accessibilityArea.frame = CGRect(x: 0, y: 0, width: item.editing ? contentSize.width : max(0, rowLayout.info.minX), height: contentSize.height)
                            
                            strongSelf.infoButtonNode.accessibilityLabel = item.presentationData.strings.Conversation_Info
                            
                            strongSelf.view.accessibilityCustomActions = [UIAccessibilityCustomAction(name: item.presentationData.strings.Common_Delete, target: strongSelf, selector: #selector(strongSelf.performLocalAccessibilityCustomAction(_:)))]
                            
                            strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, iconColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor, textColor: item.presentationData.theme.list.itemSecondaryTextColor)]))
                            strongSelf.setRevealOptionsOpened(item.revealed, animated: animated)
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
    
    @objc func infoPressed() {
        if let item = self.layoutParams?.0, !item.editing {
            item.interaction.openInfo(item.topMessage.id.peerId, item.messages)
        }
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.layoutParams?.0 {
            item.interaction.setMessageIdWithRevealedOptions(item.topMessage.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.layoutParams?.0 {
            item.interaction.setMessageIdWithRevealedOptions(nil, item.topMessage.id)
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let (item, params, _, _, _) = self.layoutParams {
            let revealOffset = offset
            
            let editingOffset: CGFloat
            if let editableControlNode = self.editableControlNode {
                editingOffset = editableControlNode.bounds.size.width
                var editableControlFrame = editableControlNode.frame
                editableControlFrame.origin.x = params.leftInset + offset
                transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
            } else {
                editingOffset = 0.0
            }
            
            let rowLayout = WegramCallRowLayout(width: params.width, height: self.contentSize.height, safeLeft: params.leftInset, safeRight: params.rightInset, editingOffset: item.editing ? editingOffset : 0, revealOffset: revealOffset, editing: item.editing)
            let avatarFrame = rowLayout.avatar
            transition.updateFrameAdditive(node: self.avatarNode, frame: avatarFrame)
            
            if let conferenceAvatarListNode = self.conferenceAvatarListNode {
                var conferenceAvatarFrame = conferenceAvatarListNode.frame
                conferenceAvatarFrame.origin.x = avatarFrame.minX + floor((avatarFrame.width - conferenceAvatarFrame.width) / 2.0)
                transition.updateFrameAdditive(node: conferenceAvatarListNode, frame: conferenceAvatarFrame)
            }
            
            let titleFrame = rowLayout.title(size: self.titleNode.bounds.size)
            transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
            if let iconNode = self.credibilityIconNode {
                transition.updateFrameAdditive(node: iconNode, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4, y: iconNode.frame.minY), size: iconNode.bounds.size))
            }
            let statusFrame = rowLayout.status(size: self.statusNode.bounds.size, titleHeight: self.titleNode.bounds.height, typeIconWidth: self.typeIconNode.isHidden ? 0 : self.typeIconNode.bounds.width)
            transition.updateFrameAdditive(node: self.statusNode, frame: statusFrame)
            transition.updateFrameAdditive(node: self.dateNode, frame: rowLayout.date(size: self.dateNode.bounds.size, titleHeight: self.titleNode.bounds.height))
            transition.updateFrameAdditive(node: self.typeIconNode, frame: rowLayout.typeIcon(size: self.typeIconNode.bounds.size, statusFrame: statusFrame))
            transition.updateFrameAdditive(node: self.infoButtonNode, frame: rowLayout.info)
            self.accessibilityArea.frame = CGRect(x: max(0, revealOffset), y: 0, width: max(0, (item.editing ? params.width + revealOffset : rowLayout.info.minX) - max(0, revealOffset)), height: self.contentSize.height)
        }
    }

    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        if let item = self.layoutParams?.0 {
            item.interaction.delete(item.messages.map { $0.id })
        }
    }
    
    @objc private func performLocalAccessibilityCustomAction(_ action: UIAccessibilityCustomAction) {
        if let item = self.layoutParams?.0 {
            item.interaction.delete(item.messages.map { $0.id })
        }
    }
}

public extension ListViewItemHeaderFamily {
    static let callListCall = ListViewItemHeaderFamily("callListCall")
}
