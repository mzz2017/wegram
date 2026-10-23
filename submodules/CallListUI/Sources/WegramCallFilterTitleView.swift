import UIKit
import TelegramPresentationData

final class WegramCallFilterTitleView: UIControl {
    let label = UILabel()
    let chevron = UIImageView(image: UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)))
    var openFilter: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.label)
        self.addSubview(self.chevron)
        self.label.font = wegramNavigationTitleFont
        self.label.textAlignment = .center
        self.label.isAccessibilityElement = false
        self.chevron.isAccessibilityElement = false
        self.chevron.contentMode = .center
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.accessibilityIdentifier = "Wegram.Calls.Filter"
        self.isEnabled = false
        self.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.isEnabled else { return }
            self.openFilter?()
        }), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(title: String, selectedTitle: String, missed: Bool, color: UIColor, hint: String) {
        self.label.text = missed ? selectedTitle : title
        self.label.textColor = color
        self.chevron.tintColor = color
        self.accessibilityLabel = title
        self.accessibilityValue = selectedTitle
        self.accessibilityHint = hint
        self.isEnabled = true
        self.invalidateIntrinsicContentSize()
        self.setNeedsLayout()
    }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = ceil(self.label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44)).width) + 18
        return CGSize(width: size.width > 0 ? min(max(44, width), size.width) : max(44, width), height: 44)
    }
    override var intrinsicContentSize: CGSize { self.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44)) }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.label.frame = CGRect(x: 0, y: 0, width: max(0, self.bounds.width - 18), height: self.bounds.height)
        self.chevron.frame = CGRect(x: max(0, self.bounds.width - 14), y: (self.bounds.height - 14) * 0.5, width: 14, height: 14)
    }
}
