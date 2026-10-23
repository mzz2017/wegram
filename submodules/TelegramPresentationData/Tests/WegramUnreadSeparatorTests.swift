import XCTest
import UIKit
import Display
import ChatMessageItemCommon

final class WegramUnreadSeparatorTests: XCTestCase {
    func testActualSeparatorUsesPlainTextAndLinesAndDoesNotBlockHistoryTouches() throws {
        for dark in [false, true] {
            let view = WegramUnreadSeparatorView(frame: CGRect(x: 0, y: 0, width: 402, height: 25))
            view.update(text: "以下为新消息", font: Font.regular(13), isDark: dark)
            view.updateLayout(leftInset: 0, rightInset: 0)
            let label = try XCTUnwrap(view.subviews.compactMap { $0 as? UILabel }.first)
            let lines = view.subviews.filter { !($0 is UILabel) }
            XCTAssertNil(view.backgroundColor, "The unread marker must not paint a full-width bar over the wallpaper")
            XCTAssertEqual(label.text, "以下为新消息")
            XCTAssertEqual(label.textColor, UIColor(rgb: dark ? 0x999999 : 0x888888))
            XCTAssertEqual(lines.count, 2)
            XCTAssertTrue(lines.allSatisfy { $0.frame.height == UIScreenPixel && $0.frame.width > 0 })
            XCTAssertLessThanOrEqual(lines[0].frame.maxX, label.frame.minX - 7.5)
            XCTAssertGreaterThanOrEqual(lines[1].frame.minX, label.frame.maxX + 7.5)
            XCTAssertEqual(view.accessibilityLabel, label.text)
            XCTAssertEqual(view.accessibilityTraits, .staticText)
            XCTAssertTrue(view.isAccessibilityElement)
            XCTAssertTrue(view.subviews.allSatisfy { !$0.isAccessibilityElement })
            XCTAssertNil(view.hitTest(view.bounds.center, with: nil))
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                let canvas = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 65))
                canvas.backgroundColor = UIColor(rgb: dark ? 0x151515 : 0xededed)
                view.frame.origin.y = 20
                canvas.addSubview(view)
                label.contentScaleFactor = 3
                label.setNeedsDisplay()
                label.layer.displayIfNeeded()
                let format = UIGraphicsImageRendererFormat(); format.scale = 3
                let image = UIGraphicsImageRenderer(size: canvas.bounds.size, format: format).image { canvas.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("unread-separator-\(dark ? "dark" : "light").png"))
            }
        }
    }

    func testSafeInsetsLargeTextAndReuseKeepTextInsideTheRowAndAccessible() throws {
        let view = WegramUnreadSeparatorView(frame: .zero)
        for width: CGFloat in [160, 240, 402, 874] {
            for fontSize: CGFloat in [13, 26, 39] {
                for text in ["以下为新消息", "以下為新訊息", "Unread messages with a long localized title"] {
                    let font = Font.regular(fontSize)
                    let height = WegramUnreadSeparatorView.height(font: font)
                    view.frame = CGRect(x: 0, y: 0, width: width, height: height)
                    view.update(text: text, font: font, isDark: true)
                    view.updateLayout(leftInset: 24, rightInset: 8)
                    let label = try XCTUnwrap(view.subviews.compactMap { $0 as? UILabel }.first)
                    XCTAssertGreaterThanOrEqual(label.frame.minX, 24)
                    XCTAssertLessThanOrEqual(label.frame.maxX, width - 8)
                    XCTAssertGreaterThanOrEqual(label.frame.minY, 0)
                    XCTAssertLessThanOrEqual(label.frame.maxY, height)
                    XCTAssertEqual(label.frame.midX, 24 + (width - 24 - 8) / 2, accuracy: 0.5)
                    XCTAssertEqual(view.accessibilityLabel, text, "VoiceOver retains the complete title even when the visual label truncates")
                    for line in view.subviews.filter({ !($0 is UILabel) }) {
                        XCTAssertGreaterThanOrEqual(line.frame.width, 0)
                        XCTAssertGreaterThanOrEqual(line.frame.minX, 24)
                        XCTAssertLessThanOrEqual(line.frame.maxX, width - 8)
                        XCTAssertLessThanOrEqual(line.frame.maxY, height)
                    }
                }
            }
        }
        XCTAssertEqual(WegramUnreadSeparatorView.height(font: Font.regular(13)), 25)
        XCTAssertGreaterThan(WegramUnreadSeparatorView.height(font: Font.regular(26)), 25)
    }
}
