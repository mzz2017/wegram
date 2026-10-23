import UIKit

final class WegramAdminGridView: UIView {
    struct Member: Equatable {
        let id: Int64
        let name: String
        let role: String
        let enabled: Bool
        let canOpen: Bool
        let canRemove: Bool
        var warning: String? = nil
    }
    enum Action: Equatable {
        case member(Int64), remove(Int64), add, toggleEditing
    }
    var open: ((Action) -> Void)?
    var configureAvatar: ((Int64, UIView) -> Void)?
    var releaseAvatar: ((Int64, UIView) -> Void)?
    private let icon = UIImageView()
    private let title = UILabel()
    private let information = UILabel()
    private var members: [Member] = []
    private var fontSize: CGFloat = 17
    private var generation = 0
    private var buttons: [UIButton] = []
    private var labels: [UILabel] = []
    private var roles: [UILabel] = []
    private var avatars: [(Int64, UIView)] = []
    private var configuredAvatars = Set<Int64>()
    var visibleRect: CGRect = .infinite {
        didSet { self.updateVisibleAvatars() }
    }
    private func clearAvatar(id: Int64, host: UIView) {
        self.releaseAvatar?(id, host)
        for view in host.subviews { view.removeFromSuperview() }
    }
    private func updateVisibleAvatars() {
        for (id, host) in self.avatars {
            let visible = self.visibleRect.intersects(host.convert(host.bounds, to: self))
            if visible && !self.configuredAvatars.contains(id) {
                self.configuredAvatars.insert(id)
                self.configureAvatar?(id, host)
            } else if !visible && self.configuredAvatars.remove(id) != nil {
                self.clearAvatar(id: id, host: host)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.icon.image = UIImage(systemName: "person.crop.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 80, weight: .ultraLight))
        self.icon.contentMode = .scaleAspectFit
        self.icon.tintColor = UIColor(red: 0.32, green: 0.62, blue: 0.20, alpha: 1)
        self.icon.isAccessibilityElement = false
        self.title.textAlignment = .center
        self.title.accessibilityTraits = .header
        self.addSubview(self.icon)
        self.addSubview(self.title)
        self.information.numberOfLines = 0
        self.addSubview(self.information)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(members: [Member], canAdd: Bool, editing: Bool, title: String, info: String = "", addTitle: String, editTitle: String, doneTitle: String, dark: Bool, fontSize: CGFloat) {
        self.generation += 1
        let generation = self.generation
        for (id, host) in self.avatars where self.configuredAvatars.contains(id) { self.clearAvatar(id: id, host: host) }
        self.configuredAvatars.removeAll()
        for view in self.buttons { view.removeFromSuperview() }
        self.buttons.removeAll(); self.labels.removeAll(); self.roles.removeAll(); self.avatars.removeAll()
        self.members = members
        self.fontSize = fontSize
        let color = UIColor(white: dark ? 0.85 : 0.10, alpha: 1)
        self.backgroundColor = UIColor(white: dark ? 0.12 : 1, alpha: 1)
        self.title.text = title
        self.title.textColor = color
        self.title.font = UIFont.systemFont(ofSize: fontSize)
        self.information.text = info
        self.information.font = UIFont.systemFont(ofSize: max(13, fontSize * 13 / 17))
        self.information.textColor = UIColor(white: dark ? 0.6 : 0.5, alpha: 1)
        for member in members {
            let action: Action = editing ? .remove(member.id) : .member(member.id)
            let button = self.button(action: action, generation: generation)
            button.isEnabled = member.enabled && (editing ? member.canRemove : member.canOpen)
            button.accessibilityIdentifier = "Wegram.Admins.Member.\(member.id)"
            button.accessibilityLabel = member.name
            button.accessibilityValue = member.role
            if !member.enabled { button.accessibilityTraits.insert(.notEnabled) }
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
            host.isUserInteractionEnabled = false
            host.layer.cornerRadius = 4
            host.clipsToBounds = true
            button.addSubview(host)
            self.avatars.append((member.id, host))
            let name = UILabel()
            name.font = UIFont.systemFont(ofSize: max(13, fontSize * 13 / 17))
            name.text = member.name
            name.textColor = UIColor(white: dark ? 0.6 : 0.5, alpha: 1)
            name.textAlignment = .center
            name.isAccessibilityElement = false
            button.addSubview(name)
            self.labels.append(name)
            let role = UILabel()
            role.font = UIFont.systemFont(ofSize: max(11, fontSize * 11 / 17))
            role.text = member.role
            role.numberOfLines = 2
            role.textColor = name.textColor
            role.textAlignment = .center
            role.isAccessibilityElement = false
            button.addSubview(role)
            self.roles.append(role)
            if let warning = member.warning {
                let label = UILabel()
                label.text = warning
                label.font = UIFont.boldSystemFont(ofSize: 10)
                label.textColor = .white
                label.backgroundColor = UIColor(red: 0.85, green: 0.2, blue: 0.15, alpha: 1)
                label.textAlignment = .center
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.5
                label.isAccessibilityElement = false
                label.tag = 3
                button.addSubview(label)
            }
            if editing && member.canRemove {
                let minus = UIImageView(image: UIImage(systemName: "minus.circle.fill"))
                minus.frame = CGRect(x: 0, y: 0, width: 18, height: 18)
                minus.tintColor = UIColor(red: 0.98, green: 0.32, blue: 0.32, alpha: 1)
                minus.tag = 1
                button.addSubview(minus)
            }
            button.alpha = member.enabled ? 1 : 0.5
        }
        if canAdd {
            self.control(symbol: "plus", title: addTitle, action: .add, generation: generation, dark: dark)
        }
        if members.contains(where: { $0.canRemove }) || editing {
            self.control(symbol: editing ? "checkmark" : "minus", title: editing ? doneTitle : editTitle, action: .toggleEditing, generation: generation, dark: dark)
        }
        self.setNeedsLayout()
    }
    private func button(action: Action, generation: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.addAction(UIAction { [weak self, weak button] _ in
            guard let self, button?.isEnabled == true, !self.isHidden, generation == self.generation else { return }
            self.open?(action)
        }, for: .touchUpInside)
        self.buttons.append(button)
        self.addSubview(button)
        return button
    }
    private func control(symbol: String, title: String, action: Action, generation: Int, dark: Bool) {
        let button = self.button(action: action, generation: generation)
        button.accessibilityLabel = title
        button.accessibilityIdentifier = action == .add ? "Wegram.Admins.Add" : "Wegram.Admins.Edit"
        let image = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .ultraLight)))
        image.contentMode = .center
        image.isUserInteractionEnabled = false
        image.tintColor = UIColor(white: 0.6, alpha: 1)
        image.layer.borderWidth = 1 / UIScreen.main.scale
        image.layer.borderColor = UIColor(white: dark ? 0.25 : 0.9, alpha: 1).cgColor
        image.layer.cornerRadius = 4
        image.tag = 2
        button.addSubview(image)
    }
    private func columns(width: CGFloat) -> Int { min(6, max(1, Int(max(0, width - 32) / 66))) }
    private var rowHeight: CGFloat {
        48 + 6 + ceil(UIFont.systemFont(ofSize: max(13, self.fontSize * 13 / 17)).lineHeight) + 2 * ceil(UIFont.systemFont(ofSize: max(11, self.fontSize * 11 / 17)).lineHeight) + 16
    }
    private var gridTop: CGFloat {
        48 + 80 + 16 + ceil(UIFont.systemFont(ofSize: self.fontSize).lineHeight) + 36 + Self.informationHeight(self.information.text ?? "", fontSize: self.fontSize, width: self.bounds.width)
    }
    private static func informationHeight(_ text: String, fontSize: CGFloat, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return ceil((text as NSString).boundingRect(with: CGSize(width: max(1, width - 32), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: max(13, fontSize * 13 / 17))], context: nil).height) + 24
    }
    static func measure(members: [Member], canAdd: Bool, editing: Bool, fontSize: CGFloat, info: String = "", width: CGFloat) -> CGFloat {
        let columns = min(6, max(1, Int(max(0, width - 32) / 66)))
        let count = members.count + (canAdd ? 1 : 0) + ((editing || members.contains(where: { $0.canRemove })) ? 1 : 0)
        let nameHeight = ceil(UIFont.systemFont(ofSize: max(13, fontSize * 13 / 17)).lineHeight)
        let roleHeight = ceil(UIFont.systemFont(ofSize: max(11, fontSize * 11 / 17)).lineHeight)
        return 48 + 80 + 16 + ceil(UIFont.systemFont(ofSize: fontSize).lineHeight) + 36 + Self.informationHeight(info, fontSize: fontSize, width: width) + CGFloat((count + columns - 1) / columns) * (48 + 6 + nameHeight + 2 * roleHeight + 16) + 24
    }
    func height(width: CGFloat) -> CGFloat {
        self.gridTop + CGFloat((self.buttons.count + self.columns(width: width) - 1) / self.columns(width: width)) * self.rowHeight + 24
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.icon.frame = CGRect(x: floor((self.bounds.width - 80) / 2), y: 48, width: 80, height: 80)
        self.title.frame = CGRect(x: 16, y: 144, width: max(0, self.bounds.width - 32), height: ceil(self.title.font.lineHeight))
        self.information.frame = CGRect(x: 16, y: self.title.frame.maxY + 36, width: max(0, self.bounds.width - 32), height: max(0, Self.informationHeight(self.information.text ?? "", fontSize: self.fontSize, width: self.bounds.width) - 24))
        let columns = self.columns(width: self.bounds.width)
        let slot = max(0, self.bounds.width - 32) / CGFloat(columns)
        for (index, button) in self.buttons.enumerated() {
            button.frame = CGRect(x: 16 + CGFloat(index % columns) * slot, y: self.gridTop + CGFloat(index / columns) * self.rowHeight, width: slot, height: self.rowHeight)
            let avatarFrame = CGRect(x: floor((slot - 48) / 2), y: 0, width: 48, height: 48)
            if index < self.members.count {
                self.avatars[index].1.frame = avatarFrame
                let nameHeight = ceil(self.labels[index].font.lineHeight)
                self.labels[index].frame = CGRect(x: 2, y: 54, width: max(0, slot - 4), height: nameHeight)
                self.roles[index].frame = CGRect(x: 2, y: 54 + nameHeight, width: max(0, slot - 4), height: 2 * ceil(self.roles[index].font.lineHeight))
                button.viewWithTag(3)?.frame = CGRect(x: avatarFrame.minX, y: 35, width: 48, height: 13)
                button.viewWithTag(1)?.frame.origin = CGPoint(x: avatarFrame.minX - 6, y: -6)
            } else {
                button.viewWithTag(2)?.frame = avatarFrame
            }
        }
        self.updateVisibleAvatars()
    }
}
