import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import ChatListUI
import AccountContext
import PhotoResources
import LocationResources

final class WegramSavedAttachmentItem: ListViewItem {
    let context: AccountContext
    let message: EngineMessage
    let data: ChatListPresentationData
    let action: () -> Void
    let query: String
    var neighborDescriptor: AnyEquatable { return AnyEquatable.noNeighborInfluence }
    init(context: AccountContext, message: EngineMessage, data: ChatListPresentationData, query: String, action: @escaping () -> Void) {
        self.context = context; self.message = message; self.data = data; self.query = query; self.action = action
    }
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        Queue.mainQueue().async {
            let node = WegramSavedAttachmentItemNode()
            let layout = node.update(item: self, params: params)
            node.contentSize = layout.contentSize; node.insets = layout.insets
            completion(node, { (nil, { _ in }) })
        }
    }
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let node = node() as? WegramSavedAttachmentItemNode else { return }
            let measurement = WegramSavedAttachmentCardView()
            _ = self.updateCard(measurement)
            let width = max(0, params.width - params.leftInset - params.rightInset)
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: measurement.preferredHeight(width: width)), insets: .zero)
            completion(layout, { _ in _ = node.update(item: self, params: params) })
        }
    }
    func updateCard(_ card: WegramSavedAttachmentCardView) -> (preview: (CGSize, Signal<(TransformImageArguments) -> DrawingContext?, NoError>)?, icon: UIImage?) {
        let data = self.data
        let message = self.message
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let previewText = descriptionStringForMessage(contentSettings: self.context.currentContentSettings.with { $0 }, message: message, strings: data.strings, nameDisplayOrder: data.nameDisplayOrder, dateTimeFormat: data.dateTimeFormat, accountPeerId: self.context.account.peerId).0
        let hidden = wegramSavedAttachmentHasHiddenText(message, preview: previewText)
        let description = previewText.string
        var title = hidden ? (chinese ? "[剧透内容]" : "[Spoiler]") : description
        var subtitle = ""
        if !hidden, !message.text.isEmpty, message.richText == nil {
            let lines = message.text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            title = lines.first ?? description
            subtitle = lines.dropFirst().joined(separator: " ")
        }
        let original = message._asMessage()
        let sourceName = wegramSavedAttachmentSource(forwardInfo: original.forwardInfo, author: message.author)
        var preview: (CGSize, Signal<(TransformImageArguments) -> DrawingContext?, NoError>)?
        var icon: UIImage?
        if !original.containsSecretMedia {
            let blurred = message.attributes.contains { $0 is MediaSpoilerMessageAttribute }
            for media in message.engineMedia {
                if case let .image(image) = media, let representation = largestRepresentationForPhoto(image), representation.dimensions.width > 0, representation.dimensions.height > 0 {
                    preview = (representation.dimensions.cgSize, chatMessagePhotoThumbnail(account: self.context.account, userLocation: .peer(message.id.peerId), photoReference: .message(message: MessageReference(original), media: image), blurred: blurred))
                    break
                } else if case let .file(file) = media {
                    if let document = WegramSavedAttachmentDocument(file: file, caption: message.text, captionIsHidden: hidden, strings: data.strings, decimalSeparator: data.dateTimeFormat.decimalSeparator) {
                        title = document.title
                        subtitle = document.subtitle
                        icon = document.icon
                    } else {
                        let artwork: WegramIcon = file.isMusic ? .attachmentMusic : (file.isVideo ? .attachmentVideo : .attachmentFile)
                        icon = artwork.image()?.withRenderingMode(.alwaysTemplate)
                    }
                    if file.isVideo, !file.isInstantVideo, let representation = largestImageRepresentation(file.previewRepresentations), representation.dimensions.width > 0, representation.dimensions.height > 0 {
                        preview = (representation.dimensions.cgSize, chatMessageVideoThumbnail(account: self.context.account, userLocation: .peer(message.id.peerId), fileReference: .message(message: MessageReference(original), media: file), blurred: blurred))
                    }
                    break
                } else if case let .geo(map) = media, !blurred,
                          let location = WegramSavedAttachmentLocation(map: map, caption: message.text, captionIsHidden: hidden, strings: data.strings) {
                    title = location.title
                    subtitle = location.subtitle
                    preview = (CGSize(width: 56, height: 56), chatMapSnapshotImage(engine: self.context.engine, resource: MapSnapshotMediaResource(latitude: map.latitude, longitude: map.longitude, width: 56, height: 56)))
                    break
                } else if case let .webpage(webpage) = media,
                          let link = WegramSavedAttachmentLink(webpage: webpage, caption: message.text, captionIsHidden: hidden) {
                    title = link.title
                    subtitle = link.subtitle
                    if let image = link.image, let representation = largestRepresentationForPhoto(image), representation.dimensions.width > 0, representation.dimensions.height > 0 {
                        preview = (representation.dimensions.cgSize, chatMessagePhotoThumbnail(account: self.context.account, userLocation: .peer(message.id.peerId), photoReference: .webPage(webPage: WebpageReference(webpage), media: image), blurred: blurred))
                    }
                    break
                }
            }
        }
        card.update(title: title, subtitle: subtitle, source: sourceName, date: wegramSavedAttachmentDate(timestamp: message.timestamp, chinese: chinese), hasThumbnail: preview != nil || icon != nil, dark: data.theme.overallDarkAppearance, fontSize: data.fontSize.baseDisplaySize, query: self.query, highlightContent: !hidden)
        return (preview, icon)
    }

}

private final class WegramSavedAttachmentItemNode: ListViewItemNode {
    private let card = WegramSavedAttachmentCardView()
    private var imageNode: TransformImageNode?
    init() {
        super.init(layerBacked: false)
        self.view.addSubview(self.card)
    }
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        guard let item = item as? WegramSavedAttachmentItem else { return }
        let layout = self.update(item: item, params: params)
        self.contentSize = layout.contentSize; self.insets = layout.insets
    }
    func update(item: WegramSavedAttachmentItem, params: ListViewItemLayoutParams) -> ListViewItemNodeLayout {
        self.imageNode?.view.removeFromSuperview()
        self.imageNode = nil
        self.card.thumbnailHost.subviews.forEach { $0.removeFromSuperview() }
        let (preview, icon) = item.updateCard(self.card)
        self.card.pressed = item.action
        self.backgroundColor = UIColor(rgb: item.data.theme.overallDarkAppearance ? 0x202020 : 0xededed)
        let width = max(0, params.width - params.leftInset - params.rightInset)
        let height = self.card.preferredHeight(width: width)
        self.card.frame = CGRect(x: params.leftInset, y: 0, width: width, height: height)
        self.card.layoutIfNeeded()
        if let (dimensions, signal) = preview {
            let node = TransformImageNode()
            self.imageNode = node
            self.card.thumbnailHost.addSubview(node.view)
            node.frame = self.card.thumbnailHost.bounds
            node.setSignal(signal)
            node.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 0), imageSize: dimensions.aspectFilled(node.bounds.size), boundingSize: node.bounds.size, intrinsicInsets: .zero))()
        } else if let icon {
            let image = UIImageView(image: icon)
            image.tintColor = UIColor(rgb: item.data.theme.overallDarkAppearance ? 0xd0d0d0 : 0x4c4c4c)
            image.contentMode = .scaleAspectFit
            let inset: CGFloat = icon.renderingMode == .alwaysOriginal ? 6 : 10
            image.frame = self.card.thumbnailHost.bounds.insetBy(dx: inset, dy: inset)
            self.card.thumbnailHost.addSubview(image)
        }
        return ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: height), insets: .zero)
    }
}
