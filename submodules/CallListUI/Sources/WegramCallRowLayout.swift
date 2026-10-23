import UIKit

struct WegramCallRowLayout {
    let textLeft: CGFloat
    let textRight: CGFloat
    let avatar: CGRect
    let info: CGRect

    init(width: CGFloat, height: CGFloat, safeLeft: CGFloat, safeRight: CGFloat, editingOffset: CGFloat, revealOffset: CGFloat, editing: Bool) {
        self.textLeft = safeLeft + editingOffset + revealOffset + 68
        self.textRight = width - safeRight - (editing ? 16 : 60) + revealOffset
        self.avatar = CGRect(x: safeLeft + editingOffset + revealOffset + 16, y: floor((height - 40) * 0.5), width: 40, height: 40)
        self.info = CGRect(x: width - safeRight - 52 + revealOffset, y: floor((height - 44) * 0.5), width: 44, height: 44)
    }
    func dateMaxWidth(credibilityWidth: CGFloat) -> CGFloat {
        let available = self.textRight - self.textLeft
        return max(0, min((available - 10) * 0.45, available - credibilityWidth - 42))
    }
    func titleWidth(dateWidth: CGFloat, credibilityWidth: CGFloat) -> CGFloat {
        max(0, self.textRight - self.textLeft - dateWidth - 10 - credibilityWidth)
    }
    func statusWidth(typeIconWidth: CGFloat) -> CGFloat {
        max(0, self.textRight - self.textLeft - (typeIconWidth > 0 ? typeIconWidth + 6 : 0))
    }
    static func height(titleHeight: CGFloat, statusHeight: CGFloat) -> CGFloat { max(72, titleHeight + 4 + statusHeight + 24) }
    func title(size: CGSize) -> CGRect { CGRect(x: self.textLeft, y: 12, width: size.width, height: size.height) }
    func date(size: CGSize, titleHeight: CGFloat) -> CGRect {
        CGRect(x: self.textRight - size.width, y: 12 + floor((titleHeight - size.height) * 0.5), width: size.width, height: size.height)
    }
    func status(size: CGSize, titleHeight: CGFloat, typeIconWidth: CGFloat) -> CGRect {
        CGRect(x: self.textLeft + (typeIconWidth > 0 ? typeIconWidth + 6 : 0), y: 12 + titleHeight + 4, width: size.width, height: size.height)
    }
    func typeIcon(size: CGSize, statusFrame: CGRect) -> CGRect {
        CGRect(x: self.textLeft, y: floor(statusFrame.midY - size.height * 0.5), width: size.width, height: size.height)
    }
}
