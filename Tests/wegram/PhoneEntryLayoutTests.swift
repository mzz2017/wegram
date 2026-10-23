import Foundation
import CoreGraphics

@main
struct PhoneEntryLayoutTests {
    static func main() {
        for keyboard: CGFloat in [0, 285, 336] {
            for contacts: CGFloat in [0, 40] {
                let frames = WegramPhoneEntryLayout(size: CGSize(width: 402, height: 874), statusHeight: 62, navigationBarHeight: 122, bottomInset: 34, keyboardHeight: keyboard, titleSize: CGSize(width: 240, height: 27), noticeSize: CGSize(width: 280, height: 44), contactSyncHeight: contacts)
                precondition(frames.title.maxY < frames.form.minY)
                let contentBottom = contacts > 0 ? frames.contactSync.maxY : frames.form.maxY
                precondition(contentBottom + 16 <= frames.notice.minY)
                precondition(frames.notice.maxY + 20 == frames.button.minY)
                precondition(frames.button.maxY <= 874 - max(34, keyboard))
                precondition(frames.button.width == 170 && frames.button.height == 44)
                precondition(frames.showsButton)
            }
        }
        let compact = WegramPhoneEntryLayout(size: CGSize(width: 320, height: 568), statusHeight: 20, navigationBarHeight: 80, bottomInset: 0, keyboardHeight: 216, titleSize: CGSize(width: 240, height: 27), noticeSize: CGSize(width: 260, height: 44), contactSyncHeight: 40)
        if compact.title.minY < 80 {
            print("FAIL: 320pt title starts at \(compact.title.minY), overlapping the navigation Next region ending at 80")
            exit(1)
        }
        precondition(!compact.showsButton, "320pt devices retain the existing navigation Next button")
        precondition(compact.contactSync.maxY + 16 <= compact.notice.minY)
        precondition(compact.notice.maxY <= 568 - 216)
        print("Phone entry layout checks passed")
    }
}
