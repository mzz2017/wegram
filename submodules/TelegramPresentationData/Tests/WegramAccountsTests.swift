import XCTest
import UIKit

final class WegramAccountsTests: XCTestCase {
    private let current = WegramAccountRow(id: 42, name: "Current Account", unreadCount: 7, current: true)
    private let other = WegramAccountRow(id: 86, name: "Another Account", unreadCount: 123, current: false)

    func testCurrentProtectionLiveIdentityAndStaleCardCannotSwitch() throws {
        let view = WegramAccountsContentView()
        var selected: [Int64] = []
        var adds = 0
        view.select = { selected.append($0) }
        view.add = { adds += 1 }
        view.addCard.sendActions(for: .touchUpInside)
        XCTAssertEqual(adds, 0)
        view.load(rows: [self.other, self.current, self.current])
        XCTAssertEqual(view.rows.map(\.id), [42, 86])
        let oldCard = try XCTUnwrap(view.cards[86])
        view.cards[42]?.sendActions(for: .touchUpInside)
        oldCard.sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, [86])
        XCTAssertTrue(view.cards[42]!.accessibilityTraits.contains(.selected))
        XCTAssertTrue(view.cards[42]!.accessibilityTraits.contains(.notEnabled))
        XCTAssertEqual(oldCard.unreadLabel.text, "99+")
        XCTAssertTrue(oldCard.accessibilityValue!.contains("123"))
        view.addCard.sendActions(for: .touchUpInside)
        XCTAssertEqual(adds, 1)
        view.load(rows: [self.current])
        oldCard.sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, [86], "Removed account actions must not use a stale index or record")
        XCTAssertNil(oldCard.superview)
        view.load(rows: [])
        view.addCard.sendActions(for: .touchUpInside)
        XCTAssertEqual(adds, 2, "An empty loaded list must still offer original add-account flow")
    }

    func testBusyBlocksBothPathsAndRestoresAccessibility() throws {
        let view = WegramAccountsContentView()
        view.load(rows: [self.current, self.other])
        var events = 0
        view.select = { _ in events += 1 }
        view.add = { events += 1 }
        view.busy = true
        let card = try XCTUnwrap(view.cards[86])
        card.sendActions(for: .touchUpInside)
        view.addCard.sendActions(for: .touchUpInside)
        XCTAssertEqual(events, 0)
        XCTAssertFalse(card.isEnabled)
        XCTAssertTrue(card.accessibilityTraits.contains(.notEnabled))
        XCTAssertTrue(view.loading.isAnimating)
        view.busy = false
        XCTAssertFalse(card.accessibilityTraits.contains(.notEnabled))
        card.sendActions(for: .touchUpInside)
        XCTAssertEqual(events, 1)
        XCTAssertFalse(view.loading.isAnimating)
        view.update(dark: true, fontSize: 17, chinese: false)
        XCTAssertEqual(view.addCard.accessibilityLabel, "Add Account")
    }

    func testCardsLargeTypeUnreadAndAvatarsFitOnShortScreens() throws {
        for width: CGFloat in [320, 402, 720] {
            for font: CGFloat in [17, 34] {
                let view = WegramAccountsContentView()
                view.frame = CGRect(x: 0, y: 0, width: width, height: 300)
                view.update(dark: false, fontSize: font, chinese: true)
                let long = WegramAccountRow(id: 99, name: String(repeating: "很长的账号名称", count: 10), unreadCount: 500, current: false)
                view.load(rows: [self.current, long, self.other])
                view.layoutIfNeeded()
                XCTAssertLessThan(view.headline.frame.maxY, view.divider.frame.minY)
                var bottom = view.divider.frame.maxY
                for row in view.rows {
                    let card = try XCTUnwrap(view.cards[row.id])
                    card.layoutIfNeeded()
                    XCTAssertGreaterThan(card.frame.minY, bottom)
                    XCTAssertEqual(card.frame.minX, 20)
                    XCTAssertEqual(card.frame.maxX, width - 20)
                    XCTAssertEqual(card.avatarHost.bounds.size, CGSize(width: 44, height: 44))
                    XCTAssertLessThan(card.avatarHost.frame.maxX, card.nameLabel.frame.minX)
                    XCTAssertLessThan(card.nameLabel.frame.maxX, card.unreadLabel.frame.minX)
                    XCTAssertGreaterThanOrEqual(card.bounds.height, 76)
                    XCTAssertLessThanOrEqual(card.nameLabel.frame.maxY, card.bounds.height)
                    if row.current { XCTAssertLessThanOrEqual(card.currentLabel.frame.maxY, card.bounds.height - 8) }
                    XCTAssertEqual(card.accessibilityLabel, row.name)
                    bottom = card.frame.maxY
                }
                XCTAssertGreaterThan(view.addCard.frame.minY, bottom)
                XCTAssertGreaterThan(view.contentSize.height, view.bounds.height)
                if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    view.frame.size.height = 740
                    view.layoutIfNeeded()
                    let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("accounts-component.png"))
                }
            }
        }
    }
}
