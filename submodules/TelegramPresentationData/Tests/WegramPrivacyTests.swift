import XCTest
import UIKit

final class WegramPrivacyTests: XCTestCase {
    func testLoadingDoesNotPretendEveryoneOrAllowEditingUnknownPrivacy() {
        let view = WegramPrivacyContentView()
        var opened: [WegramPrivacyDestination] = []
        view.open = { opened.append($0) }
        for destination in WegramPrivacyDestination.allCases {
            let row = view.rows[destination.rawValue]
            row.sendActions(for: .touchUpInside)
            if destination.needsSettings {
                XCTAssertFalse(row.isEnabled)
                XCTAssertTrue(row.accessibilityTraits.contains(.notEnabled))
                XCTAssertEqual(row.accessibilityValue, "正在读取")
            }
        }
        XCTAssertEqual(opened, [.blocked, .system])
        view.load(values: [.phone: "所有人", .presence: "联系人", .groups: "联系人及例外", .forwards: "没有人"])
        opened.removeAll()
        for row in view.rows { row.sendActions(for: .touchUpInside) }
        XCTAssertEqual(opened, WegramPrivacyDestination.allCases)
        XCTAssertEqual(view.rows[0].accessibilityValue, "所有人")
        XCTAssertFalse(view.rows[0].accessibilityTraits.contains(.notEnabled))
        view.load(values: [.phone: "没有人"])
        XCTAssertFalse(view.rows[WegramPrivacyDestination.presence.rawValue].isEnabled)
        view.update(dark: true, fontSize: 17, chinese: false)
        XCTAssertEqual(view.rows[0].accessibilityLabel, "Phone Number")
        XCTAssertEqual(view.rows[WegramPrivacyDestination.presence.rawValue].accessibilityValue, "Loading")
    }

    func testReferenceRowsKeepFullExceptionValueAndScaleWithoutOverlap() throws {
        for width: CGFloat in [320, 402, 720] {
            for font: CGFloat in [17, 34] {
                let view = WegramPrivacyContentView()
                view.frame = CGRect(x: 0, y: 0, width: width, height: 280)
                view.update(dark: false, fontSize: font, chinese: true)
                let exception = "联系人及20个例外"
                view.load(values: [.phone: "所有人", .groups: exception, .presence: "联系人", .forwards: "没有人"])
                view.layoutIfNeeded()
                for row in view.rows {
                    row.layoutIfNeeded()
                    XCTAssertGreaterThanOrEqual(row.bounds.height, 56)
                    XCTAssertEqual(row.label.frame.minX, 16)
                    XCTAssertLessThan(row.label.frame.maxX, row.arrow.frame.minX)
                    if !(row.valueLabel.text ?? "").isEmpty { XCTAssertLessThan(row.label.frame.maxX, row.valueLabel.frame.minX) }
                    XCTAssertGreaterThanOrEqual(row.label.bounds.height + 0.5, row.label.sizeThatFits(CGSize(width: row.label.bounds.width, height: .greatestFiniteMagnitude)).height)
                    XCTAssertGreaterThanOrEqual(row.valueLabel.bounds.height + 0.5, row.valueLabel.sizeThatFits(CGSize(width: row.valueLabel.bounds.width, height: .greatestFiniteMagnitude)).height)
                }
                XCTAssertEqual(view.rows[WegramPrivacyDestination.groups.rawValue].accessibilityValue, exception)
                XCTAssertGreaterThan(view.contentSize.height, view.bounds.height)
                if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    view.frame.size.height = 700
                    view.layoutIfNeeded()
                    let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("privacy-component.png"))
                }
            }
        }
    }
}
