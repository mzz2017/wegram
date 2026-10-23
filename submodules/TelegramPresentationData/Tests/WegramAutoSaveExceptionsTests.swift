import XCTest
import UIKit

final class WegramAutoSaveExceptionsTests: XCTestCase {
    private func view(dark: Bool = false, font: CGFloat = 17) -> WegramAutoSaveExceptionsContentView {
        let view = WegramAutoSaveExceptionsContentView()
        view.update(dark: dark, fontSize: font, addTitle: "添加例外", deleteAllTitle: "删除所有例外", deleteTitle: "删除", emptyTitle: "暂无例外")
        return view
    }
    private let rows = [WegramAutoSaveExceptionRow(id: 21, name: "测试用户", summary: "照片、视频（最多 100 MB）"), WegramAutoSaveExceptionRow(id: 32, name: "仅用来验证组件的长群组名称", summary: "不保存照片、不保存视频；仅用来验证完整摘要在窄屏和大字号下的换行布局。")]
    func testLoadingEmptyListAndRemovedPeersRejectStaleActions() throws {
        let view = self.view()
        var adds = 0
        var opens: [Int64] = []
        var removes: [Int64] = []
        var clears = 0
        view.add = { adds += 1 }
        view.open = { opens.append($0) }
        view.remove = { removes.append($0) }
        view.deleteAll = { clears += 1 }
        let add = IndexPath(row: 0, section: 0)
        let peer = IndexPath(row: 0, section: 1)
        let clear = IndexPath(row: 0, section: 2)
        XCTAssertTrue(view.activity.isAnimating)
        XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: 0), 0)
        for index in [add, peer, clear] { view.tableView(view.table, didSelectRowAt: index) }
        XCTAssertFalse(view.requestRemove(21))
        XCTAssertEqual(adds, 0)
        XCTAssertTrue(opens.isEmpty)
        XCTAssertTrue(removes.isEmpty)
        XCTAssertEqual(clears, 0)
        view.load(rows: [], loaded: true)
        XCTAssertFalse(view.activity.isAnimating)
        XCTAssertFalse(view.status.isHidden)
        XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: 2), 0)
        view.tableView(view.table, didSelectRowAt: add)
        view.tableView(view.table, didSelectRowAt: clear)
        XCTAssertEqual(adds, 1)
        XCTAssertEqual(clears, 0)
        view.load(rows: self.rows, loaded: true)
        view.tableView(view.table, didSelectRowAt: peer)
        view.tableView(view.table, didSelectRowAt: clear)
        XCTAssertEqual(opens, [21])
        XCTAssertEqual(clears, 1)
        XCTAssertTrue(view.requestRemove(21))
        XCTAssertEqual(removes, [21])
        XCTAssertEqual(view.rows, self.rows, "Deletion is an original transaction intent, not an optimistic disappearance")
        let swipe = try XCTUnwrap(view.tableView(view.table, trailingSwipeActionsConfigurationForRowAt: peer))
        XCTAssertFalse(swipe.performsFirstActionWithFullSwipe)
        view.load(rows: [self.rows[1]], loaded: true)
        XCTAssertFalse(view.requestRemove(21))
        XCTAssertEqual(removes, [21])
        view.load(rows: [], loaded: false)
        XCTAssertTrue(view.status.isHidden)
        XCTAssertTrue(view.activity.isAnimating)
    }
    func testPeerRowsSummaryAvatarAccessibilityAndRotation() throws {
        for dark in [false, true] {
            for font: CGFloat in [17, 34] {
                let view = self.view(dark: dark, font: font)
                view.load(rows: self.rows, loaded: true)
                for width: CGFloat in [402, 320, 720, 402] {
                    view.frame = CGRect(x: 0, y: 0, width: width, height: 780)
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    view.table.layoutIfNeeded()
                    for index in self.rows.indices {
                        let path = IndexPath(row: index, section: 1)
                        view.table.scrollToRow(at: path, at: .middle, animated: false)
                        view.table.layoutIfNeeded()
                        let cell = try XCTUnwrap(view.table.cellForRow(at: path) as? WegramAutoSaveExceptionCell)
                        cell.layoutIfNeeded()
                        XCTAssertEqual(cell.avatarHost.frame.width, 40)
                        XCTAssertEqual(cell.avatarHost.frame.minX, 16)
                        XCTAssertEqual(cell.avatarHost.layer.cornerRadius, 4)
                        XCTAssertEqual(cell.name.frame.minX, 68)
                        XCTAssertEqual(cell.summary.frame.minY, cell.name.frame.maxY + 4)
                        XCTAssertGreaterThanOrEqual(cell.bounds.height, 56)
                        XCTAssertLessThanOrEqual(cell.summary.frame.maxY, cell.contentView.bounds.height - 7)
                        XCTAssertEqual(cell.accessibilityLabel, self.rows[index].name)
                        XCTAssertEqual(cell.accessibilityValue, self.rows[index].summary)
                        XCTAssertTrue(cell.accessibilityTraits.contains(.button))
                        XCTAssertEqual(cell.accessibilityCustomActions?.first?.name, "删除")
                        XCTAssertFalse(cell.name.isAccessibilityElement)
                        XCTAssertTrue(cell.avatarHost.accessibilityElementsHidden)
                        XCTAssertEqual(cell.summary.sizeThatFits(CGSize(width: cell.summary.bounds.width, height: .greatestFiniteMagnitude)).height, cell.summary.bounds.height, accuracy: 1)
                    }
                    if font == 17 && width == 402, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        view.table.setContentOffset(.zero, animated: false)
                        view.table.layoutIfNeeded()
                        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "autosave-exceptions-dark.png" : "autosave-exceptions-light.png"))
                    }
                }
                view.load(rows: [], loaded: true)
                view.layoutIfNeeded()
                XCTAssertGreaterThan(view.table.tableFooterView?.bounds.height ?? 0, 48)
                XCTAssertFalse(view.status.isHidden)
            }
        }
    }
}
