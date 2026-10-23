import Foundation
import CoreGraphics

@main struct AttachmentLayoutTests {
    static func main() {
        for (width, left, right, bottom, maximum): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) in [(320,0,0,34,600), (402,0,0,34,600), (874,59,59,21,180), (402,24,8,0,128)] {
            for count in [1,4,8,9,20,37] {
                let layout = WegramAttachmentLayout(width: width, left: left, right: right, bottom: bottom, maximumHeight: maximum, count: count)
                precondition(layout.height <= maximum)
                precondition(layout.viewport.minX >= left)
                precondition(layout.viewport.maxX <= width - right)
                precondition(layout.frames.count == count)
                for (index, frame) in layout.frames.enumerated() {
                    let page = index / (4 * layout.rows)
                    let pageBounds = CGRect(x: CGFloat(page) * layout.pageWidth, y: 0, width: layout.pageWidth, height: layout.viewport.height)
                    precondition(pageBounds.contains(frame), "Attachment cell clipped on width \(width), index \(index)")
                    precondition(frame.width >= 44 && frame.height >= 44)
                    for other in layout.frames.prefix(index) { precondition(!frame.intersects(other), "Overlapping attachment touch targets") }
                }
                precondition(layout.pageCount * layout.rows * 4 >= count)
                precondition((layout.pageCount - 1) * layout.rows * 4 < count)
            }
        }
        let portrait = WegramAttachmentLayout(width: 402, left: 0, right: 0, bottom: 34, maximumHeight: 600, count: 9)
        precondition(portrait.rows == 2 && portrait.pageCount == 2)
        let landscape = WegramAttachmentLayout(width: 874, left: 59, right: 59, bottom: 21, maximumHeight: 180, count: 9)
        precondition(landscape.rows == 1 && landscape.pageCount == 3)
        print("Attachment grid paging, touch targets, safe insets and constrained-height checks passed")
    }
}
