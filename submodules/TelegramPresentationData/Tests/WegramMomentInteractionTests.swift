import XCTest
import UIKit
import Display

final class WegramMomentInteractionTests: XCTestCase {
    private let target = WegramStoryInteractionTarget(peerId: 10, storyId: 20)
    func testInteractionWaitsForVisibleReadyViewerAndConsumesOnlyOnce() {
        var request = WegramStoryInteractionRequest(target: self.target, action: .like)
        XCTAssertNil(request.take(current: self.target, expiration: 200, expired: false, now: 100, visible: false, ready: true, interacting: false))
        XCTAssertEqual(request.action, .like)
        XCTAssertNil(request.take(current: self.target, expiration: 200, expired: false, now: 100, visible: true, ready: false, interacting: false))
        XCTAssertEqual(request.action, .like)
        XCTAssertEqual(request.take(current: self.target, expiration: 200, expired: false, now: 100, visible: true, ready: true, interacting: false), .like)
        XCTAssertNil(request.take(current: self.target, expiration: 200, expired: false, now: 100, visible: true, ready: true, interacting: false))
    }
    func testDifferentStoryExpiryAndNavigationCancelRatherThanExecuteLater() {
        for current in [WegramStoryInteractionTarget(peerId: 11, storyId: 20), WegramStoryInteractionTarget(peerId: 10, storyId: 21)] {
            var request = WegramStoryInteractionRequest(target: self.target, action: .unlike)
            XCTAssertNil(request.take(current: current, expiration: 200, expired: false, now: 100, visible: true, ready: true, interacting: false))
            XCTAssertNil(request.take(current: self.target, expiration: 200, expired: false, now: 100, visible: true, ready: true, interacting: false))
        }
        for expired in [false, true] {
            var request = WegramStoryInteractionRequest(target: self.target, action: .reply)
            XCTAssertNil(request.take(current: self.target, expiration: 200, expired: expired, now: expired ? 100 : 200, visible: true, ready: true, interacting: false))
            XCTAssertNil(request.action)
        }
        var request = WegramStoryInteractionRequest(target: self.target, action: .like)
        XCTAssertNil(request.take(current: self.target, expiration: 200, expired: false, now: 100, visible: true, ready: false, interacting: true))
        XCTAssertNil(request.action)
        request = WegramStoryInteractionRequest(target: self.target, action: .reply)
        request.cancel()
        XCTAssertNil(request.take(current: self.target, expiration: 200, expired: false, now: 100, visible: true, ready: true, interacting: false))
    }
    func testDelayedStealthConfirmationCannotTargetTheNewStoryOrExpiredContent() {
        XCTAssertTrue(self.target.matches(self.target, expiration: 200, expired: false, now: 199))
        XCTAssertFalse(self.target.matches(WegramStoryInteractionTarget(peerId: 10, storyId: 21), expiration: 200, expired: false, now: 199))
        XCTAssertFalse(self.target.matches(WegramStoryInteractionTarget(peerId: 11, storyId: 20), expiration: 200, expired: false, now: 199))
        XCTAssertFalse(self.target.matches(self.target, expiration: 200, expired: false, now: 200))
        XCTAssertFalse(self.target.matches(self.target, expiration: 200, expired: true, now: 100))
    }
    func testMoreButtonAndVoiceOverIntentDisappearOnReuseAndLiveItems() throws {
        let cell = WegramMomentCell(style: .default, reuseIdentifier: nil)
        var content = WegramMomentContent(peerId: 1, storyId: 2, timestamp: 10, expiration: 100, expired: false, protected: false, caption: "测试正文", status: "", aspectRatio: 1, video: false)
        var opens = 0
        cell.moreAction = { opens += 1 }
        cell.load(content, name: "测试用户", date: "测试日期：1分钟前", dark: false, font: 34, actionsAvailable: true, moreTitle: "更多互动")
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: cell.measuredHeight(width: 320))
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.more.bounds.size, CGSize(width: 44, height: 44))
        XCTAssertGreaterThanOrEqual(cell.more.frame.minX, cell.date.frame.maxX + 8)
        XCTAssertGreaterThan(cell.more.frame.minY, cell.mediaHost.frame.maxY)
        XCTAssertLessThanOrEqual(cell.more.frame.maxY, cell.bounds.height)
        XCTAssertFalse(cell.more.isAccessibilityElement)
        XCTAssertEqual(cell.accessibilityCustomActions?.first?.name, "更多互动")
        cell.more.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 1)
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let image = UIGraphicsImageRenderer(size: cell.bounds.size).image { cell.layer.render(in: $0.cgContext) }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("moments-more-large.png"))
        }
        cell.prepareForReuse()
        cell.more.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 1)
        XCTAssertTrue(cell.more.isHidden)
        XCTAssertNil(cell.accessibilityCustomActions)
        content.live = true
        cell.load(content, name: "直播", date: "", dark: true, font: 17, actionsAvailable: true)
        XCTAssertTrue(cell.more.isHidden)
    }
    func testCompactFooterKeepsImageTapsOutsideTheInteractionButton() {
        let cell = WegramMomentCell(style: .default, reuseIdentifier: nil)
        let content = WegramMomentContent(peerId: 1, storyId: 2, timestamp: 10, expiration: 100, expired: false, protected: false, caption: "正文", status: "", aspectRatio: 1, video: false)
        for width: CGFloat in [320, 402, 720] {
            cell.load(content, name: "作者", date: "1分钟前", dark: false, font: 17, actionsAvailable: true)
            cell.frame = CGRect(x: 0, y: 0, width: width, height: cell.measuredHeight(width: width))
            cell.layoutIfNeeded()
            XCTAssertEqual(cell.date.frame.minY, cell.mediaHost.frame.maxY + 12)
            XCTAssertEqual(cell.more.frame.midY, cell.date.frame.midY)
            XCTAssertEqual(cell.more.bounds.size, CGSize(width: 44, height: 44))
            XCTAssertLessThanOrEqual(cell.more.frame.maxY, cell.bounds.height)
            let edge = CGPoint(x: min(cell.mediaHost.frame.maxX - 1, cell.more.frame.midX), y: cell.mediaHost.frame.maxY - 1)
            XCTAssertFalse(cell.hitTest(edge, with: nil) === cell.more, "The enlarged target must not steal a media tap")
            XCTAssertTrue(cell.hitTest(cell.more.center, with: nil) === cell.more)
        }
    }

    func testPopoverActionsEscapeAndLargeFontLayout() throws {
        let view = WegramMomentActionsOverlay(frame: .zero)
        var actions: [WegramStoryInteraction] = []
        var closes = 0
        view.select = { actions.append($0) }
        view.close = { closes += 1 }
        for chinese in [false, true] {
            for font: CGFloat in [17, 34] {
                for width: CGFloat in [402, 320, 720, 402] {
                    view.frame = CGRect(x: 0, y: 0, width: width, height: 700)
                    view.load(anchor: CGRect(x: width - 60, y: 620, width: 44, height: 44), reacted: true, canReply: true, chinese: chinese, font: font)
                    view.layoutIfNeeded()
                    for button in [view.reaction, view.reply] {
                        button.layoutIfNeeded()
                        XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                        XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
                        XCTAssertLessThanOrEqual(button.imageView!.frame.maxX + 8, button.titleLabel!.frame.minX)
                        XCTAssertGreaterThanOrEqual(button.imageView!.frame.minX, 12)
                        XCTAssertLessThanOrEqual(button.titleLabel!.sizeThatFits(CGSize(width: button.titleLabel!.bounds.width, height: .greatestFiniteMagnitude)).height, button.titleLabel!.bounds.height + 1)
                    }
                    if font == 17 && chinese { XCTAssertEqual(view.bar.bounds.height, 44, "Ordinary-size reaction and reply labels should fit on one line") }
                    XCTAssertGreaterThanOrEqual(view.bar.frame.minX, 16)
                    XCTAssertLessThanOrEqual(view.bar.frame.maxX, width - 16)
                    XCTAssertLessThanOrEqual(view.bar.frame.maxY, 692)
                    XCTAssertLessThanOrEqual(view.reaction.frame.maxX, view.reply.frame.minX)
                    if width == 402 && font == 17 && chinese, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("moments-actions.png"))
                    }
                }
            }
        }
        view.reaction.sendActions(for: .touchUpInside)
        view.reply.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.unlike, .reply])
        view.load(anchor: .zero, reacted: false, canReply: false, chinese: true, font: 17)
        view.reaction.sendActions(for: .touchUpInside)
        view.reply.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.unlike, .reply, .like])
        XCTAssertTrue(view.accessibilityViewIsModal)
        XCTAssertTrue(view.accessibilityPerformEscape())
        XCTAssertEqual(closes, 1)
        view.sendActions(for: .touchUpInside)
        XCTAssertEqual(closes, 2)
    }
}
