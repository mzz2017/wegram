import XCTest
import UIKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import AccountContext

final class WegramSavedConfirmationTests: XCTestCase {
    func testFavoriteRequiresExplicitSendAndConsumesCancelOrSendOnlyOnce() {
        for sending in [false, true] {
            let view = WegramSavedConfirmationView()
            view.update(recipient: "测试联系人", summary: "实际收藏摘要", dark: false, chinese: true, fontSize: 17)
            var sent: [String] = []
            var cancellations = 0
            view.send = { sent.append($0) }
            view.cancel = { cancellations += 1 }
            XCTAssertTrue(sent.isEmpty)
            view.comment.text = "附言 👋 保留输入"
            let button = sending ? view.sendButton : view.cancelButton
            button.sendActions(for: .touchUpInside)
            button.sendActions(for: .touchUpInside)
            (sending ? view.cancelButton : view.sendButton).sendActions(for: .touchUpInside)
            XCTAssertEqual(sent, sending ? ["附言 👋 保留输入"] : [])
            XCTAssertEqual(cancellations, sending ? 0 : 1)
        }
        let hidden = WegramSavedConfirmationView()
        hidden.isHidden = true
        var sent = false
        hidden.send = { _ in sent = true }
        hidden.sendButton.sendActions(for: .touchUpInside)
        XCTAssertFalse(sent)
    }

    func testRecipientCommentAndActionsFitLargeTypeAndSmallKeyboardViewport() throws {
        for dark in [false, true] {
            for font: CGFloat in [17, 26] {
                for width: CGFloat in [250, 320] {
                    let node = WegramSavedConfirmationContentNode()
                    XCTAssertEqual(node.containerCornerRadius, 4)
                    let view = node.content
                    view.update(recipient: "真实联系人姓名比较长，需要两行展示", summary: String(repeating: "收藏原文和文件摘要。", count: 40), dark: dark, chinese: true, fontSize: font)
                    view.comment.text = "不要因主题变化清空留言"
                    view.update(recipient: "真实联系人姓名比较长，需要两行展示", summary: String(repeating: "收藏原文和文件摘要。", count: 40), dark: dark, chinese: true, fontSize: font)
                    XCTAssertEqual(view.comment.text, "不要因主题变化清空留言")
                    let size = node.updateLayout(size: CGSize(width: width, height: 230), transition: .immediate)
                    XCTAssertEqual(size.width, width)
                    XCTAssertEqual(size.height, 230)
                    let scroll = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIScrollView }.first)
                    XCTAssertGreaterThan(scroll.contentSize.height, size.height)
                    XCTAssertLessThanOrEqual(view.heading.frame.maxY, view.recipient.frame.minY)
                    XCTAssertLessThanOrEqual(view.recipient.frame.maxY, view.summary.frame.minY)
                    XCTAssertLessThanOrEqual(view.summary.frame.maxY, view.comment.frame.minY)
                    XCTAssertLessThanOrEqual(view.comment.frame.maxY, view.sendButton.frame.minY)
                    for button in [view.cancelButton, view.sendButton] {
                        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
                        XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                        XCTAssertLessThanOrEqual(button.frame.maxX, width)
                        XCTAssertEqual(button.frame.maxY, scroll.contentSize.height)
                    }
                    XCTAssertEqual(view.avatarHost.frame.size, CGSize(width: 40, height: 40))
                    XCTAssertFalse(view.summary.isEditable)
                    XCTAssertEqual(view.backgroundColor, UIColor(rgb: dark ? 0x2c2c2c : 0xffffff))
                    if width == 320, font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        let format = UIGraphicsImageRendererFormat(); format.scale = 3
                        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("favorite-confirmation-\(dark ? "dark" : "light").png"))
                    }
                }
            }
        }
    }

    func testHiddenForwardingOptionsPreserveCommentAndNeverAlsoSend() throws {
        for accessible in [false, true] {
            let view = WegramSavedConfirmationView()
            view.update(recipient: "测试联系人", summary: "收藏", dark: false, chinese: true, fontSize: 17)
            view.comment.text = "转发附言 👋"
            var sent = false
            var options: [String] = []
            view.send = { _ in sent = true }
            view.options = { options.append($0) }
            if accessible {
                let action = try XCTUnwrap(view.sendButton.accessibilityCustomActions?.first)
                XCTAssertEqual(action.name, "转发选项")
                XCTAssertTrue(try XCTUnwrap(action.actionHandler)(action))
            } else {
                XCTAssertTrue(view.requestOptions())
            }
            view.sendButton.sendActions(for: .touchUpInside)
            XCTAssertFalse(view.requestOptions())
            XCTAssertFalse(sent)
            XCTAssertEqual(options, ["转发附言 👋"])
            XCTAssertTrue(view.sendButton.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer } == true)
        }
        let hidden = WegramSavedConfirmationView()
        hidden.alpha = 0
        XCTAssertFalse(hidden.requestOptions())
        hidden.alpha = 1
        hidden.isUserInteractionEnabled = false
        XCTAssertFalse(hidden.requestOptions())
    }

    func testForwardingEditorAppendsCommentWithoutReplacingSelectedRichDraft() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [ChatInputRun(text: "Title")])),
            .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "existing draft")]))
        ])
        let current = ChatTextInputState(content: content, selectionRange: 6 ..< 14)
        XCTAssertEqual(wegramSavedAttachmentDraftInput(current: current, comment: " \n "), current)
        let result = wegramSavedAttachmentDraftInput(current: current, comment: "  附言 👋  ")
        XCTAssertEqual(result.content.blocks.first, current.content.blocks.first)
        XCTAssertEqual(result.content.plainText, "Title\nexisting draft\n附言 👋")
        XCTAssertEqual(result.selectionRange, result.content.length ..< result.content.length)
        XCTAssertEqual(wegramSavedAttachmentDraftInput(current: ChatTextInputState(), comment: "附言").inputText.string, "附言")
        let emptyHeading = ChatTextInputState(content: ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: []))]), selectionRange: 0 ..< 0)
        let headingResult = wegramSavedAttachmentDraftInput(current: emptyHeading, comment: "附言")
        XCTAssertEqual(headingResult.content.plainText, "附言")
        guard case let .paragraph(paragraph) = headingResult.content.blocks.first else { return XCTFail("The empty heading remains a paragraph") }
        XCTAssertEqual(paragraph.style, .heading1)
    }

    func testEmptyCommentStillConfirmsAndSendsOnlyOnExplicitActivation() {
        let view = WegramSavedConfirmationView()
        var comments: [String] = []
        view.send = { comments.append($0) }
        XCTAssertTrue(comments.isEmpty)
        view.sendButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(comments, [""])
    }

    func testOptionalCommentDoesNotEnqueueAnEmptyMessageAndUsesOriginalTextSplitting() {
        XCTAssertTrue(wegramSavedAttachmentCommentParts("").isEmpty)
        XCTAssertTrue(wegramSavedAttachmentCommentParts(" \n ").isEmpty)
        XCTAssertEqual(wegramSavedAttachmentCommentParts("  附言 👋  ").map(\.string), ["附言 👋"])
        let text = String(repeating: "a", count: 4200)
        let parts = wegramSavedAttachmentCommentParts(text)
        XCTAssertEqual(parts.map(\.length), [4096, 104])
        XCTAssertEqual(parts.map(\.string).joined(), text)
    }

    func testRealAlertUsesSmallCornersAndKeepsPhotoPreviewAboveCommentWithKeyboard() throws {
        XCTAssertEqual(AlertContentNode().containerCornerRadius, 14, "Other Telegram alerts retain their existing corners")
        for dimensions in [CGSize(width: 120, height: 1000), CGSize(width: 1000, height: 120)] {
            let content = WegramSavedConfirmationContentNode()
            content.content.previewDimensions = dimensions
            content.content.update(recipient: "测试联系人", summary: "图片", dark: false, chinese: true, fontSize: 17)
            let controller = AlertController(theme: AlertControllerTheme(presentationData: defaultPresentationData()), contentNode: content)
            let root = controller.displayNode
            _ = root.view
            let size = CGSize(width: 402, height: 874)
            root.frame = CGRect(origin: .zero, size: size)
            controller.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: 285, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), transition: .immediate)
            XCTAssertEqual(content.supernode?.layer.cornerRadius, 4)
            XCTAssertEqual(content.frame.width, 320)
            let rect = content.view.convert(content.bounds, to: root.view)
            XCTAssertLessThanOrEqual(rect.maxY, 874 - 285)
            XCTAssertFalse(content.content.previewHost.isHidden)
            XCTAssertTrue(content.content.summary.isHidden)
            XCTAssertLessThanOrEqual(content.content.previewHost.frame.maxY, content.content.comment.frame.minY)
            XCTAssertGreaterThan(content.previewNode.frame.width, 0)
            XCTAssertGreaterThan(content.previewNode.frame.height, 0)
            XCTAssertLessThanOrEqual(content.previewNode.frame.maxX, content.content.previewHost.bounds.width)
            XCTAssertLessThanOrEqual(content.previewNode.frame.maxY, 166)
            XCTAssertEqual(content.previewNode.frame.width / content.previewNode.frame.height, dimensions.width / dimensions.height, accuracy: 0.01)
        }
    }

    func testTextSpoilersDoNotLeakIntoPlainConfirmationSummary() {
        let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(10))
        func message(_ entities: [MessageTextEntity]) -> EngineMessage {
            return EngineMessage(stableId: 1, stableVersion: 0, id: EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "剧透内容", attributes: [TextEntitiesMessageAttribute(entities: entities)], media: [], peers: [:], associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
        }
        XCTAssertTrue(wegramSavedAttachmentHasHiddenText(message([MessageTextEntity(range: 0 ..< 4, type: .Spoiler)])))
        XCTAssertFalse(wegramSavedAttachmentHasHiddenText(message([MessageTextEntity(range: 0 ..< 4, type: .Bold)])))
        XCTAssertFalse(wegramSavedAttachmentHasHiddenText(message([])))
    }

    func testFavoritePermissionsFollowActualMediaTypeAndComment() {
        func file(_ attributes: [TelegramMediaFileAttribute]) -> EngineMedia {
            return .file(TelegramMediaFile(fileId: MediaId(namespace: 0, id: 40), partialReference: nil, resource: LocalFileMediaResource(fileId: 40), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/octet-stream", size: nil, attributes: attributes, alternativeRepresentations: []))
        }
        let cases: [(EngineMedia, TelegramChatBannedRightsFlags)] = [
            (.image(TelegramMediaImage(imageId: MediaId(namespace: 0, id: 30), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])), .banSendPhotos),
            (file([]), .banSendFiles),
            (file([.Animated]), .banSendGifs),
            (file([.Audio(isVoice: true, duration: 1, title: nil, performer: nil, waveform: nil)]), .banSendVoice),
            (file([.Audio(isVoice: false, duration: 1, title: nil, performer: nil, waveform: nil)]), .banSendMusic),
            (file([.Video(duration: 1, size: PixelDimensions(width: 640, height: 480), flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)]), .banSendVideos),
            (file([.Video(duration: 1, size: PixelDimensions(width: 640, height: 480), flags: [.instantRoundVideo], preloadSize: nil, coverTime: nil, videoCodec: nil)]), .banSendInstantVideos)
        ]
        XCTAssertEqual(wegramSavedAttachmentRequiredPermissions(media: [], hasComment: false), [.banSendText])
        for (media, right) in cases {
            XCTAssertEqual(wegramSavedAttachmentRequiredPermissions(media: [media], hasComment: false), [right])
            XCTAssertEqual(wegramSavedAttachmentRequiredPermissions(media: [media], hasComment: true), [right, .banSendText])
        }
    }
}
