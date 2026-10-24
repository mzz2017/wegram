import UIKit
import AsyncDisplayKit
import Display
import TelegramCore

/// WeGram: the capsule WeChat draws behind times and notices on a photo wallpaper in light mode
/// (IMG_2490). Against the bare wallpaper blurred at radius 30, every channel of the reference
/// reads 0.54 * blur + 177 (rms 1.3 over five capsules). No normal blend reaches that, since it would
/// need a fill brighter than white, so the blur is dimmed with black and the rest is added with `plusL`.
public final class WegramCapsuleBackgroundNode: ASDisplayNode {
    /// 12px at 3x, fitted to the reference's corner profile.
    public static let cornerRadius: CGFloat = 4.0
    public static let timeTextColor = UIColor(rgb: 0x5f5e60)
    public static let noticeTextColor = UIColor(rgb: 0x545355)

    public static func isApplicable(wallpaper: TelegramWallpaper, isDark: Bool) -> Bool {
        if isDark {
            return false
        }
        switch wallpaper {
        case .image:
            return true
        case let .file(file):
            return !file.isPattern
        default:
            return false
        }
    }

    private let blurNode = NavigationBackgroundNode(color: UIColor(white: 0.0, alpha: 0.46), enableBlur: true, enableSaturation: false, customBlurRadius: 30.0)
    private let liftLayer = SimpleLayer()

    public override init() {
        super.init()
        self.isUserInteractionEnabled = false
        self.addSubnode(self.blurNode)
        // Per channel: the residual offsets against the reference were +1/0/+2 with a grey 177 lift.
        self.liftLayer.backgroundColor = UIColor(red: 176.0 / 255.0, green: 177.0 / 255.0, blue: 175.0 / 255.0, alpha: 1.0).cgColor
        self.liftLayer.compositingFilter = "plusL"
        self.layer.addSublayer(self.liftLayer)
        // The reference's outermost pixel is 10% darker and the next one 5%: a hairline inner rim.
        // A layer's border is drawn above its sublayers.
        self.layer.borderWidth = 0.5
        self.layer.borderColor = UIColor(white: 0.0, alpha: 0.1).cgColor
        self.layer.cornerRadius = WegramCapsuleBackgroundNode.cornerRadius
    }

    public func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        let bounds = CGRect(origin: CGPoint(), size: size)
        transition.updateFrame(node: self.blurNode, frame: bounds)
        self.blurNode.update(size: size, cornerRadius: WegramCapsuleBackgroundNode.cornerRadius, transition: transition)
        transition.updateFrame(layer: self.liftLayer, frame: bounds)
        self.liftLayer.cornerRadius = WegramCapsuleBackgroundNode.cornerRadius
    }
}

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
    private var capsuleNode: WegramCapsuleBackgroundNode?

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

    public func update(text: String, font: UIFont, isDark: Bool, usesCapsuleMaterial: Bool = false, synchronous: Bool) {
        self.text = text
        self.font = font
        self.textColor = isDark ? UIColor.white.withAlphaComponent(0.5) : (usesCapsuleMaterial ? WegramCapsuleBackgroundNode.timeTextColor : UIColor(rgb: 0x999999))
        self.labelNode.displaysAsynchronously = !synchronous
        self.accessibilityArea.accessibilityLabel = text
        self.accessibilityArea.isAccessibilityElement = !text.isEmpty
        if usesCapsuleMaterial {
            if self.capsuleNode == nil {
                let capsuleNode = WegramCapsuleBackgroundNode()
                self.capsuleNode = capsuleNode
                self.insertSubnode(capsuleNode, aboveSubnode: self.backgroundNode)
            }
            self.backgroundNode.updateColor(color: .clear, enableBlur: false, transition: .immediate)
        } else {
            self.capsuleNode?.removeFromSupernode()
            self.capsuleNode = nil
            self.backgroundNode.updateColor(color: UIColor(rgb: isDark ? 0x242424 : 0xdadada).withAlphaComponent(isDark ? 0.9 : 1), enableBlur: isDark, transition: .immediate)
        }
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
        if let capsuleNode = self.capsuleNode {
            transition.updateFrame(node: capsuleNode, frame: frame)
            capsuleNode.update(size: frame.size, transition: transition)
        }
        // On the capsule WeChat's text sits a pixel lower than a floored centre.
        let labelY = self.capsuleNode != nil ? ceilToScreenPixels((height - labelSize.height) / 2) : floorToScreenPixels((height - labelSize.height) / 2)
        transition.updatePosition(node: self.labelNode, position: CGPoint(x: frame.minX + 6 + labelSize.width / 2, y: frame.minY + labelY + labelSize.height / 2))
        transition.updateFrame(node: self.accessibilityArea, frame: frame)
    }
}
