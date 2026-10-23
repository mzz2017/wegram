import Foundation
import CoreGraphics

enum WegramComposerMode {
    case text, voice, video

    func showsSend(hasText: Bool, hasForward: Bool, isEditing: Bool = false, isInlineSearch: Bool = false, hasMediaDraft: Bool = false) -> Bool {
        return self == .text && (hasMediaDraft || (!isInlineSearch && (hasText || hasForward || isEditing)))
    }

    func togglingVoice(isRecording: Bool) -> Self {
        guard !isRecording else { return self }
        return self == .text ? .voice : .text
    }

    func selectingVideo(isRecording: Bool) -> Self {
        return isRecording ? self : .video
    }
}

struct WegramComposerLayout {
    static let leftInset: CGFloat = 48
    static func rightInset(showsSend: Bool, sendButtonWidth: CGFloat = 58) -> CGFloat { showsSend ? 48 + sendButtonWidth : 88 }
    static func maximumSendButtonWidth(containerWidth: CGFloat) -> CGFloat {
        max(58, containerWidth - leftInset - 48 - 80)
    }

    let voice: CGRect
    let emoji: CGRect
    let action: CGRect

    init(field: CGRect, showsSend: Bool, sendButtonWidth: CGFloat = 58) {
        let y = field.maxY - 40
        self.voice = CGRect(x: field.minX - 44, y: y, width: 40, height: 40)
        self.emoji = CGRect(x: field.maxX + 4, y: y, width: 40, height: 40)
        self.action = CGRect(x: self.emoji.maxX, y: y, width: showsSend ? sendButtonWidth : 40, height: 40)
    }
}

struct WegramComposerContentLayout {
    let textOriginY: CGFloat
    let accessoryOriginY: CGFloat
    let contentHeight: CGFloat

    init(fieldHeight: CGFloat, accessoryHeight: CGFloat, accessoryBelow: Bool) {
        self.textOriginY = accessoryBelow ? 0 : accessoryHeight
        self.accessoryOriginY = accessoryBelow ? fieldHeight : 0
        self.contentHeight = fieldHeight + accessoryHeight
    }
}
