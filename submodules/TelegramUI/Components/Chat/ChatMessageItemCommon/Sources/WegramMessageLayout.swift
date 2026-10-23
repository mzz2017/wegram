import Foundation
import CoreGraphics
import AsyncDisplayKit

public enum WegramMessageLayout {
    public static let avatarDiameter: CGFloat = 40
    public static let avatarCornerRadius: CGFloat = 4
    public static let edgeInset: CGFloat = 12
    public static let avatarInset: CGFloat = 48
    public static let messageSpacing: CGFloat = 8

    public static func avatarSelectionOffset(outgoing: Bool, isSelected: Bool) -> CGFloat {
        return isSelected && !outgoing ? 42 : 0
    }

    public static func authorHeaderFrame(bubbleFrame: CGRect, headerSize: CGSize) -> CGRect {
        return CGRect(x: bubbleFrame.minX + 5, y: bubbleFrame.minY - headerSize.height, width: headerSize.width, height: headerSize.height)
    }

    public static func authorNameFrame(bubbleFrame: CGRect, nameSize: CGSize, headerSize: CGSize) -> CGRect {
        let header = authorHeaderFrame(bubbleFrame: bubbleFrame, headerSize: headerSize)
        return CGRect(x: header.minX, y: header.minY + floor((header.height - 4 - nameSize.height) / 2), width: nameSize.width, height: nameSize.height)
    }

    public static func avatarFrame(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, outgoing: Bool) -> CGRect {
        let x = outgoing ? width - rightInset - edgeInset - avatarDiameter : leftInset + edgeInset
        return CGRect(x: x, y: 0, width: avatarDiameter, height: avatarDiameter)
    }

    public static func bubbleOriginX(width: CGFloat, bubbleWidth: CGFloat, leftInset: CGFloat, rightInset: CGFloat, outgoing: Bool, failedInset: CGFloat) -> CGFloat {
        let bubbleEdge = edgeInset + avatarInset
        return outgoing ? width - rightInset - bubbleWidth - bubbleEdge - failedInset : leftInset + bubbleEdge
    }
}

public struct WegramReplyAccessoryLayout {
    public let hasStatus: Bool
    public let hasCheck: Bool
    public let hasGift: Bool

    public init(hasStatus: Bool, hasCheck: Bool, hasGift: Bool) {
        self.hasStatus = hasStatus
        self.hasCheck = hasCheck
        self.hasGift = hasGift
    }

    public var leadingInset: CGFloat {
        return (self.hasStatus ? 18 : 0) + (self.hasCheck ? 16 : 0)
    }

    public var trailingInset: CGFloat {
        return self.hasGift ? 22 : 0
    }

    public func thumbnailSide(constrainedWidth: CGFloat) -> CGFloat {
        return min(32.0, max(0.0, constrainedWidth - 24.0 - self.leadingInset - self.trailingInset))
    }

    public func authorMaxWidth(constrainedWidth: CGFloat, hasImage: Bool) -> CGFloat {
        let available = max(0.0, constrainedWidth - 24.0 - self.leadingInset - self.trailingInset)
        if hasImage {
            return max(0.0, available - self.thumbnailSide(constrainedWidth: constrainedWidth))
        }
        return min(available, max(0.0, constrainedWidth * 0.45))
    }

    public func cardHeight(titleHeight: CGFloat, textHeight: CGFloat, thumbnailSide: CGFloat?) -> CGFloat {
        if let thumbnailSide {
            return max(thumbnailSide + 16.0, titleHeight + 10.0)
        }
        return max(32.0, max(titleHeight, textHeight) + 6.0)
    }

    public func authorOriginY(cardHeight: CGFloat, titleHeight: CGFloat, hasImage: Bool) -> CGFloat {
        // The text node includes 3pt top padding; image quotes align its content at 8pt.
        return hasImage ? 5.0 : floor((cardHeight - titleHeight) / 2.0)
    }

    public func statusFrame(afterTitleX: CGFloat, height: CGFloat, hasImage: Bool) -> CGRect {
        return CGRect(x: afterTitleX + (hasImage ? 4 : 0), y: floor((height - 16) / 2), width: 16, height: 16)
    }

    public func checkFrame(afterTitleX: CGFloat, height: CGFloat) -> CGRect {
        return CGRect(x: afterTitleX + (self.hasStatus ? 18 : 0), y: floor((height - 12) / 2), width: 12, height: 12)
    }

    public func giftFrame(width: CGFloat, height: CGFloat) -> CGRect {
        return CGRect(x: width - 10 - 18, y: floor((height - 18) / 2), width: 18, height: 18)
    }
}


public enum WegramMessageDateLayout {
    public static func textWidth(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat) -> CGFloat {
        return max(0, width - leftInset - rightInset - 12)
    }
    public static func cardHeight(labelHeight: CGFloat) -> CGFloat {
        return max(20, ceil(labelHeight) + 2)
    }
    public static func headerHeight(labelHeight: CGFloat) -> CGFloat {
        return self.cardHeight(labelHeight: labelHeight) + 14
    }
}

/// Visible sticker bounds exclude the renderer's 10pt intrinsic padding.
public struct WegramStickerMessageLayout {
    public enum Part: Hashable {
        case suggestedPost, author, viaBot, forward, status, reply, buttons, reactions
    }

    public let imageFrame: CGRect
    public let animationFrame: CGRect
    public let mediaContentRect: CGRect
    public let contentRect: CGRect
    public let height: CGFloat
    private let frames: [Part: CGRect]

    public subscript(_ part: Part) -> CGRect? { self.frames[part] }

    public static func contentArea(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, outgoing: Bool, failed: Bool, selected: Bool) -> CGRect {
        let leading = leftInset + WegramMessageLayout.edgeInset + (outgoing ? 0 : WegramMessageLayout.avatarInset)
        let trailing = rightInset + WegramMessageLayout.edgeInset + (outgoing ? WegramMessageLayout.avatarInset : 0)
        let selection = WegramMessageLayout.avatarSelectionOffset(outgoing: outgoing, isSelected: selected)
        return CGRect(x: leading, y: 0, width: max(0, width - leading - trailing - selection - (outgoing && failed ? 24 : 0)), height: 0)
    }

    public static func imageSize(_ size: CGSize, availableWidth: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(1, min(132 / max(size.width, size.height), max(0, availableWidth) / size.width))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    public init(area: CGRect, outgoing: Bool, imageSize: CGSize, minimumImageHeight: CGFloat, animationVerticalOffset: CGFloat = 0, parts: [Part: CGSize]) {
        var frames: [Part: CGRect] = [:]
        var y: CGFloat = 0
        var extracted = CGRect.null
        func frame(size: CGSize, inset: CGFloat = 0) -> CGRect {
            let width = min(max(0, area.width - inset * 2), size.width)
            return CGRect(x: outgoing ? area.maxX - inset - width : area.minX + inset, y: y, width: width, height: size.height)
        }
        for part in [Part.suggestedPost, .author, .viaBot, .forward] {
            if let size = parts[part] {
                let rect = frame(size: size, inset: part == .viaBot || part == .forward ? 6 : 0)
                frames[part] = rect
                extracted = extracted.union(rect)
                y = rect.maxY + (part == .suggestedPost ? 8 : 4)
            }
        }
        let animationOffset = max(0, animationVerticalOffset)
        let imageHeight = max(imageSize.height + animationOffset, minimumImageHeight)
        let visibleImage = frame(size: imageSize).offsetBy(dx: 0, dy: floor((imageHeight - imageSize.height - animationOffset) / 2))
        self.imageFrame = visibleImage.insetBy(dx: -10, dy: -10)
        self.animationFrame = visibleImage.offsetBy(dx: 0, dy: animationOffset)
        self.mediaContentRect = visibleImage.union(self.animationFrame)
        extracted = extracted.union(self.mediaContentRect)
        y += imageHeight
        for part in [Part.status, .reply, .buttons, .reactions] {
            if let size = parts[part] {
                y += 4
                let rect = frame(size: size)
                frames[part] = rect
                if part == .status || part == .reply { extracted = extracted.union(rect) }
                y = rect.maxY
            }
        }
        self.frames = frames
        self.contentRect = extracted
        self.height = max(WegramMessageLayout.avatarDiameter, y)
    }
}

/// Frames for the same media nodes in the folded and expanded album presentations.
public struct WegramMediaAlbumLayout {
    public let frames: [CGRect]
    public let size: CGSize
    public let expanded: Bool

    public init(itemSizes: [CGSize], maxSize: CGSize, outgoing: Bool, expanded: Bool) {
        self.expanded = expanded
        let width = min(150, max(1, maxSize.width - (expanded ? 0 : 24)))
        let height = min(200, max(1, maxSize.height))
        if expanded {
            let sizes = itemSizes.map { source -> CGSize in
                let source = source.width > 0 && source.height > 0 && source.width.isFinite && source.height.isFinite ? source : CGSize(width: 150, height: 200)
                let factor = min(width / source.width, height / source.height)
                return CGSize(width: max(1, floor(source.width * factor)), height: max(1, floor(source.height * factor)))
            }
            let groupWidth = sizes.map(\.width).max() ?? 0
            var y: CGFloat = 0
            self.frames = sizes.map { size in
                defer { y += max(40, size.height) + 16 }
                return CGRect(x: outgoing ? groupWidth - size.width : 0, y: y, width: size.width, height: size.height)
            }
            self.size = CGSize(width: groupWidth, height: max(0, y - 16))
        } else {
            self.frames = itemSizes.indices.map { index in
                let layer = CGFloat(min(index, 2))
                return CGRect(x: layer * 12, y: layer * 12, width: width, height: max(1, height - layer * 24))
            }
            self.size = itemSizes.isEmpty ? .zero : CGSize(width: width + CGFloat(min(2, itemSizes.count - 1)) * 12, height: height)
        }
    }

    public var statusAnchor: CGPoint {
        guard let frame = self.expanded ? self.frames.last : self.frames.first else { return .zero }
        return CGPoint(x: frame.maxX, y: frame.maxY)
    }

    public func arrangeNodes(_ nodes: [ASDisplayNode]) {
        let order = self.expanded ? nodes : Array(nodes.reversed())
        for node in order {
            if let parent = node.supernode, let last = parent.subnodes?.last, node !== last {
                parent.insertSubnode(node, aboveSubnode: last)
            }
        }
    }

    public func hitIndex(at point: CGPoint) -> Int? {
        for (index, frame) in self.frames.enumerated() where self.isVisible(at: index) {
            let local = CGPoint(x: point.x - frame.midX, y: point.y - frame.midY).applying(CGAffineTransform(rotationAngle: -self.rotation(at: index)))
            if CGRect(x: -frame.width / 2, y: -frame.height / 2, width: frame.width, height: frame.height).contains(local) { return index }
        }
        return nil
    }

    public func rotation(at index: Int) -> CGFloat {
        return self.expanded || index == 0 ? 0 : CGFloat(min(index, 2)) * .pi / 180 * 2
    }

    public func isVisible(at index: Int) -> Bool { self.expanded || index < 3 }
}
