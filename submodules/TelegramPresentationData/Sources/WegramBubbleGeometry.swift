import Foundation
import CoreGraphics

enum WegramBubbleGeometry {
    static let sourceSize = CGSize(width: 20, height: 40)
    static let stretchPoint = CGPoint(x: 7, y: 28)

    static func path(in rect: CGRect, incoming: Bool, showsTail: Bool) -> CGPath {
        let radius: CGFloat = 4
        let tailWidth: CGFloat = 5
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width - tailWidth, height: rect.height)
        let centerY = rect.minY + 20
        let path = CGMutablePath()
        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY + radius), radius: radius)
        if showsTail {
            path.addLine(to: CGPoint(x: body.maxX, y: centerY - 5))
            path.addLine(to: CGPoint(x: rect.maxX, y: centerY))
            path.addLine(to: CGPoint(x: body.maxX, y: centerY + 5))
        }
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX - radius, y: body.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY - radius), radius: radius)
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX + radius, y: body.minY), radius: radius)
        path.closeSubpath()
        if incoming {
            var mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.minX + rect.maxX, ty: 0)
            return path.copy(using: &mirror)!
        }
        return path
    }
}
