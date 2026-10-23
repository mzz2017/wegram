import XCTest
import UIKit
import AccountContext
import TelegramCore

final class WegramMessageSelectionTests: XCTestCase {
    func testMoreActionsRequireCurrentSelectionAndOriginalCapabilities() {
        let actions = ChatAvailableMessageActions(options: [.forward, .externalShare, .report], banAuthor: nil, banAuthors: [], disableDelete: false, isCopyProtected: false, setTag: true, editTags: [])
        XCTAssertEqual(wegramSelectionExtras(nil, hasSelection: true, isSecret: false), [])
        XCTAssertEqual(wegramSelectionExtras(actions, hasSelection: false, isSecret: false), [])
        XCTAssertEqual(wegramSelectionExtras(actions, hasSelection: true, isSecret: false), [.share, .report, .tag])
        XCTAssertEqual(wegramSelectionExtras(actions, hasSelection: true, isSecret: true), [.report, .tag])
        var restricted = actions
        restricted.options = [.forward]
        restricted.setTag = false
        XCTAssertEqual(wegramSelectionExtras(restricted, hasSelection: true, isSecret: false), [])
        restricted.options = [.externalShare]
        XCTAssertEqual(wegramSelectionExtras(restricted, hasSelection: true, isSecret: false), [])
    }

    func testFourRealControlsKeepTheirOrderTargetsAndAccessibilityAcrossSizes() throws {
        let bar = WegramMessageSelectionBar(frame: .zero)
        let titles = ["转发", "收藏", "删除", "更多"]
        for width: CGFloat in [320, 402, 750] {
            for dark in [false, true] {
                bar.frame = CGRect(x: 0, y: 0, width: width, height: 56)
                bar.backgroundColor = dark ? UIColor(white: 0.125, alpha: 1) : UIColor(white: 0.969, alpha: 1)
                bar.update(isDark: dark, titles: titles, enabled: [true, true, true, true])
                bar.layoutIfNeeded()
                var last: CGFloat = 0
                for (index, button) in bar.buttons.enumerated() {
                    XCTAssertEqual(button.accessibilityLabel, titles[index])
                    XCTAssertEqual(button.bounds.size, CGSize(width: 44, height: 44))
                    XCTAssertEqual(button.center.y, 28)
                    XCTAssertGreaterThanOrEqual(button.frame.minX, last)
                    XCTAssertLessThanOrEqual(button.frame.maxX, width)
                    XCTAssertNotNil(button.image(for: .normal))
                    XCTAssertTrue(button.isAccessibilityElement)
                    XCTAssertTrue(bar.hitTest(button.center, with: nil) === button)
                    last = button.frame.maxX
                }
                if width == 402, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let renderer = UIGraphicsImageRenderer(size: bar.bounds.size)
                    let image = renderer.image { bar.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "selection-bar-dark.png" : "selection-bar-light.png"))
                }
            }
        }
    }

    func testDisabledAndHiddenControlsCannotDispatchOldActions() {
        let bar = WegramMessageSelectionBar(frame: CGRect(x: 0, y: 0, width: 402, height: 56))
        let titles = ["Forward", "Save", "Delete", "More"]
        var selected: [WegramMessageSelectionBar.Action] = []
        bar.selected = { selected.append($0) }
        bar.update(isDark: false, titles: titles, enabled: [true, false, false, true])
        for button in bar.buttons { button.sendActions(for: .touchUpInside) }
        XCTAssertEqual(selected, [.forward, .more])
        XCTAssertTrue(bar.buttons[1].accessibilityTraits.contains(.notEnabled))
        bar.update(isDark: true, titles: titles, enabled: [false, false, false, false])
        for button in bar.buttons { button.sendActions(for: .touchUpInside) }
        XCTAssertEqual(selected, [.forward, .more])
        bar.update(isDark: true, titles: titles, enabled: [true, true, true, true])
        bar.isHidden = true
        for button in bar.buttons { button.sendActions(for: .touchUpInside) }
        XCTAssertEqual(selected, [.forward, .more])
    }
}
