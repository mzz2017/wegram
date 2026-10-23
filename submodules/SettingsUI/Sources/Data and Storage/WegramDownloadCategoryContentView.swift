import UIKit
import Display
import LegacyComponents

enum WegramMediaRuleField: CaseIterable {
    case contact, otherPrivate, group, channel, preload, photo, video
}
struct WegramDownloadToggle {
    let field: WegramMediaRuleField
    let title: String
    let value: Bool
    let enabled: Bool
}
struct WegramDownloadSize {
    let heading: String
    let text: String
    let bytes: Int64
    let minimum: String
    let maximum: String
}
struct WegramMediaRuleAction {
    let title: String
    let value: String
}
final class WegramMediaRuleActionButton: UIButton {
    let caption = UILabel()
    let detail = UILabel()
    let arrow = UIImageView(image: wegramDisclosureArrowImage)
    var normalColor = UIColor.white { didSet { self.updateBackground() } }
    var pressedColor = UIColor(white: 0.9, alpha: 1) { didSet { self.updateBackground() } }
    override var isHighlighted: Bool { didSet { self.updateBackground() } }
    override var isEnabled: Bool {
        didSet {
            self.accessibilityTraits = self.isEnabled ? .button : [.button, .notEnabled]
        }
    }
    init() {
        super.init(frame: .zero)
        self.caption.numberOfLines = 0
        self.detail.textAlignment = .right
        for view in [self.caption, self.detail, self.arrow] {
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
            self.addSubview(view)
        }
        self.isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func updateBackground() { self.backgroundColor = self.isHighlighted ? self.pressedColor : self.normalColor }
    private func detailWidth(_ width: CGFloat) -> CGFloat { min(max(0, width * 0.35), ceil(self.detail.sizeThatFits(CGSize(width: max(0, width * 0.35), height: .greatestFiniteMagnitude)).width)) }
    func measuredHeight(width: CGFloat) -> CGFloat {
        let textWidth = max(1, width - 70 - self.detailWidth(width))
        return max(56, ceil(self.caption.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height) + 24, ceil(self.detail.font.lineHeight) + 24)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let height = self.bounds.height
        let detailWidth = self.detailWidth(width)
        self.detail.frame = CGRect(x: width - 42 - detailWidth, y: 0, width: detailWidth, height: height)
        self.caption.frame = CGRect(x: 16, y: 12, width: max(0, self.detail.frame.minX - 28), height: max(0, height - 24))
        self.arrow.frame = wegramDisclosureArrowFrame(trailingEdge: width, centerY: height / 2)
    }
}
final class WegramDownloadSizeSlider: TGPhotoEditorSliderView {
    override func accessibilityIncrement() { self.adjust(0.05) }
    override func accessibilityDecrement() { self.adjust(-0.05) }
    private func adjust(_ delta: CGFloat) {
        guard self.isEnabled, self.value.isFinite else { return }
        let previous = self.value
        self.value = min(1, max(0, previous + delta))
        if self.value != previous { self.sendActions(for: .valueChanged) }
    }
}
final class WegramDownloadRuleRow: UIView {
    let title = UILabel()
    let toggle = WegramAppearanceSwitch()
    let separator = UIView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.title.numberOfLines = 0
        self.title.isAccessibilityElement = false
        self.separator.isUserInteractionEnabled = false
        self.addSubview(self.title)
        self.addSubview(self.toggle)
        self.addSubview(self.separator)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.title.frame = CGRect(x: 16, y: 12, width: max(0, self.bounds.width - 99), height: max(0, self.bounds.height - 24))
        self.toggle.frame = CGRect(x: max(16, self.bounds.width - 67), y: floor((self.bounds.height - 44) / 2), width: 51, height: 44)
        let pixel = 1 / max(1, self.traitCollection.displayScale)
        self.separator.frame = CGRect(x: 16, y: self.bounds.height - pixel, width: max(0, self.bounds.width - 16), height: pixel)
    }
}
final class WegramMediaRulePeerHeader: UIView {
    let avatarHost = UIView()
    let name = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.name.numberOfLines = 0
        self.avatarHost.layer.cornerRadius = 4
        self.avatarHost.clipsToBounds = true
        self.avatarHost.accessibilityElementsHidden = true
        self.avatarHost.isUserInteractionEnabled = false
        self.addSubview(self.avatarHost)
        self.addSubview(self.name)
        self.isAccessibilityElement = true
        self.name.isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func measuredHeight(width: CGFloat) -> CGFloat {
        max(56, ceil(self.name.sizeThatFits(CGSize(width: max(1, width - 84), height: .greatestFiniteMagnitude)).height) + 24)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.avatarHost.frame = CGRect(x: 16, y: (self.bounds.height - 40) / 2, width: 40, height: 40)
        self.name.frame = CGRect(x: 68, y: 12, width: max(0, self.bounds.width - 84), height: max(0, self.bounds.height - 24))
        for view in self.avatarHost.subviews { view.frame = self.avatarHost.bounds }
    }
}
final class WegramDownloadCategoryContentView: UIScrollView {
    let peerHeader = WegramMediaRulePeerHeader(frame: .zero)
    let heading = UILabel()
    let sizeHeading = UILabel()
    let sizeBlock = UIView()
    let sizeLabel = UILabel()
    let slider = WegramDownloadSizeSlider()
    let minimum = UILabel()
    let maximum = UILabel()
    let footer = UILabel()
    let sectionInfo = UILabel()
    let actionButton = WegramMediaRuleActionButton()
    let loading = UILabel()
    private(set) var rowViews: [WegramMediaRuleField: WegramDownloadRuleRow] = [:]
    private var rules: [WegramDownloadToggle] = []
    private var size: WegramDownloadSize?
    private var action: WegramMediaRuleAction?
    private var fontSize: CGFloat = 17
    var toggle: ((WegramMediaRuleField) -> Void)?
    var adjustSize: ((Int64) -> Void)?
    var formatSize: ((Int64) -> String)?
    var openAction: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentInsetAdjustmentBehavior = .never
        self.alwaysBounceVertical = true
        for label in [self.heading, self.sizeHeading, self.sizeLabel, self.minimum, self.maximum, self.footer, self.sectionInfo, self.loading] { label.numberOfLines = 0 }
        self.sizeLabel.textAlignment = .center
        self.maximum.textAlignment = .right
        self.heading.accessibilityTraits = .header
        self.sizeHeading.accessibilityTraits = .header
        self.sizeLabel.isAccessibilityElement = false
        self.minimum.isAccessibilityElement = false
        self.maximum.isAccessibilityElement = false
        self.addSubview(self.peerHeader)
        self.addSubview(self.heading)
        self.addSubview(self.sizeHeading)
        self.addSubview(self.sizeBlock)
        self.addSubview(self.footer)
        self.addSubview(self.sectionInfo)
        self.addSubview(self.actionButton)
        self.addSubview(self.loading)
        for view in [self.sizeLabel, self.slider, self.minimum, self.maximum] { self.sizeBlock.addSubview(view) }
        self.slider.enablePanHandling = true
        self.slider.trackCornerRadius = 2
        self.slider.lineSize = 4
        self.slider.dotSize = 5
        self.slider.minimumValue = 0
        self.slider.maximumValue = 1
        self.slider.startValue = 0
        self.slider.displayEdges = true
        self.slider.disablesInteractiveTransitionGestureRecognizer = true
        self.slider.knobImage = generateFilledCircleImage(diameter: 27, color: .white, strokeColor: UIColor(rgb: 0xcccccc), strokeWidth: 0.5)
        self.slider.isAccessibilityElement = true
        self.slider.accessibilityTraits = .adjustable
        self.slider.accessibilityIdentifier = "Wegram.DownloadRule.Size"
        self.slider.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.size != nil, self.slider.isEnabled, self.slider.value.isFinite, (0...1).contains(self.slider.value) else { return }
            let bytes = autodownloadSizeForSliderValue(for: self.slider.value)
            self.slider.accessibilityValue = self.formatSize?(bytes)
            self.adjustSize?(bytes)
        }), for: .valueChanged)
        self.actionButton.accessibilityIdentifier = "Wegram.MediaRule.Action"
        self.actionButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.action != nil, self.actionButton.isEnabled else { return }
            self.openAction?()
        }), for: .touchUpInside)
        for field in WegramMediaRuleField.allCases {
            let row = WegramDownloadRuleRow(frame: .zero)
            row.toggle.accessibilityIdentifier = "Wegram.DownloadRule.\(field)"
            row.toggle.addAction(UIAction(handler: { [weak self] _ in
                guard let self, self.rules.first(where: { $0.field == field })?.enabled == true else { return }
                self.toggle?(field)
            }), for: .valueChanged)
            self.rowViews[field] = row
            self.addSubview(row)
        }
        self.load(heading: "", rules: [], size: nil, footer: "")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.fontSize = fontSize
        self.backgroundColor = UIColor(rgb: dark ? 0x111111 : 0xededed)
        let text = UIColor(rgb: dark ? 0xcfcfcf : 0x191919)
        let gray = UIColor(rgb: dark ? 0x888888 : 0x777777)
        let block = UIColor(rgb: dark ? 0x191919 : 0xffffff)
        for label in [self.heading, self.sizeHeading, self.minimum, self.maximum, self.footer, self.sectionInfo, self.loading] {
            label.font = .systemFont(ofSize: fontSize * 13 / 17)
            label.textColor = gray
        }
        self.peerHeader.backgroundColor = block
        self.peerHeader.name.font = .systemFont(ofSize: fontSize)
        self.peerHeader.name.textColor = text
        self.sizeLabel.font = .systemFont(ofSize: fontSize)
        self.sizeLabel.textColor = text
        self.actionButton.normalColor = block
        self.actionButton.pressedColor = UIColor(rgb: dark ? 0x292929 : 0xe5e5e5)
        self.actionButton.caption.font = .systemFont(ofSize: fontSize)
        self.actionButton.caption.textColor = text
        self.actionButton.detail.font = .systemFont(ofSize: fontSize * 13 / 17)
        self.actionButton.detail.textColor = gray
        self.actionButton.arrow.tintColor = UIColor(white: dark ? 1 : 0, alpha: 0.3)
        self.loading.text = chinese ? "正在加载…" : "Loading…"
        self.sizeBlock.backgroundColor = block
        self.slider.backgroundColor = block
        self.slider.backColor = UIColor(rgb: dark ? 0x393939 : 0xdddddd)
        self.slider.startColor = self.slider.backColor
        self.slider.trackColor = UIColor(rgb: 0x07c160)
        for row in self.rowViews.values {
            row.backgroundColor = block
            row.title.font = .systemFont(ofSize: fontSize)
            row.title.textColor = text
            row.separator.backgroundColor = UIColor(rgb: dark ? 0x383838 : 0xe5e5e5)
            row.toggle.onTitle = chinese ? "开启" : "On"
            row.toggle.offTitle = chinese ? "关闭" : "Off"
            row.toggle.onTintColor = UIColor(rgb: 0x07c160)
            row.toggle.offTintColor = self.slider.backColor
        }
        self.setNeedsLayout()
    }
    func load(heading: String, rules: [WegramDownloadToggle], size: WegramDownloadSize?, footer: String, sectionInfo: String = "", action: WegramMediaRuleAction? = nil, peerName: String? = nil) {
        self.peerHeader.isHidden = peerName == nil
        self.peerHeader.name.text = peerName
        self.peerHeader.accessibilityLabel = peerName
        self.heading.text = heading
        self.rules = rules
        self.size = size
        self.footer.text = footer
        self.sectionInfo.text = sectionInfo
        self.action = action
        self.actionButton.isHidden = action == nil
        self.actionButton.isEnabled = action != nil
        self.actionButton.caption.text = action?.title
        self.actionButton.detail.text = action?.value
        self.actionButton.accessibilityLabel = action?.title
        self.actionButton.accessibilityValue = action?.value
        self.loading.isHidden = !rules.isEmpty
        self.heading.isHidden = heading.isEmpty
        for (field, row) in self.rowViews {
            let value = rules.first(where: { $0.field == field })
            row.isHidden = value == nil
            row.title.text = value?.title
            row.title.alpha = value?.enabled == true ? 1 : 0.45
            row.toggle.accessibilityLabel = value?.title
            row.toggle.isOn = value?.value ?? false
            row.toggle.isEnabled = value?.enabled ?? false
        }
        self.sizeHeading.isHidden = size == nil
        self.sizeBlock.isHidden = size == nil
        self.slider.isEnabled = size != nil
        self.slider.accessibilityTraits = size == nil ? [.adjustable, .notEnabled] : .adjustable
        self.sizeHeading.text = size?.heading
        self.sizeLabel.text = size?.text
        self.minimum.text = size?.minimum
        self.maximum.text = size?.maximum
        self.slider.accessibilityLabel = size?.heading
        self.slider.accessibilityValue = size?.text
        if let size { self.slider.value = min(1, max(0, autodownloadSizeSliderValue(for: size.bytes))) }
        self.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        func labelHeight(_ label: UILabel, width: CGFloat) -> CGFloat { ceil(label.sizeThatFits(CGSize(width: max(1, width), height: .greatestFiniteMagnitude)).height) }
        var y: CGFloat = 16
        if !self.peerHeader.isHidden {
            self.peerHeader.frame = CGRect(x: 0, y: 8, width: width, height: self.peerHeader.measuredHeight(width: width))
            y = self.peerHeader.frame.maxY + 16
        } else { self.peerHeader.frame = .zero }
        if !self.heading.isHidden {
            let height = labelHeight(self.heading, width: width - 32)
            self.heading.frame = CGRect(x: 16, y: y, width: max(0, width - 32), height: height)
            y += height + 8
        }
        func layoutRow(_ rule: WegramDownloadToggle, last: Bool) {
            guard let row = self.rowViews[rule.field] else { return }
            let height = max(56, labelHeight(row.title, width: width - 99) + 24)
            row.frame = CGRect(x: 0, y: y, width: width, height: height)
            row.separator.isHidden = last
            y += height
        }
        let peers = self.rules.filter { $0.field != .preload }
        for (index, rule) in peers.enumerated() { layoutRow(rule, last: index == peers.count - 1) }
        if self.sectionInfo.text?.isEmpty == false {
            self.sectionInfo.frame = CGRect(x: 16, y: y + 8, width: max(0, width - 32), height: labelHeight(self.sectionInfo, width: width - 32))
            y = self.sectionInfo.frame.maxY
        } else { self.sectionInfo.frame = .zero }
        if self.size != nil {
            y += 16
            self.sizeHeading.frame = CGRect(x: 16, y: y, width: max(0, width - 32), height: labelHeight(self.sizeHeading, width: width - 32))
            y = self.sizeHeading.frame.maxY + 8
            let textHeight = labelHeight(self.sizeLabel, width: width - 32)
            self.sizeLabel.frame = CGRect(x: 16, y: 12, width: max(0, width - 32), height: textHeight)
            self.slider.frame = CGRect(x: 16, y: self.sizeLabel.frame.maxY + 8, width: max(0, width - 32), height: 44)
            let endpointWidth = max(0, (width - 48) / 2)
            let endpointHeight = max(labelHeight(self.minimum, width: endpointWidth), labelHeight(self.maximum, width: endpointWidth))
            self.minimum.frame = CGRect(x: 16, y: self.slider.frame.maxY, width: endpointWidth, height: endpointHeight)
            self.maximum.frame = CGRect(x: width - 16 - endpointWidth, y: self.slider.frame.maxY, width: endpointWidth, height: endpointHeight)
            self.sizeBlock.frame = CGRect(x: 0, y: y, width: width, height: self.minimum.frame.maxY + 12)
            y = self.sizeBlock.frame.maxY
        }
        if let preload = self.rules.first(where: { $0.field == .preload }) { layoutRow(preload, last: true) }
        if self.footer.text?.isEmpty == false {
            self.footer.frame = CGRect(x: 16, y: y + 8, width: max(0, width - 32), height: labelHeight(self.footer, width: width - 32))
            y = self.footer.frame.maxY
        } else { self.footer.frame = .zero }
        if self.action != nil {
            self.actionButton.frame = CGRect(x: 0, y: y + 16, width: width, height: self.actionButton.measuredHeight(width: width))
            y = self.actionButton.frame.maxY
        } else { self.actionButton.frame = .zero }
        if !self.loading.isHidden {
            self.loading.frame = CGRect(x: 16, y: 32, width: max(0, width - 32), height: labelHeight(self.loading, width: width - 32))
            y = self.loading.frame.maxY
        }
        self.contentSize = CGSize(width: width, height: y + 24)
    }
}
