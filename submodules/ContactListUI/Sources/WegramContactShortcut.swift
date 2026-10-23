import UIKit
import Display

enum WegramContactShortcut: Int, CaseIterable {
    case newFriends, groups, tags, channels

    var title: String {
        switch self {
        case .newFriends: return "新的朋友"
        case .groups: return "群聊"
        case .tags: return "标签"
        case .channels: return "公众号"
        }
    }

    func image() -> UIImage? {
        return generateImage(CGSize(width: 40, height: 40), rotatedContext: { _, context in
            context.clear(CGRect(x: 0, y: 0, width: 40, height: 40))
            let color: UIColor
            switch self {
            case .newFriends: color = UIColor(rgb: 0xfa9d3b)
            case .groups: color = UIColor(rgb: 0x00c25f)
            case .tags, .channels: color = UIColor(rgb: 0x1485ee)
            }
            context.setFillColor(color.cgColor)
            context.addPath(UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 40, height: 40), cornerRadius: 4).cgPath)
            context.fillPath()
            context.setFillColor(UIColor.white.cgColor)
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(1.8)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            func person(x: CGFloat, y: CGFloat, scale: CGFloat) {
                context.fillEllipse(in: CGRect(x: x - 4 * scale, y: y, width: 8 * scale, height: 8 * scale))
                let body = UIBezierPath(roundedRect: CGRect(x: x - 7 * scale, y: y + 10 * scale, width: 14 * scale, height: 9 * scale), cornerRadius: 4 * scale)
                context.addPath(body.cgPath)
                context.fillPath()
            }
            switch self {
            case .newFriends:
                person(x: 17, y: 10, scale: 1.1)
                context.fillEllipse(in: CGRect(x: 25, y: 21, width: 12, height: 12))
                context.setStrokeColor(color.cgColor)
                context.move(to: CGPoint(x: 28, y: 27))
                context.addLine(to: CGPoint(x: 34, y: 27))
                context.move(to: CGPoint(x: 31, y: 24))
                context.addLine(to: CGPoint(x: 31, y: 30))
                context.strokePath()
            case .groups:
                person(x: 27, y: 13, scale: 0.9)
                person(x: 17, y: 9, scale: 1.1)
            case .tags:
                context.move(to: CGPoint(x: 8, y: 24))
                context.addLine(to: CGPoint(x: 23, y: 9))
                context.addLine(to: CGPoint(x: 32, y: 9))
                context.addLine(to: CGPoint(x: 32, y: 18))
                context.addLine(to: CGPoint(x: 17, y: 33))
                context.closePath()
                context.fillPath()
                context.setFillColor(color.cgColor)
                context.fillEllipse(in: CGRect(x: 25, y: 13, width: 4, height: 4))
            case .channels:
                person(x: 20, y: 10, scale: 1.1)
            }
        })?.withRenderingMode(.alwaysOriginal)
    }
}
