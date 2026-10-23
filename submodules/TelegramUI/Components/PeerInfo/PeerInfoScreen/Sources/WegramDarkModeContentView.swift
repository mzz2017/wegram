import UIKit
import Display
import TelegramUIPreferences

// Advanced automatic rules remain unchanged until an explicit simple mode is chosen.
enum WegramDarkMode: Equatable {
    case system, light, dark, advanced

    static func current(settings: PresentationThemeSettings, resolvedDark: Bool) -> Self {
        if settings.automaticThemeSwitchSetting.force { return .dark }
        switch settings.automaticThemeSwitchSetting.trigger {
        case .system: return .system
        case .timeBased, .brightness: return .advanced
        case .explicitNone:
            switch settings.theme.generalThemeReference {
            case .builtin(.day), .builtin(.dayClassic): return .light
            case .builtin(.night), .builtin(.nightAccent): return .dark
            default: return resolvedDark ? .dark : .light
            }
        }
    }

    func applying(to current: PresentationThemeSettings) -> PresentationThemeSettings {
        guard self != .advanced else { return current }
        var updated = current
        // The simple modes use the built-in light/dark pair; saved custom themes,
        // wallpapers and accents stay available in the full appearance settings.
        updated.theme = .builtin(.dayClassic)
        updated.automaticThemeSwitchSetting.theme = .builtin(.night)
        updated.automaticThemeSwitchSetting.force = self == .dark
        updated.automaticThemeSwitchSetting.trigger = self == .system ? .system : .explicitNone
        return updated
    }
}

final class WegramDarkModeButton: UIButton {
    let check = UIImageView(image: UIImage(systemName: "checkmark"))
    init() {
        super.init(frame: .zero)
        self.addSubview(self.check)
        self.check.contentMode = .center
        self.check.isUserInteractionEnabled = false
        self.check.isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.titleLabel?.frame = CGRect(x: 16, y: 12, width: max(0, self.bounds.width - 80), height: max(0, self.bounds.height - 24))
        self.check.frame = CGRect(x: self.bounds.width - 44, y: (self.bounds.height - 24) / 2, width: 24, height: 24)
    }
}

final class WegramDarkModeContentView: UIScrollView {
    let systemRow = UIView()
    let systemLabel = UILabel()
    let explanation = UILabel()
    let followSwitch = WegramAppearanceSwitch()
    let manualLabel = UILabel()
    let advancedLabel = UILabel()
    let lightButton = WegramDarkModeButton()
    let darkButton = WegramDarkModeButton()
    private let divider = UIView()
    private var lightCheck: UIImageView { self.lightButton.check }
    private var darkCheck: UIImageView { self.darkButton.check }
    private var resolvedDark = false
        private(set) var mode: WegramDarkMode?
    var change: ((WegramDarkMode) -> Void)?
    var submitting = false { didSet { self.updateState() } }

    init() {
        super.init(frame: .zero)
        self.contentInsetAdjustmentBehavior = .never
        self.alwaysBounceVertical = true
        self.addSubview(self.systemRow)
        for view in [self.systemLabel, self.explanation, self.followSwitch] { self.systemRow.addSubview(view) }
        for view in [self.manualLabel, self.advancedLabel, self.lightButton, self.darkButton, self.divider] { self.addSubview(view) }
        self.systemLabel.numberOfLines = 0
        self.explanation.numberOfLines = 0
        self.manualLabel.numberOfLines = 0
        self.advancedLabel.numberOfLines = 0
        self.followSwitch.onTintColor = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
        self.followSwitch.accessibilityIdentifier = "Wegram.Settings.FollowSystem"
        self.followSwitch.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.mode != nil, !self.submitting else { return }
            self.change?(self.followSwitch.isOn ? .system : (self.resolvedDark ? .dark : .light))
        }), for: .valueChanged)
        for (button, check, mode) in [(self.lightButton, self.lightCheck, WegramDarkMode.light), (self.darkButton, self.darkCheck, WegramDarkMode.dark)] {
            button.titleLabel?.numberOfLines = 0
            button.contentHorizontalAlignment = .leading
            button.addSubview(check)
            check.contentMode = .center
            check.tintColor = self.followSwitch.onTintColor
            check.isUserInteractionEnabled = false
            check.isAccessibilityElement = false
            button.addAction(UIAction(handler: { [weak self] _ in
                guard let self, self.mode != nil, self.mode != .system, !self.submitting else { return }
                self.change?(mode)
            }), for: .touchUpInside)
        }
        self.lightButton.accessibilityIdentifier = "Wegram.Settings.LightMode"
        self.darkButton.accessibilityIdentifier = "Wegram.Settings.DarkMode"
        self.updateState()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func load(mode: WegramDarkMode) {
        self.mode = mode
        self.updateState()
        self.setNeedsLayout()
    }

    func update(dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.resolvedDark = dark
        self.backgroundColor = UIColor(white: dark ? 0.07 : 237 / 255, alpha: 1)
        let row = UIColor(white: dark ? 0.1 : 1, alpha: 1)
        let text = UIColor(white: dark ? 0.82 : 0.1, alpha: 1)
        let secondary = UIColor(white: dark ? 0.45 : 0.6, alpha: 1)
        self.systemRow.backgroundColor = row
        self.systemLabel.text = chinese ? "跟随系统" : "Follow System"
        self.systemLabel.font = .systemFont(ofSize: fontSize)
        self.systemLabel.textColor = text
        self.explanation.text = chinese ? "开启后，将跟随系统打开或关闭深色模式" : "Match the system’s light or dark appearance."
        self.explanation.font = .systemFont(ofSize: max(13, fontSize * 13 / 17))
        self.explanation.textColor = secondary
        self.manualLabel.text = chinese ? "手动选择" : "Manual"
        self.manualLabel.font = .systemFont(ofSize: max(13, fontSize * 13 / 17))
        self.manualLabel.textColor = secondary
        self.advancedLabel.text = chinese ? "当前使用定时或亮度自动切换，选择任一模式即可替换。" : "A schedule or brightness rule is active. Choosing a mode replaces it."
        self.advancedLabel.font = self.manualLabel.font
        self.advancedLabel.textColor = secondary
        self.followSwitch.offTintColor = UIColor(white: dark ? 0.22 : 0.9, alpha: 1)
        self.followSwitch.onTitle = chinese ? "已开启" : "On"
        self.followSwitch.offTitle = chinese ? "已关闭" : "Off"
        self.followSwitch.accessibilityLabel = self.systemLabel.text
        self.followSwitch.accessibilityHint = self.explanation.text
        for (button, title) in [(self.lightButton, chinese ? "普通模式" : "Light Mode"), (self.darkButton, chinese ? "深色模式" : "Dark Mode")] {
            button.setTitle(title, for: .normal)
            button.accessibilityLabel = title
            button.titleLabel?.font = .systemFont(ofSize: fontSize)
            button.setTitleColor(text, for: .normal)
            button.backgroundColor = row
        }
        self.divider.backgroundColor = UIColor(white: dark ? 0.16 : 0.94, alpha: 1)
        self.setNeedsLayout()
    }

    private func updateState() {
        self.followSwitch.isOn = self.mode == .system
        self.followSwitch.isEnabled = self.mode != nil && !self.submitting
        let hidden = self.mode == nil || self.mode == .system
        self.manualLabel.isHidden = hidden
        self.lightButton.isHidden = hidden
        self.darkButton.isHidden = hidden
        self.divider.isHidden = hidden
        self.advancedLabel.isHidden = self.mode != .advanced
        for (button, check, selected) in [(self.lightButton, self.lightCheck, self.mode == .light), (self.darkButton, self.darkCheck, self.mode == .dark)] {
            check.isHidden = !selected
            button.isEnabled = !hidden && !self.submitting
            var traits: UIAccessibilityTraits = selected ? [.button, .selected] : .button
            if !button.isEnabled { traits.insert(.notEnabled) }
            button.accessibilityTraits = traits
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let textWidth = max(1, width - 108)
        let titleHeight = ceil(self.systemLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        let descriptionHeight = ceil(self.explanation.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        let systemHeight = max(72, titleHeight + descriptionHeight + 24)
        self.systemRow.frame = CGRect(x: 0, y: 0, width: width, height: systemHeight)
        self.systemLabel.frame = CGRect(x: 16, y: 10, width: textWidth, height: titleHeight)
        self.explanation.frame = CGRect(x: 16, y: 14 + titleHeight, width: textWidth, height: descriptionHeight)
        self.followSwitch.frame = CGRect(x: width - 67, y: (systemHeight - 44) / 2, width: 51, height: 44)
        var y = systemHeight
        if !self.advancedLabel.isHidden {
            let height = ceil(self.advancedLabel.sizeThatFits(CGSize(width: max(1, width - 32), height: .greatestFiniteMagnitude)).height)
            self.advancedLabel.frame = CGRect(x: 16, y: y + 12, width: width - 32, height: height)
            y += height + 12
        }
        if !self.manualLabel.isHidden {
            let headerHeight = max(36, ceil(self.manualLabel.font.lineHeight) + 16)
            self.manualLabel.frame = CGRect(x: 16, y: y + 8, width: width - 32, height: headerHeight - 16)
            y += headerHeight
            for (button, check) in [(self.lightButton, self.lightCheck), (self.darkButton, self.darkCheck)] {
                let textSize = button.titleLabel?.sizeThatFits(CGSize(width: max(1, width - 80), height: .greatestFiniteMagnitude)) ?? .zero
                let height = max(56, ceil(textSize.height) + 24)
                button.frame = CGRect(x: 0, y: y, width: width, height: height)
                button.titleLabel?.frame = CGRect(x: 16, y: 12, width: width - 80, height: height - 24)
                check.frame = CGRect(x: width - 44, y: (height - 24) / 2, width: 24, height: 24)
                y += height
            }
            self.divider.frame = CGRect(x: 16, y: self.lightButton.frame.maxY, width: width - 16, height: 1 / self.traitCollection.displayScale)
        }
        self.contentSize = CGSize(width: width, height: y + 16)
    }
}
