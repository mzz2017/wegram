import Display
import AccountContext
import TelegramPresentationData
import PresentationDataUtils

// Shared confirmation UI; callers retain the original session operation and state.
public func recentSessionTerminationController(context: AccountContext, confirmed: @escaping () -> Void) -> ViewController {
    let data = context.sharedContext.currentPresentationData.with { $0 }
    return textAlertController(context: context, title: nil, text: data.strings.AuthSessions_TerminateSessionText, actions: [
        TextAlertAction(type: .defaultDestructiveAction, title: data.strings.AuthSessions_TerminateSession, action: confirmed),
        TextAlertAction(type: .genericAction, title: data.strings.Common_Cancel, action: {})
    ], actionLayout: .vertical)
}
