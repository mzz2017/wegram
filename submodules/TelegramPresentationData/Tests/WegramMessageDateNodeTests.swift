import XCTest
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import ChatMessageItemCommon

final class WegramMessageDateNodeTests: XCTestCase {
    func testActualDateNodeKeepsTagAndTextInsideSafeWidthAtLargeFonts() throws {
        for width: CGFloat in [240, 320, 402, 874] {
            for fontSize: CGFloat in [14, 28, 42, 56] {
                for dark in [false, true] {
                    let font = Font.regular(fontSize)
                    let height = WegramMessageDateLayout.cardHeight(labelHeight: WegramMessageDateTextLayout.labelHeight(font: font))
                    for text in ["00:08", "昨天 19:48", "星期三 20:57", "2025年10月10日 12:19"] {
                        let node = WegramMessageDateNode()
                        node.update(text: text, font: font, isDark: dark, synchronous: true)
                        _ = node.view
                        node.frame = CGRect(x: 0, y: 0, width: width, height: height)
                        node.updateLayout(size: node.bounds.size, leftInset: 24, rightInset: 8, transition: .immediate)
                        let background = node.backgroundNode.frame
                        let label = node.labelNode.frame
                        XCTAssertGreaterThanOrEqual(background.minX, 24)
                        XCTAssertLessThanOrEqual(background.maxX, width - 8)
                        XCTAssertEqual(background.midX, 24 + (width - 24 - 8) / 2, accuracy: 0.5)
                        XCTAssertGreaterThanOrEqual(label.minX, background.minX + 6 - 0.01)
                        XCTAssertLessThanOrEqual(label.maxX, background.maxX - 6 + 0.01)
                        XCTAssertGreaterThanOrEqual(label.minY, background.minY)
                        XCTAssertLessThanOrEqual(label.maxY, background.maxY)
                        XCTAssertEqual(node.backgroundNode.backgroundCornerRadius, 3)
                        XCTAssertEqual(node.accessibilityArea.frame, background)
                        XCTAssertEqual(node.accessibilityArea.accessibilityLabel, text, "AX retains complete dates when visual text is truncated")
                        XCTAssertTrue(node.accessibilityArea.isAccessibilityElement)
                        if width == 402 && fontSize == 14 && text == "星期三 20:57", let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                            let canvas = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 70))
                            canvas.backgroundColor = UIColor(rgb: dark ? 0x151515 : 0xededed)
                            node.frame.origin.y = 20
                            canvas.addSubnode(node)
                            node.labelNode.setNeedsDisplayAtScale(3)
                            node.recursivelyEnsureDisplaySynchronously(true)
                            let format = UIGraphicsImageRendererFormat(); format.scale = 3
                            let image = UIGraphicsImageRenderer(size: canvas.bounds.size, format: format).image { canvas.layer.render(in: $0.cgContext) }
                            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("date-node-\(dark ? "dark" : "light").png"))
                        }
                    }
                }
            }
        }
    }

    func testDateNodeReadsUpdatedDateAndRunsOnlyTheCurrentNavigationAction() {
        let node = WegramMessageDateNode()
        _ = node.view
        var first = 0
        var second = 0
        node.update(text: "00:08", font: Font.regular(14), isDark: false, synchronous: true)
        node.action = { first += 1 }
        XCTAssertTrue(node.accessibilityArea.accessibilityTraits.contains(.button))
        XCTAssertTrue(node.accessibilityArea.accessibilityActivate())
        XCTAssertEqual(first, 1)
        node.update(text: "昨天 00:08", font: Font.regular(28), isDark: true, synchronous: true)
        node.action = { second += 1 }
        node.updateLayout(size: CGSize(width: 240, height: 40), leftInset: 0, rightInset: 0, transition: .immediate)
        XCTAssertEqual(node.accessibilityArea.accessibilityLabel, "昨天 00:08")
        XCTAssertEqual(node.labelNode.cachedLayout?.attributedString?.string, "昨天 00:08")
        XCTAssertEqual(node.backgroundNode.color, UIColor(rgb: 0x242424).withAlphaComponent(0.9))
        XCTAssertTrue(node.accessibilityArea.accessibilityActivate())
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
        node.action = nil
        XCTAssertFalse(node.accessibilityArea.accessibilityActivate())
        XCTAssertEqual(node.accessibilityArea.accessibilityTraits, .staticText)
        node.update(text: "", font: Font.regular(14), isDark: false, synchronous: true)
        XCTAssertFalse(node.accessibilityArea.isAccessibilityElement)
        XCTAssertEqual(node.accessibilityArea.accessibilityLabel, "")
        XCTAssertEqual(second, 1)
    }
}

private final class DateSpacingHeader: ListViewItemHeader {
    let id: ListViewItemNode.HeaderId
    let height: CGFloat
    var stackingId: ListViewItemNode.HeaderId? { nil }
    var stickDirection: ListViewItemHeaderStickDirection { .bottom }
    var stickOverInsets: Bool { true }
    init(space: Int, height: CGFloat) { self.id = .init(space: space, id: 0); self.height = height }
    func combinesWith(other: ListViewItemHeader) -> Bool { self.id == other.id }
    func node(synchronousLoad: Bool) -> ListViewItemHeaderNode { ListViewItemHeaderNode() }
    func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {}
}

extension WegramMessageDateNodeTests {
    func testRowsReserveTheEnlargedDateHeaderWithoutChangingTopicOrDefaultSpacing() {
        let constants = ChatMessageItemLayoutConstants.default
        for fontSize: CGFloat in [14, 28, 42, 56] {
            let font = Font.regular(fontSize)
            let height = WegramMessageDateLayout.headerHeight(labelHeight: WegramMessageDateTextLayout.labelHeight(font: font))
            let node = WegramMessageDateNode()
            node.update(text: "昨天 19:48", font: font, isDark: true, synchronous: true)
            node.updateLayout(size: CGSize(width: 402, height: height), leftInset: 0, rightInset: 0, transition: .immediate)
            let headers: [ListViewItemHeader] = [DateSpacingHeader(space: 1, height: 120), DateSpacingHeader(space: 3, height: 34), DateSpacingHeader(space: 2, height: height)]
            let date = chatMessageDateHeaderSpacing(headers: headers, hasDate: true, hasTopic: false, constants: constants)
            XCTAssertEqual(date, height, "Message and separator rows must reserve the actual enlarged date header")
            XCTAssertGreaterThanOrEqual(date, node.backgroundNode.frame.maxY + 7 - 0.5)
            XCTAssertEqual(chatMessageDateHeaderSpacing(headers: headers, hasDate: true, hasTopic: true, constants: constants), constants.timestampDateAndTopicHeaderHeight + height - 34)
            XCTAssertEqual(chatMessageDateHeaderSpacing(headers: headers, hasDate: false, hasTopic: true, constants: constants), 34)
            XCTAssertEqual(chatMessageDateHeaderSpacing(headers: headers, hasDate: false, hasTopic: false, constants: constants), 0)
        }
        for headers: [ListViewItemHeader] in [[], [DateSpacingHeader(space: 2, height: 34)], [DateSpacingHeader(space: 3, height: 120)]] {
            XCTAssertEqual(chatMessageDateHeaderSpacing(headers: headers, hasDate: true, hasTopic: false, constants: constants), 34)
            XCTAssertEqual(chatMessageDateHeaderSpacing(headers: headers, hasDate: true, hasTopic: true, constants: constants), constants.timestampDateAndTopicHeaderHeight)
        }
    }

    func testCapsuleMaterialAppliesOnlyToPhotoWallpapersInLightMode() throws {
        let settings = WallpaperSettings()
        guard case var .file(file) = TelegramWallpaper.emoticonWallpaper(emoticon: "") else {
            return XCTFail("expected a file wallpaper")
        }
        XCTAssertTrue(WegramCapsuleBackgroundNode.isApplicable(wallpaper: .image([], settings), isDark: false))
        XCTAssertTrue(WegramCapsuleBackgroundNode.isApplicable(wallpaper: .file(file), isDark: false))
        XCTAssertFalse(WegramCapsuleBackgroundNode.isApplicable(wallpaper: .image([], settings), isDark: true), "No dark reference exists")
        file.isPattern = true
        XCTAssertFalse(WegramCapsuleBackgroundNode.isApplicable(wallpaper: .file(file), isDark: false), "A pattern is not a photo")
        XCTAssertFalse(WegramCapsuleBackgroundNode.isApplicable(wallpaper: .color(0xededed), isDark: false))
        XCTAssertFalse(WegramCapsuleBackgroundNode.isApplicable(wallpaper: .builtin(settings), isDark: false))
        XCTAssertFalse(WegramCapsuleBackgroundNode.isApplicable(wallpaper: .gradient(TelegramWallpaper.Gradient(id: nil, colors: [0xffffff, 0x000000], settings: settings)), isDark: false))
    }

    func testCapsuleMaterialReplacesTheFillUnderTheTimeAndCanBeRemoved() throws {
        let node = WegramMessageDateNode()
        _ = node.view
        let capsules = { node.subnodes?.compactMap { $0 as? WegramCapsuleBackgroundNode } ?? [] }
        let textColor = { node.labelNode.cachedLayout?.attributedString?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor }

        node.update(text: "14:03", font: Font.regular(14), isDark: false, usesCapsuleMaterial: true, synchronous: true)
        node.updateLayout(size: CGSize(width: 402, height: 34), leftInset: 0, rightInset: 0, transition: .immediate)
        let capsule = try XCTUnwrap(capsules().first)
        XCTAssertEqual(capsules().count, 1)
        XCTAssertEqual(capsule.frame, node.backgroundNode.frame)
        XCTAssertEqual(capsule.layer.cornerRadius, 4)
        XCTAssertEqual(capsule.layer.borderWidth, 0.5)
        XCTAssertGreaterThan(node.subnodes!.firstIndex(of: capsule)!, node.subnodes!.firstIndex(of: node.backgroundNode)!)
        XCTAssertLessThan(node.subnodes!.firstIndex(of: capsule)!, node.subnodes!.firstIndex(of: node.labelNode)!, "The time is drawn over the capsule")
        XCTAssertEqual(node.backgroundNode.color, .clear)
        XCTAssertEqual(textColor(), WegramCapsuleBackgroundNode.timeTextColor)
        let label = node.labelNode.frame
        XCTAssertGreaterThanOrEqual(label.minY, capsule.frame.minY)
        XCTAssertLessThanOrEqual(label.maxY, capsule.frame.maxY)

        node.update(text: "14:03", font: Font.regular(14), isDark: false, synchronous: true)
        node.updateLayout(size: CGSize(width: 402, height: 34), leftInset: 0, rightInset: 0, transition: .immediate)
        XCTAssertTrue(capsules().isEmpty)
        XCTAssertNil(capsule.supernode)
        XCTAssertEqual(node.backgroundNode.color, UIColor(rgb: 0xdadada))
        XCTAssertEqual(textColor(), UIColor(rgb: 0x999999))
    }
}
