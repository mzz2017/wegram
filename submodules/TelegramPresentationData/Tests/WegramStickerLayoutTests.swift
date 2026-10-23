import XCTest
import UIKit
import Display
import ChatMessageItemCommon

final class WegramStickerLayoutTests: XCTestCase {
    func testMediaSnapshotClipsAwayAdjacentNameAndReplyButKeepsPremiumBottom() throws {
        func pixel(_ image: UIImage, x: CGFloat, y: CGFloat) throws -> [UInt8] {
            let cgImage = try XCTUnwrap(image.cgImage)
            var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
            let context = try XCTUnwrap(CGContext(data: &bytes, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: cgImage.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            let index = (Int(y * image.scale) * cgImage.width + Int(x * image.scale)) * 4
            return Array(bytes[index ..< index + 4])
        }
        for premium in [false, true] {
            let area = WegramStickerMessageLayout.contentArea(width: 402, leftInset: 0, rightInset: 0, outgoing: false, failed: false, selected: false)
            let layout = WegramStickerMessageLayout(area: area, outgoing: false, imageSize: CGSize(width: 132, height: 132), minimumImageHeight: 80, animationVerticalOffset: premium ? 20 : 0, parts: [.author: CGSize(width: 200, height: 17), .reply: CGSize(width: 200, height: 48)])
            let content = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: layout.height))
            let thumbnail = layout.imageFrame.insetBy(dx: 10, dy: 10)
            for (rect, color) in [(try XCTUnwrap(layout[.author]), UIColor.blue), (thumbnail, UIColor.red), (layout.animationFrame, UIColor.red), (try XCTUnwrap(layout[.reply]), UIColor.green)] {
                let view = UIView(frame: rect)
                view.backgroundColor = color
                content.addSubview(view)
            }
            let frame = layout.imageFrame.union(layout.animationFrame)
            let (snapshot, snapshotFrame) = try XCTUnwrap(wegramStickerMediaSnapshot(contentView: content, mediaFrame: frame, clippingRect: layout.mediaContentRect))
            XCTAssertEqual(snapshotFrame, frame)
            XCTAssertEqual(snapshot.size, frame.size)
            XCTAssertEqual(try pixel(snapshot, x: 15, y: 2)[3], 0, "The transparent top padding must not contain the sender name")
            XCTAssertEqual(try pixel(snapshot, x: 15, y: 25), [255, 0, 0, 255])
            XCTAssertEqual(try pixel(snapshot, x: 15, y: frame.height - 1)[3], premium ? 255 : 0, "Premium keeps its real animation bottom; normal padding must not contain the reply")
            if !premium {
                let (unclipped, _) = try XCTUnwrap(wegramStickerMediaSnapshot(contentView: content, mediaFrame: frame, clippingRect: nil))
                XCTAssertEqual(try pixel(unclipped, x: 15, y: 2), [0, 0, 255, 255])
                XCTAssertEqual(try pixel(unclipped, x: 15, y: frame.height - 1), [0, 255, 0, 255])
            }
        }
        XCTAssertNil(wegramStickerMediaSnapshot(contentView: UIView(), mediaFrame: .zero, clippingRect: nil))
    }

    func testStickerAndAllAccessoriesLeaveRoomForBothAvatarsAndSelection() throws {
        for width: CGFloat in [240, 320, 402, 874] {
            for outgoing in [false, true] {
                for selected in [false, true] {
                    for failed in [false, true] {
                        let left: CGFloat = width == 874 ? 59 : 12
                        let right: CGFloat = width == 874 ? 34 : 8
                        let area = WegramStickerMessageLayout.contentArea(width: width, leftInset: left, rightInset: right, outgoing: outgoing, failed: failed, selected: selected)
                        let avatar = WegramMessageLayout.avatarFrame(width: width, leftInset: left, rightInset: right, outgoing: outgoing)
                        let selection = WegramMessageLayout.avatarSelectionOffset(outgoing: outgoing, isSelected: selected)
                        if outgoing {
                            XCTAssertEqual(area.maxX + (failed ? 24 : 0) + 8, avatar.minX)
                            XCTAssertEqual(area.minX, left + 12)
                        } else {
                            XCTAssertEqual(area.minX, avatar.maxX + 8)
                            XCTAssertEqual(area.maxX + selection, width - right - 12)
                        }
                        let size = WegramStickerMessageLayout.imageSize(CGSize(width: 512, height: 512), availableWidth: area.width)
                        let layout = WegramStickerMessageLayout(area: area, outgoing: outgoing, imageSize: size, minimumImageHeight: 80, parts: [.author: CGSize(width: area.width, height: 17), .viaBot: CGSize(width: area.width - 12, height: 16), .forward: CGSize(width: area.width - 12, height: 48), .reply: CGSize(width: area.width - 12, height: 48), .buttons: CGSize(width: area.width, height: 80), .reactions: CGSize(width: area.width, height: 60)])
                        let image = layout.imageFrame.insetBy(dx: 10, dy: 10)
                        XCTAssertFalse(image.offsetBy(dx: selection, dy: 0).intersects(avatar.offsetBy(dx: selection, dy: 0)))
                        let ordered = try [layout[.author], layout[.viaBot], layout[.forward], image, layout[.reply], layout[.buttons], layout[.reactions]].map { try XCTUnwrap($0) }
                        for (index, rect) in ordered.enumerated() {
                            XCTAssertGreaterThanOrEqual(rect.minX, area.minX)
                            XCTAssertLessThanOrEqual(rect.maxX, area.maxX)
                            XCTAssertLessThanOrEqual(rect.maxY, layout.height)
                            if index > 0 { XCTAssertGreaterThanOrEqual(rect.minY, ordered[index - 1].maxY + 4) }
                        }
                        XCTAssertTrue(layout.contentRect.contains(try XCTUnwrap(layout[.reply])))
                        XCTAssertTrue(layout.contentRect.contains(try XCTUnwrap(layout[.author])))
                        XCTAssertFalse(layout.contentRect.intersects(try XCTUnwrap(layout[.buttons])))
                        XCTAssertFalse(layout.contentRect.intersects(try XCTUnwrap(layout[.reactions])))
                        XCTAssertFalse(layout.mediaContentRect.intersects(try XCTUnwrap(layout[.author])))
                        XCTAssertFalse(layout.mediaContentRect.intersects(try XCTUnwrap(layout[.reply])))
                        XCTAssertTrue(layout.mediaContentRect.contains(image))
                    }
                }
            }
        }
    }

    func testSmallStickerKeepsItsAspectRatioAndMetadataDoesNotOverlayTheImage() throws {
        XCTAssertEqual(WegramStickerMessageLayout.imageSize(CGSize(width: 512, height: 256), availableWidth: 300), CGSize(width: 132, height: 66))
        XCTAssertEqual(WegramStickerMessageLayout.imageSize(CGSize(width: 256, height: 512), availableWidth: 40), CGSize(width: 40, height: 80))
        XCTAssertEqual(WegramStickerMessageLayout.imageSize(CGSize(width: 30, height: 20), availableWidth: 300), CGSize(width: 30, height: 20))
        XCTAssertEqual(WegramStickerMessageLayout.imageSize(.zero, availableWidth: 300), .zero)
        let area = WegramStickerMessageLayout.contentArea(width: 402, leftInset: 0, rightInset: 0, outgoing: false, failed: false, selected: false)
        for fontSize: CGFloat in [14, 28, 56] {
            let (name, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "很长的群聊发送者名字 Long Sender", font: .systemFont(ofSize: fontSize), textColor: .gray), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: area.width, height: .greatestFiniteMagnitude), alignment: .natural))
            let layout = WegramStickerMessageLayout(area: area, outgoing: false, imageSize: CGSize(width: 30, height: 20), minimumImageHeight: 80, parts: [.suggestedPost: CGSize(width: 280, height: 50), .author: name.size, .reply: CGSize(width: 180, height: 48)])
            XCTAssertEqual(layout[.author]?.minY, 58)
            let image = layout.imageFrame.insetBy(dx: 10, dy: 10)
            XCTAssertEqual(image.minY, try XCTUnwrap(layout[.author]).maxY + 4 + 30)
            XCTAssertGreaterThan(try XCTUnwrap(layout[.reply]).minY, image.maxY)
            XCTAssertEqual(layout.height, try XCTUnwrap(layout[.reply]).maxY)
            XCTAssertGreaterThanOrEqual(layout.height, layout.contentRect.maxY)
        }
        let plain = WegramStickerMessageLayout(area: area, outgoing: false, imageSize: CGSize(width: 132, height: 132), minimumImageHeight: 80, parts: [:])
        XCTAssertEqual(plain.height, 132)
        XCTAssertEqual(plain.imageFrame.insetBy(dx: 10, dy: 10), CGRect(x: 60, y: 0, width: 132, height: 132))
        XCTAssertNil(plain[.author])
        XCTAssertNil(plain[.reply])
    }

    func testSendingAndOtherStatusIndicatorsHaveTheirOwnRowBeforeTheReply() throws {
        for outgoing in [false, true] {
            let area = WegramStickerMessageLayout.contentArea(width: 240, leftInset: 12, rightInset: 8, outgoing: outgoing, failed: false, selected: true)
            let layout = WegramStickerMessageLayout(area: area, outgoing: outgoing, imageSize: CGSize(width: 100, height: 100), minimumImageHeight: 80, parts: [.status: CGSize(width: 30, height: 18), .reply: CGSize(width: 110, height: 48), .reactions: CGSize(width: 120, height: 40)])
            let status = try XCTUnwrap(layout[.status])
            XCTAssertEqual(status.minY, 104)
            XCTAssertEqual(status.width, 30)
            XCTAssertEqual(outgoing ? status.maxX : status.minX, outgoing ? area.maxX : area.minX)
            XCTAssertEqual(layout[.reply]?.minY, status.maxY + 4)
            XCTAssertTrue(layout.contentRect.contains(status))
            XCTAssertLessThan(layout.contentRect.maxY, try XCTUnwrap(layout[.reactions]).minY)
        }
    }

    func testPremiumAnimationKeepsItsOriginalOffsetAndDoesNotRunIntoTheReply() throws {
        for outgoing in [false, true] {
            for selected in [false, true] {
                let area = WegramStickerMessageLayout.contentArea(width: 240, leftInset: 12, rightInset: 8, outgoing: outgoing, failed: true, selected: selected)
                let imageSize = WegramStickerMessageLayout.imageSize(CGSize(width: 240, height: 240), availableWidth: area.width - 36)
                let layout = WegramStickerMessageLayout(area: area, outgoing: outgoing, imageSize: imageSize, minimumImageHeight: 80, animationVerticalOffset: 20, parts: [.author: CGSize(width: area.width, height: 17), .reply: CGSize(width: area.width, height: 48), .buttons: CGSize(width: area.width, height: 44)])
                let thumbnail = layout.imageFrame.insetBy(dx: 10, dy: 10)
                XCTAssertEqual(layout.animationFrame.size, thumbnail.size)
                XCTAssertEqual(layout.animationFrame.minX, thumbnail.minX)
                XCTAssertEqual(layout.animationFrame.minY, thumbnail.minY + 20)
                XCTAssertTrue(layout.contentRect.contains(thumbnail))
                XCTAssertTrue(layout.contentRect.contains(layout.animationFrame))
                XCTAssertTrue(layout.mediaContentRect.contains(thumbnail))
                XCTAssertTrue(layout.mediaContentRect.contains(layout.animationFrame))
                XCTAssertFalse(layout.mediaContentRect.intersects(try XCTUnwrap(layout[.reply])))
                XCTAssertFalse(layout.mediaContentRect.intersects(try XCTUnwrap(layout[.author])))
                XCTAssertLessThan(layout.animationFrame.maxY, try XCTUnwrap(layout[.reply]).minY)
                XCTAssertLessThanOrEqual(try XCTUnwrap(layout[.buttons]).maxY, layout.height)
                XCTAssertGreaterThanOrEqual(thumbnail.minY, try XCTUnwrap(layout[.author]).maxY + 4)
                XCTAssertLessThanOrEqual(layout.animationFrame.maxX, area.maxX)
            }
        }
    }
}
