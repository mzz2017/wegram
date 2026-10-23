import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import Markdown

private final class WegramAuthorizationAlertController: AlertController {
    override func dismissAnimated() {
        self.willDismiss?()
        super.dismissAnimated()
    }

    deinit {
        self.willDismiss?()
    }
}

public func wegramAuthorizationConfirmationController(
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
    text: String,
    actions: [TextAlertAction]
) -> AlertController {
    return wegramTextConfirmationController(updatedPresentationData: updatedPresentationData, title: nil, text: text, actions: actions)
}

public func wegramTextConfirmationController(
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
    title: String?,
    text: String,
    actions: [TextAlertAction],
    parseMarkdown: Bool = false
) -> AlertController {
    func alertTheme(_ data: PresentationData) -> AlertControllerTheme {
        let dark = data.theme.overallDarkAppearance
        return AlertControllerTheme(backgroundType: dark ? .dark : .light, backgroundColor: UIColor(rgb: dark ? 0x2c2c2c : 0xffffff), separatorColor: UIColor(white: dark ? 1 : 0, alpha: 0.1), highlightedItemColor: UIColor(rgb: dark ? 0x393939 : 0xf2f2f2), primaryColor: data.theme.list.itemPrimaryTextColor, secondaryColor: data.theme.list.itemSecondaryTextColor, accentColor: UIColor(rgb: 0x07c160), contrastColor: .white, destructiveColor: UIColor(rgb: 0xfa5151), disabledColor: data.theme.list.itemDisabledTextColor, controlBorderColor: data.theme.list.itemPlainSeparatorColor, baseFontSize: data.listsFontSize.baseDisplaySize)
    }
    let theme = alertTheme(updatedPresentationData.initial)
    var completed = false
    weak var controller: AlertController?
    let textFont = title == nil ? Font.semibold(theme.baseFontSize) : Font.regular(theme.baseFontSize * 14 / 17)
    let attributedText: NSAttributedString
    if parseMarkdown {
        attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: theme.primaryColor), bold: MarkdownAttributeSet(font: Font.semibold(textFont.pointSize), textColor: theme.primaryColor), link: MarkdownAttributeSet(font: textFont, textColor: theme.accentColor), linkAttribute: { _ in nil }), textAlignment: .center)
    } else {
        attributedText = NSAttributedString(string: text, font: textFont, textColor: theme.primaryColor, paragraphAlignment: .center)
    }
    let content = TextAlertContentNode(theme: theme, title: title.map { NSAttributedString(string: $0, font: Font.semibold(theme.baseFontSize), textColor: theme.primaryColor, paragraphAlignment: .center) }, text: attributedText, actions: actions.map { action in
        return TextAlertAction(type: action.type, title: action.title, action: {
            guard !completed else { return }
            completed = true
            controller?.dismissAnimated()
            action.action()
        })
    }, actionLayout: .horizontal, dismissOnOutsideTap: true)
    let result = WegramAuthorizationAlertController(theme: theme, contentNode: content)
    controller = result
    let disposable = (updatedPresentationData.signal |> deliverOnMainQueue).start(next: { [weak result] data in
        result?.theme = alertTheme(data)
    })
    result.willDismiss = {
        completed = true
        disposable.dispose()
        controller = nil
    }
    result.dismissed = { _ in
        completed = true
        disposable.dispose()
        controller = nil
    }
    return result
}
