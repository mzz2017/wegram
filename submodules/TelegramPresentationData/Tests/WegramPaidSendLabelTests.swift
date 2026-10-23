import XCTest
import UIKit
import Display
import AsyncDisplayKit
import AnimatedCountLabelNode

final class WegramPaidSendLabelTests: XCTestCase {
    func testFullAmountKeepsEveryDigitBeforeScalingIntoTheButtonAndRestoresScale() throws {
        let node = ImmediateAnimatedCountLabelNode()
        let font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        for amount in [String(Int64.max), "1", "1000000"] {
            let digits = amount.compactMap { Int(String($0)) }
            node.segments = [.text(0, NSAttributedString(string: "★ ", attributes: [.font: font, .foregroundColor: UIColor.white]))] + digits.map { .number($0, NSAttributedString(string: String($0), attributes: [.font: font, .foregroundColor: UIColor.white])) }
            for maximum: CGFloat in [58, 144, 320] {
                let size = layoutWegramPaidSendLabel(node, maximumWidth: maximum, height: 40, transition: .immediate)
                let glyphs = try XCTUnwrap(node.subnodes)
                XCTAssertEqual(glyphs.count, digits.count + 1)
                XCTAssertTrue(glyphs.allSatisfy { $0.bounds.width > 0 }, "Later amount digits were clipped during measurement")
                if amount.count == 19 { XCTAssertGreaterThan(node.bounds.width, 100) }
                let scale = node.transform.m11
                XCTAssertGreaterThan(scale, 0)
                XCTAssertLessThanOrEqual(scale, 1)
                XCTAssertLessThanOrEqual(node.bounds.width * scale, size.width - 16 + 0.01)
                XCTAssertEqual(node.position, CGPoint(x: size.width / 2, y: 20))
                XCTAssertGreaterThanOrEqual(size.width, 58)
                XCTAssertLessThanOrEqual(size.width, maximum)
                if amount == "1" { XCTAssertEqual(scale, 1) }
                if maximum == 144, amount.count == 19 || amount == "1", let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let root = ASDisplayNode()
                    root.frame = CGRect(origin: .zero, size: size)
                    root.backgroundColor = UIColor(red: 7.0 / 255, green: 193.0 / 255, blue: 96.0 / 255, alpha: 1)
                    root.addSubnode(node)
                    _ = root.view
                    root.recursivelyEnsureDisplaySynchronously(true)
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 3
                    let image = UIGraphicsImageRenderer(size: size, format: format).image { root.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(amount == "1" ? "paid-send-small.png" : "paid-send-long.png"))
                    node.removeFromSupernode()
                }
            }
        }
    }
}
