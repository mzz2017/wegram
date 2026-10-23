import XCTest
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit

final class WegramAuthorizationConfirmationTests: XCTestCase {
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

    func testOriginalWarningsAndButtonOrderFitTheCenteredDialogInBothThemes() throws {
        let strings = defaultPresentationStrings
        let cases = [
            (strings.Login_CancelPhoneVerification, strings.Login_CancelPhoneVerificationContinue, strings.Login_CancelPhoneVerificationStop),
            (strings.Login_CancelEmailVerification, strings.Login_CancelEmailVerificationContinue, strings.Login_CancelEmailVerificationStop),
            (strings.Login_CancelSignUpConfirmation, strings.Login_CancelPhoneVerificationContinue, strings.Login_CancelPhoneVerificationStop),
            (strings.TwoStepAuth_ResetAccountConfirmation, strings.Common_Cancel, strings.Login_ResetAccountProtected_Reset)
        ]
        for dark in [false, true] {
            let data = defaultPresentationData().withUpdated(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme)
            for (index, item) in cases.enumerated() {
                let controller = wegramAuthorizationConfirmationController(updatedPresentationData: (initial: data, signal: .never()), text: item.0, actions: [TextAlertAction(type: .genericAction, title: item.1, action: {}), TextAlertAction(type: index == 3 ? .destructiveAction : .defaultAction, title: item.2, action: {})])
                let root = controller.displayNode
                _ = root.view
                for width: CGFloat in [320, 402] {
                    let size = CGSize(width: width, height: 874)
                    root.frame = CGRect(origin: .zero, size: size)
                    controller.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: 285, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), transition: .immediate)
                    let content = controller.contentNode
                    let warning = try XCTUnwrap(self.descendants(content).compactMap { $0 as? ImmediateTextNode }.first { $0.attributedText?.string == item.0 })
                    XCTAssertEqual(warning.accessibilityLabel, item.0)
                    let buttons = self.descendants(content).compactMap { $0 as? TextAlertContentActionNode }
                    XCTAssertEqual(buttons.map { $0.action.title }, [item.1, item.2])
                    let rect = content.view.convert(content.bounds, to: root.view)
                    XCTAssertEqual(rect.midX, width / 2, accuracy: 1)
                    XCTAssertGreaterThanOrEqual(rect.minX, 16)
                    XCTAssertLessThanOrEqual(rect.maxY, 874 - 285)
                    for button in buttons {
                        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
                        XCTAssertLessThanOrEqual(button.frame.maxX, content.bounds.width)
                    }
                    XCTAssertEqual(controller.theme.backgroundColor, UIColor(rgb: dark ? 0x2c2c2c : 0xffffff))
                    XCTAssertEqual(controller.theme.accentColor, UIColor(rgb: 0x07c160))
                    if index == 0, width == 402, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        root.recursivelyEnsureDisplaySynchronously(true)
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1
                        let image = UIGraphicsImageRenderer(size: size, format: format).image { root.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("authorization-confirmation-\(dark ? "dark" : "light").png"))
                    }
                }
            }
        }
    }

    func testConsumedOrDismissedDialogRejectsEveryOldAction() throws {
        for choice in [0, 1, 2, 3, 4] {
            var calls = [0, 0]
            var disposals = 0
            let signal = Signal<PresentationData, NoError> { _ in ActionDisposable { disposals += 1 } }
            let controller = wegramAuthorizationConfirmationController(updatedPresentationData: (initial: defaultPresentationData(), signal: signal), text: "Local test warning", actions: [TextAlertAction(type: .genericAction, title: "Continue", action: { calls[0] += 1 }), TextAlertAction(type: .destructiveAction, title: "Stop", action: { calls[1] += 1 })])
            let buttons = self.descendants(controller.contentNode).compactMap { $0 as? TextAlertContentActionNode }
            if choice < 2 {
                buttons[choice].performAction()
            } else if choice == 2 {
                controller.willDismiss?()
            } else if choice == 3 {
                controller.dismiss()
            } else {
                controller.dismissAnimated()
            }
            buttons[0].performAction()
            buttons[1].performAction()
            buttons[1].performAction()
            XCTAssertEqual(calls, choice == 0 ? [1, 0] : (choice == 1 ? [0, 1] : [0, 0]))
            XCTAssertEqual(disposals, 1)
        }
    }

    func testPresentationUpdatesAndUnpresentedControllerLifetime() {
        let data = defaultPresentationData()
        let controller = wegramAuthorizationConfirmationController(updatedPresentationData: (initial: data, signal: .single(data.withUpdated(theme: defaultDarkPresentationTheme))), text: "Warning **stays literal**", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})])
        XCTAssertEqual(controller.theme.backgroundColor, UIColor(rgb: 0x2c2c2c))
        var disposals = 0
        weak var retained: AlertController?
        autoreleasepool {
            let temporary = wegramAuthorizationConfirmationController(updatedPresentationData: (initial: data, signal: Signal { _ in ActionDisposable { disposals += 1 } }), text: "Warning", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})])
            retained = temporary
        }
        XCTAssertNil(retained)
        XCTAssertEqual(disposals, 1)
    }
}
