import Foundation
import TelegramCore
import PhotoResources

struct WegramComposerMediaPreview {
    let reference: AnyMediaReference
    let dimensions: CGSize
    let blurred: Bool

    init?(message: EngineMessage, replyingTo messageId: EngineMessage.Id) {
        guard message.id == messageId, !message._asMessage().containsSecretMedia else { return nil }
        for media in message.media {
            let dimensions: CGSize
            if let image = media as? TelegramMediaImage,
               let representation = largestRepresentationForPhoto(image) {
                dimensions = representation.dimensions.cgSize
            } else if let file = media as? TelegramMediaFile,
                      file.isVideo, !file.isInstantVideo, !file.isSticker,
                      let representation = largestImageRepresentation(file.previewRepresentations) {
                dimensions = representation.dimensions.cgSize
            } else {
                continue
            }
            guard dimensions.width > 0, dimensions.height > 0 else { continue }
            self.reference = .message(message: MessageReference(message._asMessage()), media: media)
            self.dimensions = dimensions
            self.blurred = message.attributes.contains { $0 is MediaSpoilerMessageAttribute }
            return
        }
        return nil
    }
}
