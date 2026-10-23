import UIKit

public func prepareCapturedWallpaperPhoto(_ image: UIImage, viewport: CGSize, cropRect: CGRect? = nil) -> UIImage? {
    guard image.size.width > 0, image.size.height > 0, viewport.width > 0, viewport.height > 0,
          image.size.width.isFinite, image.size.height.isFinite, viewport.width.isFinite, viewport.height.isFinite else { return nil }
    let bounds = CGRect(origin: .zero, size: image.size)
    let source: CGRect
    if let cropRect {
        guard cropRect.size.width > 0, cropRect.size.height > 0, cropRect.origin.x.isFinite, cropRect.origin.y.isFinite, cropRect.size.width.isFinite, cropRect.size.height.isFinite else { return nil }
        let width = min(bounds.width, cropRect.width)
        let height = min(bounds.height, cropRect.height)
        source = CGRect(x: min(max(0, cropRect.minX), bounds.width - width), y: min(max(0, cropRect.minY), bounds.height - height), width: width, height: height)
    } else {
        let fill = max(viewport.width / image.size.width, viewport.height / image.size.height)
        let visible = CGSize(width: viewport.width / fill, height: viewport.height / fill)
        source = CGRect(x: (image.size.width - visible.width) / 2, y: (image.size.height - visible.height) / 2, width: visible.width, height: visible.height)
    }
    let scale = min(1440 / viewport.width, 2960 / viewport.height, source.width * image.scale / viewport.width, source.height * image.scale / viewport.height)
    let size = CGSize(width: max(1, floor(viewport.width * scale)), height: max(1, floor(viewport.height * scale)))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        context.cgContext.interpolationQuality = .high
        image.draw(in: CGRect(x: -source.minX * size.width / source.width, y: -source.minY * size.height / source.height, width: image.size.width * size.width / source.width, height: image.size.height * size.height / source.height))
    }
}
