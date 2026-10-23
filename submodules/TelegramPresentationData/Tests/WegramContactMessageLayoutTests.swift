import XCTest
import UIKit
import Display
import AsyncDisplayKit
import AvatarNode
import SwiftSignalKit
import ChatMessageItemCommon

final class WegramContactMessageLayoutTests: XCTestCase {
    func testContactNameAndTypeStayWithinCardAtLargeTypeAndNarrowWidths() {
        XCTAssertEqual(WegramContactMessageLayout.label(chinese: true), "个人名片")
        XCTAssertEqual(WegramContactMessageLayout.label(chinese: false), "Contact Card")
        for width: CGFloat in [0, 40, 100, 250, 400] {
            for font: CGFloat in [17, 34, 56] {
                let (title, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "很长的联系人姓名 Contact Name", font: .systemFont(ofSize: font), textColor: .black), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: WegramContactMessageLayout.titleWidth(width), height: .greatestFiniteMagnitude)))
                let (label, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "个人名片", font: .systemFont(ofSize: floor(font * 12 / 17)), textColor: .gray), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, width - 24), height: .greatestFiniteMagnitude)))
                let layout = WegramContactMessageLayout(width: width, titleSize: title.size, labelSize: label.size)
                for frame in [layout.avatarFrame, layout.titleFrame, layout.separatorFrame, layout.labelFrame] {
                    XCTAssertGreaterThanOrEqual(frame.minX, 0)
                    XCTAssertLessThanOrEqual(frame.maxX, width)
                    XCTAssertGreaterThanOrEqual(frame.minY, 0)
                    XCTAssertLessThanOrEqual(frame.maxY, layout.height)
                }
                if !layout.titleFrame.isEmpty { XCTAssertGreaterThanOrEqual(layout.titleFrame.minX - layout.avatarFrame.maxX, 12) }
                XCTAssertGreaterThanOrEqual(layout.separatorFrame.minY - max(layout.avatarFrame.maxY, layout.titleFrame.maxY), 12)
                XCTAssertGreaterThanOrEqual(layout.labelFrame.minY - layout.separatorFrame.maxY, 4)
                if width == 250 { XCTAssertEqual(layout.avatarFrame.size, CGSize(width: 44, height: 44)) }
            }
        }
    }

    func testActualLetterAvatarRebuildsWhenOnlyClipChangesAndRestoresDefaultRound() throws {
        let node = AvatarNode(font: .systemFont(ofSize: 16))
        node.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        func cornerAlpha() throws -> UInt8 {
            let parameters = node.contentNode.drawParameters(forAsyncLayer: try XCTUnwrap(node.contentNode.layer as? _ASDisplayLayer))
            let image = UIGraphicsImageRenderer(size: node.frame.size).image { _ in
                AvatarNode.ContentNode.draw(node.bounds, withParameters: parameters, isCancelled: { false }, isRasterizing: false)
            }
            let cg = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: image.scale, y: image.scale, width: 1, height: 1)))
            let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)[3]
        }
        node.setCustomLetters(["名"])
        XCTAssertEqual(try cornerAlpha(), 0)
        node.setCustomLetters(["名"], clipStyle: .none)
        XCTAssertEqual(try cornerAlpha(), 255)
        node.setCustomLetters(["名"])
        XCTAssertEqual(try cornerAlpha(), 0)
    }
    func testChangingPhotoToLettersClearsAndCancelsTheActualImageChild() {
        let node = AvatarNode(font: .systemFont(ofSize: 16))
        node.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        let photo = UIGraphicsImageRenderer(size: node.frame.size).image { output in
            UIColor.red.setFill()
            output.fill(node.bounds)
        }
        let photos = ValuePipe<UIImage?>()
        node.contentNode.imageNode.setSignal(photos.signal())
        photos.putNext(photo)
        XCTAssertNotNil(node.contentNode.imageNode.image)
        node.contentNode.unroundedImage = photo
        node.setCustomLetters(["名"], clipStyle: .none)
        XCTAssertNil(node.contentNode.imageNode.image)
        XCTAssertNil(node.contentNode.unroundedImage)
        photos.putNext(photo)
        XCTAssertNil(node.contentNode.imageNode.image, "A previous contact's delayed photo must not replace the new letters")
        node.setCustomLetters(["名"])
        XCTAssertNil(node.contentNode.imageNode.image)
    }

}
