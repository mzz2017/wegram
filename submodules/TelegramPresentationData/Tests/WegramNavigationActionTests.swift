import XCTest
import UIKit
import AsyncDisplayKit
import Display
import NavigationBarImpl

final class WegramNavigationActionTests: XCTestCase {
    private final class SearchReplacement: NavigationBarContentNode {
        let respectsInset: Bool
        init(respectsInset: Bool) {
            self.respectsInset = respectsInset
            super.init()
        }
        override var replacementRespectsTopInset: Bool { self.respectsInset }
        override var nominalHeight: CGFloat { 52 }
    }

    func testReplacementSearchBeginsBelowStatusBarWithoutMovingOriginalLegacyContent() {
        for glass in [false, true] {
            for respectsInset in [false, true] {
                for status: CGFloat in [0, 20, 54, 62] {
                    let theme = NavigationBarTheme(overallDarkAppearance: false, buttonColor: .black, disabledButtonColor: .gray, primaryTextColor: .black, backgroundColor: .white, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .gray, badgeStrokeColor: .clear, badgeTextColor: .black, accentButtonColor: .green, accentDisabledButtonColor: .gray, accentForegroundColor: .white, style: glass ? .glass : .legacy)
                    let bar = NavigationBarImpl(presentationData: NavigationBarPresentationData(theme: theme, strings: NavigationBarStrings(back: "Back", close: "Close")))
                    let content = SearchReplacement(respectsInset: respectsInset)
                    bar.setContentNode(content, animated: false)
                    bar.updateLayout(size: CGSize(width: 402, height: status + 52), defaultHeight: 44, additionalTopHeight: status, additionalContentHeight: 0, additionalBackgroundHeight: 0, additionalCutout: nil, leftInset: 24, rightInset: 8, appearsHidden: false, isLandscape: false, transition: .immediate)
                    let inset: CGFloat = glass ? status + 2 : (respectsInset ? status : 0)
                    XCTAssertEqual(content.frame.origin.y, inset)
                    XCTAssertEqual(content.frame.height, glass || respectsInset ? 52 : status + 52)
                    XCTAssertEqual(content.frame.width, 402)
                }
            }
        }
    }

    func testCustomNavigationActionReachesTheSingleWrapperAndItsView() throws {
        let navigation = NavigationButtonNodeImpl(isGlass: false)
        let custom = ASDisplayNode()
        var opened = 0
        custom.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "More", actionHandler: { _ in opened += 1; return true })]
        let item = try XCTUnwrap(UIBarButtonItem(customDisplayNode: custom))
        item.accessibilityLabel = "Chat Info"
        var presses: [Int] = []
        navigation.pressed = { presses.append($0) }
        navigation.updateItems([item], animated: false)
        let element = try XCTUnwrap(navigation.accessibilityElements?.first as? ASDisplayNode)
        XCTAssertEqual(navigation.accessibilityElements?.count, 1)
        XCTAssertEqual(element.accessibilityLabel, "Chat Info")
        XCTAssertEqual(element.accessibilityCustomActions?.map(\.name), ["More"])
        XCTAssertEqual(element.view.accessibilityCustomActions?.map(\.name), ["More"])
        XCTAssertFalse(custom.isAccessibilityElement)
        let more = try XCTUnwrap(element.view.accessibilityCustomActions?.first)
        XCTAssertTrue(more.actionHandler?(more) == true)
        XCTAssertEqual(opened, 1)
        XCTAssertTrue(presses.isEmpty)
        XCTAssertTrue(element.view.accessibilityActivate())
        XCTAssertEqual(presses, [0])
        item.accessibilityLabel = "Updated Profile"
        XCTAssertEqual(element.accessibilityLabel, "Updated Profile")
    }

    func testDisabledHiddenAndRemovedNavigationElementsCannotActivate() throws {
        let navigation = NavigationButtonNodeImpl(isGlass: false)
        let custom = ASDisplayNode()
        custom.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "More", actionHandler: { _ in true })]
        let item = try XCTUnwrap(UIBarButtonItem(customDisplayNode: custom))
        var presses = 0
        navigation.pressed = { _ in presses += 1 }
        navigation.updateItems([item], animated: false)
        let element = try XCTUnwrap(navigation.accessibilityElements?.first as? ASDisplayNode)
        item.isEnabled = false
        XCTAssertFalse(element.view.accessibilityActivate())
        XCTAssertTrue(element.accessibilityTraits.contains(.notEnabled))
        XCTAssertNil(element.accessibilityCustomActions)
        XCTAssertNil(element.view.accessibilityCustomActions)
        item.isEnabled = true
        XCTAssertFalse(element.accessibilityTraits.contains(.notEnabled))
        XCTAssertEqual(element.view.accessibilityCustomActions?.count, 1)
        element.isHidden = true
        XCTAssertFalse(element.view.accessibilityActivate())
        element.isHidden = false
        element.alpha = 0
        XCTAssertFalse(element.view.accessibilityActivate())
        element.alpha = 1
        XCTAssertTrue(element.view.accessibilityActivate())
        XCTAssertEqual(presses, 1)
        navigation.updateItems([], animated: false)
        XCTAssertFalse(element.view.accessibilityActivate())
        XCTAssertEqual(presses, 1)
    }

    func testCustomActionsRefreshAndClearWhenAWrapperIsReused() throws {
        let navigation = NavigationButtonNodeImpl(isGlass: false)
        let custom = ASDisplayNode()
        custom.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "More", actionHandler: { _ in true })]
        let item = try XCTUnwrap(UIBarButtonItem(customDisplayNode: custom))
        navigation.updateItems([item], animated: false)
        let element = try XCTUnwrap(navigation.accessibilityElements?.first as? ASDisplayNode)
        let action = try XCTUnwrap(custom.view.accessibilityCustomActions?.first)
        action.name = "更多"
        XCTAssertEqual(element.accessibilityCustomActions?.map(\.name), ["更多"])
        XCTAssertEqual(element.view.accessibilityCustomActions?.map(\.name), ["更多"])
        custom.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Updated", actionHandler: { _ in true })]
        navigation.updateItems([item], animated: false)
        XCTAssertEqual(element.accessibilityCustomActions?.map(\.name), ["Updated"])
        XCTAssertEqual(element.view.accessibilityCustomActions?.map(\.name), ["Updated"])
        navigation.updateItems([UIBarButtonItem(title: "Done", style: .plain, target: nil, action: nil)], animated: false)
        XCTAssertEqual(element.accessibilityLabel, "Done")
        XCTAssertNil(element.accessibilityCustomActions)
        XCTAssertNil(element.view.accessibilityCustomActions)
        navigation.updateManualText("Back")
        XCTAssertEqual(element.accessibilityLabel, "Back")
        XCTAssertNil(element.accessibilityCustomActions)
    }
}
