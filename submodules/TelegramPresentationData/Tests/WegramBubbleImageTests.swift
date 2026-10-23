import XCTest
import UIKit
import TelegramPresentationData

final class WegramBubbleImageTests: XCTestCase {
    private func asset(incoming: Bool, mask: Bool = false) -> UIImage {
        return messageBubbleImage(maxCornerRadius: 4, minCornerRadius: 4, incoming: incoming, fillColor: .black, strokeColor: .clear, neighbors: .none, theme: defaultDarkPresentationTheme.chat, wallpaper: .color(0xffffff), knockout: mask, mask: mask, extendedEdges: true, usesWegramShape: true)
    }

    private func render(_ image: UIImage, height: CGFloat) -> UIImage {
        let size = CGSize(width: 120, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let view = UIImageView(image: image)
        view.frame = CGRect(origin: .zero, size: size).insetBy(dx: -1, dy: -1)
        view.layoutIfNeeded()
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.translateBy(x: -1, y: -1)
            view.layer.render(in: context.cgContext)
        }
    }

    private func alpha(_ image: UIImage, x: CGFloat, y: CGFloat) -> CGFloat {
        let pixel = image.cgImage!.cropping(to: CGRect(x: floor(x * image.scale), y: floor(y * image.scale), width: 1, height: 1))!
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return CGFloat(context.data!.assumingMemoryBound(to: UInt8.self)[3]) / 255
    }

    func testTailRemainsAtMessageTopWhenUIKitStretchesTheImage() {
        for height: CGFloat in [40, 120, 300] {
            for incoming in [true, false] {
                let image = render(asset(incoming: incoming), height: height)
                let x: CGFloat = incoming ? 1 : 119
                XCTAssertGreaterThan(alpha(image, x: x, y: 20), 0.5, "Tail missing at 20pt: incoming=\(incoming), height=\(height)")
                XCTAssertLessThan(alpha(image, x: x, y: 30), 0.1, "Tail stretched down the message")
                let cornerX: CGFloat = incoming ? 119.5 : 0.5
                let innerX: CGFloat = incoming ? 118 : 2
                XCTAssertLessThan(alpha(image, x: cornerX, y: 0.5), 0.1, "Corner became square")
                XCTAssertGreaterThan(alpha(image, x: innerX, y: 2), 0.5, "Corner is larger than 4pt")
            }
        }
    }

    func testWallpaperMaskMatchesTheStretchedFill() {
        for incoming in [true, false] {
            let fill = render(asset(incoming: incoming), height: 120)
            let mask = render(asset(incoming: incoming, mask: true), height: 120)
            for x: CGFloat in [0.5, 1, 2, 4, 5, 8, 60, 112, 115, 118, 119] {
                for y: CGFloat in [0.5, 1, 2, 4, 15, 20, 25, 30, 60, 118, 119] {
                    XCTAssertEqual(alpha(fill, x: x, y: y), alpha(mask, x: x, y: y), accuracy: 0.01, "Fill and wallpaper mask diverged at \(x),\(y)")
                }
            }
        }
    }

    func testShapeStyleSeparatesGraphicsCacheKeys() {
        let plain = PresentationChatBubbleCorners(mainRadius: 4, auxiliaryRadius: 4, mergeBubbleCorners: false)
        XCTAssertNotEqual(plain, .wegram)
        XCTAssertEqual(Set([plain, .wegram]).count, 2)
    }
}
