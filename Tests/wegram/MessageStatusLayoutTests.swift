import Foundation
import CoreGraphics

@main
struct MessageStatusLayoutTests {
    static func main() {
        var failures: [String] = []
        let noDate = CGSize(width: 0, height: 13)
        let empty = MessageStatusLayout.size(dateSize: noDate, leadingInset: 5, indicatorsWidth: 0, backgroundInsets: .zero)
        if empty != .zero { failures.append("Hidden timestamp still reserves a blank status row: \(empty)") }
        let sending = MessageStatusLayout.size(dateSize: noDate, leadingInset: 5, indicatorsWidth: 13, backgroundInsets: .zero)
        if sending != CGSize(width: 18, height: 13) { failures.append("Sending indicator lost its width or text baseline height") }
        let pinned = MessageStatusLayout.size(dateSize: noDate, leadingInset: 5, indicatorsWidth: 12, backgroundInsets: .zero)
        if pinned != CGSize(width: 17, height: 13) { failures.append("Pinned indicator disappeared with timestamp") }
        let original = MessageStatusLayout.size(dateSize: CGSize(width: 30, height: 13), leadingInset: 5, indicatorsWidth: 13, backgroundInsets: CGSize(width: 14, height: 4))
        if original != CGSize(width: 62, height: 17) { failures.append("Original status metrics changed") }
        if !failures.isEmpty {
            for failure in failures { print("FAIL: \(failure)") }
            exit(1)
        }
        print("Message status layout behavior checks passed")
    }
}
