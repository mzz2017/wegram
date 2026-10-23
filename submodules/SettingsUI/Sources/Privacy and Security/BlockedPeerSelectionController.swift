import UIKit
import Display
import PresentationDataUtils
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext

// Shared with the full list so the WeGram entry keeps the original peer filters and request.
public func blockedPeerSelectionController(context: AccountContext, blockedPeersContext: BlockedPeersContext, actionDisposable: MetaDisposable) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyPrivateChats, .excludeSavedMessages, .removeSearchHeader, .excludeRecent, .doNotSearchMessages], title: presentationData.strings.BlockedUsers_SelectUserTitle))
    controller.peerSelected = { [weak controller] peer, _ in
        guard let controller, !controller.inProgress else { return }
        controller.inProgress = true
        actionDisposable.set((blockedPeersContext.add(peerId: peer.id) |> deliverOnMainQueue).start(error: { [weak controller] _ in
            guard let controller else { return }
            controller.inProgress = false
            controller.present(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }, completed: { [weak controller] in
            controller?.inProgress = false
            controller?.dismiss()
        }))
    }
    return controller
}
