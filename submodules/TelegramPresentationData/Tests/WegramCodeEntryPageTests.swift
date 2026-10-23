import XCTest
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import CodeInputView
@testable import AuthorizationUI

final class WegramCodeEntryPageTests: XCTestCase {
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
    private func layout(_ node: AuthorizationSequenceCodeEntryControllerNode, width: CGFloat) {
        let size = CGSize(width: width, height: 874)
        node.frame = CGRect(origin: .zero, size: size)
        node.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: 285, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), navigationBarHeight: 88, transition: .immediate)
    }

    func testActualSmsPageUsesFlatInputAndStillSubmitsOnlyACompleteCode() throws {
        for dark in [false, true] {
            let node = AuthorizationSequenceCodeEntryControllerNode(strings: defaultPresentationStrings, theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme, usesWegramAppearance: true)
            _ = node.view
            node.updateData(number: "+10000000000", email: nil, codeType: .sms(length: 5), nextType: .call, timeout: nil, appleSignInAllowed: false, previousCodeType: nil, isPrevious: false)
            self.layout(node, width: 402)
            let input = try XCTUnwrap(self.descendants(node).compactMap { $0 as? CodeInputView }.first)
            XCTAssertEqual(input.bounds.height, 52)
            XCTAssertEqual(input.textField.alpha, 1)
            XCTAssertEqual(input.textField.accessibilityLabel, defaultPresentationStrings.Login_Code)
            XCTAssertEqual(input.textField.textContentType, .oneTimeCode)
            XCTAssertGreaterThanOrEqual(input.frame.minX, 24)
            XCTAssertLessThanOrEqual(input.frame.maxX, 378)
            let title = try XCTUnwrap(self.descendants(node).compactMap { $0 as? AccessibilityAreaNode }.first { $0.accessibilityIdentifier == "Auth.CodeEntry.Title" })
            XCTAssertEqual(title.accessibilityLabel, defaultPresentationStrings.Login_EnterCodeSMSTitle)
            XCTAssertGreaterThanOrEqual(title.frame.minY, 88)
            var codes: [String] = []
            node.loginWithCode = { codes.append($0) }
            input.textField.text = "1234"
            _ = input.perform(NSSelectorFromString("textFieldChanged:"), with: input.textField)
            XCTAssertTrue(codes.isEmpty)
            input.textField.text = "12345"
            _ = input.perform(NSSelectorFromString("textFieldChanged:"), with: input.textField)
            XCTAssertEqual(codes, ["12345"])
            input.textField.text = ""
            _ = input.perform(NSSelectorFromString("textFieldChanged:"), with: input.textField)
            XCTAssertEqual(node.currentCode, "")
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                node.recursivelyEnsureDisplaySynchronously(true)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: node.bounds.size, format: format).image { node.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("code-entry-\(dark ? "dark" : "light").png"))
            }
        }
    }

    func testAlternateVerificationTypesKeepTheirOriginalControlsAndText() throws {
        let cases: [SentAuthorizationCodeType] = [.otherSession(length: 5), .missedCall(numberPrefix: "+123", length: 4), .email(emailPattern: "test@example.invalid", length: 6, resetAvailablePeriod: nil, resetPendingDate: nil, appleSignInAllowed: false, setup: true), .fragment(url: "https://fragment.com", length: 6), .word(startsWith: nil), .phrase(startsWith: nil), .otherSession(length: 5)]
        let node = AuthorizationSequenceCodeEntryControllerNode(strings: defaultPresentationStrings, theme: defaultPresentationTheme, usesWegramAppearance: true)
        _ = node.view
        for type in cases {
            node.updateData(number: "+10000000000", email: nil, codeType: type, nextType: nil, timeout: nil, appleSignInAllowed: false, previousCodeType: nil, isPrevious: false)
            self.layout(node, width: 320)
            let input = try XCTUnwrap(self.descendants(node).compactMap { $0 as? CodeInputView }.first)
            let words = try XCTUnwrap(self.descendants(node).compactMap { $0 as? TextFieldNode }.first)
            switch type {
            case .word, .phrase:
                XCTAssertTrue(input.isHidden)
                XCTAssertFalse(words.isHidden)
            default:
                XCTAssertFalse(input.isHidden)
                XCTAssertTrue(words.isHidden)
                XCTAssertEqual(input.textField.alpha, 1)
            }
            XCTAssertFalse(self.descendants(node).compactMap { $0 as? AccessibilityAreaNode }.filter { !($0.accessibilityLabel ?? "").isEmpty }.isEmpty)
        }
    }
}
