import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import WallpaperBackgroundNode
import ChatControllerInteraction
import ChatMessageItem
import ChatMessageItemCommon

private let titleFont = UIFont.systemFont(ofSize: 13.0)

public class ChatUnreadItem: ListViewItem, ChatHistoryItemWithHeaders {
    public let index: EngineMessage.Index
    public let presentationData: ChatPresentationData
    public let controllerInteraction: ChatControllerInteraction
    public let header: ChatMessageDateHeader
    public let usesWegramAppearance: Bool

    // The item-side mirror of the node's `headers()` override below. Load-bearing under the CoreList
    // backend: an unread separator that published nothing would split its day's header run in two.
    public var headers: [ListViewItemHeader] {
        return [self.header]
    }

    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable(ChatHistoryItemNeighbor.unread(dateHeaderId: self.header.id))
    }

    public init(index: EngineMessage.Index, presentationData: ChatPresentationData, controllerInteraction: ChatControllerInteraction, context: AccountContext, timeGroupTimestamp: Int32? = nil) {
        self.index = index
        self.usesWegramAppearance = timeGroupTimestamp != nil && !presentationData.isPreview && controllerInteraction.chatIsRotated
        self.presentationData = presentationData
        self.controllerInteraction = controllerInteraction
        self.header = ChatMessageDateHeader(timestamp: index.timestamp, separableThreadId: nil, scheduled: false, displayHeader: nil, presentationData: presentationData, controllerInteraction: controllerInteraction, context: context, timeGroupTimestamp: timeGroupTimestamp)
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatUnreadItemNode()
            
            let dateAtBottom = !chatItemsHaveCommonDateHeader(self.header.id, ChatHistoryItemNeighbors(neighbors).next)
            let (layout, apply) = node.asyncLayout()(self, params, dateAtBottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply(.None)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatUnreadItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let dateAtBottom = !chatItemsHaveCommonDateHeader(self.header.id, ChatHistoryItemNeighbors(neighbors).next)
                    
                    let (layout, apply) = nodeLayout(self, params, dateAtBottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
}

public class ChatUnreadItemNode: ListViewItemNode {
    public var item: ChatUnreadItem?
    public let backgroundNode: ASImageNode
    public let labelNode: TextNode
    
    public let activateArea: AccessibilityAreaNode
    
    private var wallpaperBackgroundNode: WallpaperBackgroundNode?
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private var absolutePosition: (CGRect, CGSize)?
    
    private var theme: ChatPresentationThemeData?
    private var wegramView: WegramUnreadSeparatorView?
    
    private let layoutConstants = ChatMessageItemLayoutConstants.default
    
    public init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = .staticText
        
        super.init(layerBacked: false, rotated: true)
        
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.labelNode)
        
        self.addSubnode(self.activateArea)
        
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.scrollPositioningInsets = UIEdgeInsets(top: 5.0, left: 0.0, bottom: 6.0, right: 0.0)
        self.canBeUsedAsScrollToItemAnchor = false
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        super.animateInsertion(currentTimestamp, duration: duration, options: options)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        if let item = item as? ChatUnreadItem {
            let dateAtBottom = !chatItemsHaveCommonDateHeader(item.header.id, ChatHistoryItemNeighbors(neighbors).next)
            let (layout, apply) = self.asyncLayout()(item, params, dateAtBottom)
            apply(.None)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
        }
    }
    
    public func asyncLayout() -> (_ item: ChatUnreadItem, _ params: ListViewItemLayoutParams, _ dateAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        let layoutConstants = self.layoutConstants
        let currentTheme = self.theme
        let hadWegramView = self.wegramView != nil
        
        return { [weak self] item, params, dateAtBottom in
            if item.usesWegramAppearance {
                let font = Font.regular(floor(item.presentationData.fontSize.baseDisplaySize * 13 / 17))
                let height = WegramUnreadSeparatorView.height(font: font)
                let language = item.presentationData.strings.baseLanguageCode.lowercased()
                let string: String
                if language.hasPrefix("zh") {
                    string = language.contains("hant") || language == "zh-tw" || language == "zh-hk" ? "以下為新訊息" : "以下为新消息"
                } else {
                    string = item.presentationData.strings.Conversation_UnreadMessages
                }
                let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: height), insets: UIEdgeInsets(top: 6 + chatMessageDateHeaderSpacing(headers: item.headers, hasDate: dateAtBottom, hasTopic: false, constants: layoutConstants), left: 0, bottom: 5, right: 0))
                return (layout, { _ in
                    guard let self else { return }
                    self.item = item
                    self.theme = item.presentationData.theme
                    self.backgroundNode.isHidden = true
                    self.labelNode.isHidden = true
                    self.activateArea.isAccessibilityElement = false
                    self.backgroundContent?.removeFromSupernode()
                    self.backgroundContent = nil
                    let view: WegramUnreadSeparatorView
                    if let current = self.wegramView { view = current }
                    else {
                        view = WegramUnreadSeparatorView(frame: .zero)
                        self.wegramView = view
                        self.view.addSubview(view)
                    }
                    view.frame = CGRect(origin: .zero, size: layout.contentSize)
                    view.update(text: string, font: font, isDark: item.presentationData.theme.theme.overallDarkAppearance)
                    view.updateLayout(leftInset: params.leftInset, rightInset: params.rightInset)
                })
            }
            var updatedBackgroundImage: UIImage?
            if currentTheme != item.presentationData.theme || hadWegramView {
                updatedBackgroundImage = PresentationResourcesChat.chatUnreadBarBackgroundImage(item.presentationData.theme.theme)
            }
            
            let string = item.presentationData.strings.Conversation_UnreadMessages
            let (size, apply) = labelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: string, font: titleFont, textColor: item.presentationData.theme.theme.chat.serviceMessage.unreadBarTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let backgroundSize = CGSize(width: params.width, height: 25.0)
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 25.0), insets: UIEdgeInsets(top: 6.0 + chatMessageDateHeaderSpacing(headers: item.headers, hasDate: dateAtBottom, hasTopic: false, constants: layoutConstants), left: 0.0, bottom: 5.0, right: 0.0)), { animation in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.theme = item.presentationData.theme
                    strongSelf.wegramView?.removeFromSuperview()
                    strongSelf.wegramView = nil
                    strongSelf.labelNode.isHidden = false
                    strongSelf.activateArea.isAccessibilityElement = true
                    
                    if let updatedBackgroundImage = updatedBackgroundImage {
                        strongSelf.backgroundNode.image = updatedBackgroundImage
                    }
                    
                    let _ = apply()
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: backgroundSize)
                    strongSelf.activateArea.accessibilityLabel = string
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: backgroundSize)
                    
                    let labelFrame = CGRect(origin: CGPoint(x: params.leftInset + floorToScreenPixels((backgroundSize.width - params.leftInset - params.rightInset - size.size.width) / 2.0), y: floorToScreenPixels((backgroundSize.height - size.size.height) / 2.0)), size: size.size)
                    animation.animator.updatePosition(layer: strongSelf.labelNode.layer, position: labelFrame.center, completion: nil)
                    strongSelf.labelNode.bounds = CGRect(origin: CGPoint(), size: labelFrame.size)
                    
                    if item.controllerInteraction.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true {
                        if strongSelf.backgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                            backgroundContent.clipsToBounds = true

                            strongSelf.backgroundContent = backgroundContent
                            strongSelf.insertSubnode(backgroundContent, at: 0)
                        }
                    } else {
                        strongSelf.backgroundContent?.removeFromSupernode()
                        strongSelf.backgroundContent = nil
                    }
                    
                    if let backgroundContent = strongSelf.backgroundContent {
                        strongSelf.backgroundNode.isHidden = true
                        backgroundContent.frame = strongSelf.backgroundNode.frame
                        if let (rect, containerSize) = strongSelf.absolutePosition {
                            strongSelf.updateAbsoluteRect(rect, within: containerSize)
                        }
                    } else {
                        strongSelf.backgroundNode.isHidden = false
                    }
                }
            })
        }
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        super.updateAbsoluteRect(rect, within: containerSize)
        
        self.absolutePosition = (rect, containerSize)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return [item.header]
        } else {
            return nil
        }
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
}
