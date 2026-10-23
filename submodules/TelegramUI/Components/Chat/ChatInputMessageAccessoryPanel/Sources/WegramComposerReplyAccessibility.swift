import Foundation
import TextFormat
import TelegramStringFormatting

func wegramComposerReplyAccessibilityText(_ text: NSAttributedString, spoilerLabel: String) -> String {
    let redacted = NSMutableAttributedString(attributedString: text)
    text.enumerateAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), in: NSRange(location: 0, length: text.length), options: .reverse) { value, range, _ in
        if value != nil {
            redacted.replaceCharacters(in: range, with: "[\(spoilerLabel)]")
        }
    }
    return instantPagePreviewPlainText(redacted)
}
