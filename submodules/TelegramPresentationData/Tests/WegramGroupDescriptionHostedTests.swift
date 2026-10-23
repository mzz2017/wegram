import XCTest
import UIKit

final class WegramGroupDescriptionHostedTests: XCTestCase {
    func testCopyExportsOnlySelectedVisibleTextAndLeavesClipboardForEmptySelection() {
        let saved = UIPasteboard.general.items
        defer { UIPasteboard.general.items = saved }
        UIPasteboard.general.items = [["public.utf8-plain-text": "Before", "public.rtf": Data("Before".utf8)]]
        let view = WegramGroupDescriptionView()
        view.update(text: "🦆 @telegram #news", dark: false, fontSize: 17, title: "群介绍", emptyText: "暂无群介绍", openTitle: "打开", moreTitle: "更多")
        view.textView.selectedRange = NSRange(location: 3, length: 9)
        view.textView.copy(nil)
        XCTAssertEqual(UIPasteboard.general.string, "@telegram")
        XCTAssertFalse(UIPasteboard.general.types.contains("public.rtf"))
        XCTAssertFalse(UIPasteboard.general.types.contains("public.html"))
        view.textView.selectedRange = NSRange(location: 0, length: 0)
        view.textView.copy(nil)
        XCTAssertEqual(UIPasteboard.general.string, "@telegram")
    }

}
