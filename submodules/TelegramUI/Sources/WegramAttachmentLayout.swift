import Foundation
import CoreGraphics

struct WegramAttachmentLayout {
    let width: CGFloat
    let height: CGFloat
    let pageWidth: CGFloat
    let rows: Int
    let pageCount: Int
    let viewport: CGRect
    let indicators: CGRect
    let frames: [CGRect]

    init(width: CGFloat, left: CGFloat, right: CGFloat, bottom: CGFloat, maximumHeight: CGFloat, count: Int, slots: [Int]? = nil) {
        self.width = width
        let slots = slots ?? Array(0 ..< count)
        precondition(slots.count == count && slots.allSatisfy { $0 >= 0 })
        self.height = max(0, min(maximumHeight, 240 + bottom))
        self.pageWidth = max(1, width - left - right)
        let contentHeight = max(0, self.height - min(bottom, max(0, self.height - 120)) - 24)
        self.rows = contentHeight >= 208 ? 2 : 1
        let capacity = 4 * self.rows
        self.pageCount = max(1, ((slots.max().map { $0 + 1 } ?? 0) + capacity - 1) / capacity)
        self.viewport = CGRect(x: left, y: 0, width: self.pageWidth, height: contentHeight)
        self.indicators = CGRect(x: left, y: contentHeight, width: self.pageWidth, height: 24)
        let rowHeight = min(96, contentHeight / CGFloat(self.rows))
        let top = max(0, (contentHeight - rowHeight * CGFloat(self.rows)) / 2)
        let cellWidth = min(72, max(0, self.pageWidth - 40) / 4)
        let firstX: CGFloat = 20
        let columnStride = max(0, self.pageWidth - 40 - cellWidth) / 3
        let pageWidth = self.pageWidth
        self.frames = (0..<count).map { index in
            let page = slots[index] / capacity
            let slot = slots[index] % capacity
            return CGRect(x: CGFloat(page) * pageWidth + floor(firstX + CGFloat(slot % 4) * columnStride), y: top + CGFloat(slot / 4) * rowHeight + max(0, (rowHeight - 88) / 2), width: cellWidth, height: min(88, rowHeight))
        }
    }
}
