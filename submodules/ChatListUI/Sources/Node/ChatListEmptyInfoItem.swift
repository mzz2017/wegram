import Foundation
import LottieSettings
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import ListSectionHeaderNode
import AppBundle
import AnimatedStickerNode
import TelegramAnimatedStickerNode

class ChatListEmptyInfoItem: ListViewItem {
    let lottieSettings: LottieRenderingSettings
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    let theme: PresentationTheme
    let strings: PresentationStrings
    let fontSize: PresentationFontSize
    let usesWegramLayout: Bool
    
    let selectable: Bool = false
    
    init(theme: PresentationTheme, strings: PresentationStrings, lottieSettings: LottieRenderingSettings, fontSize: PresentationFontSize = .regular, usesWegramLayout: Bool = false) {
        self.lottieSettings = lottieSettings
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        self.usesWegramLayout = usesWegramLayout
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListEmptyInfoItemNode(lottieSettings: self.lottieSettings)
            
            let (nodeLayout, apply) = node.asyncLayout()(self, params, false)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply()
                    })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ChatListEmptyInfoItemNode)
            if let nodeValue = node() as? ChatListEmptyInfoItemNode {
                
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, neighbors.next == nil)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

class ChatListEmptyInfoItemNode: ListViewItemNode {
    private var item: ChatListEmptyInfoItem?
    
    private let animationNode: AnimatedStickerNode
    private let textNode: TextNode
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = self.visibilityStatus
            let isVisible: Bool
            switch self.visibility {
                case let .visible(fraction, _):
                    isVisible = fraction > 0.2
                case .none:
                    isVisible = false
            }
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
            }
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                self.animationNode.visibility = self.visibilityStatus && self.item?.usesWegramLayout != true
            }
        }
    }
    
    init(lottieSettings: LottieRenderingSettings) {
        self.animationNode = DefaultAnimatedStickerNodeImpl(lottieSettings: lottieSettings)
        self.textNode = TextNode()
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.textNode)
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! ChatListEmptyInfoItem, params, neighbors.next == nil)
        apply()
    }
    
    func asyncLayout() -> (_ item: ChatListEmptyInfoItem, _ params: ListViewItemLayoutParams, _ isLast: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { [weak self] item, params, last in
            let baseWidth = params.width - params.leftInset - params.rightInset
            
            let topInset: CGFloat = item.usesWegramLayout ? 32 : 8
            let textSpacing: CGFloat = item.usesWegramLayout ? 0 : 27
            let bottomInset: CGFloat = item.usesWegramLayout ? 32 : 24
            let animationHeight: CGFloat = item.usesWegramLayout ? 0 : 140
            
            let string = NSMutableAttributedString(string: item.strings.ChatList_EmptyChatList, font: item.usesWegramLayout ? Font.regular(item.fontSize.itemListBaseFontSize) : Font.semibold(17), textColor: item.usesWegramLayout ? item.theme.list.itemSecondaryTextColor : item.theme.list.itemPrimaryTextColor)
            
            let textLayout = makeTextLayout(TextNodeLayoutArguments(attributedString: string, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: baseWidth, height: .greatestFiniteMagnitude), alignment: .center))
            
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: topInset + animationHeight + textSpacing + textLayout.0.size.height + bottomInset), insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.item = item
                
                var topOffset: CGFloat = topInset
                
                let animationFrame = CGRect(origin: CGPoint(x: floor((params.width - animationHeight) * 0.5), y: topOffset), size: CGSize(width: animationHeight, height: animationHeight))
                strongSelf.animationNode.isHidden = item.usesWegramLayout
                strongSelf.animationNode.visibility = !item.usesWegramLayout && strongSelf.visibilityStatus
                if !item.usesWegramLayout && strongSelf.animationNode.bounds.isEmpty {
                    strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ChatListEmpty"), width: 248, height: 248, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                }
                strongSelf.animationNode.frame = animationFrame
                topOffset += animationHeight + textSpacing
                
                let _ = textLayout.1()
                let originX = item.usesWegramLayout ? params.leftInset + floor((baseWidth - textLayout.0.size.width) * 0.5) : floor((params.width - textLayout.0.size.width) * 0.5)
                strongSelf.textNode.frame = CGRect(origin: CGPoint(x: originX, y: topOffset), size: textLayout.0.size)
                
                strongSelf.contentSize = layout.contentSize
                strongSelf.insets = layout.insets
            })
        }
    }
}

class ChatListSectionHeaderItem: ListViewItem {
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    let theme: PresentationTheme
    let strings: PresentationStrings
    let hide: (() -> Void)?
    
    let selectable: Bool = false
    
    init(theme: PresentationTheme, strings: PresentationStrings, hide: (() -> Void)?) {
        self.theme = theme
        self.strings = strings
        self.hide = hide
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListSectionHeaderNode()
            
            let (nodeLayout, apply) = node.asyncLayout()(self, params, false)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply()
                    })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ChatListSectionHeaderNode)
            if let nodeValue = node() as? ChatListSectionHeaderNode {
                
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, neighbors.next == nil)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

class ChatListSectionHeaderNode: ListViewItemNode {
    private var item: ChatListSectionHeaderItem?
    
    private var headerNode: ListSectionHeaderNode?
    
    required init() {
        super.init(layerBacked: false)
        
        self.zPosition = 1.0
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! ChatListSectionHeaderItem, params, neighbors.next == nil)
        apply()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let headerNode = self.headerNode {
            if let result = headerNode.view.hitTest(self.view.convert(point, to: headerNode.view), with: event) {
                return result
            }
        }
        return nil
    }
    
    func asyncLayout() -> (_ item: ChatListSectionHeaderItem, _ params: ListViewItemLayoutParams, _ isLast: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params, last in
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 28.0), insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.item = item
                
                let headerNode: ListSectionHeaderNode
                if let current = strongSelf.headerNode {
                    headerNode = current
                } else {
                    headerNode = ListSectionHeaderNode(theme: item.theme)
                    strongSelf.headerNode = headerNode
                    strongSelf.addSubnode(headerNode)
                }
                
                headerNode.title = item.strings.ChatList_EmptyListContactsHeader
                if item.hide != nil {
                    headerNode.action = item.strings.ChatList_EmptyListContactsHeaderHide
                    headerNode.actionType = .generic
                    headerNode.activateAction = { _ in
                        guard let self else {
                            return
                        }
                        self.item?.hide?()
                    }
                } else {
                    headerNode.action = nil
                }
                
                headerNode.updateTheme(theme: item.theme)
                headerNode.updateLayout(size: CGSize(width: params.width, height: layout.contentSize.height), leftInset: params.leftInset, rightInset: params.rightInset)
                
                strongSelf.contentSize = layout.contentSize
                strongSelf.insets = layout.insets
            })
        }
    }
}

