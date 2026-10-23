import Foundation
import CoreGraphics

@main
struct MessageLayoutTests {
    static func main() {
        var failures: [String] = []
        let left = WegramMessageLayout.avatarFrame(width: 402, leftInset: 0, rightInset: 0, outgoing: false)
        let right = WegramMessageLayout.avatarFrame(width: 402, leftInset: 0, rightInset: 0, outgoing: true)
        if left != CGRect(x: 12, y: 0, width: 40, height: 40) { failures.append("Incoming avatar is misplaced: \(left)") }
        if right != CGRect(x: 350, y: 0, width: 40, height: 40) { failures.append("Outgoing avatar is misplaced: \(right)") }
        let incomingX = WegramMessageLayout.bubbleOriginX(width: 402, bubbleWidth: 120, leftInset: 0, rightInset: 0, outgoing: false, failedInset: 0)
        let outgoingX = WegramMessageLayout.bubbleOriginX(width: 402, bubbleWidth: 120, leftInset: 0, rightInset: 0, outgoing: true, failedInset: 0)
        if incomingX - left.maxX != 8 { failures.append("Incoming bubble has the wrong avatar gap") }
        if right.minX - (outgoingX + 120) != 8 { failures.append("Outgoing bubble overlaps its avatar or has the wrong gap") }
        let failedX = WegramMessageLayout.bubbleOriginX(width: 402, bubbleWidth: 120, leftInset: 0, rightInset: 0, outgoing: true, failedInset: 24)
        if outgoingX - failedX != 24 { failures.append("Failed-message control space was lost") }
        let landscape = WegramMessageLayout.avatarFrame(width: 874, leftInset: 62, rightInset: 62, outgoing: true)
        if landscape.maxX != 800 { failures.append("Outgoing avatar ignores the safe area") }
        let outgoingSelection = WegramMessageLayout.avatarSelectionOffset(outgoing: true, isSelected: true)
        if right.maxX + outgoingSelection > 402 - 12 { failures.append("Outgoing avatar is clipped during message selection") }
        if WegramMessageLayout.avatarSelectionOffset(outgoing: false, isSelected: true) != 42 { failures.append("Incoming avatar does not move with selection controls") }
        if WegramMessageLayout.avatarSelectionOffset(outgoing: false, isSelected: false) != 0 { failures.append("Avatar does not return after selection ends") }
        let bubble = CGRect(x: 60, y: 32, width: 100, height: 41)
        let headerSize = CGSize(width: 210, height: 21)
        let header = WegramMessageLayout.authorHeaderFrame(bubbleFrame: bubble, headerSize: headerSize)
        let name = WegramMessageLayout.authorNameFrame(bubbleFrame: bubble, nameSize: CGSize(width: 200, height: 17), headerSize: headerSize)
        if header.maxY != bubble.minY { failures.append("Author header consumes space inside the message bubble") }
        if name.maxY + 4 != bubble.minY { failures.append("Author name overlaps the bubble instead of leaving a 4pt gap") }
        if name.minX != 65 || name.width != 200 { failures.append("Long author name is indented or constrained by short message width") }
        if !bubble.union(header).contains(name) { failures.append("Author name falls outside the extraction and touch bounds") }
        if !failures.isEmpty {
            for failure in failures { print("FAIL: \(failure)") }
            exit(1)
        }
        print("Message layout behavior checks passed")
    }
}
