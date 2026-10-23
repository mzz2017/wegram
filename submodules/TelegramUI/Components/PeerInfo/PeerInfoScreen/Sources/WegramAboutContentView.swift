import UIKit
import Display

final class WegramAboutContentView: UIView {
    enum Action: CaseIterable {
        case features, help, source, terms, privacy
    }

    let scrollView = UIScrollView()
    let iconView = UIImageView()
    let nameLabel = UILabel()
    let versionLabel = UILabel()
    let disclosureLabel = UILabel()
    private(set) var buttons: [UIButton] = []
    private let separators = (0..<4).map { _ in UIView() }
    private let action: (Action) -> Void

    init(action: @escaping (Action) -> Void) {
        self.action = action
        super.init(frame: .zero)
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.showsVerticalScrollIndicator = false
        self.addSubview(self.scrollView)
        self.iconView.layer.cornerRadius = 14
        self.iconView.clipsToBounds = true
        self.iconView.contentMode = .scaleAspectFit
        self.iconView.isAccessibilityElement = false
        self.nameLabel.text = "WeGram"
        self.nameLabel.textAlignment = .center
        self.nameLabel.accessibilityTraits = .header
        self.versionLabel.textAlignment = .center
        self.disclosureLabel.textAlignment = .center
        self.disclosureLabel.numberOfLines = 0
        for view in [self.iconView, self.nameLabel, self.versionLabel, self.disclosureLabel] { self.scrollView.addSubview(view) }
        for action in Action.allCases {
            let button = WegramAboutButton(type: .custom)
            button.accessibilityIdentifier = "Wegram.About.\(action)"
            button.contentHorizontalAlignment = action == .terms || action == .privacy ? .center : .left
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = action == .terms || action == .privacy ? .center : .natural
            button.addAction(UIAction(handler: { [weak self] _ in self?.action(action) }), for: .touchUpInside)
            self.buttons.append(button)
            self.scrollView.addSubview(button)
            if action == .features || action == .help || action == .source {
                let arrow = UIImageView(image: wegramDisclosureArrowImage)
                arrow.tag = 1
                button.addSubview(arrow)
            }
        }
        for separator in self.separators { self.scrollView.addSubview(separator) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(icon: UIImage?, version: String, build: String, chinese: Bool, isDark: Bool, fontSize: CGFloat) {
        self.iconView.image = icon
        self.backgroundColor = isDark ? UIColor(white: 0.1, alpha: 1) : .white
        let textColor = isDark ? UIColor(white: 0.82, alpha: 1) : UIColor(white: 0.1, alpha: 1)
        let secondaryColor = isDark ? UIColor(white: 0.55, alpha: 1) : UIColor(white: 0.6, alpha: 1)
        let linkColor = isDark ? UIColor(red: 0.49, green: 0.56, blue: 0.66, alpha: 1) : UIColor(red: 0.34, green: 0.42, blue: 0.58, alpha: 1)
        self.nameLabel.font = .systemFont(ofSize: fontSize * 22 / 17, weight: .semibold)
        self.nameLabel.textColor = textColor
        self.versionLabel.font = .systemFont(ofSize: fontSize)
        self.versionLabel.text = "Version " + version
        self.versionLabel.accessibilityValue = build.isEmpty ? nil : (chinese ? "构建 " : "Build ") + build
        self.versionLabel.textColor = textColor
        self.disclosureLabel.font = .systemFont(ofSize: max(12, fontSize * 12 / 17))
        self.disclosureLabel.textColor = secondaryColor
        self.disclosureLabel.text = chinese ? "基于开源项目的第三方客户端" : "Third-party client based on open source software"
        let titles = chinese ? ["功能介绍", "帮助与反馈", "开源项目", "WeGram 服务条款", "WeGram 隐私政策"] : ["Features", "Help & Feedback", "Source Code", "WeGram Terms", "WeGram Privacy"]
        for (index, button) in self.buttons.enumerated() {
            button.setTitle(titles[index], for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: index < 3 ? fontSize : max(12, fontSize * 12 / 17))
            button.setTitleColor(index < 3 ? textColor : linkColor, for: .normal)
            button.setTitleColor((index < 3 ? textColor : linkColor).withAlphaComponent(0.5), for: .highlighted)
            button.viewWithTag(1)?.tintColor = UIColor(white: isDark ? 1 : 0, alpha: 0.3)
        }
        for separator in self.separators { separator.backgroundColor = isDark ? UIColor(white: 0.16, alpha: 1) : UIColor(white: 0.94, alpha: 1) }
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.scrollView.frame = self.bounds
        let width = self.bounds.width
        let textWidth = max(0, width - 48)
        self.iconView.frame = CGRect(x: floor((width - 64) / 2), y: 48, width: 64, height: 64)
        let nameHeight = ceil(self.nameLabel.font.lineHeight)
        self.nameLabel.frame = CGRect(x: 24, y: 144, width: textWidth, height: nameHeight)
        let versionHeight = ceil(self.versionLabel.font.lineHeight)
        self.versionLabel.frame = CGRect(x: 24, y: self.nameLabel.frame.maxY + 8, width: textWidth, height: versionHeight)
        let rowsTop = self.versionLabel.frame.maxY + 32
        var y = rowsTop
        for (index, button) in self.buttons.prefix(3).enumerated() {
            let titleHeight = button.titleLabel?.sizeThatFits(CGSize(width: max(0, width - 104), height: .greatestFiniteMagnitude)).height ?? 0
            let height = max(56, ceil(titleHeight) + 24)
            button.frame = CGRect(x: 36, y: y, width: max(0, width - 72), height: height)
            button.viewWithTag(1)?.frame = wegramDisclosureArrowFrame(trailingEdge: button.bounds.width + 15, centerY: height / 2)
            self.separators[index].frame = CGRect(x: 36, y: y, width: max(0, width - 72), height: 1 / UIScreen.main.scale)
            y += height
        }
        self.separators[3].frame = CGRect(x: 36, y: y, width: max(0, width - 72), height: 1 / UIScreen.main.scale)
        let disclosureHeight = ceil(self.disclosureLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        let linkWidth = max(0, (width - 48) / 2)
        let linkHeight = max(44, self.buttons.suffix(2).map { ceil($0.titleLabel?.sizeThatFits(CGSize(width: linkWidth, height: .greatestFiniteMagnitude)).height ?? 0) + 16 }.max() ?? 44)
        let footerHeight = linkHeight + 12 + disclosureHeight
        let footerTop = max(y + 48, self.bounds.height - footerHeight - 20)
        for (index, button) in self.buttons.suffix(2).enumerated() {
            button.frame = CGRect(x: 24 + CGFloat(index) * linkWidth, y: footerTop, width: linkWidth, height: linkHeight)
        }
        self.disclosureLabel.frame = CGRect(x: 24, y: footerTop + linkHeight + 12, width: textWidth, height: disclosureHeight)
        self.scrollView.contentSize = CGSize(width: width, height: max(self.bounds.height, self.disclosureLabel.frame.maxY + 20))
    }
}

private final class WegramAboutButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        if self.viewWithTag(1) != nil {
            self.titleLabel?.frame = CGRect(x: 0, y: 0, width: max(0, self.bounds.width - 32), height: self.bounds.height)
        }
    }
}
