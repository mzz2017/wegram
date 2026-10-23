import UIKit

final class WegramMomentsHeaderView: UIView {
    let cover = UIImageView()
    let changeCoverButton = UIButton(type: .custom)
    let name = UILabel()
    let ownStories = UIButton(type: .custom)
    let avatarHost = UIView()
    private var ready = false
    var changeCover: (() -> Void)?
    var openOwnStories: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.cover)
        self.cover.contentMode = .scaleAspectFill
        self.cover.clipsToBounds = true
        self.addSubview(self.changeCoverButton)
        self.changeCoverButton.accessibilityIdentifier = "Wegram.Moments.ChangeCover"
        self.changeCoverButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.ready else { return }
            self.changeCover?()
        }), for: .touchUpInside)
        self.addSubview(self.name)
        self.addSubview(self.ownStories)
        self.name.numberOfLines = 0
        self.name.textAlignment = .right
        self.name.isAccessibilityElement = false
        self.name.textColor = .white
        self.ownStories.layer.cornerRadius = 6
        self.ownStories.clipsToBounds = true
        self.ownStories.accessibilityIdentifier = "Wegram.Moments.OwnStories"
        self.ownStories.addSubview(self.avatarHost)
        self.avatarHost.isUserInteractionEnabled = false
        self.avatarHost.accessibilityElementsHidden = true
        self.ownStories.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.ready else { return }
            self.openOwnStories?()
        }), for: .touchUpInside)
        self.update(name: nil, dark: false, fontSize: 17, chinese: true)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(name: String?, dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.ready = name != nil
        self.name.text = name
        self.name.font = .systemFont(ofSize: fontSize, weight: .medium)
        self.backgroundColor = UIColor(white: dark ? 0.1 : 1, alpha: 1)
        self.cover.backgroundColor = UIColor(white: dark ? 0.16 : 0.22, alpha: 1)
        self.ownStories.backgroundColor = UIColor(white: dark ? 0.2 : 0.9, alpha: 1)
        self.changeCoverButton.isEnabled = self.ready
        self.changeCoverButton.accessibilityLabel = chinese ? "更换封面" : "Change Cover"
        self.changeCoverButton.accessibilityHint = chinese ? "仅保存在本机当前账号" : "Saved only for this account on this device"
        self.ownStories.isEnabled = self.ready
        self.ownStories.accessibilityTraits = self.ready ? .button : [.button, .notEnabled]
        self.ownStories.accessibilityLabel = chinese ? "我的动态" : "My Stories"
        self.ownStories.accessibilityValue = name
        self.setNeedsLayout()
    }
    func measuredHeight(width: CGFloat) -> CGFloat {
        let available = max(1, width - 112)
        let textHeight = ceil(self.name.sizeThatFits(CGSize(width: available, height: .greatestFiniteMagnitude)).height)
        return max(width * 0.75, textHeight + 40, 120) + 40
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let coverHeight = max(0, self.bounds.height - 40)
        self.cover.frame = CGRect(x: 0, y: 0, width: width, height: coverHeight)
        self.changeCoverButton.frame = self.cover.frame
        self.ownStories.frame = CGRect(x: max(16, width - 80), y: coverHeight - 44, width: 64, height: 64)
        let textWidth = max(0, self.ownStories.frame.minX - 32)
        let textHeight = ceil(self.name.sizeThatFits(CGSize(width: max(1, textWidth), height: .greatestFiniteMagnitude)).height)
        self.name.frame = CGRect(x: 16, y: coverHeight - 16 - textHeight, width: textWidth, height: textHeight)
        self.avatarHost.frame = self.ownStories.bounds
        for view in self.avatarHost.subviews { view.frame = self.avatarHost.bounds }
    }
}
