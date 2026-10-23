import XCTest
import UIKit
import Display

final class WegramShortcutMenuTests: XCTestCase {
    func testStatusDetailsKeepTitleReadableAndExposeCurrentValueToVoiceOver() throws {
        let menu = WegramShortcutMenuView()
        for width: CGFloat in [250, 402, 874] {
            for font: CGFloat in [17, 34] {
                for status in ["已连接", "正在等待网络连接，请检查当前网络", "Connecting to the configured proxy…"] {
                    menu.frame = CGRect(x: 0, y: 0, width: width, height: 360)
                    menu.load(items: [WegramShortcutMenuItem(title: "代理设置 Proxy", image: nil, detail: status)], fontSize: font)
                    menu.position(anchor: CGRect(x: 16, y: 44, width: 44, height: 44), insets: UIEdgeInsets(top: 44, left: 0, bottom: 21, right: 0), alignLeft: true)
                    menu.layoutIfNeeded()
                    let button = try XCTUnwrap(menu.buttons.first)
                    button.layoutIfNeeded()
                    let title = try XCTUnwrap(button.titleLabel)
                    let detail = try XCTUnwrap(button.subviews.first(where: { $0.accessibilityIdentifier == "Wegram.Shortcut.Detail" }) as? UILabel)
                    XCTAssertEqual(button.accessibilityLabel, "代理设置 Proxy")
                    XCTAssertEqual(button.accessibilityValue, status)
                    XCTAssertEqual(detail.text, status)
                    XCTAssertFalse(detail.isAccessibilityElement)
                    XCTAssertGreaterThanOrEqual(detail.frame.minY, title.frame.maxY + 4)
                    XCTAssertLessThanOrEqual(detail.frame.maxY, button.bounds.height - 12)
                    XCTAssertLessThanOrEqual(detail.frame.maxX, button.bounds.width - 16)
                    XCTAssertGreaterThanOrEqual(detail.frame.height, ceil(detail.sizeThatFits(CGSize(width: detail.bounds.width, height: .greatestFiniteMagnitude)).height))
                    XCTAssertGreaterThanOrEqual(button.bounds.height, 52)
                }
            }
        }
    }

    func testReloadingMenuRemovesOldStatusAndRetainsSingleSelection() throws {
        let menu = WegramShortcutMenuView()
        var selected = 0
        menu.select = { _ in selected += 1 }
        menu.load(items: [WegramShortcutMenuItem(title: "代理", image: nil, detail: "已连接")], fontSize: 17)
        let old = try XCTUnwrap(menu.buttons.first)
        menu.load(items: [WegramShortcutMenuItem(title: "代理", image: nil)], fontSize: 17)
        let current = try XCTUnwrap(menu.buttons.first)
        XCTAssertNil(current.accessibilityValue)
        let detail = try XCTUnwrap(current.subviews.first(where: { $0.accessibilityIdentifier == "Wegram.Shortcut.Detail" }) as? UILabel)
        XCTAssertTrue(detail.isHidden)
        old.sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, 0)
        current.sendActions(for: .touchUpInside)
        current.sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, 1)
    }

    private func items(_ titles: [String]) -> [WegramShortcutMenuItem] {
        titles.enumerated().map { WegramShortcutMenuItem(title: $0.element, image: UIImage(systemName: "star"), separatorBefore: $0.offset == titles.count - 1) }
    }
    func testShortcutMenuDispatchesOnceAndRejectsRemovedOrCancelledButtons() {
        let menu = WegramShortcutMenuView()
        var selected: [Int] = []
        var closed = 0
        menu.select = { selected.append($0) }
        menu.close = { closed += 1 }
        menu.load(items: self.items(["First", "Second"]), fontSize: 17)
        let old = menu.buttons[0]
        menu.load(items: self.items(["Replacement"]), fontSize: 17)
        old.sendActions(for: .touchUpInside)
        XCTAssertTrue(selected.isEmpty)
        menu.buttons[0].sendActions(for: .touchUpInside)
        menu.buttons[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, [0])
        menu.load(items: self.items(["Cancelled"]), fontSize: 17)
        menu.sendActions(for: .touchUpInside)
        menu.buttons[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, [0])
        XCTAssertEqual(closed, 1)
        menu.load(items: self.items(["Escape"]), fontSize: 17)
        XCTAssertTrue(menu.accessibilityPerformEscape())
        XCTAssertTrue(menu.accessibilityPerformEscape())
        XCTAssertEqual(closed, 2)
        menu.load(items: self.items(["Invalidated"]), fontSize: 17)
        menu.invalidate()
        menu.buttons[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, [0])
    }
    func testShortcutMenuFitsSafeAreasLargeTextAndScrollableLandscape() throws {
        let menu = WegramShortcutMenuView()
        let titles = ["收藏", "频道", "Downloads", "Calls", "Proxy", "Archived Chats with a longer localized name", "Lock App"]
        for width: CGFloat in [320, 402, 874] {
            for font: CGFloat in [17, 34] {
                for left in [true, false] {
                    let safe: CGFloat = width == 874 ? 59 : 0
                    menu.frame = CGRect(x: 0, y: 0, width: width, height: 360)
                    menu.load(items: self.items(titles), fontSize: font)
                    menu.position(anchor: CGRect(x: left ? safe + 16 : width - safe - 60, y: 44, width: 44, height: 44), insets: UIEdgeInsets(top: 44, left: safe, bottom: 21, right: safe), alignLeft: left)
                    menu.layoutIfNeeded()
                    XCTAssertGreaterThanOrEqual(menu.panel.frame.minX, safe + 8)
                    XCTAssertLessThanOrEqual(menu.panel.frame.maxX, width - safe - 8)
                    XCTAssertLessThanOrEqual(menu.panel.frame.maxY, 360 - 21 - 8)
                    XCTAssertGreaterThan(menu.panel.contentSize.height, menu.panel.bounds.height)
                    XCTAssertTrue(menu.panel.isScrollEnabled)
                    XCTAssertTrue(menu.accessibilityViewIsModal)
                    XCTAssertEqual(menu.accessibilityElements?.count, titles.count)
                    for (index, button) in menu.buttons.enumerated() {
                        button.layoutIfNeeded()
                        XCTAssertGreaterThanOrEqual(button.bounds.height, 52)
                        XCTAssertEqual(button.accessibilityLabel, titles[index])
                        let image = try XCTUnwrap(button.imageView)
                        let label = try XCTUnwrap(button.titleLabel)
                        XCTAssertLessThanOrEqual(image.frame.maxX + 12, label.frame.minX)
                        XCTAssertLessThanOrEqual(label.frame.maxX, button.bounds.width - 16)
                        XCTAssertGreaterThanOrEqual(label.frame.height, ceil(label.sizeThatFits(CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude)).height))
                    }
                }
            }
        }
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            menu.frame = CGRect(x: 0, y: 0, width: 402, height: 380)
            menu.load(items: self.items(["发起聊天", "添加朋友", "扫一扫", "发布动态", "管理聊天"]), fontSize: 17)
            menu.position(anchor: CGRect(x: 352, y: 8, width: 44, height: 44), insets: .zero, alignLeft: false)
            for dark in [false, true] {
                menu.backgroundColor = dark ? UIColor(white: 0.1, alpha: 1) : UIColor(white: 0.93, alpha: 1)
                menu.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(size: menu.bounds.size).image { menu.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "shortcut-menu-dark.png" : "shortcut-menu-light.png"))
            }
        }
    }
}
