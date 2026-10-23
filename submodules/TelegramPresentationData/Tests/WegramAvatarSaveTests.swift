import XCTest
import UIKit
import SwiftSignalKit

final class WegramAvatarSaveTests: XCTestCase {
    func testPreparedImageUsesLosslessPNGAndRechecksTheCapturedDeadlineAfterAWait() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            UIColor.black.setFill(); context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        let deadline = Date(timeIntervalSince1970: 100)
        let data = try XCTUnwrap(cameraRollImageData(image, validUntil: deadline, now: Date(timeIntervalSince1970: 99)))
        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(decoded.size, image.size)
        XCTAssertEqual(decoded.cgImage?.width, 32)
        XCTAssertEqual(decoded.cgImage?.height, 32)
        XCTAssertNil(cameraRollImageData(image, validUntil: deadline, now: deadline), "An expired export must fail even if it was generated while valid")
        XCTAssertNil(cameraRollImageData(image, validUntil: deadline, now: Date(timeIntervalSince1970: 1000)), "A refreshed live token cannot extend this captured image's deadline")
        XCTAssertNotNil(cameraRollImageData(image, validUntil: nil, now: Date(timeIntervalSince1970: 1000)))
    }

    func testDownloadedMediaDoesNotAnnounceSavedBeforeThePhotoLibraryCallback() {
        var progress: Subscriber<Float, NoError>?
        var result: ((CameraRollSaveResult) -> Void)?
        var values: [CameraRollSaveResult] = []
        var completed = false
        let signal = cameraRollSaveResultSignal { callback in
            result = callback
            return Signal { subscriber in
                progress = subscriber
                return EmptyDisposable
            }
        }
        let disposable = signal.start(next: { values.append($0) }, completed: { completed = true })
        progress?.putNext(0)
        progress?.putNext(1)
        XCTAssertTrue(values.isEmpty)
        XCTAssertFalse(completed)
        result?(.saved)
        XCTAssertEqual(values, [.saved])
        XCTAssertTrue(completed)
        result?(.failed)
        progress?.putCompletion()
        XCTAssertEqual(values, [.saved], "A completed save cannot produce a second outcome")
        disposable.dispose()
    }

    func testDeniedOrFailedPhotoWriteCannotBeConvertedFromFullDownloadProgressToSuccess() {
        for outcome in [CameraRollSaveResult.accessDenied, .failed] {
            var values: [CameraRollSaveResult] = []
            var completed = false
            let signal = cameraRollSaveResultSignal { callback in
                return Signal { subscriber in
                    subscriber.putNext(1)
                    callback(outcome)
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
            }
            let disposable = signal.start(next: { values.append($0) }, completed: { completed = true })
            XCTAssertEqual(values, [outcome])
            XCTAssertTrue(completed)
            disposable.dispose()
        }
    }

    func testCancelDisposesFetchAndIgnoresAPhotoWriteThatFinishesLater() {
        var progress: Subscriber<Float, NoError>?
        var result: ((CameraRollSaveResult) -> Void)?
        var cancelled = false
        var values: [CameraRollSaveResult] = []
        var completed = false
        let signal = cameraRollSaveResultSignal { callback in
            result = callback
            return Signal { subscriber in
                progress = subscriber
                return ActionDisposable { cancelled = true }
            }
        }
        let disposable = signal.start(next: { values.append($0) }, completed: { completed = true })
        disposable.dispose()
        XCTAssertTrue(cancelled)
        result?(.saved)
        progress?.putCompletion()
        XCTAssertTrue(values.isEmpty)
        XCTAssertFalse(completed)
    }

    func testMissingMediaCompletionDoesNotInventASuccessfulSave() {
        var values: [CameraRollSaveResult] = []
        var completed = false
        let disposable = cameraRollSaveResultSignal { _ in .complete() }.start(next: { values.append($0) }, completed: { completed = true })
        XCTAssertTrue(values.isEmpty)
        XCTAssertTrue(completed)
        disposable.dispose()
    }
}
