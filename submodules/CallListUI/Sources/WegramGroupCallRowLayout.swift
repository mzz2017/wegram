import UIKit

struct WegramGroupCallRowLayout {
    let height: CGFloat
    let avatar: CGRect
    let indicator: CGRect
    let title: CGRect
    let join: CGRect
    let joinBackground: CGRect
    let joinText: CGRect

    static func joinTextMaxWidth(width: CGFloat, safeLeft: CGFloat, safeRight: CGFloat, editingOffset: CGFloat) -> CGFloat {
        max(20, min(180, (width - safeLeft - safeRight - editingOffset - 84) * 0.45 - 24))
    }
    static func titleMaxWidth(width: CGFloat, safeLeft: CGFloat, safeRight: CGFloat, editingOffset: CGFloat, joinTextWidth: CGFloat, active: Bool) -> CGFloat {
        max(0, width - safeLeft - safeRight - editingOffset - 84 - (active ? 0 : max(44, joinTextWidth + 24) + 12))
    }
    init(width: CGFloat, safeLeft: CGFloat, safeRight: CGFloat, editingOffset: CGFloat, revealOffset: CGFloat, titleSize: CGSize, joinTextSize: CGSize, active: Bool) {
        let joinSize = CGSize(width: max(44, joinTextSize.width + 24), height: max(44, joinTextSize.height + 20))
        self.height = max(56, titleSize.height + 24, active ? 0 : joinSize.height + 12)
        self.avatar = CGRect(x: safeLeft + editingOffset + revealOffset + 16, y: floor((self.height - 40) * 0.5), width: 40, height: 40)
        self.indicator = CGRect(x: self.avatar.maxX - 14, y: self.avatar.maxY - 18, width: 22, height: 22)
        self.title = CGRect(x: safeLeft + editingOffset + revealOffset + 68, y: floor((self.height - titleSize.height) * 0.5), width: titleSize.width, height: titleSize.height)
        self.join = CGRect(x: width - safeRight - 16 - joinSize.width + revealOffset, y: floor((self.height - joinSize.height) * 0.5), width: joinSize.width, height: joinSize.height)
        self.joinBackground = CGRect(x: 0, y: 6, width: joinSize.width, height: joinSize.height - 12)
        self.joinText = CGRect(x: floor((joinSize.width - joinTextSize.width) * 0.5), y: floor((joinSize.height - joinTextSize.height) * 0.5), width: joinTextSize.width, height: joinTextSize.height)
    }
}
