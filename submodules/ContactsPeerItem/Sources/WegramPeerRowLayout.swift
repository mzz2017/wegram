import Foundation
import CoreGraphics

struct WegramPeerRowLayout {
    let height: CGFloat
    let titleY: CGFloat
    let statusY: CGFloat

    init(titleHeight: CGFloat, statusHeight: CGFloat, minimumHeight: CGFloat = 56) {
        let titleHeight = max(0, titleHeight)
        let statusHeight = max(0, statusHeight)
        let gap: CGFloat = statusHeight > 0 ? 4 : 0
        let textHeight = titleHeight + gap + statusHeight
        self.height = max(minimumHeight, textHeight + 24)
        self.titleY = floor((self.height - textHeight) / 2)
        self.statusY = self.titleY + titleHeight + gap
    }
}

func wegramPeerSearchRanges(text: String, query: String) -> [NSRange] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return [] }
    let text = text as NSString
    var ranges: [NSRange] = []
    var offset = 0
    while offset < text.length {
        let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: NSRange(location: offset, length: text.length - offset))
        guard range.location != NSNotFound, range.length > 0 else { break }
        ranges.append(range)
        offset = NSMaxRange(range)
    }
    return ranges
}
