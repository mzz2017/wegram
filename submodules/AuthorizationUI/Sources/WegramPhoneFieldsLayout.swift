import UIKit
import PhoneInputNode

func layoutWegramPhoneFields(_ node: PhoneInputNode, size: CGSize) {
    let field = node.countryCodeField.textField
    let textWidth = field.attributedText?.size().width ?? 0
    let codeWidth = min(max(0, size.width - 86), max(40, ceil(textWidth) + 8))
    node.countryCodeField.frame = CGRect(x: 0, y: 0, width: codeWidth, height: size.height)
    node.numberField.frame = CGRect(x: codeWidth + 6, y: 0, width: max(0, size.width - codeWidth - 6), height: size.height)
}
