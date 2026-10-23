import XCTest
import UIKit

final class WegramDevicesTests: XCTestCase {
    func testRealIdsSurviveReorderingAndCurrentDeviceCannotBeRemoved() {
        let view = WegramDevicesContentView()
        view.update(dark: false, fontSize: 17, chinese: true)
        XCTAssertTrue(view.activity.isAnimating)
        XCTAssertFalse(view.hasEditableDevices)
        view.load(rows: [WegramDeviceRow(id: 72, name: "Desktop", passwordPending: false), WegramDeviceRow(id: 0, name: "This Phone", passwordPending: false), WegramDeviceRow(id: 72, name: "Duplicate", passwordPending: false), WegramDeviceRow(id: 81, name: "Pending", passwordPending: true)], loading: false)
        XCTAssertEqual(view.rows.map { $0.id }, [0, 72, 81])
        XCTAssertFalse(view.activity.isAnimating)
        var removals: [Int64] = []
        view.remove = { removals.append($0) }
        XCTAssertFalse(view.tableView(view.table, canEditRowAt: IndexPath(row: 0, section: 0)))
        view.tableView(view.table, commit: .delete, forRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(removals.isEmpty)
        view.tableView(view.table, commit: .delete, forRowAt: IndexPath(row: 2, section: 0))
        XCTAssertEqual(removals, [81])
        XCTAssertEqual(view.rows.count, 3, "A delete intent must not optimistically erase a session before confirmation and server result")
        view.load(rows: [WegramDeviceRow(id: 81, name: "Pending", passwordPending: true), WegramDeviceRow(id: 0, name: "Phone", passwordPending: false)], loading: false)
        view.tableView(view.table, commit: .delete, forRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(removals, [81, 81], "Actions must use current row IDs after updates")
    }

    func testLoadingEmptyBusyAndEditStateRespectActualDeviceAvailability() throws {
        let view = WegramDevicesContentView()
        view.frame = CGRect(x: 0, y: 0, width: 402, height: 450)
        view.update(dark: true, fontSize: 17, chinese: false)
        view.load(rows: [], loading: false)
        XCTAssertFalse(view.emptyLabel.isHidden)
        XCTAssertFalse(view.activity.isAnimating)
        view.load(rows: [WegramDeviceRow(id: 0, name: "Current", passwordPending: false)], loading: false)
        view.setEditing(true)
        XCTAssertFalse(view.table.isEditing)
        view.load(rows: [WegramDeviceRow(id: 0, name: "Current", passwordPending: false), WegramDeviceRow(id: 5, name: "Other", passwordPending: false)], loading: false)
        view.setEditing(true)
        XCTAssertTrue(view.table.isEditing)
        view.layoutIfNeeded()
        view.table.layoutIfNeeded()
        let editingCell = try XCTUnwrap(view.table.cellForRow(at: IndexPath(row: 1, section: 0)) as? WegramDeviceCell)
        XCTAssertTrue(editingCell.arrow.isHidden)
        var opened: [Int64] = []
        var removed: [Int64] = []
        view.open = { opened.append($0) }
        view.remove = { removed.append($0) }
        view.busy = true
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 1, section: 0))
        view.tableView(view.table, commit: .delete, forRowAt: IndexPath(row: 1, section: 0))
        XCTAssertTrue(opened.isEmpty && removed.isEmpty)
        view.table.layoutIfNeeded()
        let disabled = try XCTUnwrap(view.table.cellForRow(at: IndexPath(row: 1, section: 0)))
        XCTAssertTrue(disabled.accessibilityTraits.contains(.notEnabled))
        view.busy = false
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(opened, [5])
        view.load(rows: [WegramDeviceRow(id: 0, name: "Current", passwordPending: false)], loading: false)
        XCTAssertFalse(view.table.isEditing, "Removing the final other device must leave editing mode")
    }

    func testFlatRowsExposeFullNamesAndStateAtLargeSizes() throws {
        for size in [CGSize(width: 320, height: 450), CGSize(width: 402, height: 771), CGSize(width: 720, height: 200)] {
            for font: CGFloat in [17, 34] {
                let view = WegramDevicesContentView()
                view.frame = CGRect(origin: .zero, size: size)
                view.update(dark: false, fontSize: font, chinese: true)
                let longName = String(repeating: "设备长名称", count: 8)
                view.load(rows: [WegramDeviceRow(id: 0, name: "iPhone", passwordPending: false), WegramDeviceRow(id: 5, name: longName, passwordPending: true)], loading: false)
                view.layoutIfNeeded()
                view.table.layoutIfNeeded()
                if size.width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let image = UIGraphicsImageRenderer(size: size).image { view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("devices-component.png"))
                }
                let index = IndexPath(row: 1, section: 0)
                view.table.scrollToRow(at: index, at: .middle, animated: false)
                view.table.layoutIfNeeded()
                let cell = try XCTUnwrap(view.table.cellForRow(at: index) as? WegramDeviceCell)
                cell.layoutIfNeeded()
                XCTAssertLessThan(cell.name.frame.maxX, cell.badge.frame.minX)
                XCTAssertLessThan(cell.badge.frame.maxX, cell.arrow.frame.minX)
                XCTAssertEqual(cell.accessibilityLabel, longName + ", 待验证")
                XCTAssertGreaterThanOrEqual(cell.bounds.height, 56)
                XCTAssertLessThanOrEqual(view.explanation.frame.maxY, view.table.tableHeaderView!.bounds.height - 8)
            }
        }
    }
}
