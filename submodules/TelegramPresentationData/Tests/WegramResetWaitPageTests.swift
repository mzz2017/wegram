import XCTest
import UIKit
import AsyncDisplayKit
import Display
import NavigationBarImpl
import TelegramPresentationData
@testable import AuthorizationUI

final class WegramResetWaitPageTests: XCTestCase {
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
    private func layout(_ node: AuthorizationSequenceAwaitingAccountResetControllerNode, size: CGSize, navigation: CGFloat) {
        node.frame = CGRect(origin: .zero, size: size)
        node.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), navigationBarHeight: navigation, transition: .immediate)
    }

    func testWaitingInstructionsAndCountdownRemainReachableInBothThemes() throws {
        let now = Int32(Date().timeIntervalSince1970)
        for dark in [false, true] {
            let node = AuthorizationSequenceAwaitingAccountResetControllerNode(strings: defaultPresentationStrings, theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme, usesWegramAppearance: true)
            _ = node.view
            node.updateData(protectedUntil: now + 2 * 86400 + 5400, number: "+10000000000")
            let scroll = try XCTUnwrap(self.descendants(node).compactMap { $0 as? ASScrollNode }.first)
            let title = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.ResetWait.Title" } as? ASTextNode)
            let notice = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.ResetWait.Notice" } as? ASTextNode)
            let value = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.ResetWait.TimerValue" } as? ASTextNode)
            let button = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.ResetWait.Reset" } as? HighlightableButtonNode)
            for (size, navigation): (CGSize, CGFloat) in [(CGSize(width: 320, height: 568), 64), (CGSize(width: 402, height: 874), 88), (CGSize(width: 874, height: 402), 64)] {
                self.layout(node, size: size, navigation: navigation)
                XCTAssertEqual(title.attributedText?.string, defaultPresentationStrings.Login_ResetAccountProtected_Title)
                XCTAssertEqual(notice.attributedText?.string, defaultPresentationStrings.Login_ResetAccountProtected_Text("+10000000000").string)
                XCTAssertTrue(value.attributedText?.string.contains(defaultPresentationStrings.MessageTimer_Days(2)) == true)
                XCTAssertEqual(value.accessibilityLabel, value.attributedText?.string)
                XCTAssertEqual(scroll.frame.minY, navigation)
                XCTAssertGreaterThanOrEqual(title.frame.minY, 0)
                XCTAssertLessThanOrEqual(button.frame.maxY, scroll.view.contentSize.height)
                XCTAssertGreaterThanOrEqual(button.frame.height, 44)
                XCTAssertGreaterThanOrEqual(button.frame.minX, 30)
                XCTAssertLessThanOrEqual(button.frame.maxX, size.width - 30)
                XCTAssertFalse(button.isEnabled)
                XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))
                scroll.view.scrollRectToVisible(button.frame, animated: false)
                XCTAssertLessThanOrEqual(button.frame.maxY, scroll.view.contentOffset.y + scroll.bounds.height + 1)
            }
            self.layout(node, size: CGSize(width: 402, height: 874), navigation: 88)
            scroll.view.contentOffset = .zero
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                node.recursivelyEnsureDisplaySynchronously(true)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: node.bounds.size, format: format).image { node.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("reset-wait-\(dark ? "dark" : "light").png"))
            }
        }
    }

    func testOriginalTimerEnablesResetOnlyAfterExpiryAndRefreshesAccessibility() throws {
        let node = AuthorizationSequenceAwaitingAccountResetControllerNode(strings: defaultPresentationStrings, theme: defaultPresentationTheme, usesWegramAppearance: true)
        _ = node.view
        self.layout(node, size: CGSize(width: 320, height: 568), navigation: 64)
        let button = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.ResetWait.Reset" } as? HighlightableButtonNode)
        let value = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.ResetWait.TimerValue" } as? ASTextNode)
        node.updateData(protectedUntil: Int32(Date().timeIntervalSince1970) + 2, number: "")
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(value.attributedText?.string, defaultPresentationStrings.MessageTimer_Minutes(1))
        let elapsed = self.expectation(description: "Original one-second timer observes expiry")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) { elapsed.fulfill() }
        self.wait(for: [elapsed], timeout: 4)
        XCTAssertTrue(button.isEnabled)
        XCTAssertFalse(button.accessibilityTraits.contains(.notEnabled))
        XCTAssertEqual(value.attributedText?.string, defaultPresentationStrings.MessageTimer_Minutes(0))
        var resets = 0
        node.reset = { resets += 1 }
        node.resetPressed()
        XCTAssertEqual(resets, 1)
        node.updateData(protectedUntil: Int32(Date().timeIntervalSince1970) + 3600, number: "")
        XCTAssertFalse(button.isEnabled)
        XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))
    }

    func testControllerKeepsLogoutLabelAfterProgressAndDefaultNodeStaysOriginal() throws {
        let previousFactory = defaultNavigationBarImpl
        defaultNavigationBarImpl = { NavigationBarImpl(presentationData: $0) }
        defer { defaultNavigationBarImpl = previousFactory }
        let controller = AuthorizationSequenceAwaitingAccountResetController(strings: defaultPresentationStrings, theme: defaultPresentationTheme, usesWegramAppearance: true, back: {})
        _ = controller.displayNode.view
        var logouts = 0
        controller.logout = { logouts += 1 }
        XCTAssertEqual(controller.navigationItem.rightBarButtonItem?.title, defaultPresentationStrings.Settings_Logout)
        controller.inProgress = true
        controller.inProgress = false
        XCTAssertEqual(controller.navigationItem.rightBarButtonItem?.title, defaultPresentationStrings.Settings_Logout)
        controller.logoutPressed()
        XCTAssertEqual(logouts, 1)
        let original = AuthorizationSequenceAwaitingAccountResetControllerNode(strings: defaultPresentationStrings, theme: defaultPresentationTheme)
        _ = original.view
        self.layout(original, size: CGSize(width: 320, height: 568), navigation: 64)
        XCTAssertTrue(self.descendants(original).compactMap { $0 as? ASScrollNode }.isEmpty)
        let title = try XCTUnwrap(self.descendants(original).first { $0.accessibilityIdentifier == "Auth.ResetWait.Title" } as? ASTextNode)
        XCTAssertEqual((title.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, 30)
    }
}
