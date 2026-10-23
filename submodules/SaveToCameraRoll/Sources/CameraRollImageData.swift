import UIKit

func cameraRollImageData(_ image: UIImage, validUntil: Date?, now: Date = Date()) -> Data? {
    guard validUntil.map({ $0 > now }) ?? true else { return nil }
    return image.pngData()
}
