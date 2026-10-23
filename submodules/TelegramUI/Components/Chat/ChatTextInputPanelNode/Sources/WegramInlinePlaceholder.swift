import UIKit

func wegramInlinePlaceholder(_ source: NSAttributedString, color: UIColor) -> NSAttributedString {
    let result = NSMutableAttributedString(attributedString: source)
    source.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: source.length)) { value, range, _ in
        // The transparent @bot prefix reserves width for the real editable text.
        if let value = value as? UIColor, value.cgColor.alpha == 0 { return }
        result.addAttribute(.foregroundColor, value: color, range: range)
    }
    return result
}
