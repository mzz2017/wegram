import XCTest
import UIKit
import Display
import TelegramPresentationData
@testable import ChatListUI

final class WegramChatListSeparatorTests: XCTestCase {
    func testMainListSeparatorsStayAlignedAcrossPinnedAndFinalRowBoundaries() {
        for width: CGFloat in [240, 320, 402, 874] {
            for safeInsets: (CGFloat, CGFloat) in [(0, 0), (24, 8)] {
                let params = ListViewItemLayoutParams(width: width, leftInset: safeInsets.0, rightInset: safeInsets.1, availableHeight: 1000)
                for editingOffset: CGFloat in [0, 38] {
                    let content = safeInsets.0 + 76 + editingOffset
                    for fullWidth in [false, true] {
                        let frame = chatListSeparatorFrame(params: params, contentInset: content, y: 72 - UIScreenPixel, height: UIScreenPixel, fullWidth: fullWidth, isWegram: true)
                        XCTAssertEqual(frame.minX, content, "The pinned-section boundary and final row must keep the same text-aligned separator")
                        XCTAssertEqual(frame.maxX, width - safeInsets.1, accuracy: 0.01, "The reference separator reaches the trailing safe edge")
                        XCTAssertEqual(frame.maxY, 72, accuracy: 0.01)
                    }
                }
                let legacyNormal = chatListSeparatorFrame(params: params, contentInset: safeInsets.0 + 78, y: 71, height: 1, fullWidth: false, isWegram: false)
                XCTAssertEqual(legacyNormal.minX, safeInsets.0 + 78)
                XCTAssertEqual(legacyNormal.maxX, width - safeInsets.1 - 16)
                let legacyBoundary = chatListSeparatorFrame(params: params, contentInset: safeInsets.0 + 78, y: 71, height: 1, fullWidth: true, isWegram: false)
                XCTAssertEqual(legacyBoundary.minX, safeInsets.0)
                XCTAssertEqual(legacyBoundary.maxX, width - safeInsets.1 - (safeInsets.1 == 0 ? 0 : 16))
            }
        }
        let narrow = ListViewItemLayoutParams(width: 80, leftInset: 20, rightInset: 20, availableHeight: 200)
        XCTAssertGreaterThanOrEqual(chatListSeparatorFrame(params: narrow, contentInset: 96, y: 0, height: 1, fullWidth: false, isWegram: true).width, 0)
    }

    func testDefaultDarkListDistinguishesPinnedOrdinaryAndSelectedRows() throws {
        let dark = defaultDarkPresentationTheme.chatList
        XCTAssertEqual(dark.itemBackgroundColor, UIColor(rgb: 0x191919))
        XCTAssertEqual(dark.backgroundColor, dark.itemBackgroundColor)
        XCTAssertEqual(dark.pinnedItemBackgroundColor, UIColor(rgb: 0x202020))
        XCTAssertNotEqual(dark.itemBackgroundColor, dark.pinnedItemBackgroundColor, "The screenshot distinguishes pinned chats with their background")
        XCTAssertNotEqual(dark.itemSelectedBackgroundColor, dark.itemBackgroundColor)
        for (name, theme) in [("light", defaultPresentationTheme), ("dark", defaultDarkPresentationTheme)] {
            guard let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] else { continue }
            let canvas = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 72 * 3))
            let params = ListViewItemLayoutParams(width: 402, leftInset: 0, rightInset: 0, availableHeight: 1000)
            for i in 0..<3 {
                let row = UIView(frame: CGRect(x: 0, y: i * 72, width: 402, height: 72))
                row.backgroundColor = i < 2 ? theme.chatList.pinnedItemBackgroundColor : theme.chatList.itemBackgroundColor
                canvas.addSubview(row)
                let line = UIView(frame: chatListSeparatorFrame(params: params, contentInset: 76, y: 72 - UIScreenPixel, height: UIScreenPixel, fullWidth: i == 1 || i == 2, isWegram: true))
                line.backgroundColor = theme.chatList.itemSeparatorColor
                row.addSubview(line)
            }
            let format = UIGraphicsImageRendererFormat(); format.scale = 3
            let image = UIGraphicsImageRenderer(size: canvas.bounds.size, format: format).image { canvas.layer.render(in: $0.cgContext) }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("chat-list-separators-\(name).png"))
        }
    }
}
