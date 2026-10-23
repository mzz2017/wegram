import XCTest
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
@testable import AuthorizationUI

final class WegramPasswordEntryPageTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }
    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }
    private func descendants(_ node: ASDisplayNode) -> [ASDisplayNode] {
        return [node] + (node.subnodes ?? []).flatMap(self.descendants)
    }
    private func layout(_ node: AuthorizationSequencePasswordEntryControllerNode, width: CGFloat, height: CGFloat = 874, inputHeight: CGFloat = 285, navigationHeight: CGFloat = 88) {
        let size = CGSize(width: width, height: height)
        node.frame = CGRect(origin: .zero, size: size)
        node.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), navigationBarHeight: navigationHeight, transition: .immediate)
    }

    func testSecurePasswordFormAndRecoveryControlsFitBothThemesAndCompactWidths() throws {
        for dark in [false, true] {
            let node = AuthorizationSequencePasswordEntryControllerNode(strings: defaultPresentationStrings, theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme, usesWegramAppearance: true)
            _ = node.view
            node.updateData(hint: "Local test hint", didForgotWithNoRecovery: false, suggestReset: false)
            let fieldNode = try XCTUnwrap(self.descendants(node).compactMap { $0 as? TextFieldNode }.first)
            let field = fieldNode.textField
            let button = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.PasswordEntry.Continue" })
            let reset = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.PasswordEntry.Reset" })
            let forgot = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.PasswordEntry.Forgot" })
            for width: CGFloat in [320, 402, 874] {
                self.layout(node, width: width)
                XCTAssertTrue(field.isSecureTextEntry)
                XCTAssertEqual(field.font?.pointSize, 17)
                XCTAssertEqual(field.attributedPlaceholder?.string, "Local test hint")
                XCTAssertEqual(field.accessibilityLabel, defaultPresentationStrings.Login_VoiceOver_Password)
                XCTAssertFalse(button.isHidden)
                XCTAssertEqual(button.frame.height, 44)
                XCTAssertGreaterThanOrEqual(button.frame.minX, 30)
                XCTAssertLessThanOrEqual(button.frame.maxY, 874 - 285)
                XCTAssertGreaterThanOrEqual(fieldNode.frame.width, 150)
                XCTAssertLessThanOrEqual(fieldNode.frame.maxX, width - 30)
                XCTAssertLessThanOrEqual(fieldNode.frame.maxY, forgot.frame.minY)
                XCTAssertLessThanOrEqual(forgot.frame.maxY, button.frame.minY)
                XCTAssertTrue(reset.isHidden)
                node.updateData(hint: "Local test hint", didForgotWithNoRecovery: false, suggestReset: true)
                XCTAssertFalse(reset.isHidden)
                XCTAssertLessThanOrEqual(reset.frame.maxY, button.frame.minY)
                node.updateData(hint: "Local test hint", didForgotWithNoRecovery: true, suggestReset: false)
                XCTAssertFalse(reset.isHidden)
                node.updateData(hint: "Local test hint", didForgotWithNoRecovery: false, suggestReset: false)
                XCTAssertTrue(reset.isHidden)
            }
            self.layout(node, width: 402)
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                node.recursivelyEnsureDisplaySynchronously(true)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: node.bounds.size, format: format).image { node.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("password-entry-\(dark ? "dark" : "light").png"))
            }
        }
    }

    func testShortScreenWithKeyboardKeepsTitleAndResetAboveTheSubmitButton() throws {
        let node = AuthorizationSequencePasswordEntryControllerNode(strings: defaultPresentationStrings, theme: defaultPresentationTheme, usesWegramAppearance: true)
        _ = node.view
        node.updateData(hint: "", didForgotWithNoRecovery: true, suggestReset: false)
        for (width, height, keyboard, navigation): (CGFloat, CGFloat, CGFloat, CGFloat) in [(320, 568, 216, 64), (375, 667, 216, 64), (402, 874, 285, 88)] {
            self.layout(node, width: width, height: height, inputHeight: keyboard, navigationHeight: navigation)
            let title = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.PasswordEntry.Title" })
            let reset = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.PasswordEntry.Reset" })
            let button = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.PasswordEntry.Continue" })
            XCTAssertGreaterThanOrEqual(title.frame.minY, navigation)
            XCTAssertLessThanOrEqual(reset.frame.maxY + 8, button.frame.minY)
            XCTAssertLessThanOrEqual(button.frame.maxY, height - keyboard)
        }
    }

    func testOriginalSubmissionRecoveryAndInvalidPasswordEditingRemainConnected() throws {
        let node = AuthorizationSequencePasswordEntryControllerNode(strings: defaultPresentationStrings, theme: defaultPresentationTheme, usesWegramAppearance: true)
        _ = node.view
        self.layout(node, width: 320)
        let field = try XCTUnwrap(self.descendants(node).compactMap { $0 as? TextFieldNode }.first).textField
        let button = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.PasswordEntry.Continue" })
        XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))
        var submitted: [String] = []
        var forgotCount = 0
        var resetCount = 0
        node.loginWithCode = { submitted.append($0) }
        node.forgot = { forgotCount += 1 }
        node.reset = { resetCount += 1 }
        field.text = "local-test-only"
        node.textDidChange()
        XCTAssertEqual(node.currentPassword, "local-test-only")
        XCTAssertFalse(button.accessibilityTraits.contains(.notEnabled))
        XCTAssertFalse(node.textFieldShouldReturn(field))
        XCTAssertEqual(submitted, ["local-test-only"])
        node.forgotPressed()
        node.resetPressed()
        XCTAssertEqual(forgotCount, 1)
        XCTAssertEqual(resetCount, 1)
        node.passwordIsInvalid()
        XCTAssertFalse(node.textField(field, shouldChangeCharactersIn: NSRange(location: 14, length: 1), replacementString: ""))
        XCTAssertEqual(field.text, "")
        XCTAssertTrue(node.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "a"))
        node.textDidChange()
        XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))

        let original = AuthorizationSequencePasswordEntryControllerNode(strings: defaultPresentationStrings, theme: defaultPresentationTheme)
        _ = original.view
        self.layout(original, width: 320)
        let originalField = try XCTUnwrap(self.descendants(original).compactMap { $0 as? TextFieldNode }.first).textField
        XCTAssertTrue(originalField.isSecureTextEntry)
        XCTAssertEqual(originalField.font?.pointSize, 20)
        XCTAssertTrue(try XCTUnwrap(self.descendants(original).first { $0.accessibilityIdentifier == "Auth.PasswordEntry.Continue" }).isHidden)
    }
}
