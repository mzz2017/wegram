import XCTest
import UIKit

final class WegramCallFilterTests: XCTestCase {
    func testFilterTitleTracksAllMissedAndLanguageWithoutLosingAccessibleState() {
        let view = WegramCallFilterTitleView(frame: .zero)
        var opens = 0
        view.openFilter = { opens += 1 }
        view.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 0)
        view.update(title: "通话", selectedTitle: "全部", missed: false, color: .black, hint: "筛选来电")
        XCTAssertEqual(view.label.text, "通话")
        XCTAssertEqual(view.accessibilityLabel, "通话")
        XCTAssertEqual(view.accessibilityValue, "全部")
        XCTAssertEqual(view.accessibilityHint, "筛选来电")
        XCTAssertEqual(view.label.font.pointSize, 17)
        view.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 1)
        view.update(title: "通话", selectedTitle: "未接来电", missed: true, color: .white, hint: "筛选来电")
        XCTAssertEqual(view.label.text, "未接来电")
        XCTAssertEqual(view.accessibilityValue, "未接来电")
        XCTAssertEqual(view.label.textColor, .white)
        XCTAssertEqual(view.chevron.tintColor, .white)
        view.update(title: "Calls", selectedTitle: "All", missed: false, color: .black, hint: "Filter calls")
        XCTAssertEqual(view.label.text, "Calls")
        XCTAssertEqual(view.accessibilityValue, "All")
        view.isEnabled = false
        view.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 1)
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertTrue(view.accessibilityTraits.contains(.button))
        XCTAssertFalse(view.label.isAccessibilityElement)
        XCTAssertFalse(view.chevron.isAccessibilityElement)
    }
    func testNaturalSizingTruncationChevronAndFortyFourPointHitArea() throws {
        let view = WegramCallFilterTitleView(frame: .zero)
        for color in [UIColor.black, .white] {
            for title in ["通话", "未接来电", "Missed calls with a very long translated title"] {
                view.update(title: "Calls", selectedTitle: title, missed: true, color: color, hint: "Filter calls")
                view.frame.size = view.intrinsicContentSize
                view.layoutIfNeeded()
                XCTAssertGreaterThanOrEqual(view.bounds.width, 44)
                XCTAssertEqual(view.bounds.height, 44)
                XCTAssertGreaterThanOrEqual(view.sizeThatFits(.zero).width, 44)
                XCTAssertGreaterThanOrEqual(view.label.frame.width, view.label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44)).width)
                for width: CGFloat in [44, 80, 180, 80] {
                    view.frame.size = view.sizeThatFits(CGSize(width: width, height: 44))
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    XCTAssertLessThanOrEqual(view.bounds.width, width)
                    XCTAssertLessThanOrEqual(view.label.frame.maxX + 4, view.chevron.frame.minX + 0.1)
                    XCTAssertLessThanOrEqual(view.chevron.frame.maxX, view.bounds.width)
                    for y: CGFloat in [0.1, 43.9] {
                        XCTAssertTrue(view.hitTest(CGPoint(x: view.bounds.midX, y: y), with: nil) === view)
                    }
                    XCTAssertEqual(view.accessibilityValue, title)
                }
                if title == "未接来电", let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    view.frame.size = view.intrinsicContentSize
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    let image = UIGraphicsImageRenderer(size: view.bounds.size).image { context in
                        (color == .white ? UIColor.black : .white).setFill()
                        context.fill(view.bounds)
                        view.layer.render(in: context.cgContext)
                    }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(color == .white ? "calls-filter-dark.png" : "calls-filter-light.png"))
                }
            }
        }
    }
}
