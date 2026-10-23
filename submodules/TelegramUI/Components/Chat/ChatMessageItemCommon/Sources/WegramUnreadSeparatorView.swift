import UIKit
import Display

public final class WegramUnreadSeparatorView: UIView {
    private let label = UILabel()
    private let leadingLine = UIView()
    private let trailingLine = UIView()
    private var leftInset: CGFloat = 0
    private var rightInset: CGFloat = 0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.isAccessibilityElement = true
        self.accessibilityTraits = .staticText
        self.label.textAlignment = .center
        self.label.lineBreakMode = .byTruncatingTail
        for view in [self.leadingLine, self.trailingLine, self.label] {
            view.isAccessibilityElement = false
            self.addSubview(view)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public static func height(font: UIFont) -> CGFloat {
        return max(25, ceil(font.lineHeight) + 8)
    }

    public func update(text: String, font: UIFont, isDark: Bool) {
        self.label.text = text
        self.label.font = font
        self.label.textColor = UIColor(rgb: isDark ? 0x999999 : 0x888888)
        let lineColor = UIColor(rgb: isDark ? 0x3d3d3d : 0xd0d0d0)
        self.leadingLine.backgroundColor = lineColor
        self.trailingLine.backgroundColor = lineColor
        self.accessibilityLabel = text
        self.setNeedsLayout()
    }

    public func updateLayout(leftInset: CGFloat, rightInset: CGFloat) {
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let available = max(0, self.bounds.width - self.leftInset - self.rightInset)
        let width = min(260, max(0, available - 48))
        let centerX = self.leftInset + available / 2
        let size = self.label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        let labelWidth = min(width, size.width)
        self.label.frame = CGRect(x: floorToScreenPixels(centerX - labelWidth / 2), y: floorToScreenPixels((self.bounds.height - size.height) / 2), width: labelWidth, height: size.height)
        let start = centerX - width / 2
        let lineWidth = max(0, (width - labelWidth) / 2 - 8)
        let lineY = floorToScreenPixels(self.bounds.midY)
        self.leadingLine.frame = CGRect(x: start, y: lineY, width: lineWidth, height: UIScreenPixel)
        self.trailingLine.frame = CGRect(x: centerX + width / 2 - lineWidth, y: lineY, width: lineWidth, height: UIScreenPixel)
    }
}
