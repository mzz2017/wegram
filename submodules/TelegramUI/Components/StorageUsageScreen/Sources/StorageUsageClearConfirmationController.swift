import Display
import AccountContext
import TelegramPresentationData
import PresentationDataUtils

public func storageUsageClearConfirmationController(context: AccountContext, clearTitle: String, confirmed: @escaping () -> Void) -> ViewController {
    let data = context.sharedContext.currentPresentationData.with { $0 }
    return textAlertController(context: context, title: data.strings.StorageManagement_ClearConfirmationTitle, text: data.strings.StorageManagement_ClearConfirmationText, actions: [
        TextAlertAction(type: .defaultAction, title: clearTitle, action: confirmed),
        TextAlertAction(type: .genericAction, title: data.strings.Common_Cancel, action: {})
    ], actionLayout: .vertical)
}
