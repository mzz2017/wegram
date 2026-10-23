import XCTest
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
@testable import ChatListUI

final class WegramChatListEmptyTests: XCTestCase {
    override class func setUp() { super.setUp(); ChatListRichTextPreviewTests.exchangeResourceLookups() }
    override class func tearDown() { ChatListRichTextPreviewTests.exchangeResourceLookups(); super.tearDown() }
    private func views(_ view: UIView) -> [UIView] { return [view] + view.subviews.flatMap(self.views) }
    private func update(_ view: WegramChatListEmptyView, dark: Bool = false, fontSize: PresentationFontSize = .regular, title: String = "No chats yet", description: String = "", action: String? = "New Message", loading: Bool = false) {
        view.update(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme, fontSize: fontSize, title: title, description: description, actionTitle: action, loadingText: "Loading", isLoading: loading)
    }
    func testFlatEmptyContentLeavesBackgroundTouchesAvailableAndUsesActualLocalizedText() throws {
        let data = defaultPresentationData()
        for dark in [false, true] {
            let theme = dark ? defaultDarkPresentationTheme : defaultPresentationTheme
            let view = WegramChatListEmptyView(action: {})
            view.backgroundColor = theme.chatList.backgroundColor
            view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
            self.update(view, dark: dark, title: data.strings.ChatList_EmptyChatListWithArchive, action: data.strings.ChatList_EmptyChatListNewMessage)
            view.updateLayout(insets: UIEdgeInsets(top: 170, left: 16, bottom: 84, right: 16))
            let button = try XCTUnwrap(self.views(view).compactMap { $0 as? UIButton }.first)
            let title = try XCTUnwrap(self.views(view).compactMap { $0 as? UILabel }.first { $0.text == data.strings.ChatList_EmptyChatListWithArchive })
            XCTAssertEqual(title.textColor, theme.list.itemSecondaryTextColor)
            XCTAssertEqual(button.layer.cornerRadius, 4)
            XCTAssertEqual(button.backgroundColor, UIColor(rgb: 0x07c160))
            XCTAssertGreaterThanOrEqual(button.frame.height, 48)
            let frame = button.convert(button.bounds, to: view)
            XCTAssertGreaterThan(frame.minY, title.convert(title.bounds, to: view).maxY)
            XCTAssertLessThanOrEqual(frame.maxY, 874 - 84)
            XCTAssertNil(view.hitTest(CGPoint(x: 30, y: 180), with: nil), "The empty overlay must not block the archive row or list background")
            XCTAssertNotNil(view.hitTest(frame.center, with: nil))
            XCTAssertEqual(button.accessibilityLabel, data.strings.ChatList_EmptyChatListNewMessage)
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                view.layoutIfNeeded()
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("chat-list-empty-\(dark ? "dark" : "light").png"))
            }
        }
    }

    func testNarrowLandscapeAndLargeTextCanScrollToTheCompleteButton() throws {
        let view = WegramChatListEmptyView(action: {})
        view.frame = CGRect(x: 0, y: 0, width: 240, height: 170)
        self.update(view, fontSize: .extraLargeX2, title: "An empty chat folder with a long localized name", description: "Edit this folder to change which chats it includes.", action: "Edit the selected chat folder")
        view.updateLayout(insets: UIEdgeInsets(top: 20, left: 12, bottom: 20, right: 24))
        let scroll = try XCTUnwrap(self.views(view).compactMap { $0 as? UIScrollView }.first)
        let button = try XCTUnwrap(self.views(view).compactMap { $0 as? UIButton }.first)
        XCTAssertTrue(scroll.isScrollEnabled)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        XCTAssertGreaterThan(button.frame.height, 48)
        XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
        XCTAssertLessThanOrEqual(button.frame.maxX, scroll.bounds.width)
        scroll.scrollRectToVisible(button.frame, animated: false)
        let rect = button.convert(button.bounds, to: view)
        let visible = rect.intersection(scroll.frame)
        XCTAssertFalse(visible.isEmpty)
        XCTAssertNotNil(view.hitTest(visible.center, with: nil))
        if rect.minY < scroll.frame.minY {
            XCTAssertNil(view.hitTest(CGPoint(x: rect.midX, y: scroll.frame.minY - 1), with: nil), "Clipped button content must not steal a tap above the viewport")
        }
        if rect.maxY > scroll.frame.maxY {
            XCTAssertNil(view.hitTest(CGPoint(x: rect.midX, y: scroll.frame.maxY + 1), with: nil), "Clipped button content must not steal a tap below the viewport")
        }
        XCTAssertGreaterThan(button.titleLabel?.bounds.height ?? 0, 0)
        view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        view.updateLayout(insets: UIEdgeInsets(top: 100, left: 0, bottom: 80, right: 0))
        XCTAssertFalse(scroll.isScrollEnabled)
        XCTAssertEqual(scroll.contentOffset, .zero, "Returning to a roomy layout must reveal the centered content again")
    }

    func testInlineEmptyIntroRemovesAnimationAndKeepsDefaultLayoutOnReuse() throws {
        let data = defaultPresentationData()
        let item = ChatListEmptyInfoItem(theme: data.theme, strings: data.strings, lottieSettings: .noAccountFallback, fontSize: .extraLargeX2, usesWegramLayout: true)
        let node = ChatListEmptyInfoItemNode(lottieSettings: .noAccountFallback)
        let params = ListViewItemLayoutParams(width: 320, leftInset: 30, rightInset: 10, availableHeight: 1000)
        let (layout, apply) = node.asyncLayout()(item, params, true)
        apply()
        let text = try XCTUnwrap(node.subnodes?.compactMap { $0 as? TextNode }.first)
        XCTAssertEqual(text.cachedLayout?.attributedString?.string, data.strings.ChatList_EmptyChatList)
        XCTAssertEqual(text.frame.midX, 30 + (320 - 30 - 10) / 2, accuracy: 1)
        XCTAssertEqual(layout.contentSize.height, text.frame.height + 64)
        XCTAssertEqual(node.subnodes?.filter { !$0.isHidden && !$0.frame.isEmpty }.count, 1)
        let original = ChatListEmptyInfoItem(theme: data.theme, strings: data.strings, lottieSettings: .noAccountFallback)
        let (oldLayout, restore) = node.asyncLayout()(original, params, true)
        restore()
        XCTAssertEqual(text.frame.midX, 160, accuracy: 1)
        XCTAssertEqual(oldLayout.contentSize.height, text.frame.height + 8 + 140 + 27 + 24)
        XCTAssertEqual(node.subnodes?.filter { !$0.isHidden && !$0.frame.isEmpty }.count, 2)
    }
}
