import TelegramCore

struct ReplyThumbnailState {
    let reference: AnyMediaReference?
    let isSpoiler: Bool

    func needsReload(comparedTo previous: ReplyThumbnailState?) -> Bool {
        guard let previous else { return self.reference != nil }
        if self.isSpoiler != previous.isSpoiler { return true }
        if let reference = self.reference, let previousReference = previous.reference {
            return !reference.media.isEqual(to: previousReference.media)
        }
        return (self.reference != nil) != (previous.reference != nil)
    }
}
