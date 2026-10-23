import XCTest
import UIKit

final class WegramCallDetailsViewTests: XCTestCase {
    func testProfileActionsAndOriginalRecordsHostRemainSeparateAndScrollable() throws {
        for dark in [false, true] {
            for font: CGFloat in [17, 34] {
                let view = WegramCallDetailsView()
                view.update(name: "陈晨 A long contact name", username: "long_username_for_layout", messageTitle: "发消息 Send Message", callTitle: "回拨 Call Back", dark: dark, fontSize: font)
                for size in [CGSize(width: 320, height: 480), CGSize(width: 402, height: 786), CGSize(width: 720, height: 300)] {
                    view.frame = CGRect(origin: .zero, size: size)
                    view.updateLayout(recordsHeight: 600, bottomInset: 34)
                    XCTAssertEqual(view.avatarHost.frame.size, CGSize(width: 64, height: 64))
                    XCTAssertLessThanOrEqual(view.avatarHost.frame.maxX + 16, view.name.frame.minX)
                    XCTAssertLessThanOrEqual(view.name.frame.maxX, size.width - 16)
                    XCTAssertLessThanOrEqual(view.username.frame.maxY + 16, view.profile.frame.maxY)
                    XCTAssertGreaterThanOrEqual(view.message.frame.minY, view.profile.frame.maxY)
                    XCTAssertGreaterThanOrEqual(view.call.frame.minY, view.message.frame.maxY)
                    XCTAssertGreaterThanOrEqual(view.recordsHost.frame.minY, view.call.frame.maxY + 8)
                    XCTAssertEqual(view.recordsHost.frame.height, 600)
                    XCTAssertEqual(view.scroll.contentSize.height, view.recordsHost.frame.maxY + 50)
                    for button in [view.message, view.call] {
                        button.layoutIfNeeded()
                        XCTAssertGreaterThanOrEqual(button.frame.height, 56)
                        let label = try XCTUnwrap(button.titleLabel)
                        XCTAssertLessThanOrEqual(label.frame.maxY, button.bounds.height)
                        XCTAssertEqual(label.numberOfLines, 0)
                    }
                    view.scroll.scrollRectToVisible(CGRect(x: 0, y: view.recordsHost.frame.maxY - 30, width: size.width, height: 30), animated: false)
                    XCTAssertLessThanOrEqual(view.recordsHost.frame.maxY, view.scroll.contentOffset.y + view.scroll.bounds.height + 1)
                }
            }
        }
    }

    func testActionsPreserveTheirMeaningAndPeerUpdatesClearMissingUsername() {
        let view = WegramCallDetailsView()
        var actions: [WegramCallDetailsView.Action] = []
        view.open = { actions.append($0) }
        view.update(name: "Local test", username: "fixture", messageTitle: "Message", callTitle: "Call Back", dark: false, fontSize: 17)
        view.profile.sendActions(for: .touchUpInside)
        view.message.sendActions(for: .touchUpInside)
        view.call.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.profile, .message, .call])
        XCTAssertEqual(view.profile.accessibilityLabel, "Local test, @fixture")
        view.update(name: "Updated", username: nil, messageTitle: "发消息", callTitle: "回拨", dark: true, fontSize: 17)
        XCTAssertNil(view.username.text)
        XCTAssertEqual(view.profile.accessibilityLabel, "Updated")
        XCTAssertEqual(view.message.accessibilityLabel, "发消息")
        XCTAssertEqual(view.call.accessibilityLabel, "回拨")
    }

    func testActualProfileAndActionRenderingInBothThemes() throws {
        for dark in [false, true] {
            let view = WegramCallDetailsView()
            view.frame = CGRect(x: 0, y: 0, width: 402, height: 786)
            view.update(name: "陈晨", username: "local_fixture", messageTitle: "发消息", callTitle: "回拨", dark: dark, fontSize: 17)
            view.updateLayout(recordsHeight: 160, bottomInset: 34)
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("call-details-view-\(dark ? "dark" : "light").png"))
            }
        }
    }
}
