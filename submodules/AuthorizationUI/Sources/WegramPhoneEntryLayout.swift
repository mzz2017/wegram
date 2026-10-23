import Foundation
import CoreGraphics

struct WegramPhoneEntryLayout {
    let title: CGRect
    let form: CGRect
    let contactSync: CGRect
    let notice: CGRect
    let button: CGRect
    let showsButton: Bool

    init(size: CGSize, statusHeight: CGFloat, navigationBarHeight: CGFloat, bottomInset: CGFloat, keyboardHeight: CGFloat, titleSize: CGSize, noticeSize: CGSize, contactSyncHeight: CGFloat) {
        let width = min(430, size.width)
        let left = floor((size.width - width) * 0.5)
        let availableBottom = size.height - max(bottomInset, keyboardHeight)
        let compact = availableBottom - statusHeight < 480
        self.showsButton = size.width > 320
        var title = CGRect(x: floor((size.width - titleSize.width) * 0.5), y: max(navigationBarHeight, statusHeight + (compact ? 24 : 82)), width: titleSize.width, height: titleSize.height)
        var form = CGRect(x: left, y: title.maxY + (compact ? 24 : 44), width: width, height: 104)
        var contactSync = CGRect(x: left, y: form.maxY + 8, width: width, height: contactSyncHeight)
        let button = CGRect(x: floor((size.width - 170) * 0.5), y: availableBottom - (keyboardHeight > 0 ? 24 : 90) - 44, width: 170, height: 44)
        let contentBottom = contactSyncHeight > 0 ? contactSync.maxY : form.maxY
        let noticeY = self.showsButton ? button.minY - 20 - noticeSize.height : contentBottom + 16
        if self.showsButton {
            let shift = min(max(0, contentBottom + 16 - noticeY), max(0, title.minY - max(navigationBarHeight, statusHeight + 8)))
            title.origin.y -= shift
            form.origin.y -= shift
            contactSync.origin.y -= shift
        }
        self.title = title
        self.form = form
        self.contactSync = contactSync
        self.notice = CGRect(x: floor((size.width - noticeSize.width) * 0.5), y: noticeY, width: noticeSize.width, height: noticeSize.height)
        self.button = button
    }
}
