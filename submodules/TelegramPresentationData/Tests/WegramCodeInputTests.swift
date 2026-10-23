import XCTest
import UIKit
import CodeInputView

final class WegramCodeInputTests: XCTestCase {
    private func theme(_ dark: Bool) -> CodeInputView.Theme {
        return .init(inactiveBorder: dark ? 0xff323232 : 0xffededed, activeBorder: 0xff07c160, succeedBorder: 0xff07c160, failedBorder: 0xfffa5151, foreground: dark ? 0xffd0d0d0 : 0xff181818, isDark: dark)
    }

    func testFlatInputKeepsNativeCodeFieldAndOriginalDigitValidation() {
        for dark in [false, true] {
            for width: CGFloat in [260, 342, 650] {
                let node = CodeInputView()
                let size = node.update(theme: self.theme(dark), prefix: "", count: 6, width: width, compact: false, usesWegramAppearance: true, wegramLabel: "验证码")
                node.frame = CGRect(origin: .zero, size: size)
                XCTAssertEqual(size.height, 52)
                XCTAssertEqual(node.textField.alpha, 1)
                XCTAssertEqual(node.textField.font?.pointSize, 17)
                XCTAssertEqual(node.textField.frame, CGRect(x: 94, y: 0, width: width - 94, height: 52))
                XCTAssertEqual(node.textField.textContentType, .oneTimeCode)
                XCTAssertEqual(node.textField.tintColor, UIColor(argb: 0xff07c160))
                XCTAssertTrue(node.textField(node.textField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "123456"))
                XCTAssertFalse(node.textField(node.textField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "1234567"))
                XCTAssertFalse(node.textField(node.textField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "abc"))
                var changes = 0
                node.updated = { changes += 1 }
                node.textField.text = "123"
                _ = node.perform(NSSelectorFromString("textFieldChanged:"), with: node.textField)
                XCTAssertEqual(node.text, "123")
                XCTAssertEqual(changes, 1)
            }
        }
    }

    func testOriginalBoxesAndPrefixCanBeRestoredOnTheSameNode() {
        let node = CodeInputView()
        let original = node.update(theme: self.theme(false), prefix: "", count: 5, width: 342, compact: false)
        XCTAssertEqual(original.height, 51)
        XCTAssertEqual(node.textField.alpha, 0.01, accuracy: 0.000001)
        XCTAssertEqual(node.textField.frame.size, CGSize(width: 1, height: 1))
        node.text = "42"
        _ = node.update(theme: self.theme(false), prefix: "+123", count: 3, width: 260, compact: false, usesWegramAppearance: true)
        XCTAssertGreaterThan(node.textField.frame.minX, 0)
        XCTAssertLessThan(node.textField.frame.minX, 130)
        XCTAssertEqual(node.textField.frame.maxX, 260)
        XCTAssertEqual(node.text, "42")
        let restored = node.update(theme: self.theme(false), prefix: "", count: 5, width: 342, compact: true)
        XCTAssertEqual(restored.height, 44)
        XCTAssertEqual(node.textField.alpha, 0.01, accuracy: 0.000001)
        XCTAssertEqual(node.textField.frame.size, CGSize(width: 1, height: 1))
        XCTAssertEqual(node.text, "42")
    }
}
