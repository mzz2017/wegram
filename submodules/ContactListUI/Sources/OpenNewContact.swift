import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import DeviceAccess
import AccountContext
import PresentationDataUtils
import ShareController

/// Shared entry for the existing Contacts and chat-list add-friend actions.
public func openNewContact(context: AccountContext, from parent: ViewController) {
    let _ = (DeviceAccess.authorizationStatus(subject: .contacts)
    |> take(1)
    |> deliverOnMainQueue).start(next: { [weak parent] status in
        guard parent != nil else {
            return
        }

        switch status {
            case .allowed:
                if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController {
                    let controller = context.sharedContext.makeNewContactScreen(
                        context: context,
                        peer: nil,
                        firstName: nil,
                        lastName: nil,
                        phoneNumber: nil,
                        shareViaException: false,
                        completion: { [weak parent] peer, stableId, contactData in
                            guard parent != nil else {
                                return
                            }
                            if let peer {
                                Queue.mainQueue().async { [weak parent] in
                                    guard parent != nil else { return }
                                    if let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                        if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController {
                                            navigationController.pushViewController(infoController)
                                        }
                                    }
                                }
                            } else if let stableId, let contactData {
                                if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController {
                                    navigationController.pushViewController(context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: context), environment: ShareControllerAppEnvironment(sharedContext: context.sharedContext), subject: .vcard(nil, stableId, contactData), completed: nil, cancelled: nil))
                                }
                            }
                        }
                    )
                    navigationController.pushViewController(controller)
                }
            case .notDetermined:
                DeviceAccess.authorizeAccess(to: .contacts)
            default:
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController, let topController = navigationController.topViewController as? ViewController {
                    topController.present(textAlertController(context: context, title: presentationData.strings.AccessDenied_Title, text: presentationData.strings.Contacts_AccessDeniedError, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.AccessDenied_Settings, action: {
                        if parent != nil { context.sharedContext.applicationBindings.openSettings() }
                    })]), in: .window(.root))
                }
        }
    })
}
