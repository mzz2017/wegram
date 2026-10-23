import XCTest
import UIKit
import Display
@testable import ChatListUI

final class WegramChatListPreviewTests: XCTestCase {
    private let marker = NSAttributedString.Key("Wegram.Preview.Fixture.Entity")
    private func preview(text: NSAttributedString?, author: String? = nil, topic: String? = nil, draft: Bool = false, unread: String? = nil) -> NSAttributedString? {
        wegramChatListPreview(text: text, author: author.map(NSAttributedString.init(string:)), topic: topic.map(NSAttributedString.init(string:)), isDraft: draft, mutedUnreadPrefix: unread, font: UIFont.systemFont(ofSize: 14), textColor: .gray, draftColor: .red)
    }
    func testTopicAndMutedCountStayInOneSummaryWithoutDroppingRichTextOrUTF16Offsets() throws {
        let message = NSMutableAttributedString(string: "🦆 hello link")
        let range = (message.string as NSString).range(of: "link")
        message.addAttributes([self.marker: 42, .underlineStyle: NSUnderlineStyle.single.rawValue], range: range)
        let result = try XCTUnwrap(self.preview(text: message, author: "Sender", topic: "Topic", unread: "[182条] "))
        XCTAssertEqual(result.string, "[182条] [Topic] Sender: 🦆 hello link")
        let resultRange = (result.string as NSString).range(of: "link")
        XCTAssertEqual(result.attribute(self.marker, at: resultRange.location, effectiveRange: nil) as? Int, 42)
        XCTAssertEqual(result.attribute(.underlineStyle, at: resultRange.location, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(message.string, "🦆 hello link")
        XCTAssertEqual(message.attribute(self.marker, at: range.location, effectiveRange: nil) as? Int, 42)
    }
    func testForumAuthorSurvivesTheOriginalPreprocessingBeforeTheCompactSummary() throws {
        let body = NSAttributedString(string: "Body", attributes: [self.marker: 7])
        let author = NSAttributedString(string: "Sender")
        let compact = chatListForumPreview(text: body, author: author, keepsAuthorSeparate: true, font: .systemFont(ofSize: 14), textColor: .gray)
        XCTAssertEqual(compact.author?.string, "Sender")
        let result = try XCTUnwrap(wegramChatListPreview(text: compact.text, author: compact.author, topic: NSAttributedString(string: "Topic"), isDraft: false, mutedUnreadPrefix: nil, font: .systemFont(ofSize: 14), textColor: .gray, draftColor: .red))
        XCTAssertEqual(result.string, "[Topic] Sender: Body")
        XCTAssertEqual(result.attribute(self.marker, at: result.length - 1, effectiveRange: nil) as? Int, 7)
        let original = chatListForumPreview(text: body, author: author, keepsAuthorSeparate: false, font: .systemFont(ofSize: 14), textColor: .gray)
        XCTAssertEqual(original.text?.string, "Sender: Body")
        XCTAssertNil(original.author)
        XCTAssertEqual(original.text?.attribute(self.marker, at: 8, effectiveRange: nil) as? Int, 7)
    }
    func testDraftKeepsItsRedPrefixAndDoesNotBorrowTheLastMessagesTopic() throws {
        let result = try XCTUnwrap(self.preview(text: NSAttributedString(string: "Unsent"), author: "Draft", topic: "Old topic", draft: true))
        XCTAssertEqual(result.string, "Draft: Unsent")
        XCTAssertEqual(result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
        XCTAssertEqual(result.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? UIColor, .red)
        XCTAssertNil(result.attribute(.foregroundColor, at: 7, effectiveRange: nil))
        XCTAssertEqual(self.preview(text: NSAttributedString(string: ""), author: "Draft", draft: true)?.string, "Draft: ")
    }
    func testEmptySourceDoesNotFabricateMessageTextAndTopicOnlyRemainsReadable() {
        XCTAssertNil(self.preview(text: nil))
        XCTAssertEqual(self.preview(text: NSAttributedString(string: ""))?.string, "")
        XCTAssertEqual(self.preview(text: nil, topic: "General")?.string, "[General] ")
        XCTAssertEqual(self.preview(text: NSAttributedString(string: "Body"), author: "", topic: "")?.string, "Body")
    }
    func testTopicLineBreaksDoNotHideTheMessageOnASingleLine() {
        XCTAssertEqual(self.preview(text: NSAttributedString(string: "Body"), author: "Sender", topic: "Topic\nName")?.string, "[Topic Name] Sender: Body")
        XCTAssertEqual(self.preview(text: NSAttributedString(string: "Body"), topic: "   ")?.string, "Body")
        XCTAssertNil(self.preview(text: nil, topic: " \n "))
    }
    func testActualTextNodeRendersTheCompleteSummaryAsOneTruncatedLine() throws {
        for width: CGFloat in [160, 300, 620] {
            let text = try XCTUnwrap(self.preview(text: NSAttributedString(string: String(repeating: "Long message ", count: 12), attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.gray]), author: "Sender", topic: "Topic", unread: "[182条] "))
            let node = TextNode()
            let (layout, apply) = TextNode.asyncLayout(node)(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width, height: .greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: .zero))
            _ = apply()
            node.frame = CGRect(origin: .zero, size: layout.size)
            XCTAssertLessThanOrEqual(layout.size.width, width)
            XCTAssertLessThan(layout.size.height, 24)
            XCTAssertTrue(layout.truncated)
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                node.recursivelyEnsureDisplaySynchronously(true)
                let format = UIGraphicsImageRendererFormat(); format.scale = 2
                let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: 24), format: format).image { context in
                    UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: 24))
                    node.layer.render(in: context.cgContext)
                }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("chat-list-compact-preview-\(Int(width)).png"))
            }
        }
    }
}
