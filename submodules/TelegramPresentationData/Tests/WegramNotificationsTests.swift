import XCTest
import UIKit
import UserNotifications
import TelegramCore
import TelegramUIPreferences

final class WegramNotificationsTests: XCTestCase {
    func testMixedCategoriesAndActualSystemPermissionRemainDistinct() {
        var global = GlobalNotificationSettingsSet.defaultSettings
        let local = InAppNotificationSettings.defaultSettings
        global.groupChats.enabled = false
        global.channels.displayPreviews = false
        XCTAssertEqual(WegramNotificationToggle.messages.value(global: global, local: local), .mixed)
        XCTAssertEqual(WegramNotificationToggle.previews.value(global: global, local: local), .mixed)
        var hiddenLocalPreviews = local
        hiddenLocalPreviews.displayPreviews = false
        XCTAssertEqual(WegramNotificationToggle.previews.value(global: .defaultSettings, local: hiddenLocalPreviews), .mixed)
        XCTAssertEqual(WegramNotificationPermission(status: .authorized, alerts: .disabled).title(chinese: true), "弹出提醒已关闭")
        for (status, alerts, expected): (UNAuthorizationStatus, UNNotificationSetting, WegramNotificationPermission) in [
            (.notDetermined, .notSupported, .notDetermined), (.denied, .disabled, .denied),
            (.authorized, .enabled, .allowed), (.authorized, .disabled, .alertsOff),
            (.provisional, .enabled, .quiet), (.ephemeral, .enabled, .temporary)
        ] { XCTAssertEqual(WegramNotificationPermission(status: status, alerts: alerts), expected) }
    }

    func testOnlyChosenFieldsChangeInLatestOriginalPreferences() {
        var global = GlobalNotificationSettingsSet.defaultSettings
        global.groupChats.enabled = false
        global.channels.displayPreviews = false
        global.privateChats.sound = .none
        global.contactsJoined = false
        var local = InAppNotificationSettings.defaultSettings
        local.customSound = "preserve-custom-sound"
        local.displayNameOnLockscreen = false
        local.displayNotificationsFromAllAccounts = false
        local.totalUnreadCountDisplayCategory = .chats
        for field in WegramNotificationToggle.allCases {
            for value in [false, true] {
                let changedGlobal = field.applying(value, to: global)
                let changedLocal = field.applying(value, to: local)
                var expectedGlobal = global
                var expectedLocal = local
                switch field {
                case .messages:
                    expectedGlobal.privateChats.enabled = value
                    expectedGlobal.groupChats.enabled = value
                    expectedGlobal.channels.enabled = value
                case .previews:
                    expectedGlobal.privateChats.displayPreviews = value
                    expectedGlobal.groupChats.displayPreviews = value
                    expectedGlobal.channels.displayPreviews = value
                    expectedLocal.displayPreviews = value
                case .sound: expectedLocal.playSounds = value
                case .vibration: expectedLocal.vibrate = value
                }
                XCTAssertEqual(changedGlobal, expectedGlobal)
                XCTAssertEqual(changedLocal, expectedLocal)
                XCTAssertEqual(field.affectsGlobal, field == .messages || field == .previews)
                XCTAssertEqual(field.affectsLocal, field != .messages)
            }
        }
    }

    func testLoadingBusyAndMixedAccessibilityDoNotInventChanges() {
        let view = WegramNotificationsContentView()
        view.update(dark: false, fontSize: 17, chinese: true)
        var requests: [(WegramNotificationToggle, Bool)] = []
        var permissions = 0
        view.change = { requests.append(($0, $1)) }
        view.openPermission = { permissions += 1 }
        view.rows[0].control.sendActions(for: .valueChanged)
        view.permissionButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(permissions, 0)
        var global = GlobalNotificationSettingsSet.defaultSettings
        global.groupChats.enabled = false
        view.load(global: global, local: .defaultSettings)
        view.load(permission: .denied)
        XCTAssertEqual(view.rows[0].control.accessibilityValue, "部分开启")
        XCTAssertEqual(view.permissionButton.accessibilityValue, "已关闭")
        XCTAssertTrue(view.rows[0].control.accessibilityActivate())
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].0, .messages)
        XCTAssertFalse(requests[0].1)
        view.permissionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(permissions, 1)
        view.submitting = true
        for row in view.rows {
            XCTAssertFalse(row.control.accessibilityActivate())
            XCTAssertTrue(row.control.accessibilityTraits.contains(.notEnabled))
            row.control.sendActions(for: .valueChanged)
        }
        view.permissionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(permissions, 1)
    }

    func testFlatRowsLargeTypeAndShortScreensKeepControlsSeparate() throws {
        for width: CGFloat in [320, 402, 720] {
            for font: CGFloat in [17, 34] {
                let view = WegramNotificationsContentView()
                view.frame = CGRect(x: 0, y: 0, width: width, height: 300)
                view.update(dark: false, fontSize: font, chinese: true)
                var global = GlobalNotificationSettingsSet.defaultSettings
                global.groupChats.enabled = false
                view.load(global: global, local: .defaultSettings)
                view.load(permission: .quiet)
                view.layoutIfNeeded()
                for row in view.rows {
                    row.layoutIfNeeded()
                    XCTAssertEqual(row.control.frame.maxX, width - 16, accuracy: 0.5)
                    XCTAssertGreaterThanOrEqual(row.control.bounds.height, 44)
                    XCTAssertLessThan(row.label.frame.maxX, row.control.frame.minX)
                    if !row.valueLabel.isHidden { XCTAssertLessThan(row.label.frame.maxX, row.valueLabel.frame.minX) }
                    XCTAssertGreaterThanOrEqual(row.label.bounds.height + 0.5, row.label.sizeThatFits(CGSize(width: row.label.bounds.width, height: .greatestFiniteMagnitude)).height)
                }
                XCTAssertLessThan(view.permissionLabel.frame.maxX, view.permissionValue.frame.minX)
                XCTAssertGreaterThan(view.contentSize.height, view.bounds.height)
                if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    view.frame.size.height = 700
                    view.layoutIfNeeded()
                    let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("notifications-component.png"))
                }
            }
        }
    }
}
