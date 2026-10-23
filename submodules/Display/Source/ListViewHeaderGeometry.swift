import Foundation

enum ListViewHeaderGeometry {
    static func bottomOriginY(upperBound: CGFloat, lowerBound: CGFloat, displayBound: CGFloat, height: CGFloat, isSticky: Bool) -> CGFloat {
        let bottom = isSticky ? min(lowerBound, displayBound) : lowerBound
        return max(upperBound, bottom - height)
    }
}
