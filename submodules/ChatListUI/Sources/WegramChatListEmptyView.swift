import UIKit
import Display
import ItemListUI
import TelegramPresentationData
import TelegramUIPreferences

private final class EmptyActionButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        self.titleLabel?.frame = CGRect(x: 16, y: 12, width: max(0, self.bounds.width - 32), height: max(0, self.bounds.height - 24))
    }
}

final class WegramChatListEmptyView: UIView {
    private let scrollView = UIScrollView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let button = EmptyActionButton(type: .system)
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let action: () -> Void
    private var isLoading = false
    private var hasAction = false
    private var insets = UIEdgeInsets.zero

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceVertical = false
        self.addSubview(self.scrollView)
        for label in [self.titleLabel, self.descriptionLabel] {
            label.numberOfLines = 0
            label.textAlignment = .center
            self.scrollView.addSubview(label)
        }
        self.button.layer.cornerRadius = 4
        self.button.backgroundColor = UIColor(rgb: 0x07c160)
        self.button.setTitleColor(.white, for: .normal)
        self.button.titleLabel?.numberOfLines = 0
        self.button.titleLabel?.textAlignment = .center
        self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        self.scrollView.addSubview(self.button)
        self.indicator.hidesWhenStopped = true
        self.indicator.isAccessibilityElement = true
        self.addSubview(self.indicator)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(theme: PresentationTheme, fontSize: PresentationFontSize, title: String, description: String, actionTitle: String?, loadingText: String, isLoading: Bool) {
        self.titleLabel.text = title
        self.titleLabel.textColor = theme.list.itemSecondaryTextColor
        self.titleLabel.font = Font.regular(fontSize.itemListBaseFontSize)
        self.descriptionLabel.text = description
        self.descriptionLabel.textColor = theme.list.itemSecondaryTextColor
        self.descriptionLabel.font = Font.regular(fontSize.itemListBaseFontSize * 14 / 17)
        self.descriptionLabel.isHidden = description.isEmpty
        self.button.setTitle(actionTitle, for: .normal)
        self.button.accessibilityLabel = actionTitle
        self.button.titleLabel?.font = Font.semibold(fontSize.itemListBaseFontSize)
        self.hasAction = actionTitle != nil
        self.indicator.color = theme.list.itemSecondaryTextColor
        self.indicator.accessibilityLabel = loadingText
        self.updateIsLoading(isLoading)
        self.setNeedsLayout()
    }

    func updateIsLoading(_ value: Bool) {
        self.isLoading = value
        self.titleLabel.isHidden = value
        self.descriptionLabel.isHidden = value || self.descriptionLabel.text?.isEmpty != false
        self.button.isHidden = value || !self.hasAction
        self.button.isEnabled = !value && self.hasAction
        if value { self.indicator.startAnimating() }
        else { self.indicator.stopAnimating() }
        self.setNeedsLayout()
    }

    func updateLayout(insets: UIEdgeInsets) {
        self.insets = insets
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = max(0, self.bounds.width - self.insets.left - self.insets.right)
        let height = max(0, self.bounds.height - self.insets.top - self.insets.bottom)
        let viewport = CGRect(x: self.insets.left, y: self.insets.top, width: width, height: height)
        self.scrollView.frame = viewport
        self.indicator.sizeToFit()
        self.indicator.center = CGPoint(x: viewport.midX, y: viewport.midY)
        let textWidth = max(1, width - 48)
        let titleSize = self.titleLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        let descriptionSize = self.descriptionLabel.isHidden ? .zero : self.descriptionLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        let buttonWidth = min(270, max(0, width - 64))
        let buttonSize = self.button.isHidden ? .zero : (self.button.titleLabel?.sizeThatFits(CGSize(width: max(1, buttonWidth - 32), height: .greatestFiniteMagnitude)) ?? .zero)
        let buttonHeight = self.button.isHidden ? 0 : max(48, buttonSize.height + 24)
        let descriptionGap: CGFloat = descriptionSize.height == 0 ? 0 : 8
        let buttonGap: CGFloat = buttonHeight == 0 ? 0 : 24
        let contentHeight = titleSize.height + descriptionGap + descriptionSize.height + buttonGap + buttonHeight
        let top = max(24, floor((height - contentHeight) / 2))
        self.titleLabel.frame = CGRect(x: floor((width - textWidth) / 2), y: top, width: textWidth, height: titleSize.height)
        self.descriptionLabel.frame = CGRect(x: self.titleLabel.frame.minX, y: self.titleLabel.frame.maxY + descriptionGap, width: textWidth, height: descriptionSize.height)
        self.button.frame = CGRect(x: floor((width - buttonWidth) / 2), y: self.descriptionLabel.frame.maxY + buttonGap, width: buttonWidth, height: buttonHeight)
        self.scrollView.contentSize = CGSize(width: width, height: max(height, top + contentHeight + 24))
        self.scrollView.isScrollEnabled = !self.isLoading && self.scrollView.contentSize.height > height
    }

    @objc private func pressed() {
        guard self.window != nil, !self.isHidden, !self.isLoading, self.hasAction else { return }
        self.action()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !self.isHidden, self.alpha > 0.01, !self.isLoading,
              self.bounds.contains(point), self.scrollView.frame.contains(point) else { return nil }
        if !self.button.isHidden, self.button.bounds.contains(self.convert(point, to: self.button)) {
            return self.button.hitTest(self.convert(point, to: self.button), with: event)
        }
        if self.scrollView.isScrollEnabled, self.scrollView.frame.contains(point) {
            return super.hitTest(point, with: event)
        }
        return nil
    }
}
