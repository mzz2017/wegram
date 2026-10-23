import Foundation
import CoreGraphics

@main struct PeerRowLayoutTests {
    static func main() {
        for titleHeight: CGFloat in [18, 21, 40, 60] {
            for statusHeight: CGFloat in [0, 16, 34, 72] {
                let layout = WegramPeerRowLayout(titleHeight: titleHeight, statusHeight: statusHeight)
                precondition(layout.height >= 56)
                precondition(layout.titleY >= 12)
                precondition(layout.titleY + titleHeight <= layout.height - 12)
                if statusHeight > 0 {
                    precondition(layout.statusY == layout.titleY + titleHeight + 4)
                    precondition(layout.statusY + statusHeight <= layout.height - 12, "Subtitle clipped at large font or multiline status")
                } else {
                    precondition(layout.titleY == floor((layout.height - titleHeight) / 2), "Single title no longer centered")
                }
            }
        }
        precondition(wegramPeerSearchRanges(text: "Alice alice", query: "ALICE") == [NSRange(location: 0, length: 5), NSRange(location: 6, length: 5)])
        precondition(wegramPeerSearchRanges(text: "👩🏽‍💻 张三 张三", query: "张三") == [NSRange(location: 8, length: 2), NSRange(location: 11, length: 2)])
        precondition(wegramPeerSearchRanges(text: "café", query: "cafe") == [NSRange(location: 0, length: 4)])
        precondition(wegramPeerSearchRanges(text: "abc", query: "   ").isEmpty)
        precondition(wegramPeerSearchRanges(text: "abc", query: "z").isEmpty)
        let search = WegramPeerRowLayout(titleHeight: 21, statusHeight: 0, minimumHeight: 64)
        let contact = WegramPeerRowLayout(titleHeight: 21, statusHeight: 0)
        precondition(search.height == 64 && contact.height == 56)
        print("Peer row spacing, large text containment and UTF-16 search match checks passed")
    }
}
