import XCTest
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import ChatMessageItemCommon

final class WegramMapMessageLayoutTests: XCTestCase {
    private func map(latitude: Double = 31.2, longitude: Double = 121.4, venue: MapVenue? = nil, address: MapGeoAddress? = nil, timeout: Int32? = nil) -> TelegramMediaMap {
        return TelegramMediaMap(latitude: latitude, longitude: longitude, heading: nil, accuracyRadius: nil, venue: venue, address: address, liveBroadcastingTimeout: timeout)
    }

    func testStaticMapUsesActualPlaceInformationAndNeverConvertsLiveLocations() {
        let place = MapVenue(title: "天府广场-A口", address: "四川省成都市青羊区", provider: "test", id: "1", type: nil)
        let media = self.map(venue: place)
        XCTAssertTrue(WegramMapMessageLayout.supports(media))
        XCTAssertEqual(WegramMapMessageLayout.title(media, fallback: "位置"), place.title)
        XCTAssertEqual(WegramMapMessageLayout.address(media), place.address)
        XCTAssertEqual(WegramMapMessageLayout.title(self.map(), fallback: "位置"), "位置")
        XCTAssertEqual(WegramMapMessageLayout.address(self.map()), "31.20000, 121.40000")
        XCTAssertEqual(WegramMapMessageLayout.address(self.map(address: MapGeoAddress(country: "CN", state: "上海", city: "", street: "巨鹿路"))), "上海 巨鹿路")
        XCTAssertEqual(WegramMapMessageLayout.title(self.map(venue: MapVenue(title: "  ", address: nil, provider: nil, id: nil, type: nil)), fallback: "位置"), "位置")
        for timeout: Int32 in [0, 1, 3600, liveLocationIndefinitePeriod] {
            XCTAssertFalse(WegramMapMessageLayout.supports(self.map(venue: place, timeout: timeout)))
        }
        for value in [Double.nan, .infinity, 91, -91] { XCTAssertFalse(WegramMapMessageLayout.supports(self.map(latitude: value))) }
        XCTAssertFalse(WegramMapMessageLayout.supports(self.map(longitude: 181)))
        XCTAssertTrue(WegramMapMessageLayout.supports(self.map(latitude: -90, longitude: 180)))
    }

    func testActualTextLayoutsLeaveMapAndStatusOnSeparateRowsAtLargeType() {
        XCTAssertEqual(WegramMapMessageLayout.imageSize(width: 400), CGSize(width: 250, height: 96))
        for width: CGFloat in [40, 100, 250] {
            for font: CGFloat in [17, 34, 56] {
                let textWidth = max(0, width - 24)
                let (title, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "天府广场-A口 很长的位置名称", font: .systemFont(ofSize: font), textColor: .black), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textWidth, height: .greatestFiniteMagnitude)))
                let (address, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "四川省成都市青羊区 新地址", font: .systemFont(ofSize: floor(font * 12 / 17)), textColor: .gray), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textWidth, height: .greatestFiniteMagnitude)))
                for status in [CGSize.zero, CGSize(width: min(width - 20, 80), height: 32)] {
                    let layout = WegramMapMessageLayout(width: width, titleSize: title.size, addressSize: address.size, statusSize: status)
                    for frame in [layout.titleFrame, layout.addressFrame, layout.imageFrame, layout.statusFrame] {
                        XCTAssertGreaterThanOrEqual(frame.minX, 0)
                        XCTAssertLessThanOrEqual(frame.maxX, width)
                        XCTAssertGreaterThanOrEqual(frame.minY, 0)
                        XCTAssertLessThanOrEqual(frame.maxY, layout.height)
                    }
                    XCTAssertGreaterThanOrEqual(layout.addressFrame.minY, layout.titleFrame.maxY)
                    XCTAssertGreaterThanOrEqual(layout.imageFrame.minY - layout.addressFrame.maxY, 5)
                    XCTAssertEqual(layout.statusFrame.minY - layout.imageFrame.maxY, status.height > 0 ? 6 : 0)
                    XCTAssertEqual(layout.height, layout.statusFrame.maxY)
                    XCTAssertEqual(layout.imageFrame.size, WegramMapMessageLayout.imageSize(width: width))
                }
            }
        }
    }

    func testMapMarkerUsesOriginalCanvasPointAndTransparentMargins() throws {
        let image = WegramMapMessageLayout.pinImage
        XCTAssertEqual(image.size, CGSize(width: 62, height: 74))
        func pixel(_ x: CGFloat, _ y: CGFloat) throws -> [UInt8] {
            let cg = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: x * image.scale, y: y * image.scale, width: 1, height: 1)))
            let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return Array(UnsafeBufferPointer(start: try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self), count: 4))
        }
        XCTAssertEqual(try pixel(0, 40)[3], 0)
        XCTAssertEqual(try pixel(31, 70)[3], 0)
        let head = try pixel(21, 35)
        XCTAssertGreaterThan(head[1], head[0] * 2)
        XCTAssertEqual(head[3], 255)
        XCTAssertGreaterThan(try pixel(31, 63)[3], 0)
    }
    func testUserIOSLocationCardReferenceHasShortMapTwelvePointInsetAndGreenHollowPin() throws {
        XCTAssertEqual(WegramMapMessageLayout.imageSize(width: 402), CGSize(width: 250, height: 96))
        let layout = WegramMapMessageLayout(width: 250, titleSize: CGSize(width: 200, height: 20), addressSize: CGSize(width: 160, height: 14), statusSize: .zero)
        XCTAssertEqual(layout.titleFrame.minX, 12)
        XCTAssertEqual(layout.addressFrame.minX, 12)
        XCTAssertEqual(layout.imageFrame.minY, 53)
        let image = WegramMapMessageLayout.pinImage
        func rgba(_ x: CGFloat, _ y: CGFloat) throws -> [UInt8] {
            let cg = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: x * image.scale, y: y * image.scale, width: 1, height: 1)))
            let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return Array(UnsafeBufferPointer(start: try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self), count: 4))
        }
        let ring = try rgba(21, 35)
        XCTAssertEqual(ring[0], 7, accuracy: 3)
        XCTAssertEqual(ring[1], 193, accuracy: 3)
        XCTAssertEqual(ring[2], 96, accuracy: 3)
        XCTAssertEqual(ring[3], 255)
        XCTAssertEqual(try rgba(31, 35), [255, 255, 255, 255], "The supplied iOS screenshot has a white ring center")
        XCTAssertEqual(try rgba(31, 62)[3], 255)
        XCTAssertEqual(try rgba(31, 68)[3], 0)
    }

    func testNarrowMapKeepsVisibleRingInsideTheMapWithoutMovingTheCoordinatePoint() throws {
        let normal = CGRect(x: 94, y: 1, width: 62, height: 74)
        XCTAssertEqual(WegramMapMessageLayout.pinFrame(originalFrame: normal, mapSize: CGSize(width: 250, height: 96)), normal)
        let original = CGRect(x: 19, y: -28, width: 62, height: 74)
        let frame = try XCTUnwrap(WegramMapMessageLayout.pinFrame(originalFrame: original, mapSize: CGSize(width: 100, height: 38)))
        let scale = frame.width / 62
        XCTAssertLessThan(scale, 1)
        XCTAssertEqual(frame.minX + 31 * scale, original.minX + 31, accuracy: 0.001)
        XCTAssertEqual(frame.minY + 64 * scale, original.minY + 64, accuracy: 0.001)
        let visibleInk = CGRect(x: frame.minX + 18.5 * scale, y: frame.minY + 23 * scale, width: 25 * scale, height: 41 * scale)
        XCTAssertGreaterThanOrEqual(visibleInk.minX, 0)
        XCTAssertGreaterThanOrEqual(visibleInk.minY, -0.001)
        XCTAssertLessThanOrEqual(visibleInk.maxX, 100)
        XCTAssertLessThanOrEqual(visibleInk.maxY, 38)
        XCTAssertNil(WegramMapMessageLayout.pinFrame(originalFrame: CGRect(x: -11, y: -40, width: 62, height: 74), mapSize: CGSize(width: 40, height: 15)), "An actual coordinate outside the tiny snapshot must not be replaced with a made-up visible point")
    }

    func testLiveLocationsUseTheirOwnPresentationWithoutChangingStaticQualification() {
        XCTAssertFalse(WegramLiveLocationMessageLayout.supports(self.map()))
        for timeout: Int32 in [0, -1, 1, 3600, liveLocationIndefinitePeriod] {
            let live = self.map(timeout: timeout)
            XCTAssertTrue(WegramLiveLocationMessageLayout.supports(live))
            XCTAssertFalse(WegramMapMessageLayout.supports(live))
            XCTAssertEqual(live.liveBroadcastingTimeout, timeout)
        }
        XCTAssertFalse(WegramLiveLocationMessageLayout.supports(self.map(latitude: .nan, timeout: 3600)))
        XCTAssertFalse(WegramLiveLocationMessageLayout.supports(self.map(longitude: 181, timeout: 3600)))
        XCTAssertEqual(WegramLiveLocationMessageLayout.title(active: true, chinese: true), "共享实时位置")
        XCTAssertEqual(WegramLiveLocationMessageLayout.title(active: false, chinese: true), "位置共享已结束")
        XCTAssertNotEqual(WegramLiveLocationMessageLayout.title(active: true, chinese: false), WegramLiveLocationMessageLayout.title(active: false, chinese: false))
    }

    func testActualLiveTextAndDirectionalIconStaySeparateFromStatusAtLargeType() {
        for available: CGFloat in [40, 100, 250, 402] {
            for font: CGFloat in [17, 34, 56] {
                let (title, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Live location sharing ended 位置共享已结束", font: .systemFont(ofSize: font), textColor: .gray), maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: max(1, WegramLiveLocationMessageLayout.textWidth(available)), height: .greatestFiniteMagnitude)))
                for incoming in [false, true] {
                    for status in [CGSize.zero, CGSize(width: min(available, 80), height: 24)] {
                        let width = WegramLiveLocationMessageLayout.width(available: available, title: title.size.width, status: status.width)
                        let layout = WegramLiveLocationMessageLayout(width: width, titleSize: title.size, statusSize: status, incoming: incoming)
                        XCTAssertLessThanOrEqual(width, min(250, available))
                        for frame in [layout.iconFrame, layout.titleFrame, layout.statusFrame] {
                            XCTAssertGreaterThanOrEqual(frame.minX, 0)
                            XCTAssertLessThanOrEqual(frame.maxX, width)
                            XCTAssertGreaterThanOrEqual(frame.minY, 0)
                            XCTAssertLessThanOrEqual(frame.maxY, layout.height)
                        }
                        if incoming { XCTAssertLessThanOrEqual(layout.iconFrame.maxX, layout.titleFrame.minX) }
                        else { XCTAssertLessThanOrEqual(layout.titleFrame.maxX, layout.iconFrame.minX) }
                        XCTAssertGreaterThanOrEqual(layout.statusFrame.minY - max(layout.iconFrame.maxY, layout.titleFrame.maxY), 12)
                        if font == 56 && available >= 250 { XCTAssertGreaterThan(layout.height, 50) }
                    }
                }
            }
        }
    }

    func testLiveIconIsHollowAndUsesTheRequestedActiveOrEndedColor() throws {
        for color in [UIColor(rgb: 0x07c160), .gray, UIColor.white.withAlphaComponent(0.65)] {
            let image = WegramLiveLocationMessageLayout.icon(color: color)
            XCTAssertEqual(image.size, CGSize(width: 22, height: 26))
            func pixel(_ x: CGFloat, _ y: CGFloat) throws -> [UInt8] {
                let cg = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: x * image.scale, y: y * image.scale, width: 1, height: 1)))
                let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return Array(UnsafeBufferPointer(start: try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self), count: 4))
            }
            XCTAssertEqual(try pixel(0, 0)[3], 0)
            XCTAssertEqual(try pixel(11, 10)[3], 0)
            let edge = try pixel(20, 10)
            XCTAssertGreaterThan(edge[3], 0)
            if color == UIColor(rgb: 0x07c160) { XCTAssertGreaterThan(edge[1], edge[0]) }
            else { XCTAssertEqual(edge[0], edge[1]) }
            if color == UIColor.white.withAlphaComponent(0.65) { XCTAssertLessThanOrEqual(edge[3], 170) }
        }
    }

}

final class WegramMediaAlbumLayoutTests: XCTestCase {
    func testFoldedAlbumRetainsEveryMessageAndShowsOnlyThreeCards() {
        let sources = Array(repeating: CGSize(width: 900, height: 1600), count: 10)
        let layout = WegramMediaAlbumLayout(itemSizes: sources, maxSize: CGSize(width: 280, height: 320), outgoing: true, expanded: false)
        XCTAssertEqual(layout.frames.count, sources.count)
        XCTAssertEqual(layout.size, CGSize(width: 174, height: 200))
        XCTAssertEqual(layout.frames[0], CGRect(x: 0, y: 0, width: 150, height: 200))
        XCTAssertEqual(layout.frames[1], CGRect(x: 12, y: 12, width: 150, height: 176))
        XCTAssertEqual(layout.frames[2], CGRect(x: 24, y: 24, width: 150, height: 152))
        XCTAssertTrue(layout.isVisible(at: 2))
        XCTAssertFalse(layout.isVisible(at: 3))
        XCTAssertEqual(layout.statusAnchor, CGPoint(x: 150, y: 200), "A hidden rear card must not move sending status away from the front photo")
        XCTAssertEqual(layout.rotation(at: 0), 0)
        XCTAssertGreaterThan(layout.rotation(at: 2), layout.rotation(at: 1))
    }

    func testOverlappingCardsHitFrontVisibleMessageAndNeverHiddenFourthPhoto() {
        let sizes = Array(repeating: CGSize(width: 900, height: 1600), count: 10)
        let collapsed = WegramMediaAlbumLayout(itemSizes: sizes, maxSize: CGSize(width: 280, height: 320), outgoing: true, expanded: false)
        XCTAssertEqual(collapsed.hitIndex(at: CGPoint(x: 100, y: 100)), 0)
        XCTAssertEqual(collapsed.hitIndex(at: CGPoint(x: 156, y: 100)), 1)
        XCTAssertEqual(collapsed.hitIndex(at: CGPoint(x: 170, y: 100)), 2)
        XCTAssertNil(collapsed.hitIndex(at: CGPoint(x: -10, y: 100)))
        let expanded = WegramMediaAlbumLayout(itemSizes: sizes, maxSize: CGSize(width: 280, height: 320), outgoing: true, expanded: true)
        for index in sizes.indices {
            let frame = expanded.frames[index]
            XCTAssertEqual(expanded.hitIndex(at: CGPoint(x: frame.midX, y: frame.midY)), index)
        }
    }

    func testActualNodeOrderChangesFrontCardAndRestoresOnExpansion() {
        let parent = ASDisplayNode()
        let nodes = [ASDisplayNode(), ASDisplayNode(), ASDisplayNode()]
        for node in nodes { parent.addSubnode(node) }
        let sizes = Array(repeating: CGSize(width: 900, height: 1600), count: 3)
        WegramMediaAlbumLayout(itemSizes: sizes, maxSize: CGSize(width: 280, height: 320), outgoing: true, expanded: false).arrangeNodes(nodes)
        XCTAssertTrue(parent.subnodes?.last === nodes[0])
        XCTAssertTrue(parent.subnodes?.first === nodes[2])
        let expanded = WegramMediaAlbumLayout(itemSizes: sizes, maxSize: CGSize(width: 280, height: 320), outgoing: true, expanded: true)
        expanded.arrangeNodes(nodes)
        XCTAssertTrue(parent.subnodes?.last === nodes[2])
        XCTAssertTrue(parent.subnodes?.first === nodes[0])
        XCTAssertEqual(expanded.statusAnchor.y, expanded.size.height)
    }

    func testExpansionPreservesAspectRatioOrderAndMirrorsAlignmentWithoutOverlapping() {
        let sources = [CGSize(width: 900, height: 1600), CGSize(width: 600, height: 1400), CGSize(width: 1600, height: 900)]
        for outgoing in [false, true] {
            let layout = WegramMediaAlbumLayout(itemSizes: sources, maxSize: CGSize(width: 280, height: 320), outgoing: outgoing, expanded: true)
            XCTAssertEqual(layout.frames[0].size, CGSize(width: 112, height: 200))
            XCTAssertEqual(layout.frames[1].size, CGSize(width: 85, height: 200))
            XCTAssertEqual(layout.frames[2].size, CGSize(width: 150, height: 84))
            XCTAssertEqual(layout.size, CGSize(width: 150, height: 516))
            for index in sources.indices {
                XCTAssertEqual(layout.rotation(at: index), 0)
                XCTAssertTrue(layout.isVisible(at: index))
                XCTAssertEqual(outgoing ? layout.frames[index].maxX : layout.frames[index].minX, outgoing ? 150 : 0)
                if index > 0 { XCTAssertEqual(layout.frames[index].minY - layout.frames[index - 1].maxY, 16) }
            }
        }
    }

    func testPanoramasReserveEachFortyPointAvatarWithoutStretchingImages() {
        let layout = WegramMediaAlbumLayout(itemSizes: Array(repeating: CGSize(width: 1500, height: 100), count: 3), maxSize: CGSize(width: 280, height: 320), outgoing: true, expanded: true)
        XCTAssertEqual(layout.frames.map(\.height), [10, 10, 10])
        XCTAssertEqual(layout.frames.map(\.minY), [0, 56, 112])
        XCTAssertEqual(layout.size.height, 152)
        XCTAssertEqual(layout.statusAnchor.y, 122)
    }

    func testEmptyInvalidAndNarrowAlbumFramesRemainFinite() {
        for expanded in [false, true] {
            XCTAssertEqual(WegramMediaAlbumLayout(itemSizes: [], maxSize: CGSize(width: 280, height: 320), outgoing: true, expanded: expanded).size, .zero)
            let layout = WegramMediaAlbumLayout(itemSizes: [.zero, CGSize(width: CGFloat.infinity, height: 0)], maxSize: CGSize(width: 100, height: 80), outgoing: true, expanded: expanded)
            for frame in layout.frames {
                XCTAssertTrue(frame.width.isFinite && frame.height.isFinite)
                XCTAssertGreaterThan(frame.width, 0)
                XCTAssertGreaterThan(frame.height, 0)
                XCTAssertLessThanOrEqual(frame.maxX, 100)
            }
        }
    }

    func testRenderBothActualAlbumLayoutsForReferenceReview() throws {
        guard let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] else { return }
        let sources = [CGSize(width: 900, height: 1600), CGSize(width: 600, height: 1400), CGSize(width: 1600, height: 900)]
        for expanded in [false, true] {
            let layout = WegramMediaAlbumLayout(itemSizes: sources, maxSize: CGSize(width: 280, height: 320), outgoing: true, expanded: expanded)
            let view = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: layout.size.height + 32))
            view.backgroundColor = UIColor(white: 0.88, alpha: 1)
            for index in sources.indices.reversed() {
                let card = UIView(frame: layout.frames[index].offsetBy(dx: 342 - layout.size.width, dy: 16))
                card.backgroundColor = [UIColor.systemBrown, .systemGray, .systemBlue][index]
                card.layer.cornerRadius = 4
                card.transform = CGAffineTransform(rotationAngle: layout.rotation(at: index))
                view.addSubview(card)
                if expanded || index == 0 {
                    let avatar = UIView(frame: CGRect(x: 350, y: card.frame.minY, width: 40, height: 40))
                    avatar.backgroundColor = .systemTeal
                    avatar.layer.cornerRadius = 4
                    view.addSubview(avatar)
                }
            }
            let format = UIGraphicsImageRendererFormat(); format.scale = 3
            let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(expanded ? "photo-chat-album-expanded.png" : "photo-chat-album-folded.png"))
        }
    }
}
