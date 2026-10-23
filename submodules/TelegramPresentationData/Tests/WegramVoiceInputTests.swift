import XCTest
import UIKit
import Display

final class WegramVoiceInputTests: XCTestCase {
    func testPressReleaseCancelAndAccessibleActivationUseCurrentActionsOnce() throws {
        let view = WegramVoiceInputView()
        view.update(state: .idle, dark: false, chinese: true, fontSize: 17)
        var begins = 0
        var finishes: [Bool] = []
        view.begin = { begins += 1 }
        view.finish = { finishes.append($0) }
        view.handlePress(.began)
        view.update(state: .recording, dark: false, chinese: true, fontSize: 17)
        view.handlePress(.changed, cancelRequested: true)
        XCTAssertEqual(view.status.text, "松开取消")
        view.handlePress(.ended, cancelRequested: true)
        view.handlePress(.ended)
        XCTAssertEqual(begins, 1)
        XCTAssertEqual(finishes, [true])
        let microphone = try XCTUnwrap(view.subviews.compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "Wegram.Dictation.Record" })
        XCTAssertTrue(microphone.accessibilityActivate())
        XCTAssertEqual(finishes, [true, false])
        view.update(state: .idle, dark: true, chinese: false, fontSize: 17)
        view.begin = { begins += 10 }
        XCTAssertTrue(microphone.accessibilityActivate())
        XCTAssertEqual(begins, 11)
        view.isHidden = true
        view.handlePress(.began)
        _ = microphone.accessibilityActivate()
        XCTAssertEqual(begins, 11)
    }

    func testOnlyConfirmedNonemptyResultCanBeInsertedAndOldStatesCannotDispatch() {
        let view = WegramVoiceInputView()
        var accepted: [String] = []
        var cancels = 0
        var retries = 0
        view.accept = { accepted.append($0) }
        view.cancel = { cancels += 1 }
        view.retry = { retries += 1 }
        for state: WegramVoiceInputState in [.idle, .requesting, .recording, .recognizing, .failure("Denied"), .result(" \n")] {
            view.update(state: state, dark: false, chinese: true, fontSize: 17)
            view.acceptButton.sendActions(for: .touchUpInside)
        }
        XCTAssertTrue(accepted.isEmpty)
        view.update(state: .result("识别后的真实文字"), dark: false, chinese: true, fontSize: 17)
        XCTAssertEqual(view.transcript.text, "识别后的真实文字")
        XCTAssertFalse(view.transcript.isEditable)
        XCTAssertFalse(view.acceptButton.isHidden)
        view.acceptButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(accepted, ["识别后的真实文字"])
        view.retryButton.sendActions(for: .touchUpInside)
        view.cancelButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(retries, 1)
        XCTAssertEqual(cancels, 1)
        view.alpha = 0
        view.acceptButton.sendActions(for: .touchUpInside)
        view.retryButton.sendActions(for: .touchUpInside)
        view.cancelButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(accepted.count, 1)
        XCTAssertEqual(retries, 1)
        XCTAssertEqual(cancels, 1)
    }

    func testPermissionsFailureAndLargeTypeKeepVisibleControlsSeparate() throws {
        for width: CGFloat in [250, 402, 874] {
            for font: CGFloat in [17, 26] {
                let view = WegramVoiceInputView(frame: CGRect(x: 0, y: 0, width: width, height: 240))
                for state: WegramVoiceInputState in [.idle, .requesting, .recording, .recognizing, .result("A recognized sentence"), .failure("Permission denied. Try again.")] {
                    view.update(state: state, dark: false, chinese: false, fontSize: font)
                    view.layoutIfNeeded()
                    for button in [view.cancelButton, view.retryButton, view.acceptButton] where !button.isHidden {
                        XCTAssertTrue(view.bounds.contains(button.frame))
                        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
                    }
                    XCTAssertLessThanOrEqual(view.transcript.frame.maxY, view.cancelButton.frame.minY)
                    XCTAssertLessThanOrEqual(view.status.frame.maxY, view.cancelButton.frame.minY)
                    if !view.retryButton.isHidden && !view.acceptButton.isHidden {
                        XCTAssertLessThanOrEqual(view.retryButton.frame.maxX, view.acceptButton.frame.minX)
                    }
                }
            }
        }
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let view = WegramVoiceInputView(frame: CGRect(x: 0, y: 0, width: 402, height: 240))
            for (name, state) in [("idle", WegramVoiceInputState.idle), ("result", .result("确认文字后再输入，原聊天不会自动发送。"))] {
                view.update(state: state, dark: false, chinese: true, fontSize: 17)
                view.layoutIfNeeded()
                func scale(_ view: UIView) { view.layer.contentsScale = 3; view.contentScaleFactor = 3; view.subviews.forEach(scale) }
                scale(view)
                let format = UIGraphicsImageRendererFormat(); format.scale = 3
                let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("voice-input-\(name).png"))
            }
        }
    }
}
