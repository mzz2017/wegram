import XCTest
import UIKit
import Display
import TelegramUIPreferences

final class WegramDarkModeTests: XCTestCase {
    func testOriginalAutomaticRulesAreClassifiedWithoutWriting() {
        var settings = PresentationThemeSettings.defaultSettings
        XCTAssertEqual(WegramDarkMode.current(settings: settings, resolvedDark: false), .system)
        settings.automaticThemeSwitchSetting.force = true
        XCTAssertEqual(WegramDarkMode.current(settings: settings, resolvedDark: true), .dark)
        settings.automaticThemeSwitchSetting.force = false
        settings.automaticThemeSwitchSetting.trigger = .brightness(threshold: 0.3)
        XCTAssertEqual(WegramDarkMode.current(settings: settings, resolvedDark: true), .advanced)
        let untouched = WegramDarkMode.advanced.applying(to: settings)
        XCTAssertEqual(untouched.automaticThemeSwitchSetting, settings.automaticThemeSwitchSetting)
        XCTAssertEqual(untouched.theme, settings.theme)
        settings.automaticThemeSwitchSetting.trigger = .explicitNone
        settings.theme = .builtin(.nightAccent)
        XCTAssertEqual(WegramDarkMode.current(settings: settings, resolvedDark: false), .dark, "Known stored theme must win over a delayed presentation update")
        settings.theme = .builtin(.day)
        XCTAssertEqual(WegramDarkMode.current(settings: settings, resolvedDark: true), .light)
    }

    func testExplicitModesUseOriginalPreferencesAndPreserveOtherLatestSettings() {
        var current = PresentationThemeSettings.defaultSettings
        current.fontSize = .extraLarge
        current.listsFontSize = .small
        current.reduceMotion = true
        current.theme = .builtin(.night)
        current.automaticThemeSwitchSetting.trigger = .timeBased(setting: .manual(fromSeconds: 100, toSeconds: 200))
        for mode in [WegramDarkMode.light, .dark, .system] {
            let updated = mode.applying(to: current)
            XCTAssertEqual(updated.theme, .builtin(.dayClassic))
            XCTAssertEqual(updated.automaticThemeSwitchSetting.theme, .builtin(.night))
            XCTAssertEqual(updated.automaticThemeSwitchSetting.force, mode == .dark)
            XCTAssertEqual(updated.automaticThemeSwitchSetting.trigger, mode == .system ? .system : .explicitNone)
            XCTAssertEqual(updated.fontSize, .extraLarge)
            XCTAssertEqual(updated.listsFontSize, .small)
            XCTAssertTrue(updated.reduceMotion)
        }
    }

    func testSwitchAndRowsOnlyRequestChangesWhenReady() {
        let view = WegramDarkModeContentView()
        view.update(dark: false, fontSize: 17, chinese: true)
        var requests: [WegramDarkMode] = []
        view.change = { requests.append($0) }
        XCTAssertFalse(view.followSwitch.isEnabled)
        view.darkButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(requests.isEmpty)
        view.load(mode: .system)
        XCTAssertTrue(view.followSwitch.isOn)
        XCTAssertTrue(view.lightButton.isHidden)
        view.followSwitch.isOn = false
        view.followSwitch.sendActions(for: .valueChanged)
        XCTAssertEqual(requests, [.light])
        view.load(mode: .light)
        XCTAssertFalse(view.lightButton.isHidden)
        XCTAssertTrue(view.lightButton.accessibilityTraits.contains(.selected))
        view.darkButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(requests, [.light, .dark])
        view.submitting = true
        view.darkButton.sendActions(for: .touchUpInside)
        view.followSwitch.sendActions(for: .valueChanged)
        XCTAssertEqual(requests.count, 2)
        XCTAssertFalse(view.followSwitch.isEnabled)
        XCTAssertTrue(view.lightButton.accessibilityTraits.contains(.notEnabled), "Busy mode rows must announce their disabled state")
        XCTAssertTrue(view.darkButton.accessibilityTraits.contains(.notEnabled), "Busy mode rows must announce their disabled state")
        view.submitting = false
        XCTAssertFalse(view.darkButton.accessibilityTraits.contains(.notEnabled))
        view.update(dark: true, fontSize: 17, chinese: false)
        view.load(mode: .system)
        view.followSwitch.isOn = false
        view.followSwitch.sendActions(for: .valueChanged)
        XCTAssertEqual(requests.last, .dark)
        XCTAssertEqual(view.followSwitch.accessibilityLabel, "Follow System")
        view.load(mode: .advanced)
        XCTAssertFalse(view.advancedLabel.isHidden)
        XCTAssertFalse(view.darkButton.accessibilityTraits.contains(.selected))
        XCTAssertFalse(view.lightButton.accessibilityTraits.contains(.selected))
    }

    func testFlatSwitchAccessibilityAndDisabledActivation() {
        let control = WegramAppearanceSwitch()
        var changes = 0
        control.addAction(UIAction(handler: { _ in changes += 1 }), for: .valueChanged)
        XCTAssertFalse(control.isOn)
        XCTAssertTrue(control.accessibilityActivate())
        XCTAssertTrue(control.isOn)
        XCTAssertEqual(control.accessibilityValue, "On")
        XCTAssertEqual(changes, 1)
        control.isEnabled = false
        XCTAssertFalse(control.accessibilityActivate())
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(control.accessibilityTraits.contains(.notEnabled))
        XCTAssertEqual(control.intrinsicContentSize, CGSize(width: 51, height: 44))
    }

    func testLongLabelsRemainScrollableAndDoNotCoverSwitchOrChecks() throws {
        for size in [CGSize(width: 320, height: 450), CGSize(width: 402, height: 771), CGSize(width: 720, height: 200)] {
            for font: CGFloat in [17, 34] {
                let view = WegramDarkModeContentView()
                view.frame = CGRect(origin: .zero, size: size)
                view.update(dark: false, fontSize: font, chinese: true)
                view.load(mode: .light)
                view.layoutIfNeeded()
                view.lightButton.layoutIfNeeded()
                view.darkButton.layoutIfNeeded()
                XCTAssertGreaterThanOrEqual(view.followSwitch.bounds.height, 44)
                XCTAssertEqual(view.followSwitch.frame.maxX, size.width - 16, accuracy: 0.5, "The switch must keep the reference trailing inset on iOS 27")
                XCTAssertLessThan(view.explanation.frame.maxX, view.followSwitch.frame.minX)
                XCTAssertLessThanOrEqual(view.explanation.frame.maxY, view.systemRow.bounds.height - 8)
                XCTAssertGreaterThanOrEqual(view.lightButton.bounds.height, 44)
                XCTAssertLessThan(view.lightButton.titleLabel!.frame.maxX, view.lightButton.check.frame.minX)
                XCTAssertGreaterThanOrEqual(view.contentSize.height, view.darkButton.frame.maxY)
                if size.width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let image = UIGraphicsImageRenderer(size: size).image { view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("dark-mode-light-component.png"))
                }
            }
        }
    }
}
