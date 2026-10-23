import XCTest
import UIKit
import PhoneInputNode

final class WegramPhoneFieldsTests: XCTestCase {
    func testFullThreeDigitCountryCodesFitAndLeaveRoomForTheNumber() throws {
        for width: CGFloat in [178, 218, 250] {
            let node = PhoneInputNode(fontSize: 17)
            _ = node.view
            node.frame = CGRect(x: 0, y: 0, width: width, height: 52)
            for text in ["+65", "+86", "+971", "+993", "+999", "+1"] {
                // Set the displayed field directly so this layout test does not configure or change country parsing.
                node.countryCodeField.textField.text = text
                layoutWegramPhoneFields(node, size: node.bounds.size)
                let field = node.countryCodeField.textField
                let font = try XCTUnwrap(field.font)
                let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
                XCTAssertGreaterThanOrEqual(field.textRect(forBounds: field.bounds).width, textWidth + 6, "The complete code and cursor space must fit: \(text)")
                XCTAssertEqual(node.numberField.frame.minX - node.countryCodeField.frame.maxX, 6)
                XCTAssertEqual(node.numberField.frame.maxX, width)
                XCTAssertGreaterThanOrEqual(node.numberField.frame.width, 80)
                XCTAssertEqual(field.text, text)
            }
            XCTAssertEqual(node.countryCodeField.frame.width, 40, "A short code restores the reference layout")
        }
    }
}
