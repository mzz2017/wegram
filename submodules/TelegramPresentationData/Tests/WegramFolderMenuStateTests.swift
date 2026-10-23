import XCTest
import UIKit
import Display
import ContextUI
import ContextControllerImpl
import TelegramPresentationData

final class WegramFolderMenuStateTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }

    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }

    private func node(_ action: ContextMenuActionItem) -> ContextActionNode {
        return ContextActionNode(presentationData: defaultPresentationData(), action: action, getController: { nil }, actionSelected: { _ in }, requestLayout: {}, requestUpdateAction: { _, _ in })
    }

    func testCurrentFolderAndUnreadBadgeReachTheActualAccessibilityButton() throws {
        let action = ContextMenuActionItem(text: "Groups", isSelected: true, badge: ContextMenuActionBadge(value: "12", color: .inactive), icon: { _ in nil }, action: { _, _ in })
        let node = self.node(action)
        let button = try XCTUnwrap(node.subnodes?.compactMap { $0 as? HighlightTrackingButtonNode }.first)
        XCTAssertEqual(button.accessibilityLabel, "Groups")
        XCTAssertEqual(button.accessibilityValue, "12")
        XCTAssertTrue(button.accessibilityTraits.contains(.selected))
        XCTAssertTrue(button.accessibilityTraits.contains(.button))
        XCTAssertTrue(node.subnodes?.compactMap { $0 as? ImmediateTextNode }.contains { $0.attributedText?.string == "12" } == true)

        node.updateAction(item: ContextMenuActionItem(text: "All Chats", icon: { _ in nil }, action: { _ in }))
        XCTAssertEqual(button.accessibilityLabel, "All Chats")
        XCTAssertFalse(button.accessibilityTraits.contains(.selected))
        XCTAssertNil(button.accessibilityValue)
        XCTAssertFalse(node.subnodes?.compactMap { $0 as? ImmediateTextNode }.contains { $0.attributedText?.string == "12" } == true)
    }

    func testStackRendererAlsoUpdatesSelectionAndUnreadAccessibility() {
        let item = ContextMenuActionItem(text: "Work", isSelected: true, badge: ContextMenuActionBadge(value: "3", color: .inactive), icon: { _ in nil }, action: { _ in })
        let node = ContextControllerActionsListActionItemNode(context: nil, getController: { nil }, requestDismiss: { _ in }, requestUpdateAction: { _, _ in }, item: item)
        XCTAssertTrue(node.isAccessibilityElement)
        XCTAssertTrue(node.accessibilityTraits.contains(.selected))
        XCTAssertEqual(node.accessibilityValue, "3")
        node.setItem(item: ContextMenuActionItem(text: "All Chats", icon: { _ in nil }, action: { _ in }))
        XCTAssertEqual(node.accessibilityLabel, "All Chats")
        XCTAssertNil(node.accessibilityValue)
        XCTAssertFalse(node.accessibilityTraits.contains(.selected))
        XCTAssertTrue(node.accessibilityTraits.contains(.button))
    }

    func testInactiveBadgeKeepsItsColorAcrossThemeAndValueUpdates() throws {
        let action = ContextMenuActionItem(text: "Muted", badge: ContextMenuActionBadge(value: "4", color: .inactive), icon: { _ in nil }, action: { _ in })
        let node = self.node(action)
        let dark = defaultPresentationData().withUpdated(theme: defaultDarkPresentationTheme)
        node.updateTheme(presentationData: dark)
        let badge = try XCTUnwrap(node.subnodes?.compactMap { $0 as? ImmediateTextNode }.first { $0.attributedText?.string == "4" })
        XCTAssertEqual(badge.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, dark.theme.contextMenu.badgeInactiveForegroundColor)
        node.updateAction(item: ContextMenuActionItem(text: "Muted", isSelected: true, badge: ContextMenuActionBadge(value: "7", color: .inactive), icon: { _ in nil }, action: { _ in }))
        XCTAssertEqual(badge.attributedText?.string, "7")
        XCTAssertEqual(badge.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, dark.theme.contextMenu.badgeInactiveForegroundColor)
    }
}
