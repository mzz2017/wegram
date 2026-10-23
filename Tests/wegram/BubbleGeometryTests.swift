import Foundation
import CoreGraphics

@main
struct BubbleGeometryTests {
    static func main() {
        var failures: [String] = []
        for height: CGFloat in [40, 120, 300] {
            let rect = CGRect(x: 0, y: 0, width: 120, height: height)
            let outgoing = WegramBubbleGeometry.path(in: rect, incoming: false, showsTail: true)
            let incoming = WegramBubbleGeometry.path(in: rect, incoming: true, showsTail: true)
            if !outgoing.contains(CGPoint(x: 119, y: 20)) || outgoing.contains(CGPoint(x: 119, y: 30)) {
                failures.append("Outgoing tail moved away from the first 20pt of a \(height)pt message")
            }
            if !incoming.contains(CGPoint(x: 1, y: 20)) || incoming.contains(CGPoint(x: 1, y: 30)) {
                failures.append("Incoming tail moved away from the first 20pt of a \(height)pt message")
            }
            if outgoing.contains(CGPoint(x: 1, y: 1)) || !outgoing.contains(CGPoint(x: 2, y: 2)) {
                failures.append("Message corner does not follow the 4pt radius")
            }
            for x: CGFloat in [1, 3, 8, 30, 60, 110, 119] {
                for y: CGFloat in [1, 4, 17, 20, 24, 30, height - 1] {
                    if outgoing.contains(CGPoint(x: x, y: y)) != incoming.contains(CGPoint(x: rect.width - x, y: y)) {
                        failures.append("Incoming and outgoing contours are not mirrored")
                    }
                }
            }
        }
        let sample = CGRect(origin: .zero, size: WegramBubbleGeometry.sourceSize)
        let extracted = WegramBubbleGeometry.path(in: sample, incoming: false, showsTail: false)
        if extracted.contains(CGPoint(x: 19, y: 20)) { failures.append("Extracted bubble still has a tail") }
        let stretch = WegramBubbleGeometry.stretchPoint
        if !extracted.contains(stretch) || stretch.y <= 25 || stretch.y >= sample.height - 4 {
            failures.append("Stretching deforms the tail or corners")
        }
        if sample.width + 2 > 32 { failures.append("Source image is too wide for a short message") }
        if !failures.isEmpty {
            for failure in failures { print("FAIL: \(failure)") }
            exit(1)
        }
        print("Bubble contour behavior checks passed")
    }
}
