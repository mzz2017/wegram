import XCTest
import UIKit
import AsyncDisplayKit
import Display
import CheckNode
import TelegramCore
import TelegramPresentationData
import ChatMessageSelectionNode

final class WegramMessageSelectionNodeTests: XCTestCase {
    private func check(_ node: ChatMessageSelectionNode) throws -> CheckNode {
        _ = node.view
        return try XCTUnwrap(node.subnodes?.compactMap { $0 as? CheckNode }.first)
    }

    func testWegramCheckKeepsTheFirstAvatarRowOnTallMessagesAndUsesFlatGreen() throws {
        let node = ChatMessageSelectionNode(wallpaper: .color(0xededed), theme: defaultDarkPresentationTheme, usesWegramAppearance: true, toggle: { _ in })
        let check = try self.check(node)
        for height: CGFloat in [40, 400, 1000] {
            for inset: CGFloat in [0, 59] {
                node.updateLayout(size: CGSize(width: 402, height: height), leftInset: inset)
                XCTAssertEqual(check.frame, CGRect(x: inset + 9, y: 9, width: 22, height: 22), "A long message must not move its check down to the middle")
            }
        }
        XCTAssertEqual(check.theme.backgroundColor, UIColor(rgb: 0x07c160))
        XCTAssertEqual(check.theme.strokeColor, UIColor.white)
        XCTAssertFalse(check.theme.hasInset)
        XCTAssertFalse(check.theme.hasShadow)
        XCTAssertFalse(check.theme.overlayBorder)
        node.updateSelected(true, animated: false)
        XCTAssertTrue(node.selected)
        XCTAssertTrue(check.selected)
        node.updateSelected(false, animated: false)
        XCTAssertFalse(check.selected)
    }

    func testOriginalCheckRetainsItsWallpaperStyleAndVerticalCenter() throws {
        let wallpaper = TelegramWallpaper.color(0xededed)
        let node = ChatMessageSelectionNode(wallpaper: wallpaper, theme: defaultDarkPresentationTheme, toggle: { _ in })
        let check = try self.check(node)
        node.updateLayout(size: CGSize(width: 402, height: 400), leftInset: 59)
        XCTAssertEqual(check.frame, CGRect(x: 65, y: 186, width: 28, height: 28))
        let style: CheckNodeTheme.Style = wallpaper == defaultDarkPresentationTheme.chat.defaultWallpaper ? .plain : .overlay
        XCTAssertEqual(check.theme, CheckNodeTheme(theme: defaultDarkPresentationTheme, style: style, hasInset: true))
    }

    func testReusedNodeUpdatesItsThemeAndRestoresOriginalStyleWithoutTogglingMessages() throws {
        var toggles: [Bool] = []
        let node = ChatMessageSelectionNode(wallpaper: .color(0xededed), theme: defaultPresentationTheme, toggle: { toggles.append($0) })
        let check = try self.check(node)
        node.frame = CGRect(x: 0, y: 0, width: 100, height: 80)
        for dark in [false, true] {
            let theme = dark ? defaultDarkPresentationTheme : defaultPresentationTheme
            node.updateAppearance(wallpaper: .color(0x123456), theme: theme, usesWegramAppearance: true)
            node.updateLayout(size: node.bounds.size, leftInset: 0)
            XCTAssertEqual(check.theme.borderColor, UIColor(white: dark ? 1.0 : 0.0, alpha: 0.3))
            XCTAssertFalse(check.isUserInteractionEnabled)
            for selected in [false, true] {
                node.updateSelected(selected, animated: false)
                XCTAssertEqual(node.selected, selected)
                XCTAssertEqual(check.selected, selected)
                node.view.backgroundColor = UIColor(rgb: dark ? 0x151515 : 0xededed)
                node.recursivelyEnsureDisplaySynchronously(true)
                if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let image = UIGraphicsImageRenderer(size: node.bounds.size).image { node.view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("selection-check-\(dark ? "dark" : "light")-\(selected ? "selected" : "empty").png"))
                }
            }
        }
        node.updateAppearance(wallpaper: .color(0x123456), theme: defaultDarkPresentationTheme, usesWegramAppearance: false)
        node.updateLayout(size: node.bounds.size, leftInset: 0)
        XCTAssertEqual(check.frame, CGRect(x: 6, y: 26, width: 28, height: 28))
        XCTAssertEqual(check.theme, CheckNodeTheme(theme: defaultDarkPresentationTheme, style: .overlay, hasInset: true))
        XCTAssertTrue(node.selected)
        XCTAssertTrue(check.selected)
        XCTAssertEqual(node.view.gestureRecognizers?.count, 1)
        XCTAssertTrue(toggles.isEmpty, "Relayout and theme changes must never select actual messages")
    }
}
