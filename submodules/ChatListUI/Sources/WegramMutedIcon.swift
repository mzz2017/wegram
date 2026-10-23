import UIKit
import Display

/// The muted chat's bell (the user's dark chat-list reference): a 0.6pt outlined bell with a ring on top, a round
/// dome, sides that flare into the base and a short clapper, crossed by a slash that starts inside the outline. Drawn from
/// measurements of that screenshot at 3x, not from WeChat's artwork. Telegram's filled speaker icon and its
/// `muteIconColor` stay as they are for the other icons that share that colour.
///
/// The image is exactly the ink box; the row ends it 1pt inside the content edge, as in the reference. Colour
/// is WeUI's FG-3: white at 10% in dark mode (measured 49-50 on the 25 row background) and black at 10% in
/// light mode, which has no screenshot to check against.
func wegramMutedIcon(dark: Bool) -> UIImage? {
    if let image = wegramMutedIconCache[dark] { return image }
    let lineWidth: CGFloat = 0.6
    // Ink reaches 0.25pt left of the base's start and 0.2pt above the ring's centre line.
    let origin = CGPoint(x: lineWidth / 2.0 + 0.25, y: lineWidth / 2.0 + 0.2)
    let slashStart = CGPoint(x: 0.83, y: 1.5)
    let slashEnd = CGPoint(x: 11.0, y: 11.5)
    let image = generateImage(CGSize(width: slashEnd.x + origin.x + lineWidth / 2.0, height: slashEnd.y + origin.y + lineWidth / 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.translateBy(x: origin.x, y: origin.y)
        context.setStrokeColor((dark ? UIColor.white : UIColor.black).cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Everything is stroked opaque in a transparency layer that is composited at 10%, so the clapper
        // meeting the base does not double the alpha.
        context.setAlpha(0.1)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        let centerX: CGFloat = 4.65
        let halfWidth: CGFloat = 3.45
        let apex: CGFloat = 1.5
        let shoulder: CGFloat = 3.3
        let sideBottom: CGFloat = 7.3
        let base: CGFloat = 10.5
        let bell = CGMutablePath()
        bell.move(to: CGPoint(x: centerX - 4.75, y: base))
        bell.addQuadCurve(to: CGPoint(x: centerX - halfWidth, y: sideBottom), control: CGPoint(x: centerX - halfWidth, y: base - 1.5))
        bell.addLine(to: CGPoint(x: centerX - halfWidth, y: shoulder))
        // The dome is a half ellipse, rounding all the way from the ring to the sides.
        let kappa: CGFloat = 0.5523
        bell.addCurve(to: CGPoint(x: centerX, y: apex), control1: CGPoint(x: centerX - halfWidth, y: shoulder - kappa * (shoulder - apex)), control2: CGPoint(x: centerX - kappa * halfWidth, y: apex))
        bell.addCurve(to: CGPoint(x: centerX + halfWidth, y: shoulder), control1: CGPoint(x: centerX + kappa * halfWidth, y: apex), control2: CGPoint(x: centerX + halfWidth, y: shoulder - kappa * (shoulder - apex)))
        bell.addLine(to: CGPoint(x: centerX + halfWidth, y: sideBottom))
        // The right flare ends under the slash's gap, so it is drawn shorter than the left.
        bell.addQuadCurve(to: CGPoint(x: centerX + 3.6, y: base), control: CGPoint(x: centerX + halfWidth, y: base - 1.5))
        bell.closeSubpath()
        // Ring on top.
        bell.addEllipse(in: CGRect(x: centerX - 0.75, y: 0.55 - 0.75, width: 1.5, height: 1.5))
        context.addPath(bell)
        context.strokePath()
        // A short, thicker clapper below the base.
        context.setLineWidth(0.9)
        context.move(to: CGPoint(x: centerX, y: base))
        context.addLine(to: CGPoint(x: centerX, y: base + 0.6))
        context.strokePath()
        context.setLineWidth(lineWidth)
        // The slash cuts a gap through the outline.
        let slash = CGMutablePath()
        slash.move(to: slashStart)
        slash.addLine(to: slashEnd)
        context.setBlendMode(.clear)
        context.setLineWidth(lineWidth * 2.0)
        context.addPath(slash)
        context.strokePath()
        context.setBlendMode(.normal)
        context.setLineWidth(lineWidth)
        context.addPath(slash)
        context.strokePath()
        context.endTransparencyLayer()
    })
    wegramMutedIconCache[dark] = image
    return image
}

private var wegramMutedIconCache: [Bool: UIImage] = [:]
