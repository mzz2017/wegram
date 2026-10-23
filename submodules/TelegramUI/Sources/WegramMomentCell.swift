import UIKit
import Display

struct WegramMomentContent {
    let peerId: Int64
    let storyId: Int32?
    let timestamp: Int32
    let expiration: Int32?
    let expired: Bool
    let protected: Bool
    let caption: String
    let status: String
    let aspectRatio: CGFloat?
    let video: Bool
    var live: Bool = false
    var reacted: Bool = false

    var id: WegramStoryInteractionTarget? { self.storyId.map { WegramStoryInteractionTarget(peerId: self.peerId, storyId: $0) } }

    func isVisible(at now: Int64) -> Bool { !self.expired && (self.expiration.map { Int64($0) > now } ?? true) }
    static func comesBefore(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp > rhs.timestamp }
        if lhs.peerId != rhs.peerId { return lhs.peerId < rhs.peerId }
        return (lhs.storyId ?? Int32.max) > (rhs.storyId ?? Int32.max)
    }
}

private final class WegramMomentCaptionButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard self.isEnabled else { return false }
        return self.bounds.insetBy(dx: 0, dy: -max(0, (44 - self.bounds.height) / 2)).contains(point)
    }
}

private final class WegramMomentMoreButton: UIButton {
    var excludedContent = CGRect.null
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return super.point(inside: point, with: event) && !self.excludedContent.contains(point)
    }
}

class WegramMomentCell: UITableViewCell {
    let avatarHost = UIView()
    let name = UILabel()
    let authorAvatarButton = UIButton(type: .custom)
    let authorNameButton = UIButton(type: .custom)
    var openAuthor: (() -> Bool)? {
        didSet {
            for button in [self.authorAvatarButton, self.authorNameButton] {
                button.isHidden = self.openAuthor == nil
                button.isEnabled = self.openAuthor != nil
            }
            self.updateAccessibilityActions()
        }
    }
    private var authorTitle = "查看作者资料"
    let caption = UILabel()
    let captionToggle: UIButton = WegramMomentCaptionButton(frame: .zero)
    var toggleCaption: (() -> Bool)?
    private var allowsCaptionExpansion = false
    private var captionExpanded = false
    private var captionCanExpand = false
    private var contentGeneration = 0
    let mediaHost = UIView()
    private let mediaPlaceholder = UIImageView(image: UIImage(systemName: "photo", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24)))
    let play = UIImageView(image: UIImage(systemName: "play.circle.fill"))
    let date = UILabel()
    let more: UIButton = WegramMomentMoreButton(frame: .zero)
    var moreAction: (() -> Void)?
    private var actionsAvailable = false
    private var aspectRatio: CGFloat?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        self.separatorInset = .zero
        self.preservesSuperviewLayoutMargins = false
        self.layoutMargins = .zero
        for view in [self.avatarHost, self.name, self.caption, self.mediaHost, self.date, self.play] { self.contentView.addSubview(view); view.isUserInteractionEnabled = false; view.isAccessibilityElement = false }
        self.contentView.addSubview(self.more)
        self.contentView.addSubview(self.captionToggle)
        self.captionToggle.isHidden = true
        self.captionToggle.isAccessibilityElement = false
        self.captionToggle.contentHorizontalAlignment = .left
        self.captionToggle.accessibilityIdentifier = "Wegram.Moments.CaptionToggle"
        self.captionToggle.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.captionCanExpand else { return }
            _ = self.toggleCaption?()
        }), for: .touchUpInside)
        for button in [self.authorAvatarButton, self.authorNameButton] {
            self.contentView.addSubview(button)
            button.isHidden = true
            button.isEnabled = false
            button.isAccessibilityElement = false
            button.addAction(UIAction(handler: { [weak self] _ in _ = self?.openAuthor?() }), for: .touchUpInside)
        }
        self.authorAvatarButton.accessibilityIdentifier = "Wegram.Moments.AuthorAvatar"
        self.authorNameButton.accessibilityIdentifier = "Wegram.Moments.AuthorName"
        self.more.accessibilityIdentifier = "Wegram.Moments.More"
        self.more.isAccessibilityElement = false
        self.more.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.actionsAvailable else { return }
            self.moreAction?()
        }), for: .touchUpInside)
        self.name.numberOfLines = 0
        self.caption.numberOfLines = 6
        self.date.numberOfLines = 0
        self.avatarHost.clipsToBounds = true
        self.avatarHost.layer.cornerRadius = 4
        self.avatarHost.accessibilityElementsHidden = true
        self.mediaHost.addSubview(self.mediaPlaceholder)
        self.mediaPlaceholder.contentMode = .center
        self.mediaPlaceholder.tintColor = .gray
        self.mediaHost.clipsToBounds = true
        self.mediaHost.accessibilityElementsHidden = true
        self.play.tintColor = .white
        self.play.contentMode = .scaleAspectFit
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func load(_ content: WegramMomentContent, name: String, date: String, dark: Bool, font: CGFloat, actionsAvailable: Bool = false, moreTitle: String = "More Interactions", captionExpanded: Bool = false, expandTitle: String = "全文", collapseTitle: String = "收起", authorTitle: String = "查看作者资料") {
        self.authorTitle = authorTitle
        self.contentGeneration &+= 1
        self.allowsCaptionExpansion = content.id != nil && !content.protected && !content.caption.isEmpty
        self.captionExpanded = captionExpanded && self.allowsCaptionExpansion
        self.captionCanExpand = false
        self.caption.numberOfLines = self.captionExpanded ? 0 : 6
        self.captionToggle.setTitle(self.captionExpanded ? collapseTitle : expandTitle, for: .normal)
        self.captionToggle.titleLabel?.font = .systemFont(ofSize: font)
        self.captionToggle.setTitleColor(UIColor(red: 87 / 255, green: 107 / 255, blue: 149 / 255, alpha: 1), for: .normal)
        self.captionToggle.isHidden = true
        self.captionToggle.isEnabled = false
        self.more.accessibilityLabel = moreTitle
        self.actionsAvailable = actionsAvailable && content.storyId != nil && !content.live
        self.more.isHidden = !self.actionsAvailable
        self.more.isEnabled = self.actionsAvailable
        self.updateAccessibilityActions()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 18)).image { _ in
            UIColor(white: dark ? 0.15 : 0.96, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 30, height: 18), cornerRadius: 4).fill()
            UIColor(red: 87 / 255, green: 107 / 255, blue: 149 / 255, alpha: 1).setFill()
            for x: CGFloat in [9, 17] { UIBezierPath(ovalIn: CGRect(x: x, y: 7, width: 4, height: 4)).fill() }
        }
        self.more.setImage(image, for: .normal)
        self.name.text = name
        self.name.font = .systemFont(ofSize: font, weight: .semibold)
        self.name.textColor = UIColor(red: 87 / 255, green: 107 / 255, blue: 149 / 255, alpha: 1)
        self.caption.font = .systemFont(ofSize: font)
        self.caption.textColor = UIColor(white: dark ? 0.82 : 0.1, alpha: 1)
        self.caption.text = content.protected || content.caption.isEmpty ? content.status : content.caption
        self.date.text = date
        self.date.font = .systemFont(ofSize: font * 12 / 17)
        self.date.textColor = .gray
        self.aspectRatio = content.protected ? nil : content.aspectRatio.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.mediaHost.isHidden = self.aspectRatio == nil
        self.mediaHost.backgroundColor = UIColor(white: dark ? 0.15 : 0.93, alpha: 1)
        self.play.isHidden = content.protected || !content.video || self.aspectRatio == nil
        self.mediaPlaceholder.isHidden = content.video
        self.backgroundColor = UIColor(white: dark ? 0.1 : 1, alpha: 1)
        let selection = UIView()
        selection.backgroundColor = UIColor(white: dark ? 0.15 : 0.96, alpha: 1)
        self.selectedBackgroundView = selection
        self.accessibilityLabel = name
        self.accessibilityValue = [self.caption.text, date].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        self.accessibilityIdentifier = "Wegram.Moments.\(content.peerId).\(content.storyId.map(String.init) ?? "pending")"
        self.setNeedsLayout()
    }
    private func updateAccessibilityActions() {
        let generation = self.contentGeneration
        var actions: [UIAccessibilityCustomAction] = []
        if self.actionsAvailable {
            actions.append(UIAccessibilityCustomAction(name: self.more.accessibilityLabel ?? "", actionHandler: { [weak self] _ in
                guard let self, self.contentGeneration == generation, self.actionsAvailable else { return false }
                self.moreAction?()
                return true
            }))
        }
        if self.captionCanExpand {
            actions.append(UIAccessibilityCustomAction(name: self.captionToggle.currentTitle ?? "", actionHandler: { [weak self] _ in
                guard let self, self.contentGeneration == generation, self.captionCanExpand else { return false }
                return self.toggleCaption?() ?? false
            }))
        }
        if self.openAuthor != nil {
            actions.append(UIAccessibilityCustomAction(name: self.authorTitle, actionHandler: { [weak self] _ in
                guard let self, self.contentGeneration == generation else { return false }
                return self.openAuthor?() ?? false
            }))
        }
        self.accessibilityCustomActions = actions.isEmpty ? nil : actions
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        self.contentGeneration &+= 1
        self.captionCanExpand = false
        self.allowsCaptionExpansion = false
        self.captionExpanded = false
        self.captionToggle.isHidden = true
        self.captionToggle.isEnabled = false
        self.toggleCaption = nil
        self.openAuthor = nil
        self.actionsAvailable = false
        self.more.isHidden = true
        self.more.isEnabled = false
        self.moreAction = nil
        self.accessibilityCustomActions = nil
    }
    private func frames(width: CGFloat) -> (CGRect, CGRect, CGRect, CGRect, CGFloat, CGRect, CGRect) {
        let textWidth = max(1, width - 84)
        func height(_ label: UILabel) -> CGFloat { label.text?.isEmpty == false ? ceil(label.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height) : 0 }
        let name = CGRect(x: 68, y: 16, width: textWidth, height: height(self.name))
        let originalLines = self.caption.numberOfLines
        self.caption.numberOfLines = 0
        let fullHeight = height(self.caption)
        self.caption.numberOfLines = 6
        let collapsedHeight = height(self.caption)
        self.caption.numberOfLines = originalLines
        let canExpand = self.allowsCaptionExpansion && fullHeight > collapsedHeight + 0.5
        let captionHeight = canExpand && self.captionExpanded ? fullHeight : collapsedHeight
        let caption = CGRect(x: 68, y: name.maxY + (captionHeight > 0 ? 6 : 0), width: textWidth, height: captionHeight)
        var toggle = CGRect.zero
        if canExpand {
            let titleWidth = self.captionToggle.titleLabel?.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).width ?? 44
            toggle = CGRect(x: 68, y: caption.maxY + 4, width: min(textWidth, max(44, ceil(titleWidth))), height: ceil(self.caption.font.lineHeight) + 8)
        }
        let captionBottom = toggle == .zero ? caption.maxY : toggle.maxY
        var media = CGRect.zero
        if let ratio = self.aspectRatio, ratio.isFinite, ratio > 0 {
            let mediaWidth = min(240, textWidth)
            media = CGRect(x: 68, y: captionBottom + 8, width: mediaWidth, height: min(300, max(100, mediaWidth / ratio)))
        }
        let dateWidth = max(1, textWidth - (self.actionsAvailable ? 52 : 0))
        let dateHeight = self.date.text?.isEmpty == false ? ceil(self.date.sizeThatFits(CGSize(width: dateWidth, height: .greatestFiniteMagnitude)).height) : 0
        let footerHeight = max(dateHeight, self.actionsAvailable ? ceil(self.date.font.lineHeight) : 0)
        let footerY = (media == .zero ? captionBottom : media.maxY) + 12
        let date = CGRect(x: 68, y: footerY + (footerHeight - dateHeight) / 2, width: dateWidth, height: dateHeight)
        let more = self.actionsAvailable ? CGRect(x: width - 60, y: footerY + (footerHeight - 44) / 2, width: 44, height: 44) : .zero
        return (name, caption, media, date, max(72, footerY + footerHeight + max(16, self.actionsAvailable ? (44 - footerHeight) / 2 : 0)), more, toggle)
    }
    func measuredHeight(width: CGFloat) -> CGFloat { self.frames(width: width).4 }
    override func layoutSubviews() {
        super.layoutSubviews()
        let frames = self.frames(width: self.contentView.bounds.width)
        self.name.frame = frames.0
        self.caption.frame = frames.1
        self.captionToggle.frame = frames.6
        self.captionCanExpand = frames.6 != .zero
        self.captionToggle.isHidden = !self.captionCanExpand
        self.captionToggle.isEnabled = self.captionCanExpand
        self.updateAccessibilityActions()
        self.mediaHost.frame = frames.2
        self.date.frame = frames.3
        self.more.frame = frames.5
        if let more = self.more as? WegramMomentMoreButton {
            let content = frames.2 != .zero ? frames.2 : (frames.6 != .zero ? frames.6 : (frames.1.height > 0 ? frames.1 : frames.0))
            more.excludedContent = more.convert(content, from: self.contentView)
        }
        self.avatarHost.frame = CGRect(x: 16, y: 16, width: 40, height: 40)
        self.authorAvatarButton.frame = self.avatarHost.frame.insetBy(dx: -2, dy: -2)
        let nameWidth = self.name.sizeThatFits(CGSize(width: self.name.bounds.width, height: .greatestFiniteMagnitude)).width
        self.authorNameButton.frame = CGRect(x: self.name.frame.minX, y: self.name.frame.minY, width: min(self.name.bounds.width, max(44, ceil(nameWidth) + 4)), height: self.name.bounds.height)
        self.play.frame = CGRect(x: self.mediaHost.frame.midX - 18, y: self.mediaHost.frame.midY - 18, width: 36, height: 36)
        for view in self.avatarHost.subviews { view.frame = self.avatarHost.bounds }
        for view in self.mediaHost.subviews { view.frame = self.mediaHost.bounds }
    }
}
