import XCTest
import UIKit
import AccountContext

final class WegramGroupDescriptionTests: XCTestCase {
    private func update(_ view: WegramGroupDescriptionView, text: String?, dark: Bool = false, font: CGFloat = 17) {
        view.update(text: text, dark: dark, fontSize: font, title: "群介绍", emptyText: "暂无群介绍", openTitle: "打开", moreTitle: "更多")
        view.layoutIfNeeded()
    }
    private func links(_ view: WegramGroupDescriptionView) -> [(String, URL)] {
        let text = view.textView.attributedText!
        var result: [(String, URL)] = []
        text.enumerateAttribute(.link, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if let url = value as? URL { result.append(((text.string as NSString).substring(with: range), url)) }
        }
        return result
    }
    func testLoadingEmptyAndFullDescriptionAreSelectableAndScrollable() throws {
        let view = WegramGroupDescriptionView()
        view.frame = CGRect(x: 0, y: 0, width: 402, height: 300)
        self.update(view, text: nil)
        XCTAssertTrue(view.activity.isAnimating)
        XCTAssertEqual(view.textView.text, "")
        XCTAssertFalse(view.textView.isUserInteractionEnabled)
        self.update(view, text: "")
        XCTAssertFalse(view.activity.isAnimating)
        XCTAssertEqual(view.textView.text, "暂无群介绍")
        XCTAssertFalse(view.textView.isEditable)
        XCTAssertTrue(view.textView.isSelectable)
        for width: CGFloat in [320, 402, 720] {
            for font: CGFloat in [17, 34] {
                view.frame.size.width = width
                self.update(view, text: String(repeating: "长群介绍 🦆\n", count: 35), dark: true, font: font)
                XCTAssertEqual(view.textView.frame, view.bounds)
                XCTAssertGreaterThan(view.textView.contentSize.height, view.bounds.height)
                XCTAssertEqual(view.textView.textContainerInset.left, 16)
                XCTAssertEqual(view.textView.textContainerInset.right, 16)
                XCTAssertEqual(view.textView.accessibilityLabel, "群介绍")
            }
        }
        for dark in [false, true] {
            view.frame = CGRect(x: 0, y: 0, width: 402, height: 786)
            self.update(view, text: "群介绍\n\n🦆 欢迎交流。\n@telegram\n#news\nt.me/telegram", dark: dark)
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("group-description-view-\(dark ? "dark" : "light").png"))
            }
        }
    }
    func testOriginalPrivateGroupEntitiesPreserveMentionHashtagAndInternalUrlActions() {
        let view = WegramGroupDescriptionView()
        self.update(view, text: "🦆 @telegram #news t.me/telegram https://example.com")
        let links = self.links(view)
        XCTAssertEqual(links.map { $0.0 }, ["@telegram", "#news", "t.me/telegram"])
        var tapped: [TextLinkItem] = []
        var longTapped: [TextLinkItem] = []
        view.openLink = { action, item in
            switch action { case .tap: tapped.append(item); case .longTap: longTapped.append(item) }
        }
        for (_, url) in links {
            view.activateLink(url, action: .tap)
            view.activateLink(url, action: .longTap)
        }
        XCTAssertEqual(tapped, [.mention("@telegram"), .hashtag(nil, "#news"), .url(url: "t.me/telegram", concealed: false)])
        XCTAssertEqual(longTapped, tapped)
        XCTAssertTrue(view.textView.dataDetectorTypes.isEmpty)
    }
    func testUnchangedUpdatesKeepSelectionAndOldLinkActionsAreRejectedAfterContentChanges() throws {
        let view = WegramGroupDescriptionView()
        self.update(view, text: "@telegram")
        let old = try XCTUnwrap(self.links(view).first?.1)
        view.textView.selectedRange = NSRange(location: 1, length: 4)
        self.update(view, text: "@telegram")
        XCTAssertEqual(view.textView.selectedRange, NSRange(location: 1, length: 4))
        var tapped: [TextLinkItem] = []
        view.openLink = { _, item in tapped.append(item) }
        self.update(view, text: "@durov")
        view.activateLink(old, action: .tap)
        XCTAssertTrue(tapped.isEmpty)
        let current = try XCTUnwrap(self.links(view).first?.1)
        view.isHidden = true
        view.activateLink(current, action: .tap)
        XCTAssertTrue(tapped.isEmpty)
        view.isHidden = false
        view.activateLink(current, action: .tap)
        XCTAssertEqual(tapped, [.mention("@durov")])
        self.update(view, text: nil)
        view.activateLink(current, action: .tap)
        XCTAssertEqual(tapped.count, 1)
    }
}
