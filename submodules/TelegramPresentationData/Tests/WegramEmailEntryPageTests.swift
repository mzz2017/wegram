import XCTest
import UIKit
import AuthenticationServices
import AsyncDisplayKit
import Display
import NavigationBarImpl
import TelegramPresentationData
@testable import AuthorizationUI

final class WegramEmailEntryPageTests: XCTestCase {
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
    private func layout(_ node: AuthorizationSequenceEmailEntryControllerNode, size: CGSize, keyboard: CGFloat, navigation: CGFloat) {
        node.frame = CGRect(origin: .zero, size: size)
        node.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: keyboard, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), navigationBarHeight: navigation, transition: .immediate)
    }

    func testEmailFormFitsShortScreensAndKeepsOriginalKeyboardAndModeText() throws {
        for dark in [false, true] {
            let node = AuthorizationSequenceEmailEntryControllerNode(strings: defaultPresentationStrings, theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme, mode: .setup, usesWegramAppearance: true)
            _ = node.view
            node.updateData(appleSignInAllowed: false)
            for (size, keyboard, navigation): (CGSize, CGFloat, CGFloat) in [(CGSize(width: 320, height: 568), 216, 64), (CGSize(width: 402, height: 874), 285, 88), (CGSize(width: 874, height: 874), 285, 88)] {
                self.layout(node, size: size, keyboard: keyboard, navigation: navigation)
                let field = try XCTUnwrap(self.descendants(node).compactMap { $0 as? TextFieldNode }.first)
                let title = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.EmailEntry.Title" } as? ASTextNode)
                let button = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.EmailEntry.Continue" })
                XCTAssertEqual(title.attributedText?.string, defaultPresentationStrings.LoginEmail_Title)
                XCTAssertGreaterThanOrEqual(title.frame.minY, navigation)
                XCTAssertEqual(field.textField.font?.pointSize, 17)
                XCTAssertEqual(field.textField.keyboardType, .emailAddress)
                XCTAssertEqual(field.textField.autocorrectionType, .no)
                XCTAssertEqual(field.textField.autocapitalizationType, .none)
                XCTAssertEqual(field.textField.placeholder, defaultPresentationStrings.Login_AddEmailPlaceholder)
                XCTAssertEqual(field.textField.attributedPlaceholder?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, (dark ? defaultDarkPresentationTheme : defaultPresentationTheme).list.itemPlaceholderTextColor)
                XCTAssertFalse(button.isHidden)
                XCTAssertEqual(button.frame.height, 44)
                XCTAssertEqual(button.alpha, 1)
                XCTAssertGreaterThanOrEqual(field.frame.minX, 30)
                XCTAssertLessThanOrEqual(field.frame.maxX, size.width - 30)
                XCTAssertLessThanOrEqual(field.frame.maxY + 8, button.frame.minY)
                XCTAssertLessThanOrEqual(button.frame.maxY, size.height - keyboard)
            }
            self.layout(node, size: CGSize(width: 402, height: 874), keyboard: 285, navigation: 88)
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                node.recursivelyEnsureDisplaySynchronously(true)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: node.bounds.size, format: format).image { node.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("email-entry-\(dark ? "dark" : "light").png"))
            }
        }
        let original = AuthorizationSequenceEmailEntryControllerNode(strings: defaultPresentationStrings, theme: defaultPresentationTheme, mode: .change)
        _ = original.view
        self.layout(original, size: CGSize(width: 320, height: 568), keyboard: 216, navigation: 64)
        XCTAssertTrue(try XCTUnwrap(self.descendants(original).first { $0.accessibilityIdentifier == "Auth.EmailEntry.Continue" }).isHidden)
        XCTAssertEqual(try XCTUnwrap(self.descendants(original).compactMap { $0 as? TextFieldNode }.first).textField.font?.pointSize, 20)
        XCTAssertEqual(try XCTUnwrap(self.descendants(original).first { $0.accessibilityIdentifier == "Auth.EmailEntry.Title" } as? ASTextNode).attributedText?.string, defaultPresentationStrings.Login_EnterNewEmailTitle)
    }

    func testInitialAppleChoiceAndLaterEmailEditsKeepOnlyTheIntendedButtonVisible() throws {
        let node = AuthorizationSequenceEmailEntryControllerNode(strings: defaultPresentationStrings, theme: defaultPresentationTheme, mode: .setup, usesWegramAppearance: true)
        _ = node.view
        node.updateData(appleSignInAllowed: true)
        self.layout(node, size: CGSize(width: 320, height: 568), keyboard: 216, navigation: 64)
        let button = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.EmailEntry.Continue" })
        let apple = try XCTUnwrap(node.view.subviews.compactMap { $0 as? ASAuthorizationAppleIDButton }.first)
        let field = try XCTUnwrap(self.descendants(node).compactMap { $0 as? TextFieldNode }.first).textField
        XCTAssertEqual(button.alpha, 0, "Empty email with Apple available must hide the underlying Continue control on first layout")
        XCTAssertFalse(apple.isHidden)
        XCTAssertEqual(apple.alpha, 1)
        XCTAssertGreaterThan(apple.frame.width, 0)
        field.text = "test@example.invalid"
        _ = node.perform(NSSelectorFromString("textDidChange"))
        XCTAssertEqual(button.alpha, 1)
        XCTAssertEqual(apple.alpha, 0)
        var emails: [String] = []
        var appleCount = 0
        node.proceedWithEmail = { emails.append($0) }
        node.signInWithApple = { appleCount += 1 }
        node.proceedPressed()
        XCTAssertFalse(node.textFieldShouldReturn(field))
        XCTAssertEqual(emails, ["test@example.invalid", "test@example.invalid"])
        node.signInWithApplePressed()
        XCTAssertEqual(appleCount, 1)
        field.text = ""
        _ = node.perform(NSSelectorFromString("textDidChange"))
        XCTAssertEqual(button.alpha, 0)
        XCTAssertEqual(apple.alpha, 1)
        node.updateData(appleSignInAllowed: false)
        XCTAssertTrue(apple.isHidden)
        XCTAssertEqual(button.alpha, 1)
    }

    func testActualControllerKeepsEmptyValidationAndOriginalAppleRouting() throws {
        let previousFactory = defaultNavigationBarImpl
        defaultNavigationBarImpl = { NavigationBarImpl(presentationData: $0) }
        defer { defaultNavigationBarImpl = previousFactory }
        let controller = AuthorizationSequenceEmailEntryController(presentationData: defaultPresentationData(), mode: .setup, usesWegramAppearance: true, back: {})
        let node = try XCTUnwrap(controller.displayNode as? AuthorizationSequenceEmailEntryControllerNode)
        _ = node.view
        let field = try XCTUnwrap(self.descendants(node).compactMap { $0 as? TextFieldNode }.first).textField
        var emails: [String] = []
        var appleCount = 0
        controller.proceedWithEmail = { emails.append($0) }
        controller.signInWithApple = { appleCount += 1 }
        node.proceedPressed()
        XCTAssertTrue(emails.isEmpty)
        XCTAssertEqual(appleCount, 0)
        controller.updateData(appleSignInAllowed: true)
        node.proceedPressed()
        XCTAssertEqual(appleCount, 1)
        field.text = "test@example.invalid"
        node.proceedPressed()
        XCTAssertEqual(emails, ["test@example.invalid"])
        XCTAssertEqual(appleCount, 1)
        controller.updateNavigationItems()
        XCTAssertNil(controller.navigationItem.rightBarButtonItem)
    }
}
