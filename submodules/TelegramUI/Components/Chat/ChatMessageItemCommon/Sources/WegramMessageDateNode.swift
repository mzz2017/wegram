import UIKit
import AsyncDisplayKit
import Display

public final class WegramMessageDateNode: ASDisplayNode {
    public let labelNode = TextNode()
    public let backgroundNode = NavigationBackgroundNode(color: .clear)
    public let accessibilityArea = AccessibilityAreaNode()
    public var action: (() -> Void)? {
        didSet {
            self.accessibilityArea.accessibilityTraits = self.action == nil ? .staticText : .button
        }
    }
    private var text = ""
    private var font = Font.regular(14)
    private var textColor = UIColor.gray
    private var measuredWidth: CGFloat?

    public override init() {
        super.init()
        self.isAccessibilityElement = false
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.isAccessibilityElement = false
        self.backgroundNode.isUserInteractionEnabled = false
        self.backgroundNode.isAccessibilityElement = false
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.accessibilityArea)
        self.accessibilityArea.accessibilityTraits = .staticText
        self.accessibilityArea.activate = { [weak self] in
            guard let action = self?.action else { return false }
            action()
            return true
        }
    }

    public func update(text: String, font: UIFont, isDark: Bool, synchronous: Bool) {
        self.text = text
        self.font = font
        self.textColor = isDark ? UIColor.white.withAlphaComponent(0.5) : UIColor(rgb: 0x999999)
        self.labelNode.displaysAsynchronously = !synchronous
        self.accessibilityArea.accessibilityLabel = text
        self.accessibilityArea.isAccessibilityElement = !text.isEmpty
        self.backgroundNode.updateColor(color: UIColor(rgb: isDark ? 0x242424 : 0xdadada).withAlphaComponent(isDark ? 0.9 : 1), enableBlur: isDark, transition: .immediate)
        self.backgroundNode.borderWidth = isDark ? UIScreenPixel : 0
        self.backgroundNode.borderColor = isDark ? UIColor.white.withAlphaComponent(0.1).cgColor : nil
        self.backgroundNode.cornerRadius = 3
        self.measuredWidth = nil
        self.measure(width: 320)
    }

    private func measure(width: CGFloat) {
        if self.measuredWidth == width { return }
        self.measuredWidth = width
        let (layout, apply) = TextNode.asyncLayout(self.labelNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.text, font: self.font, textColor: self.textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: .zero))
        _ = apply()
        self.labelNode.bounds = CGRect(origin: .zero, size: layout.size)
    }

    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.measure(width: WegramMessageDateLayout.textWidth(width: size.width, leftInset: leftInset, rightInset: rightInset))
        let labelSize = self.labelNode.bounds.size
        let height = WegramMessageDateLayout.cardHeight(labelHeight: labelSize.height)
        let backgroundSize = CGSize(width: labelSize.width + 12, height: height)
        let frame = CGRect(x: leftInset + floorToScreenPixels((size.width - leftInset - rightInset - backgroundSize.width) / 2), y: (size.height - height) / 2, width: backgroundSize.width, height: height)
        transition.updateFrame(node: self.backgroundNode, frame: frame)
        self.backgroundNode.update(size: frame.size, cornerRadius: 3, transition: transition)
        transition.updatePosition(node: self.labelNode, position: CGPoint(x: frame.minX + 6 + labelSize.width / 2, y: frame.minY + floorToScreenPixels((height - labelSize.height) / 2) + labelSize.height / 2))
        transition.updateFrame(node: self.accessibilityArea, frame: frame)
    }
}
