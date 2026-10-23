import XCTest
import Postbox
import TelegramCore

final class WegramComposerMediaPreviewTests: XCTestCase {
    private var messageId: EngineMessage.Id { MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 1) }
    private let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(10))

    private func representation(_ width: Int32 = 640, _ height: Int32 = 480) -> TelegramMediaImageRepresentation {
        return TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: width, height: height), resource: LocalFileMediaResource(fileId: 20), progressiveSizes: [], immediateThumbnailData: nil)
    }

    private func image(_ representations: [TelegramMediaImageRepresentation]? = nil) -> TelegramMediaImage {
        return TelegramMediaImage(imageId: MediaId(namespace: 0, id: 30), representations: representations ?? [self.representation()], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
    }

    private func file(video: Bool, round: Bool = false, previews: Bool = true) -> TelegramMediaFile {
        let attributes: [TelegramMediaFileAttribute] = video ? [.Video(duration: 1, size: PixelDimensions(width: 640, height: 480), flags: round ? [.instantRoundVideo] : [], preloadSize: nil, coverTime: nil, videoCodec: nil)] : []
        return TelegramMediaFile(fileId: MediaId(namespace: 0, id: 40), partialReference: nil, resource: LocalFileMediaResource(fileId: 40), previewRepresentations: previews ? [self.representation()] : [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: video ? "video/mp4" : "application/pdf", size: nil, attributes: attributes, alternativeRepresentations: [])
    }

    private func message(_ media: Media, attributes: [MessageAttribute] = [], flags: MessageFlags = []) -> EngineMessage {
        return EngineMessage(stableId: 1, stableVersion: 0, id: MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: flags, tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: attributes, media: [EngineMedia(media)], peers: [:], associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
    }

    func testPhotoAndVideoUseActualMessageMediaAndSpoilerState() throws {
        for media: Media in [self.image(), self.file(video: true)] {
            let plain = try XCTUnwrap(WegramComposerMediaPreview(message: self.message(media), replyingTo: self.messageId))
            XCTAssertTrue(plain.reference.media.isEqual(to: media))
            XCTAssertEqual(plain.dimensions, CGSize(width: 640, height: 480))
            XCTAssertFalse(plain.blurred)
            XCTAssertTrue(try XCTUnwrap(WegramComposerMediaPreview(message: self.message(media, attributes: [MediaSpoilerMessageAttribute()]), replyingTo: self.messageId)).blurred)
            XCTAssertNotNil(WegramComposerMediaPreview(message: self.message(media, flags: [.CopyProtected]), replyingTo: self.messageId))
        }
    }

    func testSelfDestructingMediaNeverProducesAPreview() {
        for media: Media in [self.image(), self.file(video: true)] {
            for timeout: Int32 in [1, 60, viewOnceTimeout] {
                let message = self.message(media, attributes: [AutoremoveTimeoutMessageAttribute(timeout: timeout, countdownBeginTime: nil)])
                XCTAssertTrue(message.containsSecretMedia)
                XCTAssertNil(WegramComposerMediaPreview(message: message, replyingTo: self.messageId))
            }
        }
    }

    func testChangingReplyTargetRejectsThePreviousCachedImage() {
        let cached = self.message(self.image())
        XCTAssertNotNil(WegramComposerMediaPreview(message: cached, replyingTo: self.messageId))
        for nextId in [MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 2), MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(99)), namespace: Namespaces.Message.Cloud, id: 1)] {
            XCTAssertNil(WegramComposerMediaPreview(message: cached, replyingTo: nextId))
        }
    }

    func testMissingOrInvalidThumbnailsAndOtherMediaKeepTextOnly() {
        for media: Media in [self.image([]), self.image([self.representation(0, 480)]), self.file(video: true, round: true), self.file(video: true, previews: false), self.file(video: false)] {
            XCTAssertNil(WegramComposerMediaPreview(message: self.message(media), replyingTo: self.messageId))
        }
    }
}
