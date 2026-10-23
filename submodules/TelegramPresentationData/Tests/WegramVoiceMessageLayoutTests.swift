import XCTest
import UIKit
import Display
import ChatMessageItemCommon

final class WegramVoiceMessageLayoutTests: XCTestCase {
    func testSecondsAndMirroredControlsFitShortLongAndLargeTypeVoiceMessages() {
        XCTAssertEqual(WegramVoiceMessageLayout.duration(-5), "0″")
        XCTAssertEqual(WegramVoiceMessageLayout.duration(1), "1″")
        XCTAssertEqual(WegramVoiceMessageLayout.duration(3600), "3600″")
        for available: CGFloat in [0, 30, 52, 100, 230, 600] {
            for seconds: Int32 in [1, 30, 60, 3600] {
                for fontSize: CGFloat in [14, 28, 56] {
                    let (label, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: WegramVoiceMessageLayout.duration(seconds), font: .systemFont(ofSize: fontSize), textColor: .black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, available - 36), height: .greatestFiniteMagnitude), alignment: .natural))
                    let width = WegramVoiceMessageLayout.contentWidth(duration: seconds, labelWidth: label.size.width, availableWidth: available, showsProgress: false)
                    let incoming = WegramVoiceMessageLayout(width: width, outgoing: false, durationSize: label.size)
                    let outgoing = WegramVoiceMessageLayout(width: width, outgoing: true, durationSize: label.size)
                    XCTAssertLessThanOrEqual(width, available)
                    XCTAssertGreaterThanOrEqual(incoming.height + 8, 40)
                    XCTAssertGreaterThanOrEqual(incoming.height, label.size.height)
                    for layout in [incoming, outgoing] {
                        for frame in [layout.controlFrame, layout.durationFrame] {
                            XCTAssertGreaterThanOrEqual(frame.minX, 0)
                            XCTAssertLessThanOrEqual(frame.maxX, width)
                            XCTAssertGreaterThanOrEqual(frame.minY, 0)
                            XCTAssertLessThanOrEqual(frame.maxY, layout.height)
                        }
                        if !layout.durationFrame.isEmpty { XCTAssertFalse(layout.controlFrame.intersects(layout.durationFrame)) }
                    }
                    XCTAssertEqual(incoming.controlFrame.minX, width - outgoing.controlFrame.maxX)
                    if incoming.durationFrame.width > 0 { XCTAssertEqual(incoming.durationFrame.minX, width - outgoing.durationFrame.maxX) }
                }
            }
        }
        XCTAssertEqual(WegramVoiceMessageLayout.contentWidth(duration: 1, labelWidth: 16, availableWidth: 300, showsProgress: false), 52)
        XCTAssertEqual(WegramVoiceMessageLayout.contentWidth(duration: 1, labelWidth: 16, availableWidth: 300, showsProgress: true), 160)
        XCTAssertEqual(WegramVoiceMessageLayout.contentWidth(duration: 3600, labelWidth: 40, availableWidth: 100, showsProgress: true), 100)
    }

    func testVoiceGlyphPhasesAreCachedAndHaveDistinctVisibleWaves() throws {
        var counts: [Int] = []
        for phase in 1 ... 3 {
            let image = WegramVoiceMessageLayout.icon(color: .black, outgoing: false, phase: phase)
            XCTAssertTrue(image === WegramVoiceMessageLayout.icon(color: .black, outgoing: false, phase: phase))
            XCTAssertEqual(image.size, CGSize(width: 24, height: 24))
            let cgImage = try XCTUnwrap(image.cgImage)
            let context = try XCTUnwrap(CGContext(data: nil, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: cgImage.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
            counts.append((0 ..< cgImage.width * cgImage.height).filter { bytes[$0 * 4 + 3] > 128 }.count)
        }
        XCTAssertGreaterThan(counts[0], 0)
        XCTAssertGreaterThan(counts[1], counts[0])
        XCTAssertGreaterThan(counts[2], counts[1])
        XCTAssertFalse(WegramVoiceMessageLayout.icon(color: .black, outgoing: true) === WegramVoiceMessageLayout.icon(color: .black, outgoing: false))
        XCTAssertEqual(WegramVoiceMessageLayout.unreadIcon.size, CGSize(width: 6, height: 6))
    }

    func testExpandedWaveformKeepsLargeDurationAboveTranscriptionAndStatus() {
        for width: CGFloat in [80, 160, 300] {
            for fontSize: CGFloat in [11, 22, 36, 56] {
                let (label, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "0:01 / 1:00", font: .systemFont(ofSize: fontSize), textColor: .black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 56, height: .greatestFiniteMagnitude), alignment: .natural))
                let layout = WegramVoiceMessageLayout(width: width, outgoing: false, durationSize: label.size, showsProgress: true)
                XCTAssertGreaterThanOrEqual(layout.height, layout.durationFrame.maxY)
                XCTAssertGreaterThanOrEqual(layout.height + 1, layout.durationFrame.maxY + 1, "Transcription starts after the full duration row")
                XCTAssertLessThanOrEqual(layout.durationFrame.maxX, width)
                XCTAssertGreaterThanOrEqual(layout.controlFrame.minY + 4, 0)
                XCTAssertLessThanOrEqual(layout.controlFrame.maxY, layout.height)
                XCTAssertGreaterThanOrEqual(layout.durationFrame.minY, 18 + 4, "Duration and the original waveform have separate rows")
                if fontSize == 56 { XCTAssertGreaterThan(layout.height, 44) }
            }
        }
    }

    func testVoiceAccessibilityActionsExposeCurrentTitlesAndPreserveCallbackResults() throws {
        for chinese in [true, false] {
            for expanded in [true, false] {
                var transcriptions = 0
                var progressChanges = 0
                var current = true
                let actions = WegramVoiceMessageLayout.accessibilityActions(chinese: chinese, progressExpanded: expanded, transcriptionExpanded: expanded, transcribe: {
                    guard current else { return false }
                    transcriptions += 1
                    return true
                }, toggleProgress: {
                    guard current else { return false }
                    progressChanges += 1
                    return true
                })
                XCTAssertEqual(actions.map(\.name), chinese ? (expanded ? ["收起文字", "收起进度"] : ["转文字", "播放进度"]) : (expanded ? ["Hide Transcript", "Hide Progress"] : ["Transcribe", "Playback Progress"]))
                let transcription = try XCTUnwrap(actions.first)
                let progress = try XCTUnwrap(actions.last)
                XCTAssertTrue(transcription.actionHandler?(transcription) == true)
                XCTAssertEqual(transcriptions, 1)
                XCTAssertEqual(progressChanges, 0)
                XCTAssertTrue(progress.actionHandler?(progress) == true)
                XCTAssertEqual(transcriptions, 1)
                XCTAssertEqual(progressChanges, 1)
                current = false
                XCTAssertFalse(transcription.actionHandler?(transcription) ?? true)
                XCTAssertFalse(progress.actionHandler?(progress) ?? true)
                XCTAssertEqual(transcriptions, 1)
                XCTAssertEqual(progressChanges, 1)
            }
        }
    }

    func testVoiceAccessibilityOmitsUnavailableCapabilities() {
        var calls = 0
        let unavailable = WegramVoiceMessageLayout.accessibilityActions(chinese: true, progressExpanded: nil, transcriptionExpanded: false, transcribe: { calls += 1; return true }, toggleProgress: { calls += 1; return true })
        XCTAssertTrue(unavailable.isEmpty)
        XCTAssertEqual(calls, 0)
        let progressOnly = WegramVoiceMessageLayout.accessibilityActions(chinese: true, progressExpanded: false, transcriptionExpanded: nil, transcribe: { calls += 100; return true }, toggleProgress: { calls += 1; return true })
        XCTAssertEqual(progressOnly.map(\.name), ["播放进度"])
        XCTAssertTrue(progressOnly.first?.actionHandler?(progressOnly[0]) == true)
        XCTAssertEqual(calls, 1)
    }

}
