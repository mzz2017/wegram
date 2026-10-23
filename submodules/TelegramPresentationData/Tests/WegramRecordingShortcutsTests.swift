import XCTest
import TelegramCore
import ChatInterfaceState
import AudioWaveform

final class WegramRecordingShortcutsTests: XCTestCase {
    func testPreviewActionsFollowTheExactDraftAndCurrentViewOnceEligibility() {
        let draft = ChatInterfaceMediaDraftState.audio(.init(resource: LocalFileMediaResource(fileId: 1), fileSize: 3, duration: 10, waveform: AudioWaveform(samples: Data([0, 1, 2]), peak: 2), trimRange: nil, resumeData: Data([1])))
        XCTAssertEqual(wegramRecordingShortcuts(nil, canViewOnce: true, viewOnce: true), [])
        XCTAssertEqual(wegramRecordingShortcuts(draft, canViewOnce: false, viewOnce: true), [.recordingResume(draft), .recordingDelete(draft)])
        let old = wegramRecordingShortcuts(draft, canViewOnce: true, viewOnce: false)
        XCTAssertEqual(old, [.recordingResume(draft), .recordingViewOnce(draft, false), .recordingDelete(draft)])
        let selected = wegramRecordingShortcuts(draft, canViewOnce: true, viewOnce: true)
        XCTAssertFalse(selected.contains(.recordingViewOnce(draft, false)))
        XCTAssertTrue(selected.contains(.recordingViewOnce(draft, true)))
        let replacement = ChatInterfaceMediaDraftState.audio(.init(resource: LocalFileMediaResource(fileId: 2), fileSize: 3, duration: 10, waveform: AudioWaveform(samples: Data([0, 1, 2]), peak: 2), trimRange: nil, resumeData: nil))
        let replaced = wegramRecordingShortcuts(replacement, canViewOnce: true, viewOnce: false)
        XCTAssertTrue(old.allSatisfy { !replaced.contains($0) }, "An old menu must not operate on a replacement recording")
        let video = ChatInterfaceMediaDraftState.video(.init(duration: 5, frames: [], framesUpdateTimestamp: 1, trimRange: nil))
        XCTAssertEqual(wegramRecordingShortcuts(video, canViewOnce: true, viewOnce: false), [.recordingDelete(video)])
    }
}
