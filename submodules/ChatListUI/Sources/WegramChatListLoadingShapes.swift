import UIKit
import ShimmerEffect

func chatListLoadingShapes(avatarFrame: CGRect, titleFrame: CGRect, textFrame: CGRect, dateFrame: CGRect, contentMaxX: CGFloat, isWegram: Bool) -> [ShimmerEffectNode.Shape] {
    let diameter: CGFloat = 10
    let dateWidth: CGFloat = isWegram ? min(36, max(0, contentMaxX - titleFrame.minX)) : 36
    let dateX = dateFrame.maxX - dateWidth
    let titleWidth: CGFloat = isWegram ? min(180, max(0, dateX - 12 - titleFrame.minX)) : 180
    let textWidth: CGFloat = isWegram ? min(240, max(0, contentMaxX - textFrame.minX)) : 240
    var shapes: [ShimmerEffectNode.Shape] = [
        isWegram ? .roundedRect(rect: avatarFrame, cornerRadius: 4) : .circle(avatarFrame),
        .roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - diameter) / 2)), width: titleWidth, diameter: diameter),
        .roundedRectLine(startPoint: CGPoint(x: textFrame.minX, y: textFrame.minY + 7), width: textWidth, diameter: diameter)
    ]
    if !isWegram {
        shapes.append(.roundedRectLine(startPoint: CGPoint(x: textFrame.minX, y: textFrame.minY + 7 + diameter + 9), width: 200, diameter: diameter))
    }
    shapes.append(.roundedRectLine(startPoint: CGPoint(x: dateX, y: dateFrame.minY + 3), width: dateWidth, diameter: diameter))
    return shapes
}
