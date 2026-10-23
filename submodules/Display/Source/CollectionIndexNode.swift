import Foundation
import UIKit
import AsyncDisplayKit

public final class CollectionIndexNode: ASDisplayNode {
    public static let searchIndex: String = "_$search$_"
    
    private var currentSize: CGSize?
    private var currentSections: [String] = []
    private var currentColor: UIColor?
    private var titleNodes: [String: (node: ImmediateTextNode, size: CGSize)] = [:]
    private var scrollFeedback: HapticFeedback?
    
    private var currentSelectedIndex: String?
    public var indexSelected: ((String) -> Void)?
    public var indexTouched: ((String?) -> Void)?
    public var titleFont: UIFont = Font.bold(11.0)
    public var itemHeight: CGFloat = 15.0
    public var verticalInset: CGFloat = 10.0
    // The touch feedback WeChat shows while the index is dragged: a green disc behind the selected letter and a grey bubble beside it.
    public var showsBubble: Bool = false
    private var bubbleLayer: CAShapeLayer?
    private var bubbleTitleNode: ImmediateTextNode?
    private var selectionDisc: ASDisplayNode?
    private var highlightedTitle: String?
    private var scrollHighlightTitle: String?
    private var isDraggingIndex = false
    
    override public init() {
        super.init()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    private func searchGlyph(color: UIColor) -> UIImage? {
        let side = ceil(self.titleFont.pointSize)
        return generateImage(CGSize(width: side, height: side), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.2)
            context.setLineCap(.round)
            let radius = size.width * 0.32
            context.strokeEllipse(in: CGRect(x: 1.0, y: size.height - 1.0 - radius * 2.0, width: radius * 2.0, height: radius * 2.0))
            context.move(to: CGPoint(x: 1.0 + radius * 1.7 + 0.8, y: size.height - 1.0 - radius * 1.7 - 0.8))
            context.addLine(to: CGPoint(x: size.width - 1.0, y: 1.0))
            context.strokePath()
        })
    }
    
    private func configureTitleNode(_ node: ImmediateTextNode, title: String, color: UIColor) -> CGSize {
        if title == CollectionIndexNode.searchIndex {
            node.attributedText = NSAttributedString(string: "")
            let side = ceil(self.titleFont.pointSize)
            if node.subnodes?.first == nil {
                node.addSubnode(ASImageNode())
            }
            if let imageNode = node.subnodes?.first as? ASImageNode {
                imageNode.image = self.searchGlyph(color: color)
                imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: side, height: side))
            }
            return CGSize(width: side, height: side)
        }
        node.attributedText = NSAttributedString(string: title, font: self.titleFont, textColor: color)
        return node.updateLayout(CGSize(width: 100.0, height: 100.0))
    }
    
    public func update(size: CGSize, color: UIColor, sections: [String], transition: ContainedViewLayoutTransition) {
        if self.currentColor == nil || !color.isEqual(self.currentColor) {
            self.currentColor = color
            for (title, nodeAndSize) in self.titleNodes {
                let _ = self.configureTitleNode(nodeAndSize.node, title: title, color: color)
            }
        }
        
        if self.currentSize == size && self.currentSections == sections {
            return
        }
        
        self.currentSize = size
        self.currentSections = sections
        
        let itemHeight = self.itemHeight
        let verticalInset = self.verticalInset
        let maxHeight = size.height - verticalInset * 2.0
        
        let maxItemCount = min(sections.count, Int(floor(maxHeight / itemHeight)))
        let skipCount: Int
        if sections.isEmpty {
            skipCount = 1
        } else {
            skipCount = Int(ceil(CGFloat(sections.count) / CGFloat(maxItemCount)))
        }
        let actualCount: CGFloat = ceil(CGFloat(sections.count) / CGFloat(skipCount))
        
        let totalHeight = actualCount * itemHeight
        let verticalOrigin = verticalInset + floor((maxHeight - totalHeight) / 2.0)
        
        var validTitles = Set<String>()
        
        var currentIndex = 0
        var displayIndex = 0
        var addedLastTitle = false
        
        let addTitle: (Int) -> Void = { index in
            let title = sections[index]
            let nodeAndSize: (node: ImmediateTextNode, size: CGSize)
            var animate = false
            if let current = self.titleNodes[title] {
                animate = true
                nodeAndSize = current
            } else {
                let node = ImmediateTextNode()
                let nodeSize = self.configureTitleNode(node, title: title, color: color)
                nodeAndSize = (node, nodeSize)
                self.addSubnode(node)
                self.titleNodes[title] = nodeAndSize
            }
            validTitles.insert(title)
            let previousPosition = nodeAndSize.node.position
            nodeAndSize.node.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - nodeAndSize.size.width) / 2.0), y: verticalOrigin + itemHeight * CGFloat(displayIndex) + floor((itemHeight - nodeAndSize.size.height) / 2.0)), size: nodeAndSize.size)
            if animate {
                transition.animatePosition(node: nodeAndSize.node, from: previousPosition)
            }
            
            currentIndex += skipCount
            displayIndex += 1
        }
        
        while currentIndex < sections.count {
            if currentIndex == sections.count - 1 {
                addedLastTitle = true
            }
            addTitle(currentIndex)
        }
        
        if !addedLastTitle && sections.count > 0 {
            addTitle(sections.count - 1)
        }
        
        if let title = self.highlightedTitle, let disc = self.selectionDisc, let nodeAndSize = self.titleNodes[title] {
            let target = CGRect(x: size.width / 2.0 - 7.0, y: nodeAndSize.node.frame.midY - 7.0, width: 14.0, height: 14.0)
            let previousPosition = disc.position
            disc.frame = target
            if disc.alpha != 0.0 {
                transition.animatePosition(node: disc, from: previousPosition)
            }
        }
        
        var removeTitles: [String] = []
        for title in self.titleNodes.keys {
            if !validTitles.contains(title) {
                removeTitles.append(title)
            }
        }
        
        for title in removeTitles {
            self.titleNodes.removeValue(forKey: title)?.node.removeFromSupernode()
        }
    }
    
    private func updateBubble(title: String?, color: UIColor, bubble: Bool = true) {
        guard self.showsBubble else {
            return
        }
        if self.selectionDisc == nil {
            let disc = ASDisplayNode()
            disc.isUserInteractionEnabled = false
            disc.backgroundColor = UIColor(rgb: 0x07c160)
            disc.cornerRadius = 7.0
            self.selectionDisc = disc
            self.insertSubnode(disc, at: 0)
            
            let radius: CGFloat = 25.0
            let tipDistance: CGFloat = 35.0
            let angle = acos(radius / tipDistance)
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: radius * 2.0, height: radius * 2.0))
            path.move(to: CGPoint(x: radius + radius * cos(angle), y: radius - radius * sin(angle)))
            path.addLine(to: CGPoint(x: radius + tipDistance, y: radius))
            path.addLine(to: CGPoint(x: radius + radius * cos(angle), y: radius + radius * sin(angle)))
            path.closeSubpath()
            let layer = CAShapeLayer()
            layer.path = path
            layer.fillColor = UIColor(rgb: 0x6e6e6e).cgColor
            layer.opacity = 0.0
            layer.bounds = CGRect(x: 0.0, y: 0.0, width: radius + tipDistance, height: radius * 2.0)
            layer.anchorPoint = CGPoint(x: radius / (radius + tipDistance), y: 0.5)
            self.layer.addSublayer(layer)
            self.bubbleLayer = layer
            
            let titleNode = ImmediateTextNode()
            titleNode.isUserInteractionEnabled = false
            titleNode.alpha = 0.0
            self.addSubnode(titleNode)
            self.bubbleTitleNode = titleNode
        }
        guard let disc = self.selectionDisc, let layer = self.bubbleLayer, let titleNode = self.bubbleTitleNode else {
            return
        }
        if let previous = self.highlightedTitle, let previousNode = self.titleNodes[previous]?.node, let currentColor = self.currentColor {
            if previous != CollectionIndexNode.searchIndex {
                previousNode.attributedText = NSAttributedString(string: previous, font: self.titleFont, textColor: currentColor)
                let _ = previousNode.updateLayout(CGSize(width: 100.0, height: 100.0))
            }
        }
        self.highlightedTitle = title
        let hideBubble: () -> Void = {
            if layer.opacity != 0.0 {
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.fromValue = layer.opacity
                animation.toValue = 0.0
                animation.duration = 0.15
                layer.add(animation, forKey: "fade")
                layer.opacity = 0.0
                titleNode.alpha = 0.0
                titleNode.layer.add(animation, forKey: "fade")
            }
        }
        if let title = title, let nodeAndSize = self.titleNodes[title] {
            let centerY = nodeAndSize.node.frame.midY
            let centerX = self.bounds.width / 2.0
            disc.frame = CGRect(x: centerX - 7.0, y: centerY - 7.0, width: 14.0, height: 14.0)
            disc.alpha = 1.0
            if title != CollectionIndexNode.searchIndex {
                nodeAndSize.node.attributedText = NSAttributedString(string: title, font: self.titleFont, textColor: .white)
                let _ = nodeAndSize.node.updateLayout(CGSize(width: 100.0, height: 100.0))
            }
            if !bubble {
                hideBubble()
                return
            }
            let bubbleCenterX = centerX - 65.0
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.position = CGPoint(x: bubbleCenterX, y: centerY)
            CATransaction.commit()
            titleNode.attributedText = NSAttributedString(string: title == CollectionIndexNode.searchIndex ? "" : title, font: Font.semibold(26.0), textColor: UIColor(rgb: 0xb4b4b4))
            let titleSize = titleNode.updateLayout(CGSize(width: 100.0, height: 100.0))
            titleNode.frame = CGRect(origin: CGPoint(x: bubbleCenterX - floor(titleSize.width / 2.0), y: centerY - floor(titleSize.height / 2.0)), size: titleSize)
            if layer.opacity == 0.0 {
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.fromValue = 0.0
                animation.toValue = 1.0
                animation.duration = 0.12
                layer.add(animation, forKey: "fade")
                layer.opacity = 1.0
                titleNode.layer.removeAllAnimations()
                titleNode.alpha = 1.0
                titleNode.layer.add(animation, forKey: "fade")
            }
        } else {
            disc.alpha = 0.0
            hideBubble()
        }
    }
    
    // The letter of the section at the top of the list; shown while the list scrolls and restored after a drag ends.
    public func setScrollHighlight(title: String?) {
        guard self.showsBubble, self.scrollHighlightTitle != title else {
            return
        }
        self.scrollHighlightTitle = title
        if !self.isDraggingIndex {
            self.updateBubble(title: title, color: self.currentColor ?? .gray, bubble: false)
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.isUserInteractionEnabled, self.bounds.insetBy(dx: -5.0, dy: 0.0).contains(point) {
            return self.view
        } else {
            return nil
        }
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        var locationTitleAndPosition: (String, CGFloat)?
        let location = recognizer.location(in: self.view)
        for (title, nodeAndSize) in self.titleNodes {
            let nodeFrame = nodeAndSize.node.frame
            if location.y >= nodeFrame.minY - 5.0 && location.y <= nodeFrame.maxY + 5.0 {
                if let currentTitleAndPosition = locationTitleAndPosition {
                    let distance = abs(nodeFrame.midY - location.y)
                    let previousDistance = abs(currentTitleAndPosition.1 - location.y)
                    if distance < previousDistance {
                        locationTitleAndPosition = (title, nodeFrame.midY)
                    }
                } else {
                    locationTitleAndPosition = (title, nodeFrame.midY)
                }
            }
        }
        let locationTitle = locationTitleAndPosition?.0
        switch recognizer.state {
            case .began:
                self.isDraggingIndex = true
                self.currentSelectedIndex = locationTitle
                if let locationTitle = locationTitle {
                    self.indexSelected?(locationTitle)
                    self.indexTouched?(locationTitle)
                    self.updateBubble(title: locationTitle, color: self.currentColor ?? .gray)
                }
            case .changed:
                if locationTitle != self.currentSelectedIndex {
                    self.currentSelectedIndex = locationTitle
                    if let locationTitle = locationTitle {
                        self.indexSelected?(locationTitle)
                        self.indexTouched?(locationTitle)
                        self.updateBubble(title: locationTitle, color: self.currentColor ?? .gray)
                        
                        if self.scrollFeedback == nil {
                            self.scrollFeedback = HapticFeedback()
                        }
                        self.scrollFeedback?.tap()
                    }
                }
            case .cancelled, .ended:
                self.currentSelectedIndex = nil
                self.indexTouched?(nil)
                self.isDraggingIndex = false
                self.updateBubble(title: self.scrollHighlightTitle, color: self.currentColor ?? .gray, bubble: false)
            default:
                break
        }
    }
}
