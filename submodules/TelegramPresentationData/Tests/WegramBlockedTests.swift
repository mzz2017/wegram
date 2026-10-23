import XCTest
import UIKit

final class WegramBlockedTests: XCTestCase {
    private let rows = [WegramBlockedRow(id: 42, name: "José", username: "usernameOne"), WegramBlockedRow(id: 86, name: "王艺", username: nil)]

    func testSearchUsesLoadedNamesAndUsernamesWithoutClaimingPartialListIsEmpty() {
        let view = WegramBlockedContentView()
        var requests = 0
        view.loadMore = { requests += 1 }
        view.load(rows: self.rows + [self.rows[0]], loading: false, canLoadMore: true)
        XCTAssertEqual(view.rows.map(\.id), [42, 86])
        for (query, ids) in [("jose", [Int64(42)]), ("USERNAME", [Int64(42)]), ("王", [Int64(86)]), ("missing", [])] {
            view.searchField.text = query
            view.searchField.sendActions(for: .editingChanged)
            XCTAssertEqual(view.visibleRows.map(\.id), ids)
            XCTAssertFalse(view.moreButton.isHidden, "Partial search results must still offer loading beyond the current page")
        }
        XCTAssertFalse(view.status.isHidden)
        XCTAssertTrue(view.status.text!.contains("未加载"))
        XCTAssertEqual(requests, 0, "Typing must not start extra network pagination")
        view.moreButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(requests, 1)
        view.load(rows: self.rows, loading: true, canLoadMore: true)
        view.moreButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(requests, 1)
        view.load(rows: self.rows, loading: false, canLoadMore: false)
        XCTAssertEqual(view.status.text, "未找到相关用户")
        XCTAssertTrue(view.moreButton.isHidden)
        view.searchField.text = ""
        view.searchField.sendActions(for: .editingChanged)
        XCTAssertTrue(view.status.isHidden)
        view.load(rows: [], loading: false, canLoadMore: false)
        XCTAssertEqual(view.status.text, "暂无黑名单用户")
    }

    func testUnblockIntentUsesIdentityKeepsRowUntilContextUpdateAndBusyBlocksActions() throws {
        let view = WegramBlockedContentView()
        view.frame = CGRect(x: 0, y: 0, width: 402, height: 450)
        var removed: [Int64] = []
        var opened: [Int64] = []
        view.remove = { removed.append($0) }
        view.open = { opened.append($0) }
        view.load(rows: self.rows, loading: false, canLoadMore: false)
        XCTAssertTrue(view.requestRemove(86))
        XCTAssertEqual(removed, [86])
        XCTAssertEqual(view.rows, self.rows, "Sending an unblock intent cannot optimistically erase an entry")
        let configuration = try XCTUnwrap(view.tableView(view.table, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 1, section: 0)))
        XCTAssertFalse(configuration.performsFirstActionWithFullSwipe)
        XCTAssertEqual(configuration.actions.first?.title, view.removeTitle)
        view.busy = true
        XCTAssertFalse(view.requestRemove(42))
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(opened.isEmpty)
        XCTAssertNil(view.tableView(view.table, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0)))
        view.layoutIfNeeded()
        view.table.layoutIfNeeded()
        let cell = try XCTUnwrap(view.table.cellForRow(at: IndexPath(row: 0, section: 0)))
        XCTAssertTrue(cell.accessibilityTraits.contains(.notEnabled))
        view.busy = false
        view.load(rows: [self.rows[0]], loading: false, canLoadMore: false)
        XCTAssertFalse(view.requestRemove(86), "A stale action must not act on a different peer at its former index")
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(opened, [42])
        XCTAssertEqual(removed, [86])
    }

    func testEmptyPartialSearchMessageDoesNotOverlapLoadMoreOnShortScreens() {
        for size in [CGSize(width: 320, height: 450), CGSize(width: 402, height: 771), CGSize(width: 720, height: 200)] {
            for font: CGFloat in [17, 34] {
                let view = WegramBlockedContentView()
                view.frame = CGRect(origin: .zero, size: size)
                view.update(dark: false, fontSize: font, chinese: true)
                view.load(rows: self.rows, loading: false, canLoadMore: true)
                view.searchField.text = "missing"
                view.searchField.sendActions(for: .editingChanged)
                view.layoutIfNeeded()
                view.table.layoutIfNeeded()
                let status = view.status.convert(view.status.bounds, to: view)
                let button = view.moreButton.convert(view.moreButton.bounds, to: view)
                XCTAssertFalse(view.status.isHidden)
                XCTAssertFalse(view.moreButton.isHidden)
                XCTAssertFalse(status.intersects(button), "Unloaded-user explanation overlaps Load More at \(size), font \(font)")
            }
        }
    }

    func testFlatRowsAvatarGeometryAndLongNamesAtLargeSizes() throws {
        for size in [CGSize(width: 320, height: 450), CGSize(width: 402, height: 771), CGSize(width: 720, height: 200)] {
            for font: CGFloat in [17, 34] {
                let view = WegramBlockedContentView()
                view.frame = CGRect(origin: .zero, size: size)
                view.update(dark: false, fontSize: font, chinese: true)
                let name = String(repeating: "真实完整长名称", count: 8)
                view.load(rows: [self.rows[0], WegramBlockedRow(id: 86, name: name, username: nil)], loading: false, canLoadMore: true)
                view.layoutIfNeeded()
                view.table.layoutIfNeeded()
                if size.width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let image = UIGraphicsImageRenderer(size: size).image { view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("blocked-component.png"))
                }
                let index = IndexPath(row: 1, section: 0)
                view.table.scrollToRow(at: index, at: .middle, animated: false)
                view.table.layoutIfNeeded()
                let cell = try XCTUnwrap(view.table.cellForRow(at: index) as? WegramBlockedCell)
                cell.layoutIfNeeded()
                XCTAssertEqual(cell.avatarHost.bounds.size, CGSize(width: 40, height: 40))
                XCTAssertEqual(cell.avatarHost.layer.cornerRadius, 4)
                XCTAssertEqual(cell.name.frame.minX, 68)
                XCTAssertLessThan(cell.avatarHost.frame.maxX, cell.name.frame.minX)
                XCTAssertGreaterThanOrEqual(cell.bounds.height, 56)
                XCTAssertEqual(cell.accessibilityLabel, name)
                XCTAssertEqual(cell.accessibilityCustomActions?.first?.name, view.removeTitle)
                XCTAssertEqual(view.searchField.frame.maxX, size.width - 8)
                XCTAssertGreaterThanOrEqual(view.moreButton.bounds.height, 44)
            }
        }
    }
}
