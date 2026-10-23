import XCTest
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SolidRoundedButtonNode
import TextFormat
@testable import AuthorizationUI

final class WegramSignUpPageTests: XCTestCase {
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
    private func layout(_ node: AuthorizationSequenceSignUpControllerNode, size: CGSize, keyboard: CGFloat, navigation: CGFloat) {
        node.frame = CGRect(origin: .zero, size: size)
        node.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: keyboard, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), navigationBarHeight: navigation, transition: .immediate)
    }

    func testScrollableProfileFormKeepsEveryFieldAndTermsReachableAboveKeyboard() throws {
        for dark in [false, true] {
            let theme = dark ? defaultDarkPresentationTheme : defaultPresentationTheme
            let node = AuthorizationSequenceSignUpControllerNode(theme: theme, strings: defaultPresentationStrings, usesWegramAppearance: true, addPhoto: {})
            _ = node.view
            node.updateData(firstName: "", lastName: "", hasTermsOfService: true)
            let scroll = try XCTUnwrap(self.descendants(node).compactMap { $0 as? ASScrollNode }.first)
            let terms = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.SetName.Terms" })
            let photo = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.SetName.Photo" })
            let title = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.SetName.Title" })
            let button = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.SetName.ContinueButton" })
            for (size, keyboard, navigation): (CGSize, CGFloat, CGFloat) in [(CGSize(width: 320, height: 568), 216, 64), (CGSize(width: 402, height: 874), 285, 88), (CGSize(width: 874, height: 874), 285, 88)] {
                self.layout(node, size: size, keyboard: keyboard, navigation: navigation)
                XCTAssertTrue(scroll.clipsToBounds)
                XCTAssertEqual(scroll.frame.minY, navigation)
                XCTAssertGreaterThan(scroll.frame.height, 100)
                XCTAssertLessThanOrEqual(scroll.frame.maxY + 8, button.frame.minY)
                XCTAssertLessThanOrEqual(button.frame.maxY, size.height - keyboard)
                XCTAssertFalse(button.isHidden)
                XCTAssertEqual(button.frame.height, 44)
                XCTAssertEqual(photo.frame.size, CGSize(width: 64, height: 64))
                XCTAssertGreaterThanOrEqual(photo.frame.minY, title.frame.maxY)
                XCTAssertFalse(terms.isHidden)
                XCTAssertLessThanOrEqual(terms.frame.maxY, scroll.view.contentSize.height)
                scroll.view.scrollRectToVisible(terms.frame, animated: false)
                XCTAssertLessThanOrEqual(terms.frame.maxY, scroll.view.contentOffset.y + scroll.bounds.height + 1)
                for field in self.descendants(node).compactMap({ $0 as? TextFieldNode }) {
                    XCTAssertEqual(field.textField.font?.pointSize, 17)
                    XCTAssertGreaterThanOrEqual(field.frame.minX, 30)
                    XCTAssertLessThanOrEqual(field.frame.maxX, size.width - 30)
                    XCTAssertLessThanOrEqual(field.frame.maxY, scroll.view.contentSize.height)
                }
                node.updateData(firstName: "", lastName: "", hasTermsOfService: false)
                XCTAssertTrue(terms.isHidden)
                node.updateData(firstName: "", lastName: "", hasTermsOfService: true)
                XCTAssertFalse(terms.isHidden)
            }
            self.layout(node, size: CGSize(width: 402, height: 874), keyboard: 285, navigation: 88)
            scroll.view.contentOffset = .zero
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                node.recursivelyEnsureDisplaySynchronously(true)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: node.bounds.size, format: format).image { node.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("signup-\(dark ? "dark" : "light").png"))
            }
        }
    }

    func testOriginalNamePhotoAndTermsActionsRemainConnected() throws {
        var photos = 0
        var termsOpened = 0
        var submitted: [(String, String)] = []
        let node = AuthorizationSequenceSignUpControllerNode(theme: defaultPresentationTheme, strings: defaultPresentationStrings, usesWegramAppearance: true, addPhoto: { photos += 1 })
        _ = node.view
        node.signUpWithName = { submitted.append(($0, $1)) }
        node.openTermsOfService = { termsOpened += 1 }
        node.updateData(firstName: "Local", lastName: "Test", hasTermsOfService: true)
        self.layout(node, size: CGSize(width: 320, height: 568), keyboard: 216, navigation: 64)
        let fields = self.descendants(node).compactMap { $0 as? TextFieldNode }
        XCTAssertEqual(fields.count, 2)
        XCTAssertEqual(fields[0].textField.textContentType, .givenName)
        XCTAssertEqual(fields[1].textField.textContentType, .familyName)
        XCTAssertEqual(fields[0].textField.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, defaultPresentationTheme.list.itemPrimaryTextColor)
        let button = try XCTUnwrap(self.descendants(node).compactMap { $0 as? SolidRoundedButtonNode }.first)
        button.pressed?()
        XCTAssertFalse(node.textFieldShouldReturn(fields[1].textField))
        XCTAssertEqual(submitted.map { $0.0 }, ["Local", "Local"])
        XCTAssertEqual(submitted.map { $0.1 }, ["Test", "Test"])
        _ = node.perform(NSSelectorFromString("addPhotoPressed"))
        XCTAssertEqual(photos, 1)
        let terms = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.SetName.Terms" } as? ImmediateTextNode)
        terms.tapAttributeAction?([NSAttributedString.Key(rawValue: TelegramTextAttributes.URL): ""], 0)
        XCTAssertEqual(termsOpened, 1)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12), format: format).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        node.currentPhoto = photo
        XCTAssertTrue(node.currentPhoto === photo)
        let photoButton = try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.SetName.Photo" })
        let preview = try XCTUnwrap(photoButton.subnodes?.compactMap { $0 as? ASImageNode }.last { $0.image?.size == CGSize(width: 64, height: 64) })
        XCTAssertEqual(preview.image?.size, CGSize(width: 64, height: 64))
        node.currentPhoto = nil
        XCTAssertNil(preview.image)
    }

    func testTermsRemovalAndKeyboardDismissalClampTheExistingScrollPosition() throws {
        let node = AuthorizationSequenceSignUpControllerNode(theme: defaultPresentationTheme, strings: defaultPresentationStrings, usesWegramAppearance: true, addPhoto: {})
        _ = node.view
        node.updateData(firstName: "", lastName: "", hasTermsOfService: true)
        self.layout(node, size: CGSize(width: 320, height: 568), keyboard: 216, navigation: 64)
        let scroll = try XCTUnwrap(self.descendants(node).compactMap { $0 as? ASScrollNode }.first)
        scroll.view.contentOffset.y = max(0, scroll.view.contentSize.height - scroll.bounds.height)
        XCTAssertGreaterThan(scroll.view.contentOffset.y, 0)
        node.updateData(firstName: "", lastName: "", hasTermsOfService: false)
        XCTAssertLessThanOrEqual(scroll.view.contentOffset.y, max(0, scroll.view.contentSize.height - scroll.bounds.height))
        let keyboardTransitionSettled = self.expectation(description: "Original two-second keyboard transition guard has elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { keyboardTransitionSettled.fulfill() }
        self.wait(for: [keyboardTransitionSettled], timeout: 3)
        self.layout(node, size: CGSize(width: 402, height: 874), keyboard: 0, navigation: 88)
        XCTAssertEqual(scroll.frame.maxY, 874 - 34 - 82)
        XCTAssertEqual(scroll.view.contentOffset.y, 0)
    }

    func testDefaultProfileStillUsesOriginalFieldAndAvatarAppearance() throws {
        let node = AuthorizationSequenceSignUpControllerNode(theme: defaultPresentationTheme, strings: defaultPresentationStrings, addPhoto: {})
        _ = node.view
        node.updateData(firstName: "Local", lastName: "", hasTermsOfService: false)
        self.layout(node, size: CGSize(width: 320, height: 568), keyboard: 216, navigation: 64)
        XCTAssertTrue(self.descendants(node).compactMap { $0 as? ASScrollNode }.isEmpty)
        XCTAssertEqual(try XCTUnwrap(self.descendants(node).compactMap { $0 as? TextFieldNode }.first).textField.font?.pointSize, 20)
        XCTAssertTrue(try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.SetName.ContinueButton" }).isHidden)
        XCTAssertEqual(try XCTUnwrap(self.descendants(node).first { $0.accessibilityIdentifier == "Auth.SetName.Photo" }).frame.width, 110)
    }
}
