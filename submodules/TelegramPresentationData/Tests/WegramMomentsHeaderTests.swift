import XCTest
import UIKit

final class WegramMomentsHeaderTests: XCTestCase {
    func testOwnStoriesWaitForRealPeerAndRejectStaleActions() {
        let view = WegramMomentsHeaderView(frame: .zero)
        var opens = 0
        view.openOwnStories = { opens += 1 }
        XCTAssertFalse(view.ownStories.isEnabled)
        XCTAssertTrue(view.ownStories.accessibilityTraits.contains(.notEnabled))
        view.ownStories.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 0)
        view.update(name: "组件测试用户", dark: false, fontSize: 17, chinese: true)
        XCTAssertTrue(view.ownStories.isEnabled)
        XCTAssertEqual(view.ownStories.accessibilityLabel, "我的动态")
        XCTAssertEqual(view.ownStories.accessibilityValue, "组件测试用户")
        XCTAssertFalse(view.name.isAccessibilityElement)
        XCTAssertTrue(view.avatarHost.accessibilityElementsHidden)
        view.ownStories.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 1)
        view.update(name: nil, dark: true, fontSize: 34, chinese: false)
        XCTAssertNil(view.name.text)
        XCTAssertNil(view.ownStories.accessibilityValue)
        XCTAssertEqual(view.ownStories.accessibilityLabel, "My Stories")
        view.ownStories.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 1)
    }
    func testCoverAvatarOverlapNameAndHitAreaAtLargeFontsAndRotations() throws {
        let view = WegramMomentsHeaderView(frame: .zero)
        for dark in [false, true] {
            for font: CGFloat in [17, 34] {
                view.update(name: "仅用于组件布局检查的长名称", dark: dark, fontSize: font, chinese: true)
                for width: CGFloat in [402, 320, 720, 402] {
                    view.frame = CGRect(x: 0, y: 0, width: width, height: view.measuredHeight(width: width))
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    XCTAssertEqual(view.cover.frame.width, width)
                    XCTAssertEqual(view.cover.frame.minY, 0)
                    XCTAssertEqual(view.ownStories.frame.size, CGSize(width: 64, height: 64))
                    XCTAssertEqual(view.ownStories.frame.maxX, width - 16)
                    XCTAssertEqual(view.ownStories.frame.maxY, view.cover.frame.maxY + 20)
                    XCTAssertEqual(view.ownStories.layer.cornerRadius, 6)
                    XCTAssertEqual(view.name.frame.maxY, view.cover.frame.maxY - 16)
                    XCTAssertLessThanOrEqual(view.name.frame.maxX, view.ownStories.frame.minX - 16)
                    XCTAssertGreaterThanOrEqual(view.name.frame.minY, 16)
                    XCTAssertLessThanOrEqual(view.name.sizeThatFits(CGSize(width: view.name.bounds.width, height: .greatestFiniteMagnitude)).height, view.name.bounds.height + 1)
                    XCTAssertEqual(view.avatarHost.frame, view.ownStories.bounds)
                    for y: CGFloat in [0.1, 63.9] {
                        XCTAssertTrue(view.ownStories.hitTest(CGPoint(x: 32, y: y), with: nil) === view.ownStories)
                    }
                    if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "moments-header-dark.png" : "moments-header-light.png"))
                    }
                }
            }
        }
    }
}
