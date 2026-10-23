import XCTest
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ChatMessageItemCommon

final class WegramFileMessageLayoutTests: XCTestCase {
    private func file(_ attributes: [TelegramMediaFileAttribute]) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: MediaId(namespace: 0, id: 40), partialReference: nil, resource: LocalFileMediaResource(fileId: 40), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/pdf", size: 8_800_000, attributes: attributes, alternativeRepresentations: [])
    }

    func testOnlyDocumentsUseTheNewFileCard() {
        XCTAssertTrue(WegramFileMessageLayout.supports(self.file([.FileName(fileName: "文件.pdf")])))
        XCTAssertFalse(WegramFileMessageLayout.supports(self.file([.Audio(isVoice: true, duration: 10, title: nil, performer: nil, waveform: nil)])))
        XCTAssertFalse(WegramFileMessageLayout.supports(self.file([.Audio(isVoice: false, duration: 10, title: nil, performer: nil, waveform: nil)])))
        XCTAssertFalse(WegramFileMessageLayout.supports(self.file([.Animated])))
        XCTAssertFalse(WegramFileMessageLayout.supports(self.file([.Video(duration: 1, size: PixelDimensions(width: 640, height: 480), flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)])))
    }

    func testRealFileNameAndSizeStayLeftOfTheRightControlAtLargeType() {
        for width: CGFloat in [40, 100, 230, 400] {
            for font: CGFloat in [16, 32, 56] {
                let textWidth = WegramFileMessageLayout.textWidth(width)
                let (title, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "新款精雕面渐变色.Stainless steel.pdf", font: .systemFont(ofSize: font), textColor: .black), maximumNumberOfLines: 2, truncationType: .middle, constrainedSize: CGSize(width: textWidth, height: .greatestFiniteMagnitude)))
                let (description, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "8.80 MB", font: .systemFont(ofSize: floor(font * 13 / 16)), textColor: .gray), maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: textWidth, height: .greatestFiniteMagnitude)))
                let layout = WegramFileMessageLayout(width: width, titleSize: title.size, descriptionSize: description.size)
                for frame in [layout.titleFrame, layout.descriptionFrame, layout.controlFrame] {
                    XCTAssertGreaterThanOrEqual(frame.minX, 0)
                    XCTAssertLessThanOrEqual(frame.maxX, width)
                    XCTAssertGreaterThanOrEqual(frame.minY, 0)
                    XCTAssertLessThanOrEqual(frame.maxY, layout.height)
                }
                XCTAssertEqual(layout.controlFrame.maxX, width)
                XCTAssertGreaterThanOrEqual(layout.descriptionFrame.minY, layout.titleFrame.maxY)
                if !layout.titleFrame.isEmpty { XCTAssertGreaterThanOrEqual(layout.controlFrame.minX - layout.titleFrame.maxX, 14) }
                if !layout.descriptionFrame.isEmpty { XCTAssertGreaterThanOrEqual(layout.controlFrame.minX - layout.descriptionFrame.maxX, 14) }
                XCTAssertGreaterThanOrEqual(layout.height, 44)
                if font == 56 { XCTAssertGreaterThan(layout.height, 44) }
            }
        }
    }

    private func pixel(_ image: UIImage, x: CGFloat, y: CGFloat) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: x * image.scale, y: y * image.scale, width: 1, height: 1)))
        let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Array(UnsafeBufferPointer(start: try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self), count: 4))
    }

    func testFilePageIconKeepsColorFoldTransparentMarginsAndDistinctCacheEntries() throws {
        let pdf = WegramFileMessageLayout.icon(fileName: "report.pdf")
        XCTAssertTrue(pdf === WegramFileMessageLayout.icon(fileName: "REPORT.PDF"))
        XCTAssertEqual(pdf.size, CGSize(width: 44, height: 44))
        XCTAssertEqual(try self.pixel(pdf, x: 0, y: 20)[3], 0)
        let body = try self.pixel(pdf, x: 20, y: 15)
        let fold = try self.pixel(pdf, x: 29, y: 7)
        XCTAssertGreaterThan(body[0], body[1] * 2)
        XCTAssertGreaterThan(body[0], fold[0])
        XCTAssertEqual(body[3], 255)
        let document = WegramFileMessageLayout.icon(fileName: "file.docx")
        XCTAssertFalse(document === WegramFileMessageLayout.icon(fileName: "file.docxunknown"))
        let blue = try self.pixel(document, x: 20, y: 15)
        XCTAssertGreaterThan(blue[2], blue[0])
        XCTAssertNotNil(WegramFileMessageLayout.icon(fileName: nil).cgImage)
    }

}
