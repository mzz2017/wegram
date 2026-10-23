import Foundation
import CoreGraphics

@main
struct ComposerLayoutTests {
    static func main() {
        var failures: [String] = []
        for (width, safe): (CGFloat, CGFloat) in [(402, 0), (874, 62)] {
            for sends in [false, true] {
                let field = CGRect(x: safe + WegramComposerLayout.leftInset, y: 8, width: width - safe * 2 - WegramComposerLayout.leftInset - WegramComposerLayout.rightInset(showsSend: sends), height: 40)
                let frames = WegramComposerLayout(field: field, showsSend: sends)
                if frames.voice.minX != safe + 4 || frames.action.maxX != width - safe - 4 { failures.append("Controls ignore screen safe areas") }
                if frames.voice.maxX + 4 != field.minX || field.maxX + 4 != frames.emoji.minX || frames.emoji.maxX != frames.action.minX { failures.append("Voice, text, emoji and action slots overlap or are out of order") }
                if width == 402 && !sends && (field.minX != 48 || field.width != 266 || frames.emoji.midX != 338 || frames.action.midX != 378) { failures.append("Empty composer does not match reference geometry") }
                if frames.voice.midY != 28 || frames.action.midY != 28 { failures.append("Controls do not align with the 40pt field") }
            }
        }
        for fieldHeight: CGFloat in [40, 80, 160] {
            for below in [false, true] {
                let accessoryHeight: CGFloat = below ? 40 : 52
                let content = WegramComposerContentLayout(fieldHeight: fieldHeight, accessoryHeight: accessoryHeight, accessoryBelow: below)
                let text = CGRect(x: 48, y: 8 + content.textOriginY, width: 266, height: fieldHeight)
                let accessory = CGRect(x: 48, y: 8 + content.accessoryOriginY, width: 266, height: accessoryHeight)
                let controls = WegramComposerLayout(field: text, showsSend: true)
                if text.intersects(accessory) || max(text.maxY, accessory.maxY) != 8 + content.contentHeight {
                    failures.append("Reply and editor overlap or escape the reserved panel height")
                }
                if below && (text.minY != 8 || accessory.minY != text.maxY || controls.action.maxY != text.maxY || controls.voice.maxY != text.maxY) {
                    failures.append("Reply accessory moves the editor or its send/voice controls below the typing line")
                }
                if !below && (accessory.minY != 8 || text.minY != accessory.maxY) {
                    failures.append("Original accessory order changed")
                }
            }
            let plain = WegramComposerContentLayout(fieldHeight: fieldHeight, accessoryHeight: 0, accessoryBelow: false)
            if plain.contentHeight != fieldHeight || plain.textOriginY != 0 { failures.append("Dismissed reply leaves a blank accessory row") }
        }
        for hasText in [false, true] {
            if !WegramComposerMode.text.showsSend(hasText: hasText, hasForward: false, isEditing: true) {
                failures.append("Editing an empty caption lost its completion slot")
            }
            if !WegramComposerMode.text.showsSend(hasText: hasText, hasForward: true) {
                failures.append("Forwarding without a comment lost its send slot")
            }
            for mode: WegramComposerMode in [.voice, .video] {
                if mode.showsSend(hasText: hasText, hasForward: false) {
                    failures.append("Recording mode exposed the text send slot")
                }
            }
            if WegramComposerMode.text.showsSend(hasText: hasText, hasForward: false) != hasText {
                failures.append("Removing the forward did not restore the ordinary send slot")
            }
        }
        for hasText in [false, true] {
            for forward in [false, true] {
                for editing in [false, true] {
                    if WegramComposerMode.text.showsSend(hasText: hasText, hasForward: forward, isEditing: editing, isInlineSearch: true) {
                        failures.append("Inline search exposed the send slot instead of its clear action")
                    }
                }
            }
        }
        for (width, safe): (CGFloat, CGFloat) in [(320, 0), (402, 0), (874, 62)] {
            let available = width - safe * 2
            let maximum = WegramComposerLayout.maximumSendButtonWidth(containerWidth: available)
            for proposed: CGFloat in [58, 90, 144, 260] {
                let sendWidth = min(proposed, maximum)
                let field = CGRect(x: safe + 48, y: 8, width: available - 48 - WegramComposerLayout.rightInset(showsSend: true, sendButtonWidth: sendWidth), height: 40)
                let frames = WegramComposerLayout(field: field, showsSend: true, sendButtonWidth: sendWidth)
                if field.width < 80 || frames.action.width != sendWidth || frames.action.maxX != width - safe - 4 || frames.emoji.maxX != frames.action.minX {
                    failures.append("Paid send width clips the cost or overlaps the field/safe area")
                }
            }
        }
        for inline in [false, true] {
            if !WegramComposerMode.text.showsSend(hasText: false, hasForward: false, isInlineSearch: inline, hasMediaDraft: true) {
                failures.append("Recording preview lost Send to an empty caption or retained inline query")
            }
        }
        let multiline = WegramComposerLayout(field: CGRect(x: 48, y: 8, width: 266, height: 100), showsSend: false)
        if multiline.voice.maxY != 108 || multiline.emoji.maxY != 108 { failures.append("Controls do not stay on the last line of a growing field") }
        if WegramComposerMode.text.togglingVoice(isRecording: false) != .voice || WegramComposerMode.video.togglingVoice(isRecording: false) != .text { failures.append("Voice and keyboard switching failed") }
        if WegramComposerMode.voice.togglingVoice(isRecording: true) != .voice || WegramComposerMode.voice.selectingVideo(isRecording: true) != .voice { failures.append("Mode changed during an active recording") }
        if WegramComposerMode.text.selectingVideo(isRecording: false) != .video { failures.append("Hidden video recording mode is unreachable") }
        if !failures.isEmpty {
            for failure in failures { print("FAIL: \(failure)") }
            exit(1)
        }
        print("Composer layout and mode behavior checks passed")
    }
}
