import XCTest
import UIKit

final class WegramInlinePlaceholderTests: XCTestCase {
    func testThemeRecolorPreservesTransparentBotPrefixAndAttributedQueryHint() {
        let font = UIFont.systemFont(ofSize: 34)
        let source = NSMutableAttributedString(string: "@example", attributes: [.font: font, .foregroundColor: UIColor.clear])
        let prefix = source.length
        source.append(NSAttributedString(string: " 搜索 👨‍👩‍👧‍👦", attributes: [.font: font, .foregroundColor: UIColor.gray]))
        for color in [UIColor.white.withAlphaComponent(0.5), UIColor.darkGray] {
            let output = wegramInlinePlaceholder(source, color: color)
            XCTAssertEqual(output.string, source.string)
            XCTAssertEqual(output.length, source.length)
            XCTAssertEqual((output.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)?.cgColor.alpha, 0)
            XCTAssertEqual(output.attribute(.foregroundColor, at: prefix, effectiveRange: nil) as? UIColor, color)
            XCTAssertEqual(output.attribute(.font, at: prefix, effectiveRange: nil) as? UIFont, font)
        }
        XCTAssertEqual(source.attribute(.foregroundColor, at: prefix, effectiveRange: nil) as? UIColor, .gray)
        XCTAssertEqual(wegramInlinePlaceholder(NSAttributedString(string: ""), color: .red).length, 0)
    }
}
