import Foundation
import CoreGraphics

@main
struct ReplyAccessoryLayoutTests {
    static func main() {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }
        for height: CGFloat in [32, 44, 56, 80] {
            for status in [false, true] {
                for completed in [false, true] {
                    for gift in [false, true] {
                        let layout = WegramReplyAccessoryLayout(hasStatus: status, hasCheck: completed, hasGift: gift)
                        let titleRight: CGFloat = 70
                        let text = CGRect(x: titleRight + layout.leadingInset, y: 3, width: 80, height: height - 6)
                        let width = text.maxX + 10 + layout.trailingInset
                        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
                        var accessories: [CGRect] = []
                        if status {
                            accessories.append(layout.statusFrame(afterTitleX: titleRight, height: height, hasImage: false))
                        }
                        if completed {
                            accessories.append(layout.checkFrame(afterTitleX: titleRight, height: height))
                        }
                        if gift {
                            let badge = layout.giftFrame(width: width, height: height)
                            accessories.append(badge)
                            check(width - badge.maxX == 10, "Gift badge lost its trailing padding")
                        }
                        for (index, frame) in accessories.enumerated() {
                            check(bounds.contains(frame), "Accessory falls outside the quote at height \(height)")
                            check(!frame.intersects(text), "Accessory overlaps the quoted text")
                            check(abs(frame.midY - height / 2) <= 0.5, "Accessory is not vertically centered")
                            check(frame.minX >= titleRight, "Accessory overlaps the author")
                            for other in accessories.dropFirst(index + 1) {
                                check(!frame.intersects(other), "Quote accessories overlap each other")
                            }
                        }
                        if !status && !completed { check(layout.leadingInset == 0, "Plain quote keeps a blank icon slot") }
                        if !gift { check(layout.trailingInset == 0, "Plain quote keeps a blank badge slot") }
                        if status && !completed {
                            let icon = layout.statusFrame(afterTitleX: titleRight, height: height, hasImage: true)
                            let image = CGRect(x: titleRight + 4 + layout.leadingInset, y: 6, width: 32, height: 32)
                            check(icon.minX - titleRight == 4, "Story thumbnail indicator touches the author")
                            check(icon.maxX + 2 == image.minX, "Story indicator overlaps its thumbnail")
                        }
                    }
                }
            }
        }
        if !failures.isEmpty {
            failures.forEach { print("FAIL: \($0)") }
            exit(1)
        }
        print("Reply accessory layout behavior checks passed")
    }
}
