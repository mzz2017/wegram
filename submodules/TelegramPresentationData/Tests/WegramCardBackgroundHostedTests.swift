import XCTest
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ChatMessageItemCommon
import ChatMessageBackground
import ChatMessageForwardInfoNode
import WallpaperBackgroundNode

private final class FileCardWallpaper: ASDisplayNode, WallpaperBackgroundNode {
    var isReady: Signal<Bool, NoError> { .single(true) }
    var rotation: CGFloat = 0
    var contentStats: WallpaperContentStats? { nil }
    var contentStatsUpdated: (() -> Void)?
    var bubbleRequests = 0
    func update(wallpaper: TelegramWallpaper, animated: Bool) {}
    func update(wallpaper: TelegramWallpaper, starGift: StarGift?, animated: Bool) {}
    func _internalUpdateIsSettingUpWallpaper() {}
    func updateLayout(size: CGSize, displayMode: WallpaperDisplayMode, transition: ContainedViewLayoutTransition) {}
    func updateIsLooping(_ isLooping: Bool) {}
    func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool) {}
    func updateBubbleTheme(bubbleTheme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners) {}
    func hasBubbleBackground(for type: WallpaperBubbleType) -> Bool { true }
    func makeBubbleBackground(for type: WallpaperBubbleType) -> WallpaperBubbleBackgroundNode? { self.bubbleRequests += 1; return nil }
    func makeFreeBackground() -> PortalView? { nil }
    func hasExtraBubbleBackground() -> Bool { false }
    func makeDimmedNode() -> ASDisplayNode? { nil }
    func makeEdgeEffectNode() -> WallpaperEdgeEffectNode? { nil }
}

final class WegramCardBackgroundHostedTests: XCTestCase {
    private func pixel(_ image: UIImage, x: CGFloat, y: CGFloat) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: x * image.scale, y: y * image.scale, width: 1, height: 1)))
        let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Array(UnsafeBufferPointer(start: try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self), count: 4))
    }

    func testNeutralCardUsesItsOwnPaletteAndRestoresWallpaperBehaviorOnReuse() throws {
        XCTAssertEqual(Set([PresentationChatBubbleCorners.wegram, .wegramCard]).count, 2)
        for theme in [defaultPresentationTheme, defaultDarkPresentationTheme] {
            let wallpaper: TelegramWallpaper = .color(0xeeeeee)
            let plain = PresentationResourcesChat.principalGraphics(theme: theme, wallpaper: wallpaper, bubbleCorners: .wegram)
            let card = PresentationResourcesChat.principalGraphics(theme: theme, wallpaper: wallpaper, bubbleCorners: .wegramCard)
            XCTAssertFalse(plain === card)
            XCTAssertTrue(card === PresentationResourcesChat.principalGraphics(theme: theme, wallpaper: wallpaper, bubbleCorners: .wegramCard))
            XCTAssertTrue(card.usesWegramNeutralFill)
            XCTAssertEqual(card.clockBubbleIncomingFrameImage.pngData(), card.clockBubbleOutgoingFrameImage.pngData())
            XCTAssertEqual(card.incomingDateAndStatusImpressionIcon.pngData(), card.outgoingDateAndStatusImpressionIcon.pngData())
            XCTAssertFalse(plain.usesWegramNeutralFill)
            let incoming = try self.pixel(card.chatMessageBackgroundIncomingImage, x: 10, y: 15)
            let outgoing = try self.pixel(card.chatMessageBackgroundOutgoingImage, x: 10, y: 15)
            XCTAssertEqual(incoming, outgoing)
            XCTAssertNotEqual(outgoing, try self.pixel(plain.chatMessageBackgroundOutgoingImage, x: 10, y: 15))
            let backdrop = ChatMessageBubbleBackdrop()
            let source = FileCardWallpaper()
            let data = ChatPresentationThemeData(theme: theme, wallpaper: wallpaper)
            backdrop.setType(type: .outgoing(.None), theme: data, essentialGraphics: plain, maskMode: true, backgroundNode: source)
            XCTAssertEqual(source.bubbleRequests, 1)
            backdrop.setType(type: .outgoing(.None), theme: data, essentialGraphics: card, maskMode: true, backgroundNode: source)
            XCTAssertEqual(source.bubbleRequests, 1)
            backdrop.setType(type: .outgoing(.None), theme: data, essentialGraphics: plain, maskMode: true, backgroundNode: source)
            XCTAssertEqual(source.bubbleRequests, 2)
            let node = ChatMessageBackground()
            node.frame = CGRect(x: 0, y: 0, width: 120, height: 80)
            node.updateLayout(size: node.frame.size, transition: ContainedViewLayoutTransition.immediate)
            node.setType(type: .outgoing(.None), highlighted: false, graphics: card, maskMode: true, hasWallpaper: true, transition: .immediate, backgroundNode: source)
            let rendered = UIGraphicsImageRenderer(size: node.frame.size).image { node.view.layer.render(in: $0.cgContext) }
            XCTAssertEqual(try self.pixel(rendered, x: 60, y: 40)[3], 255, "A wallpaper-backed chat must not hide the neutral card fill")
        }
    }

    func testNeutralHeaderPaletteAndForwardAppearanceRestoreWithoutChangingDirection() {
        let plain = PresentationChatBubbleCorners(mainRadius: 4, auxiliaryRadius: 4, mergeBubbleCorners: false)
        let invalidNeutral = PresentationChatBubbleCorners(mainRadius: 4, auxiliaryRadius: 4, mergeBubbleCorners: false, usesWegramNeutralFill: true)
        let outgoing = ChatMessageForwardInfoType.bubble(incoming: false)
        for theme in [defaultPresentationTheme, defaultDarkPresentationTheme] {
            for corners in [plain, .wegram, .wegramCard, .wegram, invalidNeutral] {
                let expectedIncoming = corners == .wegramCard
                let colors = corners.messageColors(theme: theme, incoming: false)
                XCTAssertTrue(colors === (expectedIncoming ? theme.chat.message.incoming : theme.chat.message.outgoing))
                XCTAssertTrue(corners.messageColors(theme: theme, incoming: true) === theme.chat.message.incoming)
                XCTAssertEqual(outgoing.appearanceType(bubbleCorners: corners), .bubble(incoming: expectedIncoming))
                XCTAssertEqual(ChatMessageForwardInfoType.bubble(incoming: true).appearanceType(bubbleCorners: corners), .bubble(incoming: true))
                XCTAssertEqual(ChatMessageForwardInfoType.standalone.appearanceType(bubbleCorners: corners), .standalone)
            }
            XCTAssertEqual(outgoing, .bubble(incoming: false), "Resolving colors must not mutate the actual message direction")
            XCTAssertTrue(PresentationChatBubbleCorners.wegram.messageColors(theme: theme, incoming: false) === theme.chat.message.outgoing)
        }
    }

}
