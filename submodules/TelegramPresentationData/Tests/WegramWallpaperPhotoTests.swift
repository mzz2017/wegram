import XCTest
import UIKit
import Display
import AsyncDisplayKit

final class WegramWallpaperPhotoTests: XCTestCase {
    private func stripes() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 12, height: 4), format: format).image { _ in
            UIColor.red.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 4, height: 4))
            UIColor.blue.setFill(); UIRectFill(CGRect(x: 4, y: 0, width: 4, height: 4))
            UIColor.green.setFill(); UIRectFill(CGRect(x: 8, y: 0, width: 4, height: 4))
        }
    }
    func testCapturedPhotoCropsTheCenterAndNormalizesOrientationWithoutUpscaling() throws {
        let source = self.stripes()
        let result = try XCTUnwrap(prepareCapturedWallpaperPhoto(source, viewport: CGSize(width: 1, height: 1)))
        XCTAssertEqual(result.size, CGSize(width: 4, height: 4))
        XCTAssertEqual(result.scale, 1)
        XCTAssertEqual(result.imageOrientation, .up)
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(try XCTUnwrap(result.cgImage), in: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertLessThan(pixel[0], 3)
        XCTAssertLessThan(pixel[1], 3)
        XCTAssertGreaterThan(pixel[2], 252)
        let rotated = UIImage(cgImage: try XCTUnwrap(source.cgImage), scale: 1, orientation: .right)
        let normalized = try XCTUnwrap(prepareCapturedWallpaperPhoto(rotated, viewport: CGSize(width: 402, height: 874)))
        XCTAssertEqual(normalized.imageOrientation, .up)
        XCTAssertLessThanOrEqual(normalized.size.width, 1440)
        XCTAssertLessThanOrEqual(normalized.size.height, 2960)
        XCTAssertNotNil(normalized.jpegData(compressionQuality: 0.8))
    }
    func testCapturedPhotoRejectsInvalidInputsAndRespectsTheViewportAndPixelLimit() throws {
        XCTAssertNil(prepareCapturedWallpaperPhoto(UIImage(), viewport: CGSize(width: 402, height: 874)))
        for viewport in [CGSize.zero, CGSize(width: -1, height: 10), CGSize(width: CGFloat.infinity, height: 10), CGSize(width: 10, height: CGFloat.nan)] {
            XCTAssertNil(prepareCapturedWallpaperPhoto(self.stripes(), viewport: viewport))
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let source = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 1600), format: format).image { _ in UIColor.gray.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 1600, height: 1600)) }
        for viewport in [CGSize(width: 402, height: 874), CGSize(width: 874, height: 402)] {
            let output = try XCTUnwrap(prepareCapturedWallpaperPhoto(source, viewport: viewport))
            XCTAssertLessThanOrEqual(output.size.width, 1440)
            XCTAssertLessThanOrEqual(output.size.height, 2960)
            XCTAssertEqual(output.size.width / output.size.height, viewport.width / viewport.height, accuracy: 0.002)
        }
    }
    func testSelectedCropUsesTheChosenPartOfThePhotoAndClampsEdges() throws {
        for (x, expected) in [(CGFloat(0), 0), (CGFloat(8), 1), (CGFloat(-20), 0)] {
            let result = try XCTUnwrap(prepareCapturedWallpaperPhoto(self.stripes(), viewport: CGSize(width: 1, height: 1), cropRect: CGRect(x: x, y: 0, width: 4, height: 4)))
            var pixel = [UInt8](repeating: 0, count: 4)
            let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(try XCTUnwrap(result.cgImage), in: CGRect(x: 0, y: 0, width: 1, height: 1))
            XCTAssertGreaterThan(pixel[expected], 252)
            XCTAssertLessThan(pixel[2], 3)
            XCTAssertEqual(result.size, CGSize(width: 4, height: 4))
        }
        XCTAssertNil(prepareCapturedWallpaperPhoto(self.stripes(), viewport: CGSize(width: 1, height: 1), cropRect: CGRect(x: 0, y: 0, width: -1, height: 4)))
    }

    func testOriginalWallpaperCropNodeMapsPanningAndZoomingBackToImageCoordinates() throws {
        let crop = WallpaperCropNode()
        let image = ASImageNode()
        image.image = self.stripes()
        let layout = ContainerViewLayout(size: CGSize(width: 4, height: 4), metrics: LayoutMetrics(), deviceMetrics: .iPhoneX, intrinsicInsets: .zero, safeInsets: .zero, additionalInsets: .zero, statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
        crop.frame = CGRect(origin: .zero, size: layout.size)
        crop.containerLayoutUpdated(layout, transition: .immediate)
        crop.zoomableContent = (CGSize(width: 12, height: 4), image)
        crop.zoom(to: CGRect(x: 4, y: 0, width: 4, height: 4))
        XCTAssertEqual(crop.cropRect.minX, 4, accuracy: 0.01)
        XCTAssertEqual(crop.cropRect.width, 4, accuracy: 0.01)
        crop.scrollNode.view.contentOffset = CGPoint(x: 8, y: 0)
        XCTAssertEqual(crop.cropRect.minX, 8, accuracy: 0.01)
        let result = try XCTUnwrap(prepareCapturedWallpaperPhoto(self.stripes(), viewport: CGSize(width: 1, height: 1), cropRect: crop.cropRect))
        XCTAssertEqual(result.size, CGSize(width: 4, height: 4))
        crop.zoom(to: CGRect(x: 8, y: 1, width: 2, height: 2))
        XCTAssertEqual(crop.cropRect.width, 2, accuracy: 0.01)
        XCTAssertEqual(crop.cropRect.height, 2, accuracy: 0.01)
    }

}
