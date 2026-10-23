import Foundation
import CoreGraphics

enum MessageStatusLayout {
    static func size(dateSize: CGSize, leadingInset: CGFloat, indicatorsWidth: CGFloat, backgroundInsets: CGSize) -> CGSize {
        guard dateSize.width > 0 || indicatorsWidth > 0 else { return .zero }
        return CGSize(width: leadingInset + dateSize.width + indicatorsWidth + backgroundInsets.width, height: dateSize.height + backgroundInsets.height)
    }
}
