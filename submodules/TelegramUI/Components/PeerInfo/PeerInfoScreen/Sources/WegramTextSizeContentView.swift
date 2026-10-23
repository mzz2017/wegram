import UIKit
import AsyncDisplayKit
import Display
import TelegramUIPreferences
import TelegramPresentationData

// Ordered by display size: PresentationFontSize raw values are not size ordered.
struct WegramTextSizeDraft {
    static let sizes: [PresentationFontSize] = [.extraSmall, .small, .medium, .regular, .large, .extraLarge, .extraLargeX2]
    private(set) var loaded = false
    private(set) var selection: PresentationFontSize?
    private(set) var previewSize: CGFloat = 17

    mutating func load(previewSize: CGFloat) {
        guard !self.loaded else { return }
        self.loaded = true
        self.previewSize = previewSize
    }

    mutating func select(index: Int) {
        guard self.loaded else { return }
        let size = Self.sizes[max(0, min(Self.sizes.count - 1, index))]
        self.selection = size
        self.previewSize = size.baseDisplaySize
    }

    func applying(to current: PresentationThemeSettings) -> PresentationThemeSettings {
        guard let selection = self.selection else { return current }
        var updated = current
        updated.useSystemFont = false
        updated.fontSize = selection
        updated.listsFontSize = selection
        return updated
    }
}

final class WegramTextSizeBubble: UILabel {
    override func drawText(in rect: CGRect) { super.drawText(in: rect.insetBy(dx: 12, dy: 12)) }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let text = super.sizeThatFits(CGSize(width: max(0, size.width - 24), height: size.height))
        return CGSize(width: ceil(text.width) + 24, height: ceil(text.height) + 24)
    }
}

final class WegramTextSizeContentView: UIView {
    let preview = UIScrollView()
    let slider = UISlider()
    let saveButton = WegramNameSaveButton()
    let standardLabel = UILabel()
    let smallLabel = UILabel()
    let largeLabel = UILabel()
    let panel = UIView()
    let bubbles = [WegramTextSizeBubble(), WegramTextSizeBubble(), WegramTextSizeBubble()]
    private let avatars = [UIImageView(), UIImageView(), UIImageView()]
    private let baseline = UIView()
    private let ticks = (0..<7).map { _ in UIView() }
    private(set) var draft = WegramTextSizeDraft()
    private var chinese = true
    private var safeBottom: CGFloat = 0
    private var saveItem: UIBarButtonItem?
    private lazy var saveNode: ASDisplayNode = {
        let node = ASDisplayNode(viewBlock: { [button = self.saveButton] in button })
        node.style.preferredSize = CGSize(width: 64, height: 44)
        return node
    }()
    var save: (() -> Void)?
    var submitting = false { didSet { self.updateControls() } }
    var canSave: Bool { self.draft.loaded && !self.submitting }

    init() {
        super.init(frame: .zero)
        self.preview.contentInsetAdjustmentBehavior = .never
        self.preview.alwaysBounceVertical = true
        self.addSubview(self.preview)
        self.addSubview(self.panel)
        self.panel.addSubview(self.baseline)
        for tick in self.ticks { self.panel.addSubview(tick) }
        for label in [self.smallLabel, self.largeLabel, self.standardLabel] { self.panel.addSubview(label) }
        self.panel.addSubview(self.slider)
        for (bubble, avatar) in zip(self.bubbles, self.avatars) {
            bubble.numberOfLines = 0
            bubble.layer.cornerRadius = 4
            bubble.clipsToBounds = true
            self.preview.addSubview(bubble)
            avatar.image = UIImage(systemName: "person.crop.square.fill")
            avatar.layer.cornerRadius = 4
            avatar.clipsToBounds = true
            avatar.isAccessibilityElement = false
            self.preview.addSubview(avatar)
        }
        self.smallLabel.text = "A"
        self.smallLabel.font = .systemFont(ofSize: 14)
        self.largeLabel.text = "A"
        self.largeLabel.font = .systemFont(ofSize: 26)
        self.standardLabel.font = .systemFont(ofSize: 13)
        self.standardLabel.textAlignment = .center
        let thumb = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { renderer in
            renderer.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 4, color: UIColor.black.withAlphaComponent(0.15).cgColor)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 5, y: 5, width: 30, height: 30)).fill()
        }
        self.slider.setThumbImage(thumb, for: .normal)
        self.slider.setThumbImage(thumb, for: .highlighted)
        self.slider.minimumValue = 0
        self.slider.maximumValue = 6
        self.slider.minimumTrackTintColor = .clear
        self.slider.maximumTrackTintColor = .clear
        self.slider.accessibilityIdentifier = "Wegram.Settings.TextSize"
        self.slider.addAction(UIAction(handler: { [weak self] _ in self?.sliderChanged() }), for: .valueChanged)
        self.saveButton.accessibilityIdentifier = "Wegram.Settings.SaveTextSize"
        self.saveButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.canSave else { return }
            self.save?()
        }), for: .touchUpInside)
        self.updateControls()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func load(previewSize: CGFloat) {
        guard !self.draft.loaded else { return }
        self.draft.load(previewSize: previewSize)
        let nearest = WegramTextSizeDraft.sizes.indices.min { abs(WegramTextSizeDraft.sizes[$0].baseDisplaySize - previewSize) < abs(WegramTextSizeDraft.sizes[$1].baseDisplaySize - previewSize) } ?? 3
        self.slider.value = Float(nearest)
        self.updatePreview()
        self.updateControls()
    }

    func makeSaveItem() -> UIBarButtonItem? {
        let item = UIBarButtonItem(customDisplayNode: self.saveNode)
        item?.accessibilityLabel = self.saveButton.accessibilityLabel
        item?.isEnabled = self.canSave
        self.saveItem = item
        return item
    }

    func update(isDark: Bool, chinese: Bool, doneTitle: String, safeBottom: CGFloat) {
        self.chinese = chinese
        self.safeBottom = safeBottom
        self.backgroundColor = UIColor(white: isDark ? 0.1 : 237 / 255, alpha: 1)
        self.panel.backgroundColor = isDark ? UIColor(white: 0.14, alpha: 1) : .white
        let text = UIColor(white: isDark ? 0.82 : 0.1, alpha: 1)
        for label in [self.smallLabel, self.largeLabel, self.standardLabel] { label.textColor = text }
        self.standardLabel.text = chinese ? "标准" : "Default"
        self.slider.accessibilityLabel = chinese ? "字体大小" : "Text Size"
        self.baseline.backgroundColor = UIColor(white: isDark ? 0.4 : 0.7, alpha: 1)
        for tick in self.ticks { tick.backgroundColor = UIColor(white: isDark ? 0.4 : 0.7, alpha: 1) }
        for (index, bubble) in self.bubbles.enumerated() {
            bubble.backgroundColor = index == 0 ? UIColor(red: 149 / 255, green: 236 / 255, blue: 105 / 255, alpha: 1) : self.panel.backgroundColor
            bubble.textColor = index == 0 ? UIColor(white: 0.1, alpha: 1) : text
            self.avatars[index].tintColor = UIColor(white: isDark ? 0.5 : 0.65, alpha: 1)
        }
        self.saveButton.setTitle(doneTitle, for: .normal)
        self.saveButton.accessibilityLabel = doneTitle
        self.saveItem?.accessibilityLabel = doneTitle
        self.updatePreview()
    }

    private func updateControls() {
        self.slider.isEnabled = self.canSave
        self.saveButton.isEnabled = self.canSave
        self.saveItem?.isEnabled = self.canSave
    }

    private func sliderChanged() {
        guard self.canSave else { return }
        let index = Int(self.slider.value.rounded())
        self.draft.select(index: index)
        self.slider.setValue(Float(index), animated: false)
        self.updatePreview()
    }

    private func updatePreview() {
        let texts = self.chinese ? ["预览字体大小", "拖动下面的滑块，可设置字体大小", "设置后，会改变聊天和列表中的字体大小。"] : ["Preview Text Size", "Drag the slider below to change text size.", "This changes text size in chats and lists."]
        for (label, text) in zip(self.bubbles, texts) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 3
            label.attributedText = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: self.draft.previewSize), .paragraphStyle: paragraph])
            label.accessibilityLabel = text
        }
        self.slider.accessibilityValue = "\(Int(self.draft.previewSize))"
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let panelHeight = min(self.bounds.height, 138 + self.safeBottom)
        self.panel.frame = CGRect(x: 0, y: self.bounds.height - panelHeight, width: self.bounds.width, height: panelHeight)
        self.preview.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.panel.frame.minY)
        self.slider.frame = CGRect(x: 26, y: 60, width: max(0, self.bounds.width - 52), height: 44)
        // Use UISlider's actual thumb geometry so every tick and the default label align.
        let track = self.slider.trackRect(forBounds: self.slider.bounds)
        for (index, tick) in self.ticks.enumerated() {
            let thumb = self.slider.thumbRect(forBounds: self.slider.bounds, trackRect: track, value: Float(index))
            tick.frame = CGRect(x: self.slider.frame.minX + thumb.midX - 0.5, y: self.slider.frame.midY - 5, width: 1, height: 10)
        }
        self.baseline.frame = CGRect(x: self.ticks[0].frame.midX, y: self.slider.frame.midY, width: self.ticks[6].frame.midX - self.ticks[0].frame.midX, height: 1)
        self.smallLabel.frame = CGRect(x: 26, y: 18, width: 30, height: 32)
        self.largeLabel.frame = CGRect(x: self.bounds.width - 56, y: 18, width: 30, height: 32)
        self.largeLabel.textAlignment = .right
        self.standardLabel.frame = CGRect(x: self.ticks[3].frame.midX - 40, y: 25, width: 80, height: 24)
        var y: CGFloat = 28
        for index in 0..<3 {
            let maxWidth = max(40, min(280, self.bounds.width - 96))
            let textSize = self.bubbles[index].sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
            let width = min(maxWidth, ceil(textSize.width))
            let height = max(44, ceil(textSize.height))
            let outgoing = index == 0
            self.avatars[index].frame = CGRect(x: outgoing ? self.bounds.width - 48 : 12, y: y, width: 36, height: 36)
            self.bubbles[index].frame = CGRect(x: outgoing ? self.bounds.width - 60 - width : 60, y: y, width: width, height: height)
            y += height + 20
        }
        self.preview.contentSize = CGSize(width: self.bounds.width, height: y + 8)
    }
}
