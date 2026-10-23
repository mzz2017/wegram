import XCTest
import UIKit
import TelegramCore
import Postbox
import TextFormat
@testable import ChatMessageReplyInfoNode

final class WegramReplyInteractionTests: XCTestCase {
    func testSeparateSingleLineQuoteDoesNotConsumeTheFirstTapToExpand() {
        let node = ChatMessageReplyInfoNode(isWegramStyle: true)
        XCTAssertFalse(node.expandQuoteIfNeeded(isQuote: true), "The single-line card should continue to the original navigation on its first tap")
        XCTAssertFalse(node.isQuoteExpanded)
        XCTAssertFalse(node.expandQuoteIfNeeded(isQuote: true))
        XCTAssertFalse(node.expandQuoteIfNeeded(isQuote: false))
    }

    func testOriginalQuoteStillExpandsOnceBeforeNavigationAndPlainRepliesDoNot() {
        let node = ChatMessageReplyInfoNode()
        XCTAssertFalse(node.expandQuoteIfNeeded(isQuote: false))
        XCTAssertFalse(node.isQuoteExpanded)
        XCTAssertTrue(node.expandQuoteIfNeeded(isQuote: true))
        XCTAssertTrue(node.isQuoteExpanded)
        XCTAssertFalse(node.expandQuoteIfNeeded(isQuote: true))
        node.isQuoteExpanded = false
        XCTAssertTrue(node.expandQuoteIfNeeded(isQuote: true))
    }
    private func image(_ id: Int64) -> AnyMediaReference {
        .standalone(media: TelegramMediaImage(imageId: MediaId(namespace: 0, id: id), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: []))
    }

    func testSameReplyPhotoReloadsWhenSpoilerIsAddedOrRemoved() {
        let original = ReplyThumbnailState(reference: self.image(10), isSpoiler: false)
        let unchanged = ReplyThumbnailState(reference: self.image(10), isSpoiler: false)
        XCTAssertFalse(unchanged.needsReload(comparedTo: original), "Equal media should keep the original image signal")
        let concealed = ReplyThumbnailState(reference: self.image(10), isSpoiler: true)
        XCTAssertTrue(concealed.needsReload(comparedTo: original), "Editing the same media to spoiler must replace the clear thumbnail signal")
        XCTAssertFalse(concealed.needsReload(comparedTo: concealed))
        XCTAssertTrue(original.needsReload(comparedTo: concealed), "Removing spoiler must replace the blurred thumbnail signal")
    }

    func testReplyThumbnailStillReloadsForMediaReplacementInsertionAndRemoval() {
        let original = ReplyThumbnailState(reference: self.image(10), isSpoiler: false)
        let replacement = ReplyThumbnailState(reference: self.image(11), isSpoiler: false)
        let empty = ReplyThumbnailState(reference: nil, isSpoiler: false)
        XCTAssertTrue(original.needsReload(comparedTo: nil))
        XCTAssertFalse(empty.needsReload(comparedTo: nil))
        XCTAssertTrue(replacement.needsReload(comparedTo: original))
        XCTAssertTrue(empty.needsReload(comparedTo: original))
        XCTAssertTrue(original.needsReload(comparedTo: empty))
        XCTAssertFalse(empty.needsReload(comparedTo: empty))
    }

    func testSingleLineReplyPreviewFoldsQuotedAndTranslatedLineBreaks() {
        for separator in ["\n", "\r\n", "\r", "\u{2028}", "\u{2029}"] {
            let text = NSAttributedString(string: "第一行" + separator + separator + "第二行", attributes: [.font: UIFont.systemFont(ofSize: 14)])
            let preview = wegramReplyPreviewText(text, color: .gray)
            XCTAssertEqual(preview.string, "第一行 第二行", "A single-line quote must include text after a line break")
        }
        XCTAssertEqual(wegramReplyPreviewText(NSAttributedString(string: "\n\n"), color: .gray).string, "")
        XCTAssertEqual(wegramReplyPreviewText(NSAttributedString(string: ""), color: .gray).string, "")
    }

    func testFoldingReplyPreviewPreservesEntityAttributesAfterEmojiAndLineBreaks() {
        let spoiler = NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)
        let customEmoji = ChatTextInputAttributes.customEmoji
        let emoji = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 12345, file: nil)
        let font = UIFont.systemFont(ofSize: 14)
        let source = NSMutableAttributedString(string: "开头😀\n秘密 🐥 末尾", attributes: [.font: font, .foregroundColor: UIColor.red])
        let original = source.string as NSString
        source.addAttribute(spoiler, value: true, range: original.range(of: "秘密"))
        source.addAttribute(customEmoji, value: emoji, range: original.range(of: "🐥"))
        source.addAttribute(.strikethroughStyle, value: 1, range: original.range(of: "末尾"))
        let preview = wegramReplyPreviewText(source, color: .gray)
        XCTAssertEqual(preview.string, "开头😀 秘密 🐥 末尾")
        let result = preview.string as NSString
        XCTAssertEqual(preview.attribute(spoiler, at: result.range(of: "秘密").location, effectiveRange: nil) as? Bool, true)
        XCTAssertTrue((preview.attribute(customEmoji, at: result.range(of: "🐥").location, effectiveRange: nil) as? ChatTextInputTextCustomEmojiAttribute) === emoji)
        XCTAssertEqual(preview.attribute(.strikethroughStyle, at: result.range(of: "末尾").location, effectiveRange: nil) as? Int, 1)
        XCTAssertEqual(preview.attribute(.font, at: result.range(of: "秘密").location, effectiveRange: nil) as? UIFont, font)
        XCTAssertEqual(preview.attribute(.foregroundColor, at: result.range(of: "秘密").location, effectiveRange: nil) as? UIColor, .gray)
        XCTAssertEqual(source.string, "开头😀\n秘密 🐥 末尾", "Formatting a preview must not mutate the source")
    }

}
