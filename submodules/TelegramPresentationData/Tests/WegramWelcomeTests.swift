import XCTest
import UIKit
@testable import AuthorizationUI

final class WegramWelcomeTests: XCTestCase {
    func testBothVisibleActionsContinueThroughTheSamePhoneFlowAndDisableTogether() throws {
        let view = WegramWelcomeView(chinese: false)
        var count = 0
        view.proceed = { count += 1 }
        view.loginButton.sendActions(for: .touchUpInside)
        view.registerButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(count, 2)
        view.enabled = false
        for button in [view.loginButton, view.registerButton, view.languageButton] {
            XCTAssertFalse(button.isEnabled)
        }
        view.loginButton.sendActions(for: .touchUpInside)
        view.registerButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(count, 2)
        view.enabled = true
        view.registerButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(count, 3)
    }

    func testLanguageButtonHasLocalisedTitlesAndAccessibility() {
        let view = WegramWelcomeView(chinese: true)
        XCTAssertEqual(view.loginButton.currentTitle, "登录")
        XCTAssertEqual(view.registerButton.currentTitle, "注册")
        XCTAssertEqual(view.languageButton.currentTitle, "语言")
        XCTAssertEqual(view.loginButton.accessibilityIdentifier, "Auth.Welcome.StartButton")
        XCTAssertEqual(view.accessibilityElements?.count, 3)
        XCTAssertFalse(view.isAccessibilityElement)
        XCTAssertNil(view.languageButton.menu)
    }

    func testLanguageEntryOnlyOpensPickerAndRejectsWhileDisabled() {
        let view = WegramWelcomeView(chinese: false)
        var opened = 0
        var phoneEntries = 0
        view.proceed = { phoneEntries += 1 }
        view.languagePressed = { opened += 1 }
        view.languageButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(opened, 1)
        XCTAssertEqual(phoneEntries, 0)
        view.enabled = false
        view.languageButton.sendActions(for: .touchUpInside)
        view.loginButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(opened, 1)
        XCTAssertEqual(phoneEntries, 0)
        view.updateLanguage(chinese: true)
        view.enabled = true
        XCTAssertEqual(view.loginButton.currentTitle, "登录")
        view.registerButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(phoneEntries, 1)
    }

    func testAppliedLanguageRefreshesTheReusedWelcomeControls() {
        let view = WegramWelcomeView(chinese: false)
        view.enabled = false
        view.updateLanguage(chinese: true)
        XCTAssertEqual(view.loginButton.currentTitle, "登录")
        XCTAssertEqual(view.registerButton.currentTitle, "注册")
        XCTAssertEqual(view.languageButton.currentTitle, "语言")
        XCTAssertFalse(view.loginButton.isEnabled)
        view.enabled = true
        view.updateLanguage(chinese: false)
        XCTAssertEqual(view.loginButton.currentTitle, "Log In")
        XCTAssertEqual(view.languageButton.accessibilityHint, "Choose interface language")
    }

    func testWelcomeGeometryKeepsControlsInsideSafeAreasOnSmallAndWideScreens() throws {
        let view = WegramWelcomeView(chinese: false)
        for size in [CGSize(width: 320, height: 568), CGSize(width: 402, height: 874), CGSize(width: 720, height: 1024), CGSize(width: 874, height: 402)] {
            view.updateLayout(size: size, topInset: 62, bottomInset: 34)
            let buttons = [view.loginButton, view.registerButton, view.languageButton]
            for button in buttons {
                XCTAssertTrue(view.bounds.contains(button.frame))
                XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                XCTAssertGreaterThanOrEqual(button.frame.minY, 62)
            }
            XCTAssertLessThanOrEqual(view.loginButton.frame.maxY, size.height - 34 - 16)
            XCTAssertFalse(view.loginButton.frame.intersects(view.registerButton.frame))
            XCTAssertEqual(view.loginButton.frame.midY, view.registerButton.frame.midY)
            XCTAssertFalse(view.languageButton.frame.intersects(view.loginButton.frame))
        }
        view.updateLayout(size: CGSize(width: 402, height: 874), topInset: 62, bottomInset: 34)
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("welcome-layout.png"))
        }
    }
}
