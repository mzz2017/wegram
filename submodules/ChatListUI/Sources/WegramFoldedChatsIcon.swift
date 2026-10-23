import UIKit
import Display

/// The 折叠的聊天 avatar (IMG_2440): a grey tile, an orange speech bubble, and a minus disc set into a
/// notch cut from the bubble. Drawn from measurements on a 48-unit grid (the tile is the 48pt list
/// avatar), not from WeChat's artwork.
///
/// Colours are the WeChat tokens the reference reads as: the tile F7F7F7 and `Orange_100` FA9D3B
/// (IMG_2440's P3 EEA250 is FB9E3A in sRGB). The dark pair is those tokens' dark values, 1E1E1E and
/// C87D2F; there is no dark screenshot of the row to check them against.
func wegramFoldedChatsIcon(size: CGFloat, dark: Bool) -> UIImage? {
    let tileColor = dark ? UIColor(rgb: 0x1e1e1e) : UIColor(rgb: 0xf7f7f7)
    let orange = dark ? UIColor(rgb: 0xc87d2f) : UIColor(rgb: 0xfa9d3b)
    return generateImage(CGSize(width: size, height: size), rotatedContext: { canvasSize, context in
        context.clear(CGRect(origin: CGPoint(), size: canvasSize))
        context.scaleBy(x: canvasSize.width / 48.0, y: canvasSize.height / 48.0)

        // A tenth-of-side circular corner, as on every WeChat list avatar.
        context.addPath(CGPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: 48.0, height: 48.0), cornerWidth: 4.8, cornerHeight: 4.8, transform: nil))
        context.setFillColor(tileColor.cgColor)
        context.fillPath()

        // The notch and the minus are holes, so the orange is composed in its own layer and only then
        // laid on the tile.
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setFillColor(orange.cgColor)

        // Bubble: an ellipse 26.667 x 22.667 centred at (24, 23.333).
        context.fillEllipse(in: CGRect(x: 10.667, y: 12.0, width: 26.667, height: 22.667))
        // Tail: from two points on the ellipse to a tip at (14.63, 36.494) rounded to 0.667.
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: 15.173, y: 31.828))
        tail.addArc(tangent1End: CGPoint(x: 14.630, y: 36.494), tangent2End: CGPoint(x: 19.698, y: 34.064), radius: 0.667)
        tail.addLine(to: CGPoint(x: 19.698, y: 34.064))
        tail.closeSubpath()
        context.addPath(tail)
        context.fillPath()

        // A 2-unit ring of tile shows between the bubble and the disc (centre 33.667, radius 5.667).
        context.setBlendMode(.clear)
        context.fillEllipse(in: CGRect(x: 26.0, y: 26.0, width: 15.333, height: 15.333))
        context.setBlendMode(.normal)
        context.fillEllipse(in: CGRect(x: 28.0, y: 28.0, width: 11.333, height: 11.333))

        // The minus bar, 6.667 x 1.6, is cut through the disc.
        context.setBlendMode(.clear)
        context.fill(CGRect(x: 30.333, y: 32.867, width: 6.667, height: 1.6))
        context.setBlendMode(.normal)
        context.endTransparencyLayer()
    })
}
