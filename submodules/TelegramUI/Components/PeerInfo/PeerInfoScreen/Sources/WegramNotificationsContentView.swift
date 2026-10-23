import UIKit
import Display
import UserNotifications
import TelegramCore
import TelegramUIPreferences

enum WegramNotificationValue: Equatable {
    case on, off, mixed
    init(_ values: [Bool]) {
        self = values.allSatisfy { $0 } ? .on : (values.contains(true) ? .mixed : .off)
    }
}

enum WegramNotificationToggle: Int, CaseIterable {
    case messages, previews, sound, vibration
    var affectsGlobal: Bool { self == .messages || self == .previews }
    var affectsLocal: Bool { self != .messages }
    func applying(_ value: Bool, to current: GlobalNotificationSettingsSet) -> GlobalNotificationSettingsSet {
        var result = current
        switch self {
        case .messages:
            result.privateChats.enabled = value
            result.groupChats.enabled = value
            result.channels.enabled = value
        case .previews:
            result.privateChats.displayPreviews = value
            result.groupChats.displayPreviews = value
            result.channels.displayPreviews = value
        case .sound, .vibration: break
        }
        return result
    }
    func applying(_ value: Bool, to current: InAppNotificationSettings) -> InAppNotificationSettings {
        var result = current
        switch self {
        case .previews: result.displayPreviews = value
        case .sound: result.playSounds = value
        case .vibration: result.vibrate = value
        case .messages: break
        }
        return result
    }
    func value(global: GlobalNotificationSettingsSet, local: InAppNotificationSettings) -> WegramNotificationValue {
        switch self {
        case .messages: return WegramNotificationValue([global.privateChats.enabled, global.groupChats.enabled, global.channels.enabled])
        case .previews: return WegramNotificationValue([global.privateChats.displayPreviews, global.groupChats.displayPreviews, global.channels.displayPreviews, local.displayPreviews])
        case .sound: return WegramNotificationValue([local.playSounds])
        case .vibration: return WegramNotificationValue([local.vibrate])
        }
    }
}

enum WegramNotificationPermission: Equatable {
    case unknown, notDetermined, denied, allowed, alertsOff, quiet, temporary
    init(status: UNAuthorizationStatus, alerts: UNNotificationSetting) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = alerts == .enabled ? .allowed : .alertsOff
        case .provisional: self = .quiet
        case .ephemeral: self = .temporary
        @unknown default: self = .unknown
        }
    }
    func title(chinese: Bool) -> String {
        switch self {
        case .unknown: return chinese ? "正在读取" : "Checking"
        case .notDetermined: return chinese ? "未设置" : "Not Set"
        case .denied: return chinese ? "已关闭" : "Off"
        case .allowed: return chinese ? "已开启" : "On"
        case .alertsOff: return chinese ? "弹出提醒已关闭" : "Pop-up Alerts Off"
        case .quiet: return chinese ? "静默通知" : "Quiet Delivery"
        case .temporary: return chinese ? "临时授权" : "Temporary"
        }
    }
}

final class WegramNotificationRow: UIView {
    let label = UILabel()
    let valueLabel = UILabel()
    let control = WegramAppearanceSwitch()
    init() {
        super.init(frame: .zero)
        for view in [self.label, self.valueLabel, self.control] { self.addSubview(view) }
        self.label.numberOfLines = 0
        self.label.isAccessibilityElement = false
        self.valueLabel.isAccessibilityElement = false
        self.control.onTintColor = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func height(width: CGFloat) -> CGFloat {
        let valueWidth = self.valueLabel.isHidden ? 0 : self.valueLabel.sizeThatFits(CGSize(width: 110, height: 44)).width + 8
        return max(56, self.label.sizeThatFits(CGSize(width: max(1, width - 99 - valueWidth), height: .greatestFiniteMagnitude)).height + 24)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.control.frame = CGRect(x: self.bounds.width - 67, y: (self.bounds.height - 44) / 2, width: 51, height: 44)
        let valueWidth = self.valueLabel.isHidden ? 0 : self.valueLabel.sizeThatFits(CGSize(width: 110, height: 44)).width
        self.valueLabel.frame = CGRect(x: self.control.frame.minX - 8 - valueWidth, y: 0, width: valueWidth, height: self.bounds.height)
        self.label.frame = CGRect(x: 16, y: 12, width: max(0, self.control.frame.minX - 32 - (valueWidth > 0 ? valueWidth + 8 : 0)), height: self.bounds.height - 24)
    }
}

final class WegramNotificationsContentView: UIScrollView {
    let permissionButton = UIButton(type: .custom)
    let permissionLabel = UILabel()
    let permissionValue = UILabel()
    let arrow = UIImageView(image: wegramDisclosureArrowImage)
    let messageHeader = UILabel()
    let scopeLabel = UILabel()
    let foregroundHeader = UILabel()
    let rows = WegramNotificationToggle.allCases.map { _ in WegramNotificationRow() }
    private let dividers = [UIView(), UIView()]
    private var values: [WegramNotificationValue]?
    private var chinese = true
    private var permission: WegramNotificationPermission = .unknown
    var change: ((WegramNotificationToggle, Bool) -> Void)?
    var openPermission: (() -> Void)?
    var submitting = false { didSet { self.updateState() } }

    init() {
        super.init(frame: .zero)
        self.contentInsetAdjustmentBehavior = .never
        self.alwaysBounceVertical = true
        for view in [self.permissionButton, self.messageHeader, self.scopeLabel, self.foregroundHeader] { self.addSubview(view) }
        for view in [self.permissionLabel, self.permissionValue, self.arrow] {
            self.permissionButton.addSubview(view)
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
        }
        self.permissionLabel.numberOfLines = 0
        self.permissionValue.numberOfLines = 0
        self.permissionValue.textAlignment = .right
        self.scopeLabel.numberOfLines = 0
        self.permissionButton.accessibilityIdentifier = "Wegram.Settings.NotificationPermission"
        self.permissionButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, !self.submitting, self.permission != .unknown else { return }
            self.openPermission?()
        }), for: .touchUpInside)
        for (field, row) in zip(WegramNotificationToggle.allCases, self.rows) {
            self.addSubview(row)
            row.control.accessibilityIdentifier = "Wegram.Settings.Notification.\(field)"
            row.control.addAction(UIAction(handler: { [weak self, weak row] _ in
                guard let self, let row, self.values != nil, !self.submitting else { return }
                self.change?(field, row.control.isOn)
            }), for: .valueChanged)
        }
        for divider in self.dividers { self.addSubview(divider) }
        self.updateState()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func load(global: GlobalNotificationSettingsSet, local: InAppNotificationSettings) {
        self.values = WegramNotificationToggle.allCases.map { $0.value(global: global, local: local) }
        self.updateState()
    }
    func load(permission: WegramNotificationPermission) {
        self.permission = permission
        self.updateState()
    }
    func update(dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.chinese = chinese
        self.backgroundColor = UIColor(white: dark ? 0.07 : 237 / 255, alpha: 1)
        let text = UIColor(white: dark ? 0.82 : 0.1, alpha: 1)
        let secondary = UIColor(white: dark ? 0.45 : 0.6, alpha: 1)
        let white = UIColor(white: dark ? 0.1 : 1, alpha: 1)
        self.permissionButton.backgroundColor = white
        self.permissionLabel.text = chinese ? "系统通知权限" : "System Notifications"
        self.permissionLabel.font = .systemFont(ofSize: fontSize)
        self.permissionLabel.textColor = text
        self.permissionValue.font = .systemFont(ofSize: max(13, fontSize * 14 / 17))
        self.permissionValue.textColor = secondary
        self.arrow.tintColor = UIColor(white: dark ? 1 : 0, alpha: 0.3)
        self.messageHeader.text = chinese ? "消息通知" : "Message Notifications"
        self.foregroundHeader.text = chinese ? "微信打开时" : "When the App Is Open"
        self.scopeLabel.text = chinese ? "默认通知会同步到其他设备，单独设置的聊天不受影响。分类、例外与铃声在右上角“更多”中设置。" : "Default notification settings sync across devices. Chat exceptions stay unchanged. Categories, exceptions and sounds are under More (top right)."
        for label in [self.messageHeader, self.foregroundHeader, self.scopeLabel] {
            label.font = .systemFont(ofSize: max(13, fontSize * 13 / 17))
            label.textColor = secondary
        }
        let titles = chinese ? ["新消息通知", "通知显示消息详情", "新消息提示音", "振动"] : ["New Message Notifications", "Show Message Details", "Message Sound", "Vibrate"]
        for (index, row) in self.rows.enumerated() {
            row.backgroundColor = white
            row.label.text = titles[index]
            row.label.font = .systemFont(ofSize: fontSize)
            row.label.textColor = text
            row.valueLabel.font = .systemFont(ofSize: 13)
            row.valueLabel.textColor = secondary
            row.control.offTintColor = UIColor(white: dark ? 0.22 : 0.9, alpha: 1)
            row.control.onTitle = chinese ? "已开启" : "On"
            row.control.offTitle = chinese ? "已关闭" : "Off"
            row.control.accessibilityLabel = titles[index]
        }
        for divider in self.dividers { divider.backgroundColor = UIColor(white: dark ? 0.16 : 0.94, alpha: 1) }
        self.updateState()
    }
    private func updateState() {
        self.permissionValue.text = self.permission.title(chinese: self.chinese)
        self.permissionButton.accessibilityLabel = self.permissionLabel.text
        self.permissionButton.accessibilityValue = self.permissionValue.text
        self.permissionButton.isEnabled = self.permission != .unknown && !self.submitting
        for (index, row) in self.rows.enumerated() {
            let value = self.values?[index] ?? .off
            row.control.isOn = value != .off
            row.control.isEnabled = self.values != nil && !self.submitting
            row.valueLabel.text = self.chinese ? "部分开启" : "Mixed"
            row.valueLabel.isHidden = value != .mixed
            if value == .mixed { row.control.accessibilityValue = row.valueLabel.text }
            row.control.accessibilityHint = value == .mixed ? (self.chinese ? "各分类设置不同，切换将统一默认设置" : "Categories differ. Toggling unifies the default settings.") : nil
        }
        self.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let valueWidth = min(width * 0.42, self.permissionValue.sizeThatFits(CGSize(width: width * 0.42, height: .greatestFiniteMagnitude)).width)
        let permissionTextWidth = max(1, width - valueWidth - 68)
        let height = max(56, max(self.permissionLabel.sizeThatFits(CGSize(width: permissionTextWidth, height: .greatestFiniteMagnitude)).height, self.permissionValue.sizeThatFits(CGSize(width: valueWidth, height: .greatestFiniteMagnitude)).height) + 24)
        self.permissionButton.frame = CGRect(x: 0, y: 8, width: width, height: height)
        self.permissionLabel.frame = CGRect(x: 16, y: 12, width: permissionTextWidth, height: height - 24)
        self.permissionValue.frame = CGRect(x: width - 40 - valueWidth, y: 12, width: valueWidth, height: height - 24)
        self.arrow.frame = wegramDisclosureArrowFrame(trailingEdge: width, centerY: height / 2)
        var y = self.permissionButton.frame.maxY
        let headerHeight = max(36, self.messageHeader.font.lineHeight + 16)
        self.messageHeader.frame = CGRect(x: 16, y: y, width: width - 32, height: headerHeight)
        y += headerHeight
        for index in 0..<2 {
            let row = self.rows[index]
            row.frame = CGRect(x: 0, y: y, width: width, height: row.height(width: width))
            y = row.frame.maxY
        }
        self.dividers[0].frame = CGRect(x: 16, y: self.rows[0].frame.maxY - 0.5, width: width - 16, height: 0.5)
        let captionHeight = self.scopeLabel.sizeThatFits(CGSize(width: width - 32, height: .greatestFiniteMagnitude)).height
        self.scopeLabel.frame = CGRect(x: 16, y: y + 8, width: width - 32, height: captionHeight)
        y = self.scopeLabel.frame.maxY + 8
        self.foregroundHeader.frame = CGRect(x: 16, y: y, width: width - 32, height: headerHeight)
        y += headerHeight
        for index in 2..<4 {
            let row = self.rows[index]
            row.frame = CGRect(x: 0, y: y, width: width, height: row.height(width: width))
            y = row.frame.maxY
        }
        self.dividers[1].frame = CGRect(x: 16, y: self.rows[2].frame.maxY - 0.5, width: width - 16, height: 0.5)
        self.contentSize = CGSize(width: width, height: y + 24)
    }
}
