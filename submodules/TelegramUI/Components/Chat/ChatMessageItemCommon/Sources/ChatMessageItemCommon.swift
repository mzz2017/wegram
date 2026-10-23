import Foundation
import UIKit
import Display
import TelegramCore
import Emoji

public struct WegramLiveLocationMessageLayout {
    public let iconFrame: CGRect
    public let titleFrame: CGRect
    public let statusFrame: CGRect
    public let height: CGFloat

    public static func supports(_ map: TelegramMediaMap) -> Bool {
        return map.liveBroadcastingTimeout != nil && map.latitude.isFinite && map.longitude.isFinite
            && (-90 ... 90).contains(map.latitude) && (-180 ... 180).contains(map.longitude)
    }

    public static func title(active: Bool, chinese: Bool) -> String {
        return chinese ? (active ? "共享实时位置" : "位置共享已结束") : (active ? "Sharing live location" : "Live location sharing ended")
    }

    public static func textWidth(_ width: CGFloat) -> CGFloat { return max(0, min(250, width) - 54) }

    public static func width(available: CGFloat, title: CGFloat, status: CGFloat) -> CGFloat {
        return max(0, min(250, available, max(72, title + 54, status + 20)))
    }

    public init(width: CGFloat, titleSize: CGSize, statusSize: CGSize, incoming: Bool) {
        let width = max(0, width)
        let inset = min(12, width / 2)
        let iconWidth = min(22, max(0, width - inset * 2))
        let gap = min(8, max(0, width - inset * 2 - iconWidth))
        let textWidth = max(0, width - inset * 2 - iconWidth - gap)
        let rowHeight = max(26, titleSize.height)
        self.iconFrame = CGRect(x: incoming ? inset : width - inset - iconWidth, y: 12 + (rowHeight - 26) / 2, width: iconWidth, height: 26)
        self.titleFrame = CGRect(x: incoming ? inset + iconWidth + gap : inset, y: 12 + (rowHeight - titleSize.height) / 2, width: min(textWidth, titleSize.width), height: titleSize.height)
        self.statusFrame = CGRect(x: max(0, width - inset - statusSize.width), y: 12 + rowHeight + 12 + (statusSize.height > 0 ? 6 : 0), width: min(width, statusSize.width), height: statusSize.height)
        self.height = self.statusFrame.maxY
    }

    public static func icon(color: UIColor) -> UIImage {
        return UIGraphicsImageRenderer(size: CGSize(width: 22, height: 26)).image { renderer in
            let context = renderer.cgContext
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.8)
            context.setLineJoin(.round)
            context.move(to: CGPoint(x: 11, y: 25))
            context.addCurve(to: CGPoint(x: 2, y: 10), control1: CGPoint(x: 8, y: 21), control2: CGPoint(x: 2, y: 15))
            context.addCurve(to: CGPoint(x: 20, y: 10), control1: CGPoint(x: 2, y: -2), control2: CGPoint(x: 20, y: -2))
            context.addCurve(to: CGPoint(x: 11, y: 25), control1: CGPoint(x: 20, y: 15), control2: CGPoint(x: 14, y: 21))
            context.closePath()
            context.strokePath()
            context.strokeEllipse(in: CGRect(x: 7.5, y: 6.5, width: 7, height: 7))
        }
    }
}

public struct WegramMapMessageLayout {
    public let titleFrame: CGRect
    public let addressFrame: CGRect
    public let imageFrame: CGRect
    public let statusFrame: CGRect
    public let height: CGFloat

    public static func supports(_ map: TelegramMediaMap) -> Bool {
        return map.liveBroadcastingTimeout == nil && map.latitude.isFinite && map.longitude.isFinite
            && (-90 ... 90).contains(map.latitude) && (-180 ... 180).contains(map.longitude)
    }

    public static func title(_ map: TelegramMediaMap, fallback: String) -> String {
        if let title = map.venue?.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        return fallback
    }

    public static func address(_ map: TelegramMediaMap) -> String {
        if let address = map.venue?.address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return address }
        if let address = map.address {
            let components = [address.state, address.city, address.street].compactMap { value -> String? in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return value
            }
            if !components.isEmpty { return components.joined(separator: " ") }
        }
        return String(format: "%.5f, %.5f", locale: Locale(identifier: "en_US_POSIX"), map.latitude, map.longitude)
    }

    public static func imageSize(width: CGFloat) -> CGSize {
        let width = max(0, min(250, width))
        return CGSize(width: width, height: floor(width * 96 / 250))
    }

    public init(width: CGFloat, titleSize: CGSize, addressSize: CGSize, statusSize: CGSize) {
        let inset = min(12, max(0, width / 2))
        let textWidth = max(0, width - inset * 2)
        self.titleFrame = CGRect(x: inset, y: 10, width: min(textWidth, titleSize.width), height: titleSize.height)
        self.addressFrame = CGRect(x: inset, y: self.titleFrame.maxY + (titleSize.height > 0 && addressSize.height > 0 ? 4 : 0), width: min(textWidth, addressSize.width), height: addressSize.height)
        self.imageFrame = CGRect(origin: CGPoint(x: 0, y: self.addressFrame.maxY + 5), size: Self.imageSize(width: width))
        self.statusFrame = CGRect(x: max(0, width - inset - statusSize.width), y: self.imageFrame.maxY + (statusSize.height > 0 ? 6 : 0), width: statusSize.width, height: statusSize.height)
        self.height = self.statusFrame.maxY
    }

    public static func pinFrame(originalFrame: CGRect, mapSize: CGSize) -> CGRect? {
        let point = CGPoint(x: originalFrame.minX + 31, y: originalFrame.minY + 64)
        guard point.x > 0, point.x < mapSize.width, point.y > 0, point.y <= mapSize.height else { return nil }
        let scale = min(1, point.y / 41, point.x / 12.5, (mapSize.width - point.x) / 12.5)
        return CGRect(x: point.x - 31 * scale, y: point.y - 64 * scale, width: 62 * scale, height: 74 * scale)
    }

    // Keep the original 62×74 canvas and point (31, 64), so the marker's map coordinate does not move.
    public static let pinImage: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 62, height: 74)).image { output in
        let context = output.cgContext
        let green = UIColor(rgb: 0x07c160)
        context.setStrokeColor(green.cgColor)
        context.setLineWidth(3)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: 31, y: 46))
        context.addLine(to: CGPoint(x: 31, y: 62.5))
        context.strokePath()
        context.setFillColor(green.cgColor)
        context.fillEllipse(in: CGRect(x: 18.5, y: 23, width: 25, height: 25))
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 24.75, y: 29.25, width: 12.5, height: 12.5))
    }
}

public struct WegramContactMessageLayout {
    public let avatarFrame: CGRect
    public let titleFrame: CGRect
    public let separatorFrame: CGRect
    public let labelFrame: CGRect
    public let height: CGFloat

    public static func titleWidth(_ width: CGFloat) -> CGFloat {
        let inset = min(12, max(0, width / 4))
        let avatar = min(44, max(0, (width - inset * 2) / 3))
        return max(0, width - inset * 2 - avatar - 12)
    }

    public static func label(chinese: Bool) -> String {
        return chinese ? "个人名片" : "Contact Card"
    }

    public init(width: CGFloat, titleSize: CGSize, labelSize: CGSize) {
        let inset = min(12, max(0, width / 4))
        let contentWidth = max(0, width - inset * 2)
        let avatar = min(44, contentWidth / 3)
        let rowHeight = max(44, titleSize.height)
        self.avatarFrame = CGRect(x: inset, y: 12 + floor((rowHeight - avatar) / 2), width: avatar, height: avatar)
        self.titleFrame = CGRect(x: min(width - inset, self.avatarFrame.maxX + 12), y: 12 + floor((rowHeight - titleSize.height) / 2), width: min(Self.titleWidth(width), titleSize.width), height: titleSize.height)
        self.separatorFrame = CGRect(x: inset, y: 12 + rowHeight + 12, width: contentWidth, height: UIScreenPixel)
        self.labelFrame = CGRect(x: inset, y: self.separatorFrame.maxY + 4, width: min(contentWidth, labelSize.width), height: labelSize.height)
        self.height = self.labelFrame.maxY + 5
    }
}

public struct WegramFileMessageLayout {
    public let titleFrame: CGRect
    public let descriptionFrame: CGRect
    public let controlFrame: CGRect
    public let height: CGFloat

    public static func supports(_ file: TelegramMediaFile) -> Bool {
        guard !file.isVoice, !file.isMusic, !file.isInstantVideo, !file.isVideo,
              !file.isAnimated, !file.isSticker, !file.isAnimatedSticker, !file.isCustomEmoji else { return false }
        for attribute in file.attributes {
            if case .Audio = attribute { return false }
        }
        return true
    }

    public static func textWidth(_ width: CGFloat) -> CGFloat {
        return max(0, width - min(44, max(0, width / 3)) - 14)
    }

    public init(width: CGFloat, titleSize: CGSize, descriptionSize: CGSize) {
        let side = min(44, max(0, width / 3))
        let textHeight = titleSize.height + (titleSize.height > 0 && descriptionSize.height > 0 ? 4 : 0) + descriptionSize.height
        self.height = max(44, textHeight)
        let textWidth = Self.textWidth(width)
        self.titleFrame = CGRect(x: 0, y: floor((self.height - textHeight) / 2), width: min(textWidth, titleSize.width), height: titleSize.height)
        self.descriptionFrame = CGRect(x: 0, y: self.titleFrame.maxY + (titleSize.height > 0 && descriptionSize.height > 0 ? 4 : 0), width: min(textWidth, descriptionSize.width), height: descriptionSize.height)
        self.controlFrame = CGRect(x: max(0, width - side), y: floor((self.height - side) / 2), width: side, height: side)
    }

    private static let icons = NSCache<NSString, UIImage>()
    public static func icon(fileName: String?) -> UIImage {
        let value = fileName.map { ($0 as NSString).pathExtension.uppercased() } ?? ""
        let label = value.isEmpty ? "FILE" : String(value.prefix(4))
        let color: UIColor
        switch value {
        case "PDF": color = UIColor(rgb: 0xda484c)
        case "DOC", "DOCX": color = UIColor(rgb: 0x4a8ddd)
        case "XLS", "XLSX", "CSV": color = UIColor(rgb: 0x2ca66f)
        case "PPT", "PPTX": color = UIColor(rgb: 0xe88344)
        default: color = UIColor(rgb: 0x8a9aab)
        }
        let key = "\(label)-\(color.argb)" as NSString
        if let image = self.icons.object(forKey: key) { return image }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 44, height: 44)).image { output in
            let context = output.cgContext
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 7, y: 2))
            path.addQuadCurve(to: CGPoint(x: 9, y: 0), controlPoint: CGPoint(x: 7, y: 0))
            path.addLine(to: CGPoint(x: 27, y: 0))
            path.addLine(to: CGPoint(x: 37, y: 10))
            path.addLine(to: CGPoint(x: 37, y: 42))
            path.addQuadCurve(to: CGPoint(x: 35, y: 44), controlPoint: CGPoint(x: 37, y: 44))
            path.addLine(to: CGPoint(x: 9, y: 44))
            path.addQuadCurve(to: CGPoint(x: 7, y: 42), controlPoint: CGPoint(x: 7, y: 44))
            path.close()
            color.setFill()
            path.fill()
            context.setFillColor(color.withMultipliedBrightnessBy(0.8).cgColor)
            context.move(to: CGPoint(x: 27, y: 0))
            context.addLine(to: CGPoint(x: 27, y: 10))
            context.addLine(to: CGPoint(x: 37, y: 10))
            context.closePath()
            context.fillPath()
            let font = Font.regular(label.count > 3 ? 9 : 11)
            let string = NSAttributedString(string: label, font: font, textColor: .white)
            let size = string.size()
            string.draw(at: CGPoint(x: floor((44 - size.width) / 2), y: 25))
        }
        self.icons.setObject(image, forKey: key)
        return image
    }
}

public struct WegramLinkPreviewLayout {
    public let titleFrame: CGRect
    public let summaryFrame: CGRect
    public let thumbnailFrame: CGRect
    public let sourceFrame: CGRect
    public let height: CGFloat

    public static func supports(_ content: TelegramMediaWebpageLoadedContent) -> Bool {
        guard content.type == nil || content.type == "article",
              content.file == nil, content.story == nil, content.instantPage == nil,
              content.embedUrl == nil, content.attributes.isEmpty,
              let url = URL(string: content.url), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http", let host = url.host?.lowercased(),
              !["t.me", "telegram.me", "telegram.dog"].contains(host),
              !(content.title ?? "").isEmpty || !(content.text ?? "").isEmpty else { return false }
        return true
    }

    public static func hidesURLText(_ text: String, content: TelegramMediaWebpageLoadedContent, forceLargeMedia: Bool?) -> Bool {
        return forceLargeMedia != true && self.supports(content) && text.trimmingCharacters(in: .whitespacesAndNewlines) == content.url
    }

    public static func thumbnailSize(imageSize: CGSize?, contentWidth: CGFloat) -> CGSize {
        guard let imageSize, imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let side = min(54, max(0, contentWidth / 3))
        return imageSize.aspectFitted(CGSize(width: side, height: side))
    }

    public init(width: CGFloat, titleSize: CGSize, summarySize: CGSize, sourceSize: CGSize, thumbnailSize: CGSize) {
        let inset = min(10, max(0, width / 2))
        let contentWidth = max(0, width - inset * 2)
        self.titleFrame = CGRect(x: inset, y: 12, width: min(contentWidth, titleSize.width), height: titleSize.height)
        let rowY = self.titleFrame.maxY + (titleSize.height > 0 && (summarySize.height > 0 || thumbnailSize.height > 0) ? 8 : 0)
        self.thumbnailFrame = CGRect(x: width - inset - thumbnailSize.width, y: rowY + floor(max(0, summarySize.height - thumbnailSize.height) / 2), width: thumbnailSize.width, height: thumbnailSize.height)
        self.summaryFrame = CGRect(x: inset, y: rowY, width: min(summarySize.width, max(0, contentWidth - (thumbnailSize.width > 0 ? thumbnailSize.width + 12 : 0))), height: summarySize.height)
        let rowBottom = max(self.summaryFrame.maxY, self.thumbnailFrame.maxY)
        self.sourceFrame = CGRect(x: inset, y: rowBottom + (sourceSize.height > 0 ? 20 : 0), width: min(contentWidth, sourceSize.width), height: sourceSize.height)
        self.height = self.sourceFrame.maxY + 10
    }
}

public struct WegramVoiceMessageLayout {
    public let controlFrame: CGRect
    public let durationFrame: CGRect
    public let height: CGFloat

    public init(width: CGFloat, outgoing: Bool, durationSize: CGSize, showsProgress: Bool = false) {
        if showsProgress {
            let side = min(44, max(0, width))
            self.controlFrame = CGRect(x: min(3, max(0, width - side)), y: -3, width: side, height: side)
            self.durationFrame = CGRect(x: min(56, width), y: 22, width: min(durationSize.width, max(0, width - 56)), height: durationSize.height)
            self.height = max(44, self.durationFrame.maxY)
            return
        }
        let side = min(32, max(0, width))
        self.height = max(32, durationSize.height)
        self.controlFrame = CGRect(x: outgoing ? width - side : 0, y: floor((self.height - side) / 2), width: side, height: side)
        let labelWidth = min(durationSize.width, max(0, width - side - 4))
        self.durationFrame = CGRect(x: outgoing ? max(0, self.controlFrame.minX - 4 - labelWidth) : min(width, self.controlFrame.maxX + 4), y: floor((self.height - durationSize.height) / 2), width: labelWidth, height: durationSize.height)
    }

    public static func progressActionTitle(chinese: Bool, expanded: Bool) -> String {
        return chinese ? (expanded ? "收起进度" : "播放进度") : (expanded ? "Hide Progress" : "Playback Progress")
    }

    public static func transcriptionActionTitle(chinese: Bool, expanded: Bool) -> String {
        return chinese ? (expanded ? "收起文字" : "转文字") : (expanded ? "Hide Transcript" : "Transcribe")
    }

    public static func accessibilityActions(chinese: Bool, progressExpanded: Bool?, transcriptionExpanded: Bool?, transcribe: @escaping () -> Bool, toggleProgress: @escaping () -> Bool) -> [UIAccessibilityCustomAction] {
        guard let progressExpanded else { return [] }
        var result: [UIAccessibilityCustomAction] = []
        if let transcriptionExpanded {
            result.append(UIAccessibilityCustomAction(name: self.transcriptionActionTitle(chinese: chinese, expanded: transcriptionExpanded), actionHandler: { _ in transcribe() }))
        }
        result.append(UIAccessibilityCustomAction(name: self.progressActionTitle(chinese: chinese, expanded: progressExpanded), actionHandler: { _ in toggleProgress() }))
        return result
    }

    public static func duration(_ seconds: Int32) -> String { "\(max(0, seconds))″" }

    public static func contentWidth(duration: Int32, labelWidth: CGFloat, availableWidth: CGFloat, showsProgress: Bool) -> CGFloat {
        let proportional = 52 + CGFloat(min(60, max(1, duration)) - 1) * 3
        return min(max(0, availableWidth), max(showsProgress ? 160 : proportional, labelWidth + 36))
    }

    private static let icons = NSCache<NSString, UIImage>()
    public static func icon(color: UIColor, outgoing: Bool, phase: Int = 3) -> UIImage {
        let count = min(3, max(1, phase))
        let key = "\(color.argb)-\(outgoing)-\(count)" as NSString
        if let image = self.icons.object(forKey: key) { return image }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { output in
            let context = output.cgContext
            if outgoing {
                context.translateBy(x: 24, y: 0)
                context.scaleBy(x: -1, y: 1)
            }
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(x: 3, y: 10, width: 3, height: 4))
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.6)
            context.setLineCap(.round)
            for index in 0 ..< count {
                context.addArc(center: CGPoint(x: 4, y: 12), radius: CGFloat(3 + index * 4), startAngle: -.pi / 4, endAngle: .pi / 4, clockwise: false)
                context.strokePath()
            }
        }
        self.icons.setObject(image, forKey: key)
        return image
    }

    public static let unreadIcon: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 6, height: 6)).image { output in
        UIColor(rgb: 0xfa5151).setFill()
        output.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 6, height: 6))
    }
}

public func wegramStickerMediaSnapshot(contentView: UIView, mediaFrame: CGRect, clippingRect: CGRect?) -> (UIImage, CGRect)? {
    guard mediaFrame.width > 0, mediaFrame.height > 0 else { return nil }
    UIGraphicsBeginImageContextWithOptions(mediaFrame.size, false, 0)
    defer { UIGraphicsEndImageContext() }
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    context.translateBy(x: -mediaFrame.minX, y: -mediaFrame.minY)
    if let clippingRect { context.clip(to: clippingRect) }
    contentView.layer.render(in: context)
    guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
    return (image, mediaFrame)
}

public struct ChatMessageItemWidthFill {
    public var compactInset: CGFloat
    public var compactWidthBoundary: CGFloat
    public var freeMaximumFillFactor: CGFloat
    
    public func widthFor(_ width: CGFloat) -> CGFloat {
        if width <= self.compactWidthBoundary {
            return max(1.0, width - self.compactInset)
        } else {
            return max(1.0, floor(width * self.freeMaximumFillFactor))
        }
    }
}

public struct ChatMessageItemBubbleLayoutConstants {
    public var edgeInset: CGFloat
    public var defaultSpacing: CGFloat
    public var mergedSpacing: CGFloat
    public var maximumWidthFill: ChatMessageItemWidthFill
    public var minimumSize: CGSize
    public var contentInsets: UIEdgeInsets
    public var borderInset: CGFloat
    public var strokeInsets: UIEdgeInsets
    
    public init(edgeInset: CGFloat, defaultSpacing: CGFloat, mergedSpacing: CGFloat, maximumWidthFill: ChatMessageItemWidthFill, minimumSize: CGSize, contentInsets: UIEdgeInsets, borderInset: CGFloat, strokeInsets: UIEdgeInsets) {
        self.edgeInset = edgeInset
        self.defaultSpacing = defaultSpacing
        self.mergedSpacing = mergedSpacing
        self.maximumWidthFill = maximumWidthFill
        self.minimumSize = minimumSize
        self.contentInsets = contentInsets
        self.borderInset = borderInset
        self.strokeInsets = strokeInsets
    }
}

public struct ChatMessageItemTextLayoutConstants {
    public var bubbleInsets: UIEdgeInsets
    
    public init(bubbleInsets: UIEdgeInsets) {
        self.bubbleInsets = bubbleInsets
    }
}

public struct ChatMessageItemImageLayoutConstants {
    public var bubbleInsets: UIEdgeInsets
    public var statusInsets: UIEdgeInsets
    public var defaultCornerRadius: CGFloat
    public var mergedCornerRadius: CGFloat
    public var contentMergedCornerRadius: CGFloat
    public var maxDimensions: CGSize
    public var minDimensions: CGSize
    
    public init(bubbleInsets: UIEdgeInsets, statusInsets: UIEdgeInsets, defaultCornerRadius: CGFloat, mergedCornerRadius: CGFloat, contentMergedCornerRadius: CGFloat, maxDimensions: CGSize, minDimensions: CGSize) {
        self.bubbleInsets = bubbleInsets
        self.statusInsets = statusInsets
        self.defaultCornerRadius = defaultCornerRadius
        self.mergedCornerRadius = mergedCornerRadius
        self.contentMergedCornerRadius = contentMergedCornerRadius
        self.maxDimensions = maxDimensions
        self.minDimensions = minDimensions
    }
}

public struct ChatMessageItemVideoLayoutConstants {
    public var maxHorizontalHeight: CGFloat
    public var maxVerticalHeight: CGFloat
    
    public init(maxHorizontalHeight: CGFloat, maxVerticalHeight: CGFloat) {
        self.maxHorizontalHeight = maxHorizontalHeight
        self.maxVerticalHeight = maxVerticalHeight
    }
}

public struct ChatMessageItemInstantVideoConstants {
    public var insets: UIEdgeInsets
    public var dimensions: CGSize
    
    public init(insets: UIEdgeInsets, dimensions: CGSize) {
        self.insets = insets
        self.dimensions = dimensions
    }
}

public struct ChatMessageItemFileLayoutConstants {
    public var bubbleInsets: UIEdgeInsets
    
    public init(bubbleInsets: UIEdgeInsets) {
        self.bubbleInsets = bubbleInsets
    }
}

public struct ChatMessageItemWallpaperLayoutConstants {
    public var maxTextWidth: CGFloat
    
    public init(maxTextWidth: CGFloat) {
        self.maxTextWidth = maxTextWidth
    }
}

public struct ChatMessageItemLayoutConstants {
    public var avatarInset: CGFloat
    public var timestampHeaderHeight: CGFloat
    public var timestampDateAndTopicHeaderHeight: CGFloat
    
    public var bubble: ChatMessageItemBubbleLayoutConstants
    public var image: ChatMessageItemImageLayoutConstants
    public var video: ChatMessageItemVideoLayoutConstants
    public var text: ChatMessageItemTextLayoutConstants
    public var file: ChatMessageItemFileLayoutConstants
    public var instantVideo: ChatMessageItemInstantVideoConstants
    public var wallpapers: ChatMessageItemWallpaperLayoutConstants
    
    public init(avatarInset: CGFloat, timestampHeaderHeight: CGFloat, timestampDateAndTopicHeaderHeight: CGFloat, bubble: ChatMessageItemBubbleLayoutConstants, image: ChatMessageItemImageLayoutConstants, video: ChatMessageItemVideoLayoutConstants, text: ChatMessageItemTextLayoutConstants, file: ChatMessageItemFileLayoutConstants, instantVideo: ChatMessageItemInstantVideoConstants, wallpapers: ChatMessageItemWallpaperLayoutConstants) {
        self.avatarInset = avatarInset
        self.timestampHeaderHeight = timestampHeaderHeight
        self.timestampDateAndTopicHeaderHeight = timestampDateAndTopicHeaderHeight
        self.bubble = bubble
        self.image = image
        self.video = video
        self.text = text
        self.file = file
        self.instantVideo = instantVideo
        self.wallpapers = wallpapers
    }
    
    public static var `default`: ChatMessageItemLayoutConstants {
        return self.compact
    }
    
    public static var compact: ChatMessageItemLayoutConstants {
        let bubble = ChatMessageItemBubbleLayoutConstants(edgeInset: 3.0, defaultSpacing: 2.0 + UIScreenPixel, mergedSpacing: 0.0, maximumWidthFill: ChatMessageItemWidthFill(compactInset: 36.0, compactWidthBoundary: 500.0, freeMaximumFillFactor: 0.85), minimumSize: CGSize(width: 40.0, height: 35.0), contentInsets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 0.0), borderInset: UIScreenPixel, strokeInsets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0))
        let text = ChatMessageItemTextLayoutConstants(bubbleInsets: UIEdgeInsets(top: 6.0 + UIScreenPixel, left: 11.0, bottom: 6.0 - UIScreenPixel, right: 11.0))
        let image = ChatMessageItemImageLayoutConstants(bubbleInsets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0), statusInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 6.0, right: 6.0), defaultCornerRadius: 15.0, mergedCornerRadius: 7.0, contentMergedCornerRadius: 0.0, maxDimensions: CGSize(width: 300.0, height: 380.0), minDimensions: CGSize(width: 170.0, height: 74.0))
        let video = ChatMessageItemVideoLayoutConstants(maxHorizontalHeight: 250.0, maxVerticalHeight: 360.0)
        let file = ChatMessageItemFileLayoutConstants(bubbleInsets: UIEdgeInsets(top: 15.0, left: 9.0, bottom: 15.0, right: 12.0))
        let instantVideo = ChatMessageItemInstantVideoConstants(insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0), dimensions: CGSize(width: 212.0, height: 212.0))
        let wallpapers = ChatMessageItemWallpaperLayoutConstants(maxTextWidth: 180.0)
        
        return ChatMessageItemLayoutConstants(avatarInset: 34.0 + 4.0, timestampHeaderHeight: 34.0, timestampDateAndTopicHeaderHeight: 7.0 * 2.0 + 20.0 * 2.0 + 7.0, bubble: bubble, image: image, video: video, text: text, file: file, instantVideo: instantVideo, wallpapers: wallpapers)
    }
    
    public static var regular: ChatMessageItemLayoutConstants {
        let bubble = ChatMessageItemBubbleLayoutConstants(edgeInset: 3.0, defaultSpacing: 2.0 + UIScreenPixel, mergedSpacing: 0.0, maximumWidthFill: ChatMessageItemWidthFill(compactInset: 36.0, compactWidthBoundary: 500.0, freeMaximumFillFactor: 0.65), minimumSize: CGSize(width: 40.0, height: 35.0), contentInsets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 0.0), borderInset: UIScreenPixel, strokeInsets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0))
        let text = ChatMessageItemTextLayoutConstants(bubbleInsets: UIEdgeInsets(top: 6.0 + UIScreenPixel, left: 10.0, bottom: 6.0 - UIScreenPixel, right: 10.0))
        let image = ChatMessageItemImageLayoutConstants(bubbleInsets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0), statusInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 6.0, right: 6.0), defaultCornerRadius: 16.0, mergedCornerRadius: 8.0, contentMergedCornerRadius: 5.0, maxDimensions: CGSize(width: 440.0, height: 440.0), minDimensions: CGSize(width: 170.0, height: 74.0))
        let video = ChatMessageItemVideoLayoutConstants(maxHorizontalHeight: 250.0, maxVerticalHeight: 360.0)
        let file = ChatMessageItemFileLayoutConstants(bubbleInsets: UIEdgeInsets(top: 15.0, left: 9.0, bottom: 15.0, right: 12.0))
        let instantVideo = ChatMessageItemInstantVideoConstants(insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0), dimensions: CGSize(width: 240.0, height: 240.0))
        let wallpapers = ChatMessageItemWallpaperLayoutConstants(maxTextWidth: 180.0)
        
        return ChatMessageItemLayoutConstants(avatarInset: 34.0 + 4.0, timestampHeaderHeight: 34.0, timestampDateAndTopicHeaderHeight: 7.0 * 2.0 + 20.0 * 2.0 + 7.0, bubble: bubble, image: image, video: video, text: text, file: file, instantVideo: instantVideo, wallpapers: wallpapers)
    }
}

public func canViewMessageReactionList(message: EngineMessage) -> Bool {
    var found = false
    var canViewList = false
    for attribute in message.attributes {
        if let attribute = attribute as? ReactionsMessageAttribute {
            canViewList = attribute.canViewList
            found = true
            break
        }
    }
    
    if !found {
        return false
    }
    
    if let peer = message.peers[message.id.peerId] {
        if let channel = peer as? TelegramChannel {
            if case .broadcast = channel.info {
                return false
            } else {
                return canViewList
            }
        } else if let _ = peer as? TelegramGroup {
            return canViewList
        } else if let _ = peer as? TelegramUser {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}

public let chatMessagePeerIdColors: [UIColor] = [
    UIColor(rgb: 0xfc5c51),
    UIColor(rgb: 0xfa790f),
    UIColor(rgb: 0x895dd5),
    UIColor(rgb: 0x0fb297),
    UIColor(rgb: 0x00c0c2),
    UIColor(rgb: 0x3ca5ec),
    UIColor(rgb: 0x3d72ed)
]

public enum TranscribedText: Equatable {
    case success(text: String, isPending: Bool)
    case error(AudioTranscriptionMessageAttribute.TranscriptionError)
}

public func transcribedText(message: EngineMessage) -> TranscribedText? {
    for attribute in message.attributes {
        if let attribute = attribute as? AudioTranscriptionMessageAttribute {
            if !attribute.text.isEmpty {
                return .success(text: attribute.text, isPending: attribute.isPending)
            } else {
                if attribute.isPending {
                    return nil
                } else {
                    return .error(attribute.error ?? .generic)
                }
            }
        }
    }
    return nil
}

public func isPollEffectivelyClosed(message: EngineMessage, poll: TelegramMediaPoll) -> Bool {
    if poll.isClosed {
        return true
    } else {
        return false
    }
}

public extension ChatReplyThreadMessage {
    var effectiveTopId: EngineMessage.Id {
        return self.channelMessageId ?? EngineMessage.Id(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: self.threadId))
    }
}

public func messageIsEligibleForLargeEmoji(_ message: EngineMessage) -> Bool {
    if !message.text.isEmpty && message.text.containsOnlyEmoji {
        if !(message.textEntitiesAttribute?.entities.isEmpty ?? true) {
            return false
        }
        return true
    } else {
        return false
    }
}

public func messageIsEligibleForLargeCustomEmoji(_ message: EngineMessage) -> Bool {
    let text = message.text.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: " ", with: "")
    guard !text.isEmpty && text.containsOnlyEmoji else {
        return false
    }
    let entities = message.textEntitiesAttribute?.entities ?? []
    guard entities.count > 0 else {
        return false
    }
    for entity in entities {
        if case let .CustomEmoji(_, fileId) = entity.type {
            if let _ = message.associatedMedia[EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile {
                
            } else {
                return false
            }
        } else {
            return false
        }
    }
    return true
}

public func canAddMessageReactions(message: EngineMessage) -> Bool {
    if message.id.namespace != Namespaces.Message.Cloud {
        return false
    }
    if let peer = message.peers[message.id.peerId] {
        if let _ = peer as? TelegramSecretChat {
            return false
        }
    } else {
        return false
    }
    for media in message.media {
        if let action = media as? TelegramMediaAction {
            if message.flags.contains(.ReactionsArePossible) {
                return true
            } else {
                switch action.action {
                case .unknown, .groupCreated, .channelMigratedFromGroup, .groupMigratedToChannel, .historyCleared, .customText, .botDomainAccessGranted, .botAppAccessGranted, .botSentSecureValues, .phoneNumberRequest, .webViewData, .topicCreated, .attachMenuBotAllowed, .requestedPeer, .giveawayLaunched, .suggestedPostApprovalStatus, .suggestedPostSuccess, .suggestedPostRefund:
                    return false
                default:
                    return true
                }
            }
        }
    }
    return true
}

public func chatMessageDateHeaderSpacing(headers: [ListViewItemHeader], hasDate: Bool, hasTopic: Bool, constants: ChatMessageItemLayoutConstants) -> CGFloat {
    let baseSpacing = hasDate && hasTopic ? constants.timestampDateAndTopicHeaderHeight : (hasDate ? constants.timestampHeaderHeight : 0) + (hasTopic ? constants.timestampHeaderHeight : 0)
    // Space 2 is the date; topic (3) and avatar (1) heights do not enlarge its reservation.
    guard hasDate, let date = headers.first(where: { $0.id.space == AnyHashable(2) }) else { return baseSpacing }
    return baseSpacing + max(0, date.height - constants.timestampHeaderHeight)
}
