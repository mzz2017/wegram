import Display
import SwiftSignalKit
import TelegramPresentationData

public func wegramMessageDeletionConfirmationController(
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
    title: String,
    text: String,
    actions: [TextAlertAction],
    parseMarkdown: Bool = false
) -> ViewController {
    let cancel = updatedPresentationData.initial.strings.Common_Cancel
    if actions.count == 1 {
        return wegramTextConfirmationController(
            updatedPresentationData: updatedPresentationData,
            title: text.isEmpty ? nil : title,
            text: text.isEmpty ? title : text,
            actions: [TextAlertAction(type: .genericAction, title: cancel, action: {})] + actions,
            parseMarkdown: parseMarkdown
        )
    }
    return wegramConfirmationController(
        updatedPresentationData: updatedPresentationData, title: title, text: text, cancelTitle: cancel,
        actions: actions.map { (title: $0.title, action: $0.action) }, parseMarkdown: parseMarkdown
    )
}
