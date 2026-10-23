import XCTest
import UIKit
import Display
import TelegramPresentationData
import ChatListSearchItemHeader

final class WegramSearchSectionTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }

    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }

    private func descendant(_ id: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == id { return view }
        for child in view.subviews {
            if let found = self.descendant(id, in: child) { return found }
        }
        return nil
    }

    func testPlainSectionHeightTypographyAndLegacyOptOut() throws {
        let header = ChatListSearchItemHeader(type: .text("Contacts", 1), theme: defaultPresentationTheme, strings: defaultPresentationStrings, usesWegramAppearance: true)
        let legacy = ChatListSearchItemHeader(type: .text("Contacts", 1), theme: defaultPresentationTheme, strings: defaultPresentationStrings)
        XCTAssertEqual(header.height, 40)
        XCTAssertEqual(legacy.height, 28)
        XCTAssertFalse(header.combinesWith(other: legacy))
        let node = header.node(synchronousLoad: true)
        node.frame = CGRect(x: 0, y: 0, width: 402, height: header.height)
        node.updateLayout(size: node.bounds.size, leftInset: 0, rightInset: 0, transition: .immediate)
        let title = try XCTUnwrap(self.descendant("Wegram.Search.SectionTitle", in: node.view) as? UILabel)
        XCTAssertEqual(title.text, "Contacts", "Search titles must retain their localized casing")
        XCTAssertEqual(title.font.pointSize, 14)
        XCTAssertEqual(title.frame.minX, 16)
        XCTAssertEqual(title.frame.height, 40)
        XCTAssertTrue(title.accessibilityTraits.contains(.header))
        let action = try XCTUnwrap(self.descendant("Wegram.Search.SectionAction", in: node.view) as? UIButton)
        XCTAssertTrue(action.isHidden)
        legacy.updateNode(node, previous: header, next: nil)
        XCTAssertTrue(title.superview?.isHidden == true)
    }

    func testActionIsARealNonoverlapping44ptControlWithTheOriginalSource() throws {
        var source: AnyObject?
        let header = ChatListSearchItemHeader(type: .text("Recent", 2), theme: defaultPresentationTheme, strings: defaultPresentationStrings, usesWegramAppearance: true, actionTitle: "Clear", action: { source = $0 })
        XCTAssertEqual(header.height, 44)
        let node = header.node(synchronousLoad: true)
        node.frame = CGRect(x: 0, y: 0, width: 320, height: header.height)
        node.updateLayout(size: node.bounds.size, leftInset: 24, rightInset: 8, transition: .immediate)
        let title = try XCTUnwrap(self.descendant("Wegram.Search.SectionTitle", in: node.view) as? UILabel)
        let action = try XCTUnwrap(self.descendant("Wegram.Search.SectionAction", in: node.view) as? UIButton)
        XCTAssertEqual(title.frame.minX, 40)
        XCTAssertGreaterThanOrEqual(action.bounds.width, 44)
        XCTAssertEqual(action.bounds.height, 44)
        XCTAssertLessThanOrEqual(title.frame.maxX, action.frame.minX - 8)
        XCTAssertLessThanOrEqual(action.frame.maxX, 296)
        XCTAssertEqual(action.accessibilityLabel, "Clear")
        XCTAssertTrue(action.hitTest(CGPoint(x: action.bounds.midX, y: 1), with: nil) === action)
        let bottomPoint = action.convert(CGPoint(x: action.bounds.midX, y: action.bounds.height - 0.1), to: node.view)
        XCTAssertTrue(node.view.hitTest(bottomPoint, with: nil) === action, "Section separator intercepted the bottom of the action target")
        action.sendActions(for: .touchUpInside)
        XCTAssertTrue(source === node)
    }

    func testReuseChangesThemeTitleAndActionWithoutAStaleCallback() throws {
        var oldCount = 0
        var newCount = 0
        let old = ChatListSearchItemHeader(type: .text("Recent", 3), theme: defaultPresentationTheme, strings: defaultPresentationStrings, usesWegramAppearance: true, actionTitle: "Clear", action: { _ in oldCount += 1 })
        let node = old.node(synchronousLoad: true)
        node.frame = CGRect(x: 0, y: 0, width: 402, height: old.height)
        node.updateLayout(size: node.bounds.size, leftInset: 0, rightInset: 0, transition: .immediate)
        let new = ChatListSearchItemHeader(type: .text("Chats", 3), theme: defaultDarkPresentationTheme, strings: defaultPresentationStrings, usesWegramAppearance: true, actionTitle: "Show more results", action: { _ in newCount += 1 })
        new.updateNode(node, previous: old, next: nil)
        let title = try XCTUnwrap(self.descendant("Wegram.Search.SectionTitle", in: node.view) as? UILabel)
        let action = try XCTUnwrap(self.descendant("Wegram.Search.SectionAction", in: node.view) as? UIButton)
        XCTAssertEqual(title.text, "Chats")
        XCTAssertEqual(action.titleLabel?.text, "Show more results")
        XCTAssertGreaterThan(action.titleLabel?.layer.opacity ?? 0, 0.9)
        XCTAssertEqual(title.superview?.backgroundColor, UIColor(rgb: 0x191919))
        XCTAssertLessThanOrEqual(title.frame.maxX, action.frame.minX - 8)
        action.sendActions(for: .touchUpInside)
        XCTAssertEqual(oldCount, 0)
        XCTAssertEqual(newCount, 1)
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let image = UIGraphicsImageRenderer(size: node.bounds.size).image { node.view.layer.render(in: $0.cgContext) }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("search-section-dark.png"))
        }
    }
}
