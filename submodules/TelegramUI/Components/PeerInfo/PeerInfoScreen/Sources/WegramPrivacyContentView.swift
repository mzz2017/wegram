import UIKit
import Display

enum WegramPrivacyDestination: Int, CaseIterable {
    case phone, groups, blocked, presence, forwards, system
    var needsSettings: Bool { self != .blocked && self != .system }
    func title(chinese: Bool) -> String {
        switch self {
        case .phone: return chinese ? "手机号" : "Phone Number"
        case .groups: return chinese ? "群组邀请" : "Group Invitations"
        case .blocked: return chinese ? "通讯录黑名单" : "Blocked Users"
        case .presence: return chinese ? "最后上线与在线状态" : "Last Seen & Online"
        case .forwards: return chinese ? "转发消息" : "Forwarded Messages"
        case .system: return chinese ? "系统权限管理" : "System Permissions"
        }
    }
}

final class WegramPrivacyRow: UIButton {
    let label = UILabel()
    let valueLabel = UILabel()
    let arrow = UIImageView(image: wegramDisclosureArrowImage)
    init() {
        super.init(frame: .zero)
        for view in [self.label, self.valueLabel, self.arrow] {
            self.addSubview(view)
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
        }
        self.label.numberOfLines = 0
        self.valueLabel.numberOfLines = 0
        self.valueLabel.textAlignment = .right
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func valueWidth(_ width: CGFloat) -> CGFloat {
        min(width * 0.4, self.valueLabel.sizeThatFits(CGSize(width: width * 0.4, height: .greatestFiniteMagnitude)).width)
    }
    func height(width: CGFloat) -> CGFloat {
        let valueWidth = self.valueWidth(width)
        let labelWidth = max(1, width - 56 - valueWidth - (valueWidth > 0 ? 12 : 0))
        return max(56, max(self.label.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height, self.valueLabel.sizeThatFits(CGSize(width: valueWidth, height: .greatestFiniteMagnitude)).height) + 24)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let valueWidth = self.valueWidth(self.bounds.width)
        self.label.frame = CGRect(x: 16, y: 12, width: max(0, self.bounds.width - 56 - valueWidth - (valueWidth > 0 ? 12 : 0)), height: self.bounds.height - 24)
        self.valueLabel.frame = CGRect(x: self.bounds.width - 40 - valueWidth, y: 12, width: valueWidth, height: self.bounds.height - 24)
        self.arrow.frame = wegramDisclosureArrowFrame(trailingEdge: self.bounds.width, centerY: self.bounds.height / 2)
    }
}

final class WegramPrivacyContentView: UIScrollView {
    let rows = WegramPrivacyDestination.allCases.map { _ in WegramPrivacyRow() }
    let headers = [UILabel(), UILabel(), UILabel()]
    private let dividers = [UIView(), UIView()]
    private let groups: [[WegramPrivacyDestination]] = [[.phone], [.groups, .blocked], [.presence, .forwards], [.system]]
    private var values: [WegramPrivacyDestination: String]?
    private var chinese = true
    var open: ((WegramPrivacyDestination) -> Void)?

    init() {
        super.init(frame: .zero)
        self.contentInsetAdjustmentBehavior = .never
        self.alwaysBounceVertical = true
        for header in self.headers { self.addSubview(header); header.numberOfLines = 0; header.accessibilityTraits = .header }
        for (destination, row) in zip(WegramPrivacyDestination.allCases, self.rows) {
            self.addSubview(row)
            row.accessibilityIdentifier = "Wegram.Settings.Privacy.\(destination)"
            row.addAction(UIAction(handler: { [weak self] _ in
                guard let self, !destination.needsSettings || self.values?[destination] != nil else { return }
                self.open?(destination)
            }), for: .touchUpInside)
        }
        for divider in self.dividers { self.addSubview(divider) }
        self.update(dark: false, fontSize: 17, chinese: true)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func load(values: [WegramPrivacyDestination: String]) {
        self.values = values
        self.updateState()
    }
    func update(dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.chinese = chinese
        self.backgroundColor = UIColor(white: dark ? 0.07 : 237 / 255, alpha: 1)
        let text = UIColor(white: dark ? 0.82 : 0.1, alpha: 1)
        let gray = UIColor(white: dark ? 0.45 : 0.6, alpha: 1)
        for (destination, row) in zip(WegramPrivacyDestination.allCases, self.rows) {
            row.backgroundColor = UIColor(white: dark ? 0.1 : 1, alpha: 1)
            row.label.text = destination.title(chinese: chinese)
            row.label.font = .systemFont(ofSize: fontSize)
            row.label.textColor = text
            row.valueLabel.font = .systemFont(ofSize: max(14, fontSize * 14 / 17))
            row.valueLabel.textColor = gray
            row.arrow.tintColor = UIColor(white: dark ? 1 : 0, alpha: 0.3)
        }
        let titles = chinese ? ["添加我的方式", "朋友权限", "个人信息与权限"] : ["How People Find Me", "Contact Permissions", "Personal Information"]
        for (header, title) in zip(self.headers, titles) {
            header.text = title
            header.font = .systemFont(ofSize: max(13, fontSize * 13 / 17))
            header.textColor = gray
        }
        for divider in self.dividers { divider.backgroundColor = UIColor(white: dark ? 0.16 : 0.94, alpha: 1) }
        self.updateState()
    }
    private func updateState() {
        for (destination, row) in zip(WegramPrivacyDestination.allCases, self.rows) {
            let value = self.values?[destination]
            row.valueLabel.text = value ?? (destination.needsSettings ? (self.chinese ? "正在读取" : "Loading") : nil)
            row.isEnabled = !destination.needsSettings || value != nil
            row.alpha = row.isEnabled ? 1 : 0.45
            row.accessibilityLabel = destination.title(chinese: self.chinese)
            row.accessibilityValue = row.valueLabel.text
            row.accessibilityTraits = row.isEnabled ? .button : [.button, .notEnabled]
        }
        self.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        var y: CGFloat = 0
        var dividerIndex = 0
        for (index, group) in self.groups.enumerated() {
            if index < self.headers.count {
                let header = self.headers[index]
                let height = max(36, header.sizeThatFits(CGSize(width: max(1, width - 32), height: .greatestFiniteMagnitude)).height + 16)
                header.frame = CGRect(x: 16, y: y, width: width - 32, height: height)
                y += height
            } else { y += 8 }
            for (rowIndex, destination) in group.enumerated() {
                let row = self.rows[destination.rawValue]
                row.frame = CGRect(x: 0, y: y, width: width, height: row.height(width: width))
                y = row.frame.maxY
                if rowIndex < group.count - 1 {
                    self.dividers[dividerIndex].frame = CGRect(x: 16, y: y - 0.5, width: width - 16, height: 0.5)
                    dividerIndex += 1
                }
            }
        }
        self.contentSize = CGSize(width: width, height: y + 24)
    }
}
