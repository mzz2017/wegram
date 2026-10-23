import XCTest
import UIKit

final class WegramAdminGridTests: XCTestCase {
    private func member(_ id: Int64, canOpen: Bool = true, canRemove: Bool = true, enabled: Bool = true) -> WegramAdminGridView.Member {
        .init(id: id, name: "Administrator \(id)", role: id == 0 ? "Owner" : "Custom rank · Promoted by Owner", enabled: enabled, canOpen: canOpen, canRemove: canRemove)
    }
    private func buttons(_ view: WegramAdminGridView) -> [UIButton] { view.subviews.compactMap { $0 as? UIButton } }
    private func update(_ view: WegramAdminGridView, members: [WegramAdminGridView.Member], canAdd: Bool = true, editing: Bool = false, dark: Bool = false, font: CGFloat = 17, info: String = "") {
        view.update(members: members, canAdd: canAdd, editing: editing, title: "群管理员", info: info, addTitle: "添加管理员", editTitle: "移除管理员", doneTitle: "完成", dark: dark, fontSize: font)
        view.frame.size.height = view.height(width: view.bounds.width)
        view.layoutIfNeeded()
    }
    func testGridPreservesPerMemberActionsAndRejectsDisabledHiddenAndReplacedButtons() throws {
        let view = WegramAdminGridView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        var actions: [WegramAdminGridView.Action] = []
        view.open = { actions.append($0) }
        let members = [self.member(0, canOpen: false, canRemove: false), self.member(1), self.member(2, enabled: false)]
        self.update(view, members: members)
        let old = self.buttons(view)
        old.forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(actions, [.member(1), .add, .toggleEditing])
        XCTAssertEqual(old[0].accessibilityValue, "Owner")
        XCTAssertEqual(old[2].alpha, 0.5)
        self.update(view, members: members, editing: true)
        old.forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(actions.count, 3, "Buttons from the previous projection must be inert")
        self.buttons(view).forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(Array(actions.suffix(3)), [.remove(1), .add, .toggleEditing])
        let removing = self.buttons(view)[1]
        self.update(view, members: [self.member(1, canOpen: false, canRemove: false)], canAdd: false)
        removing.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.count, 6, "Revoked rights must reject the old removal button")
        XCTAssertEqual(self.buttons(view).count, 1)
        self.buttons(view)[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.count, 6)
        self.update(view, members: members)
        view.isHidden = true
        self.buttons(view).forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(actions.count, 6)
    }
    func testGridRetainsEveryMemberAndReflowsWithoutOverlapsAtLargeTypeAndNarrowWidths() throws {
        let view = WegramAdminGridView(frame: CGRect(x: 0, y: 0, width: 720, height: 874))
        let members = (0 ..< 51).map { self.member(Int64($0)) }
        var configured: [Int64] = []
        var released: [Int64] = []
        view.configureAvatar = { id, host in
            configured.append(id)
            host.backgroundColor = .systemGreen
        }
        view.releaseAvatar = { id, _ in released.append(id) }
        for (width, dark, font): (CGFloat, Bool, CGFloat) in [(720, false, 17), (320, true, 34), (402, false, 17)] {
            view.frame.size.width = width
            self.update(view, members: members, dark: dark, font: font)
            let buttons = self.buttons(view)
            XCTAssertEqual(buttons.count, 53)
            XCTAssertEqual(view.bounds.height, WegramAdminGridView.measure(members: members, canAdd: true, editing: false, fontSize: font, width: width))
            for (index, button) in buttons.enumerated() {
                XCTAssertGreaterThanOrEqual(button.bounds.width, 48)
                XCTAssertGreaterThanOrEqual(button.bounds.height, 48)
                XCTAssertGreaterThanOrEqual(button.frame.minX, 16)
                XCTAssertLessThanOrEqual(button.frame.maxX, width - 16 + 0.01)
                XCTAssertLessThan(button.frame.maxY, view.bounds.height)
                if index > 0 { let overlap = button.frame.intersection(buttons[index - 1].frame); XCTAssertTrue(overlap.isNull || overlap.width < 0.01 || overlap.height < 0.01, "Adjacent buttons overlap: \(overlap)") }
                for label in button.subviews.compactMap({ $0 as? UILabel }) {
                    XCTAssertLessThanOrEqual(label.frame.maxY, button.bounds.height)
                    XCTAssertLessThanOrEqual(label.frame.maxX, button.bounds.width)
                }
            }
        }
        XCTAssertEqual(configured.count, 153)
        XCTAssertEqual(released.count, 102)
        self.update(view, members: [])
        XCTAssertEqual(released.count, 153)
    }
    func testOnlyVisibleAvatarHostsAreConfiguredAndScrollingReleasesOldHosts() throws {
        let view = WegramAdminGridView(frame: CGRect(x: 0, y: 0, width: 320, height: 874))
        view.visibleRect = .null
        var configured: [Int64] = []
        var released: [Int64] = []
        var hosts: [Int64: UIView] = [:]
        view.configureAvatar = { id, host in configured.append(id); hosts[id] = host; host.addSubview(UILabel()) }
        view.releaseAvatar = { id, _ in released.append(id) }
        self.update(view, members: (0 ..< 51).map { self.member(Int64($0)) })
        XCTAssertTrue(configured.isEmpty)
        view.visibleRect = try XCTUnwrap(self.buttons(view).first).frame
        XCTAssertEqual(configured, [0])
        view.visibleRect = self.buttons(view)[50].frame
        XCTAssertEqual(configured, [0, 50])
        XCTAssertEqual(released, [0])
        XCTAssertTrue(try XCTUnwrap(hosts[0]).subviews.isEmpty)
        view.visibleRect = .null
        XCTAssertEqual(released, [0, 50])
        XCTAssertTrue(try XCTUnwrap(hosts[50]).subviews.isEmpty)
    }
    func testOriginalExplanatoryTextGrowsBeforeTheGridAtLargeType() throws {
        let view = WegramAdminGridView(frame: CGRect(x: 0, y: 0, width: 320, height: 874))
        let info = String(repeating: "Administrator permissions are set separately. ", count: 10)
        self.update(view, members: [self.member(1)], font: 34, info: info)
        let label = try XCTUnwrap(view.subviews.compactMap { $0 as? UILabel }.first { $0.text == info })
        XCTAssertGreaterThan(label.bounds.height, 100)
        XCTAssertLessThanOrEqual(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height, label.bounds.height + 1)
        XCTAssertGreaterThan(try XCTUnwrap(self.buttons(view).first).frame.minY, label.frame.maxY)
        XCTAssertEqual(view.bounds.height, WegramAdminGridView.measure(members: [self.member(1)], canAdd: true, editing: false, fontSize: 34, info: info, width: 320))
    }
    func testRiskWarningHasAnIndependentVisibleSlotDespiteLongRanks() throws {
        let view = WegramAdminGridView(frame: CGRect(x: 0, y: 0, width: 320, height: 874))
        let rank = String(repeating: "Long custom rank and promoted by display name ", count: 8)
        self.update(view, members: [.init(id: 1, name: "Fixture", role: "SCAM · " + rank, enabled: true, canOpen: true, canRemove: true, warning: "SCAM")], font: 34)
        let button = try XCTUnwrap(self.buttons(view).first)
        let warning = try XCTUnwrap(button.viewWithTag(3) as? UILabel)
        XCTAssertEqual(warning.text, "SCAM")
        XCTAssertEqual(warning.numberOfLines, 1)
        XCTAssertEqual(warning.alpha, 1)
        XCTAssertFalse(warning.isHidden)
        XCTAssertGreaterThanOrEqual(warning.frame.width, 48)
        XCTAssertTrue(button.bounds.contains(warning.frame))
        XCTAssertTrue(button.accessibilityValue?.hasPrefix("SCAM") == true)
    }
    func testRenderReferenceGridWithRoleAndAddRemoveControls() throws {
        for dark in [false, true] {
            let view = WegramAdminGridView(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
            view.configureAvatar = { _, host in host.backgroundColor = .systemGreen }
            self.update(view, members: [self.member(0, canRemove: false), self.member(1)], dark: dark, info: "管理员权限由群主分别设置。")
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("admin-grid-\(dark ? "dark" : "light").png"))
            }
        }
    }
}
