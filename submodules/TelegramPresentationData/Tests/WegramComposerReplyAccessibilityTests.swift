import XCTest
import TextFormat

final class WegramComposerReplyAccessibilityTests: XCTestCase {
    private let spoiler = NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)

    func testVisibleTextAndEmojiRemainReadable() {
        for text in ["", "王艺：照片", "作者：你好 👨‍👩‍👧‍👦 café", "Sender: visible text"] {
            XCTAssertEqual(wegramComposerReplyAccessibilityText(NSAttributedString(string: text), spoilerLabel: "剧透"), text)
        }
    }

    func testHiddenRunsUseLocalizedPlaceholderWithoutLeakingOrMutatingPreview() {
        let text = "作者😀：公开 秘密甲 公开 secret-two 结束"
        let preview = NSMutableAttributedString(string: text)
        for hidden in ["秘密甲", "secret-two"] {
            preview.addAttribute(self.spoiler, value: true, range: (text as NSString).range(of: hidden))
        }
        XCTAssertEqual(wegramComposerReplyAccessibilityText(preview, spoilerLabel: "剧透"), "作者😀：公开 [剧透] 公开 [剧透] 结束")
        XCTAssertEqual(wegramComposerReplyAccessibilityText(preview, spoilerLabel: "Spoiler"), "作者😀：公开 [Spoiler] 公开 [Spoiler] 结束")
        XCTAssertEqual(preview.string, text)
        XCTAssertEqual(preview.attribute(self.spoiler, at: (text as NSString).range(of: "秘密甲").location, effectiveRange: nil) as? Bool, true)
    }

    func testHiddenEmojiAndFormattingDoNotFragmentOrRevealTheSecret() {
        let text = "public 🔒藏起来👨‍👩‍👧‍👦 tail"
        let preview = NSMutableAttributedString(string: text)
        let hidden = (text as NSString).range(of: "🔒藏起来👨‍👩‍👧‍👦")
        preview.addAttribute(self.spoiler, value: true, range: hidden)
        preview.addAttribute(NSAttributedString.Key(rawValue: "OtherFormatting"), value: 1, range: (text as NSString).range(of: "藏起来"))
        XCTAssertEqual(wegramComposerReplyAccessibilityText(preview, spoilerLabel: "剧透"), "public [剧透] tail")
    }
}
