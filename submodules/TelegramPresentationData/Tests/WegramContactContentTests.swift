import XCTest
import UIKit

final class WegramContactContentTests: XCTestCase {
    private func content(photo: Bool = true, stories: Bool = true, call: Bool = true) -> WegramContactContent {
        WegramContactContent(name: "仅用于组件检查的长联系人名称", username: "component_fixture", about: "组件检查签名；不是账号资料。", hasPhoto: photo, hasStories: stories, canCall: call)
    }
    func testMissingDataAndUpdatedCapabilitiesRejectStaleActions() {
        let view = WegramContactContentView(frame: .zero)
        var actions: [WegramContactContentView.Action] = []
        view.open = { actions.append($0) }
        view.more.sendActions(for: .touchUpInside)
        view.avatar.sendActions(for: .touchUpInside)
        XCTAssertTrue(actions.isEmpty)
        XCTAssertTrue(view.rows.isEmpty)
        view.load(self.content(), dark: false, fontSize: 17, chinese: true, statusHeight: 62, bottomInset: 34)
        XCTAssertEqual(view.rows, [[.details], [.stories], [.message, .call]])
        view.avatar.sendActions(for: .touchUpInside)
        view.more.sendActions(for: .touchUpInside)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 1, section: 2))
        XCTAssertEqual(actions, [.avatar, .more, .call])
        view.load(self.content(photo: false, stories: false, call: false), dark: true, fontSize: 17, chinese: true, statusHeight: 62, bottomInset: 34)
        XCTAssertEqual(view.rows, [[.details], [.message]])
        view.avatar.sendActions(for: .touchUpInside)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 1, section: 2))
        XCTAssertEqual(actions, [.avatar, .more, .call])
        XCTAssertTrue(view.avatar.accessibilityTraits.contains(.notEnabled))
        view.load(nil, dark: true, fontSize: 17, chinese: false, statusHeight: 62, bottomInset: 34)
        view.more.sendActions(for: .touchUpInside)
        view.avatar.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.count, 3)
        XCTAssertNil(view.name.text)
        XCTAssertNil(view.username.text)
        XCTAssertNil(view.avatar.accessibilityValue)
        XCTAssertTrue(view.rows.isEmpty)
        view.back.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.last, .back)
    }
    func testHeaderAndActualTableRowsAcrossFontsThemesAndWidths() throws {
        let view = WegramContactContentView(frame: .zero)
        for dark in [false, true] {
            for font: CGFloat in [17, 34] {
                for chinese in [true, false] {
                    view.load(self.content(), dark: dark, fontSize: font, chinese: chinese, statusHeight: 62, bottomInset: 34)
                    for width: CGFloat in [402, 320, 720, 402] {
                        view.frame = CGRect(x: 0, y: 0, width: width, height: 874)
                        view.setNeedsLayout()
                        view.layoutIfNeeded()
                        view.table.layoutIfNeeded()
                        XCTAssertEqual(view.navigation.frame.height, 106)
                        XCTAssertEqual(view.back.frame.size, CGSize(width: 44, height: 44))
                        XCTAssertEqual(view.more.frame.maxX, width - 8)
                        XCTAssertEqual(view.avatar.frame, CGRect(x: 16, y: 29.33, width: 64, height: 64))
                        XCTAssertEqual(view.avatar.layer.cornerRadius, 6)
                        XCTAssertEqual(view.name.frame.minX, 95)
                        XCTAssertLessThanOrEqual(view.name.frame.maxX, width - 16)
                        XCTAssertLessThanOrEqual(view.username.frame.maxY, view.profile.bounds.height - 24)
                        XCTAssertGreaterThanOrEqual(view.name.frame.height + 1, view.name.sizeThatFits(CGSize(width: view.name.bounds.width, height: .greatestFiniteMagnitude)).height)
                        XCTAssertTrue(view.avatarHost.accessibilityElementsHidden)
                        XCTAssertTrue(view.name.accessibilityTraits.contains(.header))
                        view.table.scrollToRow(at: IndexPath(row: 0, section: 0), at: .middle, animated: false)
                        view.table.layoutIfNeeded()
                        let info = try XCTUnwrap(view.table.cellForRow(at: IndexPath(row: 0, section: 0)) as? WegramContactDetailsCell)
                        let arrow = info.arrow
                        XCTAssertEqual(arrow.tintColor, UIColor(white: dark ? 1 : 0, alpha: 0.3))
                        XCTAssertFalse(arrow.isAccessibilityElement)
                        for path in [IndexPath(row: 0, section: 2), IndexPath(row: 1, section: 2)] {
                            view.table.scrollToRow(at: path, at: .middle, animated: false)
                            view.table.layoutIfNeeded()
                            let cell = try XCTUnwrap(view.table.cellForRow(at: path) as? WegramContactActionCell)
                            cell.layoutIfNeeded()
                            XCTAssertGreaterThanOrEqual(cell.bounds.height, 56)
                            XCTAssertLessThanOrEqual(cell.icon.frame.maxX + 8, cell.title.frame.minX + 0.1)
                            XCTAssertGreaterThanOrEqual(cell.title.frame.minX, 16)
                            XCTAssertLessThanOrEqual(cell.title.frame.maxX, width - 16)
                            XCTAssertLessThanOrEqual(cell.title.sizeThatFits(CGSize(width: cell.title.bounds.width, height: .greatestFiniteMagnitude)).height, cell.title.bounds.height + 1)
                            XCTAssertTrue(cell.accessibilityTraits.contains(.button))
                            XCTAssertFalse(cell.icon.isAccessibilityElement)
                        }
                        if width == 402 && font == 17 && chinese, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                            view.table.setContentOffset(.zero, animated: false)
                            view.table.layoutIfNeeded()
                            let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "contact-profile-dark.png" : "contact-profile-light.png"))
                        }
                    }
                }
            }
        }
    }
    func testMissingUsernameDoesNotInventAnIdentifierAndRowsReturnToTheirRealActions() throws {
        let view = WegramContactContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        view.load(WegramContactContent(name: "Component", username: nil, about: nil, hasPhoto: false, hasStories: false, canCall: false), dark: false, fontSize: 17, chinese: false, statusHeight: 62, bottomInset: 34)
        view.layoutIfNeeded()
        view.table.layoutIfNeeded()
        XCTAssertNil(view.username.text)
        XCTAssertEqual(view.username.frame.height, 0)
        XCTAssertEqual(view.tableView(view.table, heightForRowAt: IndexPath(row: 0, section: 0)), 56)
        var actions: [WegramContactContentView.Action] = []
        view.open = { actions.append($0) }
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertEqual(actions, [.details, .message])
        view.load(self.content(), dark: false, fontSize: 17, chinese: true, statusHeight: 62, bottomInset: 34)
        view.layoutIfNeeded()
        view.table.layoutIfNeeded()
        view.table.scrollToRow(at: IndexPath(row: 0, section: 1), at: .middle, animated: false)
        view.table.layoutIfNeeded()
        let row = try XCTUnwrap(view.table.cellForRow(at: IndexPath(row: 0, section: 1)))
        XCTAssertEqual(row.accessibilityLabel, "朋友圈")
        XCTAssertNil(row.detailTextLabel?.text)
        XCTAssertNil(row.accessibilityValue)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertEqual(actions.last, .stories)
    }
}
