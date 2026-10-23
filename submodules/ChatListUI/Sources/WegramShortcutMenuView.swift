import UIKit

struct WegramShortcutMenuItem {
    let title: String
    let image: UIImage?
    var separatorBefore = false
    var detail: String? = nil
}

private final class ShortcutButton: UIButton {
    let detailLabel = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.detailLabel.numberOfLines = 0
        self.detailLabel.textColor = UIColor(white: 1, alpha: 0.65)
        self.detailLabel.isAccessibilityElement = false
        self.detailLabel.accessibilityIdentifier = "Wegram.Shortcut.Detail"
        self.addSubview(self.detailLabel)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func textSize(width: CGFloat) -> CGSize {
        let constraint = CGSize(width: max(0, width), height: .greatestFiniteMagnitude)
        let title = self.titleLabel?.sizeThatFits(constraint) ?? .zero
        let detail = self.detailLabel.isHidden ? CGSize.zero : self.detailLabel.sizeThatFits(constraint)
        return CGSize(width: max(title.width, detail.width), height: ceil(title.height) + (self.detailLabel.isHidden ? 0 : 4 + ceil(detail.height)))
    }
    override var isHighlighted: Bool {
        didSet { self.backgroundColor = self.isHighlighted ? UIColor(white: 1, alpha: 0.1) : .clear }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.frame = CGRect(x: 16, y: (self.bounds.height - 24) / 2, width: 24, height: 24)
        let width = max(0, self.bounds.width - 72)
        let titleHeight = self.detailLabel.isHidden ? max(0, self.bounds.height - 24) : ceil(self.titleLabel?.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height ?? 0)
        self.titleLabel?.frame = CGRect(x: 56, y: 12, width: width, height: titleHeight)
        self.detailLabel.frame = CGRect(x: 56, y: 12 + titleHeight + 4, width: width, height: self.detailLabel.isHidden ? 0 : ceil(self.detailLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
    }
}

final class WegramShortcutMenuView: UIControl {
    let panel = UIScrollView()
    private let arrow = CAShapeLayer()
    private(set) var buttons: [UIButton] = []
    private var separators: [UIView] = []
    private var active = false
    private var anchor = CGRect.zero
    private var insets = UIEdgeInsets.zero
    private var alignLeft = false
    var select: ((Int) -> Void)?
    var close: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false
        self.panel.backgroundColor = UIColor(white: 0.27, alpha: 1)
        self.panel.layer.cornerRadius = 4
        self.panel.clipsToBounds = true
        self.panel.showsVerticalScrollIndicator = false
        self.panel.alwaysBounceVertical = false
        self.panel.contentInsetAdjustmentBehavior = .never
        self.arrow.fillColor = self.panel.backgroundColor?.cgColor
        self.layer.addSublayer(self.arrow)
        self.addSubview(self.panel)
        self.addAction(UIAction(handler: { [weak self] _ in self?.cancel() }), for: .touchUpInside)
        self.isAccessibilityElement = false
        self.accessibilityViewIsModal = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func load(items: [WegramShortcutMenuItem], fontSize: CGFloat) {
        self.active = true
        for button in self.buttons { button.removeFromSuperview() }
        for separator in self.separators { separator.removeFromSuperview() }
        self.buttons = []
        self.separators = []
        for (index, item) in items.enumerated() {
            let button = ShortcutButton(type: .custom)
            button.setTitle(item.title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.setImage(item.image?.withRenderingMode(.alwaysTemplate), for: .normal)
            button.tintColor = .white
            button.imageView?.contentMode = .scaleAspectFit
            button.titleLabel?.font = .systemFont(ofSize: fontSize)
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.lineBreakMode = .byWordWrapping
            button.detailLabel.text = item.detail
            button.detailLabel.font = .systemFont(ofSize: fontSize * 13 / 17)
            button.detailLabel.isHidden = item.detail?.isEmpty != false
            button.contentHorizontalAlignment = .left
            button.accessibilityLabel = item.title
            button.accessibilityValue = button.detailLabel.isHidden ? nil : item.detail
            button.addAction(UIAction(handler: { [weak self, weak button] _ in
                guard let self, self.active, let button, self.buttons.indices.contains(index), self.buttons[index] === button else { return }
                self.active = false
                self.select?(index)
            }), for: .touchUpInside)
            self.panel.addSubview(button)
            self.buttons.append(button)
            let separator = UIView()
            separator.backgroundColor = UIColor(white: 1, alpha: 0.12)
            separator.isUserInteractionEnabled = false
            separator.isHidden = !item.separatorBefore
            self.panel.addSubview(separator)
            self.separators.append(separator)
        }
        self.accessibilityElements = self.buttons
        self.panel.contentOffset = .zero
        self.setNeedsLayout()
    }
    func position(anchor: CGRect, insets: UIEdgeInsets, alignLeft: Bool) {
        self.anchor = anchor
        self.insets = insets
        self.alignLeft = alignLeft
        self.setNeedsLayout()
    }
    func invalidate() { self.active = false; self.select = nil; self.close = nil }
    private func cancel() {
        guard self.active else { return }
        self.active = false
        self.close?()
    }
    override func accessibilityPerformEscape() -> Bool { self.cancel(); return true }

    override func layoutSubviews() {
        super.layoutSubviews()
        let availableWidth = max(0, self.bounds.width - self.insets.left - self.insets.right - 16)
        let textWidth = self.buttons.map { ($0 as? ShortcutButton)?.textSize(width: .greatestFiniteMagnitude).width ?? 0 }.max() ?? 0
        let width = min(availableWidth, max(160, ceil(textWidth) + 72))
        var height: CGFloat = 0
        for (index, button) in self.buttons.enumerated() {
            let textHeight = (button as? ShortcutButton)?.textSize(width: max(1, width - 72)).height ?? 0
            let rowHeight = max(52, ceil(textHeight) + 24)
            button.frame = CGRect(x: 0, y: height, width: width, height: rowHeight)
            self.separators[index].frame = CGRect(x: 16, y: height, width: max(0, width - 32), height: 0.5)
            height += rowHeight
        }
        let x = max(self.insets.left + 8, min(self.bounds.width - self.insets.right - width - 8, self.alignLeft ? self.anchor.midX - 16 : self.anchor.midX + 16 - width))
        let y = max(self.insets.top + 8, min(self.bounds.height - self.insets.bottom - 52 - 8, self.anchor.maxY + 8))
        self.panel.frame = CGRect(x: x, y: y, width: width, height: max(0, min(height, self.bounds.height - self.insets.bottom - y - 8)))
        self.panel.contentSize = CGSize(width: width, height: height)
        self.panel.isScrollEnabled = height > self.panel.bounds.height
        let arrowX = max(x + 12, min(x + width - 12, self.anchor.midX))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: arrowX - 8, y: y + 1))
        path.addLine(to: CGPoint(x: arrowX, y: y - 8))
        path.addLine(to: CGPoint(x: arrowX + 8, y: y + 1))
        path.close()
        self.arrow.path = path.cgPath
    }
}
