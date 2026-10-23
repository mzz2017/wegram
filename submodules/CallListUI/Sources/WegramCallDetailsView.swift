import UIKit

final class WegramCallDetailsView: UIView {
    enum Action: Equatable { case profile, message, call }
    let scroll = UIScrollView()
    let profile = UIButton(type: .custom)
    let avatarHost = UIView()
    let name = UILabel()
    let username = UILabel()
    let message = UIButton(type: .custom)
    let call = UIButton(type: .custom)
    let recordsHost = UIView()
    var open: ((Action) -> Void)?
    private let separators = [UIView(), UIView()]
    private var fontSize: CGFloat = 17
    private var bottomInset: CGFloat = 0
    private var recordsHeight: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.scroll)
        self.scroll.contentInsetAdjustmentBehavior = .never
        self.scroll.addSubview(self.profile)
        self.profile.addSubview(self.avatarHost)
        self.profile.addSubview(self.name)
        self.profile.addSubview(self.username)
        self.avatarHost.isUserInteractionEnabled = false
        self.avatarHost.layer.cornerRadius = 6
        self.avatarHost.clipsToBounds = true
        self.name.numberOfLines = 0
        self.username.numberOfLines = 0
        self.name.isUserInteractionEnabled = false
        self.username.isUserInteractionEnabled = false
        self.profile.isAccessibilityElement = true
        self.name.isAccessibilityElement = false
        self.username.isAccessibilityElement = false
        for button in [self.message, self.call] { self.scroll.addSubview(button) }
        for separator in self.separators { self.scroll.addSubview(separator) }
        self.scroll.addSubview(self.recordsHost)
        for (button, action) in [(self.profile, Action.profile), (self.message, .message), (self.call, .call)] {
            button.addAction(UIAction { [weak self] _ in self?.open?(action) }, for: .touchUpInside)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(name: String, username: String?, messageTitle: String, callTitle: String, dark: Bool, fontSize: CGFloat) {
        self.fontSize = fontSize
        self.backgroundColor = UIColor(white: dark ? 0.07 : 0.93, alpha: 1)
        let block = UIColor(white: dark ? 0.12 : 1, alpha: 1)
        let primary = UIColor(white: dark ? 0.9 : 0.1, alpha: 1)
        self.profile.backgroundColor = block
        self.recordsHost.backgroundColor = block
        self.name.text = name
        self.name.textColor = primary
        self.name.font = .systemFont(ofSize: fontSize * 24 / 17, weight: .semibold)
        self.username.text = username.flatMap { $0.isEmpty ? nil : "@" + $0 }
        self.username.textColor = UIColor(white: dark ? 0.6 : 0.5, alpha: 1)
        self.username.font = .systemFont(ofSize: fontSize * 14 / 17)
        self.profile.accessibilityLabel = [name, self.username.text].compactMap { $0 }.joined(separator: ", ")
        for (button, title, icon) in [(self.message, messageTitle, "message"), (self.call, callTitle, "phone")] {
            var configuration = UIButton.Configuration.plain()
            configuration.cornerStyle = .fixed
            configuration.background.cornerRadius = 0
            configuration.background.backgroundColor = block
            configuration.title = title
            configuration.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: fontSize * 20 / 17))
            configuration.imagePadding = 8
            configuration.titleLineBreakMode = .byWordWrapping
            configuration.baseForegroundColor = UIColor(red: dark ? 125.0 / 255 : 87.0 / 255, green: dark ? 144.0 / 255 : 107.0 / 255, blue: dark ? 169.0 / 255 : 149.0 / 255, alpha: 1)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.systemFont(ofSize: fontSize)
                return attributes
            }
            button.configuration = configuration
            button.titleLabel?.numberOfLines = 0
            button.backgroundColor = block
            button.accessibilityLabel = title
        }
        for separator in self.separators { separator.backgroundColor = primary.withAlphaComponent(0.1) }
        self.setNeedsLayout()
    }

    func updateLayout(recordsHeight: CGFloat, bottomInset: CGFloat) {
        self.recordsHeight = recordsHeight
        self.bottomInset = bottomInset
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.scroll.frame = self.bounds
        let width = self.bounds.width
        let textWidth = max(1, width - 112)
        let nameHeight = ceil(self.name.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        let usernameHeight = self.username.text == nil ? 0 : ceil(self.username.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        let profileHeight = max(112, nameHeight + usernameHeight + 52)
        self.profile.frame = CGRect(x: 0, y: 0, width: width, height: profileHeight)
        self.avatarHost.frame = CGRect(x: 16, y: 24, width: 64, height: 64)
        self.name.frame = CGRect(x: 96, y: 24, width: textWidth, height: nameHeight)
        self.username.frame = CGRect(x: 96, y: self.name.frame.maxY + 6, width: textWidth, height: usernameHeight)
        var y = profileHeight + 8
        for (index, button) in [self.message, self.call].enumerated() {
            let height = max(56, ceil(button.sizeThatFits(CGSize(width: max(1, width - 32), height: .greatestFiniteMagnitude)).height) + 24)
            button.frame = CGRect(x: 0, y: y, width: width, height: height)
            self.separators[index].frame = CGRect(x: 16, y: y, width: max(0, width - 16), height: 0.5)
            y += height
        }
        self.recordsHost.frame = CGRect(x: 0, y: y + 8, width: width, height: self.recordsHeight)
        self.scroll.contentSize = CGSize(width: width, height: self.recordsHost.frame.maxY + self.bottomInset + 16)
    }
}
