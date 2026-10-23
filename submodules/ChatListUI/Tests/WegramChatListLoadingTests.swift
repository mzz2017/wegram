import XCTest
import UIKit
import Display
import TelegramPresentationData
import ShimmerEffect
@testable import ChatListUI

final class WegramChatListLoadingTests: XCTestCase {
    func testCompactLoadingUsesTheSquareAvatarAndOnlyOnePreviewLine() throws {
        let avatar = CGRect(x: 16, y: 12, width: 48, height: 48)
        let shapes = chatListLoadingShapes(avatarFrame: avatar, titleFrame: CGRect(x: 76, y: 12, width: 180, height: 20), textFrame: CGRect(x: 75, y: 35, width: 240, height: 20), dateFrame: CGRect(x: 348, y: 14, width: 36, height: 15), contentMaxX: 384, isWegram: true)
        XCTAssertEqual(shapes.count, 4, "The compact row must not draw a second summary line")
        XCTAssertEqual(shapes.first, .roundedRect(rect: avatar, cornerRadius: 4))
        XCTAssertEqual(shapes[2], .roundedRectLine(startPoint: CGPoint(x: 75, y: 42), width: 240, diameter: 10))
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            for (name, theme) in [("light", defaultPresentationTheme), ("dark", defaultDarkPresentationTheme)] {
                let node = ShimmerEffectNode()
                let size = CGSize(width: 402, height: 72)
                node.frame = CGRect(origin: .zero, size: size)
                node.update(backgroundColor: theme.list.plainBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: size)
                node.updateAbsoluteRect(node.frame, within: size)
                let _ = node.view
                node.recursivelyEnsureDisplaySynchronously(true)
                let format = UIGraphicsImageRendererFormat(); format.scale = 2
                let image = UIGraphicsImageRenderer(size: size, format: format).image { node.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("chat-list-loading-\(name).png"))
            }
        }
    }

    func testLoadingTextKeepsTheDateGapAndStaysInsideNarrowSafeWidths() {
        for width: CGFloat in [240, 320, 402, 874] {
            let contentMaxX = width - 34
            let shapes = chatListLoadingShapes(avatarFrame: CGRect(x: 32, y: 12, width: 48, height: 48), titleFrame: CGRect(x: 92, y: 12, width: 180, height: 20), textFrame: CGRect(x: 91, y: 35, width: 240, height: 20), dateFrame: CGRect(x: contentMaxX, y: 14, width: 0, height: 15), contentMaxX: contentMaxX, isWegram: true)
            guard case let .roundedRectLine(title, titleWidth, _) = shapes[1],
                  case let .roundedRectLine(text, textWidth, _) = shapes[2],
                  case let .roundedRectLine(date, dateWidth, _) = shapes[3] else { return XCTFail("Expected title, summary and date placeholders") }
            XCTAssertGreaterThanOrEqual(titleWidth, 0)
            XCTAssertLessThanOrEqual(title.x + titleWidth + 12, date.x)
            XCTAssertLessThanOrEqual(text.x + textWidth, contentMaxX)
            XCTAssertLessThanOrEqual(date.x + dateWidth, contentMaxX)
            XCTAssertEqual(dateWidth, 36)
        }
    }

    func testOriginalLoadingKeepsItsCircleAndBothPreviewLines() {
        let avatar = CGRect(x: 16, y: 8, width: 60, height: 60)
        let shapes = chatListLoadingShapes(avatarFrame: avatar, titleFrame: CGRect(x: 84, y: 8, width: 180, height: 20), textFrame: CGRect(x: 83, y: 26, width: 240, height: 40), dateFrame: CGRect(x: 344, y: 10, width: 36, height: 15), contentMaxX: 380, isWegram: false)
        XCTAssertEqual(shapes, [
            .circle(avatar),
            .roundedRectLine(startPoint: CGPoint(x: 84, y: 13), width: 180, diameter: 10),
            .roundedRectLine(startPoint: CGPoint(x: 83, y: 33), width: 240, diameter: 10),
            .roundedRectLine(startPoint: CGPoint(x: 83, y: 52), width: 200, diameter: 10),
            .roundedRectLine(startPoint: CGPoint(x: 344, y: 13), width: 36, diameter: 10)
        ])
    }
}
