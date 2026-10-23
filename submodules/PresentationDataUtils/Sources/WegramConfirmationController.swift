import Display
import SwiftSignalKit
import TelegramPresentationData

public func wegramConfirmationController(
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
    title: String,
    text: String,
    cancelTitle: String,
    actionTitle: String,
    parseMarkdown: Bool = false,
    action: @escaping () -> Void
) -> ActionSheetController {
    return wegramConfirmationController(updatedPresentationData: updatedPresentationData, title: title, text: text, cancelTitle: cancelTitle, actions: [(title: actionTitle, action: action)], parseMarkdown: parseMarkdown)
}

public func wegramConfirmationController(
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
    title: String,
    text: String,
    cancelTitle: String,
    actions: [(title: String, action: () -> Void)],
    parseMarkdown: Bool = false
) -> ActionSheetController {
    return wegramConfirmationController(updatedPresentationData: updatedPresentationData, title: title, text: text, cancelTitle: cancelTitle, styledActions: actions.map { (title: $0.title, color: .destructive, action: $0.action) }, parseMarkdown: parseMarkdown)
}

public func wegramConfirmationController(
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
    title: String,
    text: String,
    cancelTitle: String,
    styledActions: [(title: String, color: ActionSheetButtonColor, action: () -> Void)],
    parseMarkdown: Bool = false
) -> ActionSheetController {
    let data = updatedPresentationData.initial
    var completed = false
    let controller = ActionSheetController(theme: ActionSheetControllerTheme(wegramTheme: data.theme, fontSize: data.listsFontSize), allowInputInset: true)
    let explanation = [title, text].filter { !$0.isEmpty }.joined(separator: "\n\n")
    var items: [ActionSheetItem] = explanation.isEmpty ? [] : [ActionSheetTextItem(title: explanation, parseMarkdown: parseMarkdown)]
    for action in styledActions {
        items.append(ActionSheetButtonItem(title: action.title, color: action.color, action: { [weak controller] in
            guard !completed else { return }
            completed = true
            controller?.dismissAnimated()
            action.action()
        }))
    }
    controller.setItemGroups([
        ActionSheetItemGroup(items: items),
        ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: cancelTitle, action: { [weak controller] in
                guard !completed else { return }
                completed = true
                controller?.dismissAnimated()
            })
        ])
    ])
    let disposable = (updatedPresentationData.signal |> deliverOnMainQueue).start(next: { [weak controller] data in
        controller?.theme = ActionSheetControllerTheme(wegramTheme: data.theme, fontSize: data.listsFontSize)
    })
    controller.willDismiss = {
        completed = true
        disposable.dispose()
    }
    return controller
}
