import UIKit

public func wegramViewAcceptsActions(_ view: UIView) -> Bool {
    var current: UIView? = view
    while let ancestor = current {
        guard !ancestor.isHidden, ancestor.alpha > 0, ancestor.isUserInteractionEnabled else { return false }
        current = ancestor.superview
    }
    return true
}

public protocol AttachmentCustomBottomPanel: UIView {
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat) -> CGFloat
    func updateLoadingProgress(_ progress: CGFloat?)
}

public final class WegramPhotoSendingState {
    public var original = false
    public var mergeDisplay = false
    public init() {}

    public func sendOptions(isAvailable: Bool, asFile: Bool) -> (asFile: Bool, convertToJpeg: Bool?) {
        if !isAvailable { self.original = false }
        // Original explicitly keeps the source format; the separate Send as File action retains its conversion choice.
        return (asFile || self.original, self.original ? false : nil)
    }
}

private final class OriginalPhotoButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        if self.currentTitle?.isEmpty ?? true {
            self.imageView?.frame = CGRect(x: (self.bounds.width - 20) / 2, y: (self.bounds.height - 20) / 2, width: 20, height: 20)
            self.titleLabel?.frame = .zero
            return
        }
        let text = self.titleLabel?.sizeThatFits(self.bounds.size) ?? .zero
        let x = (self.bounds.width - text.width - 24) / 2
        self.imageView?.frame = CGRect(x: x - 1.5, y: (self.bounds.height - 23) / 2, width: 23, height: 23)
        self.titleLabel?.frame = CGRect(x: x + 24, y: (self.bounds.height - text.height) / 2, width: text.width, height: text.height)
    }
}

private final class MergePhotoButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.frame = CGRect(x: -1.5, y: (self.bounds.height - 23) / 2, width: 23, height: 23)
        let width = max(0, self.bounds.width - 28)
        let size = self.titleLabel?.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)) ?? .zero
        self.titleLabel?.frame = CGRect(x: 28, y: (self.bounds.height - size.height) / 2, width: width, height: size.height)
    }
}

public final class WegramPhotoMergeView: UIView {
    public let button: UIButton = MergePhotoButton(type: .custom)
    public var toggle: () -> Void = {}
    private var available = false
    private var minimumHeight: CGFloat = 56
    private var enabled = true

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.isHidden = true
        self.button.titleLabel?.numberOfLines = 0
        self.addSubview(self.button)
        self.button.addAction(UIAction { [weak self] _ in
            guard let self, self.available, self.enabled, self.button.isEnabled, wegramViewAcceptsActions(self) else { return }
            self.toggle()
        }, for: .touchUpInside)
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(count: Int, selected: Bool?, enabled: Bool = true, dark: Bool, fontSize: CGFloat, title: String, minimumHeight: CGFloat = 56) {
        self.minimumHeight = minimumHeight
        self.available = count >= 3 && selected != nil
        self.enabled = enabled
        self.isHidden = !self.available
        self.button.isEnabled = self.available && enabled
        self.button.titleLabel?.font = .systemFont(ofSize: fontSize)
        self.button.setTitle(title, for: .normal)
        self.button.setTitleColor(UIColor(white: dark ? 0.75 : 0.4, alpha: 1), for: .normal)
        self.button.setImage(UIImage(systemName: selected == true ? "checkmark.circle.fill" : "circle"), for: .normal)
        self.button.tintColor = selected == true ? UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1) : UIColor(white: dark ? 0.45 : 0.7, alpha: 1)
        self.button.accessibilityTraits = selected == true ? [.button, .selected] : .button
        self.alpha = enabled ? 1 : 0.4
        self.setNeedsLayout()
    }

    public func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        self.button.isEnabled = self.available && enabled
        self.alpha = enabled ? 1 : 0.4
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard self.available else { return CGSize(width: size.width, height: 0) }
        let text = self.button.titleLabel?.sizeThatFits(CGSize(width: max(1, size.width - 60), height: .greatestFiniteMagnitude)) ?? .zero
        return CGSize(width: size.width, height: max(self.minimumHeight, ceil(text.height) + 16))
    }
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.button.frame = self.bounds.insetBy(dx: 16, dy: 0)
    }
}

public final class WegramPhotoAddAccessButton: UIButton {
    public var pressed: () -> Void = {}

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.titleLabel?.numberOfLines = 0
        self.titleLabel?.textAlignment = .center
        self.setImage(UIImage(systemName: "plus"), for: .normal)
        self.addAction(UIAction { [weak self] _ in
            guard let self, self.isEnabled, wegramViewAcceptsActions(self) else { return }
            self.pressed()
        }, for: .touchUpInside)
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(title: String, fontSize: CGFloat, dark: Bool) {
        self.setTitle(title, for: .normal)
        self.isAccessibilityElement = true
        self.accessibilityLabel = title.replacingOccurrences(of: "\n", with: " ")
        self.titleLabel?.font = .systemFont(ofSize: fontSize)
        let color = UIColor(white: dark ? 0.6 : 0.5, alpha: 1)
        self.setTitleColor(color, for: .normal)
        self.tintColor = color
        self.backgroundColor = UIColor(white: dark ? 0.125 : 0.97, alpha: 1)
        self.setNeedsLayout()
    }
    public override func layoutSubviews() {
        super.layoutSubviews()
        let width = max(1, self.bounds.width - 12)
        let text = self.titleLabel?.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)) ?? .zero
        let imageSide = min(24, max(0, self.bounds.height - text.height - 16))
        let top = max(0, (self.bounds.height - imageSide - 8 - text.height) / 2)
        self.imageView?.frame = CGRect(x: (self.bounds.width - imageSide) / 2, y: top, width: imageSide, height: imageSide)
        self.titleLabel?.frame = CGRect(x: 6, y: top + imageSide + 8, width: width, height: max(0, min(text.height, self.bounds.height - top - imageSide - 8)))
    }
}

private final class PhotoLimitedAccessButton: UIButton {
    private let disclosure = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.titleLabel?.numberOfLines = 0
        self.titleLabel?.textAlignment = .left
        self.setImage(UIImage(systemName: "info.circle"), for: .normal)
        self.disclosure.contentMode = .scaleAspectFit
        self.addSubview(self.disclosure)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let text = self.titleLabel?.sizeThatFits(CGSize(width: max(1, size.width - 92), height: .greatestFiniteMagnitude)) ?? .zero
        return CGSize(width: size.width, height: max(72, ceil(text.height) + 24))
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let text = self.titleLabel?.sizeThatFits(CGSize(width: max(1, self.bounds.width - 92), height: .greatestFiniteMagnitude)) ?? .zero
        self.imageView?.frame = CGRect(x: 16, y: (self.bounds.height - 23) / 2, width: 23, height: 23)
        self.titleLabel?.frame = CGRect(x: 52, y: (self.bounds.height - text.height) / 2, width: max(1, self.bounds.width - 92), height: text.height)
        self.disclosure.frame = CGRect(x: self.bounds.width - 28, y: (self.bounds.height - 16) / 2, width: 8, height: 16)
        self.disclosure.tintColor = self.tintColor.withAlphaComponent(0.6)
    }
}

public final class WegramPhotoToolbarView: UIView, AttachmentCustomBottomPanel {
    public let mergeView = WegramPhotoMergeView()
    public let previewButton = UIButton(type: .custom)
    public let originalButton: UIButton = OriginalPhotoButton(type: .custom)
    public let sendButton = UIButton(type: .custom)
    public let limitedAccessButton: UIButton = PhotoLimitedAccessButton(frame: .zero)
    private let sendBackground = UIView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var count = 0
    private var loading = false
    private var originalAvailable = true
    private var rowHeight: CGFloat = 56
    private var font = UIFont.systemFont(ofSize: 17)
    public var preview: () -> Void = {}
    public var toggleOriginal: () -> Void = {}
    public var send: () -> Void = {}
    public var options: () -> Void = {}
    public var manageAccess: () -> Void = {}

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.mergeView)
        self.limitedAccessButton.isHidden = true
        self.addSubview(self.limitedAccessButton)
        self.limitedAccessButton.addAction(UIAction { [weak self] _ in
            guard let self, self.acceptsActions, !self.limitedAccessButton.isHidden, self.limitedAccessButton.isEnabled else { return }
            self.manageAccess()
        }, for: .touchUpInside)
        for button in [self.previewButton, self.originalButton, self.sendButton] { self.addSubview(button) }
        self.sendBackground.isUserInteractionEnabled = false
        self.sendBackground.layer.cornerRadius = 4
        self.sendButton.insertSubview(self.sendBackground, at: 0)
        self.spinner.hidesWhenStopped = true
        self.sendButton.addSubview(self.spinner)
        self.previewButton.addAction(UIAction { [weak self] _ in
            guard let self, self.acceptsActions, self.previewButton.isEnabled else { return }
            self.preview()
        }, for: .touchUpInside)
        self.originalButton.addAction(UIAction { [weak self] _ in
            guard let self, self.acceptsActions, self.originalButton.isEnabled else { return }
            self.toggleOriginal()
        }, for: .touchUpInside)
        self.sendButton.addAction(UIAction { [weak self] _ in
            guard let self, self.acceptsActions, self.sendButton.isEnabled else { return }
            self.send()
        }, for: .touchUpInside)
        self.sendButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.sendHeld(_:))))
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var acceptsActions: Bool { wegramViewAcceptsActions(self) }
    @objc private func sendHeld(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, self.acceptsActions, !self.loading, self.count > 0 else { return }
        self.options()
    }
    public func update(count: Int, original: Bool, originalAvailable: Bool, dark: Bool, fontSize: CGFloat, previewTitle: String, originalTitle: String, sendTitle: String, optionsTitle: String, mergeSelected: Bool? = nil, mergeTitle: String = "发送后合并展示", limitedAccessTitle: String? = nil) {
        self.count = count
        self.originalAvailable = originalAvailable
        self.font = .systemFont(ofSize: fontSize)
        self.rowHeight = max(56, ceil(self.font.lineHeight) + 16)
        let color = UIColor(white: dark ? 0.82 : 0.1, alpha: 1)
        self.backgroundColor = UIColor(white: dark ? 0.125 : 248 / 255, alpha: 1)
        self.limitedAccessButton.isHidden = limitedAccessTitle == nil || count > 0
        self.limitedAccessButton.setTitle(limitedAccessTitle, for: .normal)
        self.limitedAccessButton.titleLabel?.font = .systemFont(ofSize: fontSize * 14 / 17)
        let accessColor = UIColor(white: dark ? 0.6 : 0.5, alpha: 1)
        self.limitedAccessButton.setTitleColor(accessColor, for: .normal)
        self.limitedAccessButton.tintColor = accessColor
        self.previewButton.setTitle(count > 0 ? "\(previewTitle)(\(count))" : previewTitle, for: .normal)
        self.mergeView.update(count: count, selected: mergeSelected, enabled: !self.loading, dark: dark, fontSize: fontSize, title: mergeTitle, minimumHeight: 52)
        self.mergeView.button.setTitleColor(color, for: .normal)
        self.originalButton.setTitle(originalTitle, for: .normal)
        self.sendButton.setTitle(count > 0 ? "\(sendTitle)(\(count))" : sendTitle, for: .normal)
        for button in [self.previewButton, self.originalButton, self.sendButton] {
            button.titleLabel?.font = self.font
            button.setTitleColor(color, for: .normal)
            button.setTitleColor(UIColor(white: dark ? 0.4 : 0.7, alpha: 1), for: .disabled)
        }
        self.sendButton.titleLabel?.font = .systemFont(ofSize: fontSize * 14 / 17)
        self.originalButton.setImage(UIImage(systemName: original ? "checkmark.circle.fill" : "circle"), for: .normal)
        self.originalButton.tintColor = original ? UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1) : UIColor(white: dark ? 0.45 : 0.7, alpha: 1)
        self.originalButton.accessibilityTraits = original ? [.button, .selected] : .button
        self.originalButton.accessibilityHint = originalTitle == "原图" ? "以原文件发送" : "Send original files"
        self.sendButton.setTitleColor(.white, for: .normal)
        self.sendBackground.backgroundColor = count > 0 ? UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1) : UIColor(white: dark ? 0.18 : 235 / 255, alpha: 1)
        self.sendButton.accessibilityCustomActions = [UIAccessibilityCustomAction(name: optionsTitle, actionHandler: { [weak self] _ in
            guard let self, self.acceptsActions, !self.loading, self.count > 0 else { return false }
            self.options()
            return true
        })]
        self.refreshEnabled()
        self.setNeedsLayout()
    }
    private func refreshEnabled() {
        self.limitedAccessButton.isEnabled = !self.loading
        self.mergeView.setEnabled(!self.loading)
        self.mergeView.isUserInteractionEnabled = !self.loading
        self.previewButton.isEnabled = self.count > 0 && !self.loading
        self.sendButton.isEnabled = self.count > 0 && !self.loading
        self.originalButton.isEnabled = self.originalAvailable && !self.loading
        self.originalButton.alpha = self.originalButton.isEnabled ? 1 : 0.4
        self.sendButton.titleLabel?.alpha = self.loading ? 0 : 1
        if self.loading { self.spinner.startAnimating() } else { self.spinner.stopAnimating() }
    }
    public func updateLoadingProgress(_ progress: CGFloat?) {
        self.loading = progress != nil
        self.refreshEnabled()
    }
    public func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat) -> CGFloat {
        let left = leftInset + 16
        let right = max(left, width - rightInset - 16)
        let previewWidth = max(44, ceil(self.previewButton.titleLabel?.intrinsicContentSize.width ?? 0))
        let originalWidth = max(44, ceil(self.originalButton.titleLabel?.intrinsicContentSize.width ?? 0) + 24)
        let sendWidth = max(self.count > 0 ? 74 : 52, ceil(self.sendButton.titleLabel?.intrinsicContentSize.width ?? 0) + 24)
        let available = max(0, right - left)
        let stacked = previewWidth + originalWidth + sendWidth + 16 > available
        let threeRows = stacked && previewWidth + originalWidth + 8 > available
        self.previewButton.frame = CGRect(x: left, y: 0, width: min(available, previewWidth), height: self.rowHeight)
        self.originalButton.frame = CGRect(x: stacked ? max(left, right - originalWidth) : max(left + previewWidth + 8, min((width - originalWidth) / 2, right - sendWidth - 8 - originalWidth)), y: threeRows ? self.rowHeight : 0, width: min(available, originalWidth), height: self.rowHeight)
        self.sendButton.frame = CGRect(x: max(left, right - sendWidth), y: threeRows ? self.rowHeight * 2 : (stacked ? self.rowHeight : 0), width: min(available, sendWidth), height: self.rowHeight)
        let sendHeight = max(32, ceil(self.sendButton.titleLabel?.font.lineHeight ?? 0) + 12)
        self.sendBackground.frame = CGRect(x: 0, y: (self.rowHeight - sendHeight) / 2, width: self.sendButton.bounds.width, height: sendHeight)
        let mergeHeight = self.mergeView.sizeThatFits(CGSize(width: max(0, width - leftInset - rightInset), height: .greatestFiniteMagnitude)).height
        let accessWidth = max(0, width - leftInset - rightInset)
        let accessHeight = self.limitedAccessButton.isHidden ? 0 : self.limitedAccessButton.sizeThatFits(CGSize(width: accessWidth, height: .greatestFiniteMagnitude)).height
        self.limitedAccessButton.frame = CGRect(x: leftInset, y: 0, width: accessWidth, height: accessHeight)
        let mergeTopInset: CGFloat = mergeHeight > 0 ? 20 : 0
        self.mergeView.frame = CGRect(x: leftInset, y: accessHeight + mergeTopInset, width: accessWidth, height: mergeHeight)
        for button in [self.previewButton, self.originalButton, self.sendButton] { button.frame.origin.y += accessHeight + mergeTopInset + mergeHeight }
        self.spinner.center = CGPoint(x: self.sendButton.bounds.midX, y: self.sendButton.bounds.midY)
        // The legacy layout can report 20pt on a device whose home-indicator inset is 34pt.
        let effectiveBottomInset = max(0, bottomInset, self.window?.safeAreaInsets.bottom ?? 0)
        return accessHeight + mergeTopInset + mergeHeight + self.rowHeight * (threeRows ? 3 : (stacked ? 2 : 1)) + effectiveBottomInset
    }
}

public final class WegramPhotoAccessView: UIView {
    public let titleLabel = UILabel()
    public let textLabel = UILabel()
    public let settingsButton = UIButton(type: .custom)
    public let scrollView = UIScrollView()
    public var openSettings: () -> Void = {}

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.scrollView.alwaysBounceVertical = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.addSubview(self.scrollView)
        for label in [self.titleLabel, self.textLabel] {
            label.numberOfLines = 0
            label.textAlignment = .center
            self.scrollView.addSubview(label)
        }
        self.titleLabel.accessibilityTraits = .header
        self.settingsButton.titleLabel?.numberOfLines = 0
        self.settingsButton.titleLabel?.textAlignment = .center
        self.settingsButton.layer.cornerRadius = 4
        self.settingsButton.setTitleColor(.white, for: .normal)
        self.settingsButton.backgroundColor = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
        self.scrollView.addSubview(self.settingsButton)
        self.settingsButton.addAction(UIAction { [weak self] _ in
            guard let self, wegramViewAcceptsActions(self), self.settingsButton.isEnabled else { return }
            self.openSettings()
        }, for: .touchUpInside)
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(dark: Bool, fontSize: CGFloat, title: String, text: String, settingsTitle: String) {
        self.titleLabel.text = title
        self.textLabel.text = text
        self.settingsButton.setTitle(settingsTitle, for: .normal)
        self.settingsButton.accessibilityLabel = settingsTitle
        self.titleLabel.font = .systemFont(ofSize: fontSize, weight: .semibold)
        self.textLabel.font = .systemFont(ofSize: fontSize * 14 / 17)
        self.settingsButton.titleLabel?.font = .systemFont(ofSize: fontSize, weight: .medium)
        self.titleLabel.textColor = UIColor(white: dark ? 0.82 : 0.1, alpha: 1)
        self.textLabel.textColor = UIColor(white: dark ? 0.55 : 0.5, alpha: 1)
        self.backgroundColor = UIColor(white: dark ? 0.125 : 1, alpha: 1)
    }

    public func updateLayout(size: CGSize, insets: UIEdgeInsets) {
        self.scrollView.frame = CGRect(x: insets.left, y: insets.top, width: max(0, size.width - insets.left - insets.right), height: max(0, size.height - insets.top - insets.bottom))
        let width = max(0, self.scrollView.bounds.width - 32)
        let titleHeight = ceil(self.titleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        let textHeight = ceil(self.textLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        let buttonTextSize = self.settingsButton.titleLabel?.sizeThatFits(CGSize(width: max(0, width - 40), height: .greatestFiniteMagnitude)) ?? .zero
        let buttonHeight = max(44, ceil(buttonTextSize.height) + 16)
        let buttonWidth = min(width, max(180, ceil(buttonTextSize.width) + 40))
        let height = titleHeight + 12 + textHeight + 28 + buttonHeight
        let top = max(24, floor((self.scrollView.bounds.height - height) / 2))
        self.titleLabel.frame = CGRect(x: 16, y: top, width: width, height: titleHeight)
        self.textLabel.frame = CGRect(x: 16, y: self.titleLabel.frame.maxY + 12, width: width, height: textHeight)
        self.settingsButton.frame = CGRect(x: floor((self.scrollView.bounds.width - buttonWidth) / 2), y: self.textLabel.frame.maxY + 28, width: buttonWidth, height: buttonHeight)
        self.scrollView.contentSize = CGSize(width: self.scrollView.bounds.width, height: self.settingsButton.frame.maxY + 24)
    }
}

public struct WegramPhotoEditorToolbarLayout {
    public let viewport: CGRect
    public let contentSize: CGSize
    public let buttons: [CGRect]

    public init(size: CGSize, cancelFrame: CGRect?, doneFrame: CGRect, count: Int) {
        let horizontal = size.width > size.height
        if horizontal {
            let start = cancelFrame.map { $0.maxX + 4 } ?? 16
            self.viewport = CGRect(x: start, y: 0, width: max(0, doneFrame.minX - 4 - start), height: 44)
        } else {
            let end = cancelFrame.map { $0.minY - 4 } ?? (size.height - 16)
            self.viewport = CGRect(x: doneFrame.minX, y: doneFrame.maxY + 4, width: 44, height: max(0, end - doneFrame.maxY - 4))
        }
        let total = CGFloat(max(0, count)) * 44 + CGFloat(max(0, count - 1)) * 10
        let length = horizontal ? self.viewport.width : self.viewport.height
        let start = max(0, floor((length - total) / 2))
        self.contentSize = horizontal ? CGSize(width: max(length, total), height: 44) : CGSize(width: 44, height: max(length, total))
        self.buttons = (0 ..< max(0, count)).map { index in
            let offset = start + CGFloat(index) * 54
            return CGRect(x: horizontal ? offset : 0, y: horizontal ? 0 : offset, width: 44, height: 44)
        }
    }
}

public final class WegramPhotoPreviewControlsView: UIView {
    public let editButton = UIButton(type: .custom)
    public let originalButton: UIButton = OriginalPhotoButton(type: .custom)
    public let scrollView = UIScrollView()
    public var toggleOriginal: () -> Void = {}
    private var editTitle = ""
    private var originalTitle = ""
    private var font = UIFont.systemFont(ofSize: 17)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.editButton.contentHorizontalAlignment = .left
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.delaysContentTouches = false
        self.addSubview(self.scrollView)
        self.scrollView.addSubview(self.editButton)
        self.scrollView.addSubview(self.originalButton)
        self.editButton.showsMenuAsPrimaryAction = true
        self.originalButton.addAction(UIAction { [weak self] _ in
            guard let self, wegramViewAcceptsActions(self), self.originalButton.isEnabled else { return }
            self.toggleOriginal()
        }, for: .touchUpInside)
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(original: Bool, available: Bool, enabled: Bool, fontSize: CGFloat, editTitle: String, originalTitle: String, menu: UIMenu?, selectionManagementAvailable: Bool = false) {
        self.editTitle = editTitle
        self.originalTitle = originalTitle
        self.font = .systemFont(ofSize: fontSize)
        self.editButton.menu = menu
        self.editButton.isEnabled = (enabled || selectionManagementAvailable) && !(menu?.children.isEmpty ?? true)
        self.originalButton.isEnabled = enabled && available
        self.editButton.accessibilityLabel = editTitle
        self.originalButton.accessibilityLabel = originalTitle
        self.originalButton.accessibilityHint = originalTitle == "原图" ? "以原文件发送，保留原格式" : "Send original files without format conversion"
        self.originalButton.accessibilityTraits = original ? [.button, .selected] : .button
        self.originalButton.setImage(UIImage(systemName: original ? "checkmark.circle.fill" : "circle"), for: .normal)
        self.originalButton.tintColor = original ? UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1) : .white
        for button in [self.editButton, self.originalButton] {
            button.titleLabel?.font = self.font
            button.setTitleColor(.white, for: .normal)
            button.alpha = button.isEnabled ? 1 : 0.3
        }
    }

    public func updateLayout(size: CGSize, originalCenter: CGFloat? = nil) {
        self.scrollView.frame = CGRect(origin: .zero, size: size)
        if size.width > size.height {
            self.editButton.setImage(nil, for: .normal)
            self.editButton.setTitle(self.editTitle, for: .normal)
            self.originalButton.setTitle(self.originalTitle, for: .normal)
            let editWidth = max(44, ceil((self.editTitle as NSString).size(withAttributes: [.font: self.font]).width))
            let originalWidth = max(44, ceil((self.originalTitle as NSString).size(withAttributes: [.font: self.font]).width) + 24)
            let width = max(size.width, editWidth + 12 + originalWidth)
            self.editButton.frame = CGRect(x: 0, y: 0, width: editWidth, height: max(44, size.height))
            let originalX = max(editWidth + 12, min(width - originalWidth, (originalCenter ?? (width / 2)) - originalWidth / 2))
            self.originalButton.frame = CGRect(x: originalX, y: 0, width: originalWidth, height: max(44, size.height))
            self.scrollView.contentSize = CGSize(width: width, height: max(44, size.height))
        } else {
            self.editButton.setTitle(nil, for: .normal)
            self.editButton.setImage(UIImage(systemName: "pencil"), for: .normal)
            self.editButton.tintColor = .white
            self.originalButton.setTitle(nil, for: .normal)
            self.editButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
            self.originalButton.frame = CGRect(x: 0, y: 56, width: 44, height: 44)
            self.scrollView.contentSize = CGSize(width: max(44, size.width), height: max(100, size.height))
        }
        let offset = self.scrollView.contentOffset
        self.scrollView.contentOffset = CGPoint(x: max(0, min(offset.x, self.scrollView.contentSize.width - size.width)), y: max(0, min(offset.y, self.scrollView.contentSize.height - size.height)))
    }
}

public final class WegramPhotoAlbumListView: UIView, UITableViewDataSource, UITableViewDelegate {
    public struct Item {
        public let id: String
        public let title: String
        public let count: Int
        public let selected: Bool
        public init(id: String, title: String, count: Int, selected: Bool) {
            self.id = id; self.title = title; self.count = count; self.selected = selected
        }
    }

    private final class Cell: UITableViewCell {
        let thumbnail = UIImageView()
        let nameLabel = UILabel()
        let check = UIImageView(image: UIImage(systemName: "checkmark"))
        var representedId: String?
        var cancelImageLoad: (() -> Void)?
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            self.thumbnail.contentMode = .scaleAspectFill
            self.thumbnail.clipsToBounds = true
            self.check.contentMode = .scaleAspectFit
            self.check.tintColor = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
            self.nameLabel.lineBreakMode = .byTruncatingTail
            for child in [self.thumbnail, self.nameLabel, self.check] {
                child.isAccessibilityElement = false
                self.contentView.addSubview(child)
            }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func prepareForReuse() {
            super.prepareForReuse()
            self.representedId = nil
            self.cancelImageLoad?(); self.cancelImageLoad = nil
            self.thumbnail.image = nil
        }
        deinit { self.cancelImageLoad?() }
        override func layoutSubviews() {
            super.layoutSubviews()
            self.thumbnail.frame = CGRect(x: 0, y: floor((self.bounds.height - 56) / 2), width: 56, height: 56)
            self.nameLabel.frame = CGRect(x: 72, y: 0, width: max(0, self.contentView.bounds.width - 72 - 52), height: self.bounds.height)
            self.check.frame = CGRect(x: self.contentView.bounds.width - 40, y: floor((self.bounds.height - 24) / 2), width: 24, height: 24)
        }
    }

    public let tableView = UITableView(frame: .zero, style: .plain)
    public let dimmingButton = UIButton(type: .custom)
    public var select: (String) -> Void = { _ in }
    public var dismissed: () -> Void = {}
    public var loadThumbnail: ((String, @escaping (UIImage?) -> Void) -> (() -> Void)?)?
    private let items: [Item]
    private let dark: Bool
    private let font: UIFont
    private let panel = UIView()
    private var headerHeight: CGFloat
    private var active = true

    public init(items: [Item], limitedTitle: String?, dark: Bool, fontSize: CGFloat, cancelTitle: String) {
        self.items = items
        self.dark = dark
        let scale = max(1, fontSize / 17)
        self.font = .systemFont(ofSize: 17 * scale)
        self.headerHeight = limitedTitle == nil ? 0 : max(42, ceil(UIFont.systemFont(ofSize: 13 * scale).lineHeight) + 16)
        super.init(frame: .zero)
        self.accessibilityViewIsModal = true
        self.dimmingButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.dimmingButton.accessibilityLabel = cancelTitle
        self.addSubview(self.dimmingButton)
        self.panel.layer.cornerRadius = 12
        self.panel.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        self.panel.clipsToBounds = true
        self.addSubview(self.panel)
        self.panel.addSubview(self.tableView)
        self.tableView.register(Cell.self, forCellReuseIdentifier: "album")
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.rowHeight = max(56, ceil(self.font.lineHeight) + 20)
        self.tableView.separatorInset = .zero
        self.tableView.separatorColor = UIColor(white: dark ? 0.22 : 0.87, alpha: 1)
        self.tableView.backgroundColor = UIColor(white: dark ? 0.1 : 1, alpha: 1)
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.sectionHeaderTopPadding = 0
        self.tableView.tableFooterView = UIView()
        if let limitedTitle {
            let label = UILabel()
            label.text = limitedTitle
            label.textAlignment = .center
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 13 * scale)
            label.textColor = UIColor(white: dark ? 0.65 : 0.48, alpha: 1)
            label.backgroundColor = UIColor(white: dark ? 0.14 : 0.97, alpha: 1)
            label.frame = CGRect(x: 0, y: 0, width: 0, height: self.headerHeight)
            self.tableView.tableHeaderView = label
        }
        self.dimmingButton.addAction(UIAction { [weak self] _ in self?.cancel() }, for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func updateLayout(size: CGSize) {
        self.dimmingButton.frame = CGRect(origin: .zero, size: size)
        if let header = self.tableView.tableHeaderView as? UILabel {
            self.headerHeight = max(42, ceil(header.sizeThatFits(CGSize(width: max(1, size.width - 32), height: .greatestFiniteMagnitude)).height) + 16)
        }
        let height = min(max(0, size.height - 44), self.headerHeight + min(6, CGFloat(self.items.count)) * self.tableView.rowHeight)
        self.panel.frame = CGRect(x: 0, y: 0, width: size.width, height: height)
        self.tableView.frame = self.panel.bounds
        if let header = self.tableView.tableHeaderView, header.frame.width != size.width || header.frame.height != self.headerHeight {
            header.frame = CGRect(x: 0, y: 0, width: size.width, height: self.headerHeight)
            self.tableView.tableHeaderView = header
        }
        self.tableView.isScrollEnabled = self.headerHeight + CGFloat(self.items.count) * self.tableView.rowHeight > height
    }

    public func invalidate() {
        self.active = false
        for cell in self.tableView.visibleCells {
            guard let cell = cell as? Cell else { continue }
            cell.representedId = nil
            cell.cancelImageLoad?(); cell.cancelImageLoad = nil
        }
    }
    private func cancel() {
        guard self.active, wegramViewAcceptsActions(self) else { return }
        self.invalidate()
        self.dismissed()
    }
    public override func accessibilityPerformEscape() -> Bool {
        guard self.active, wegramViewAcceptsActions(self) else { return false }
        self.cancel()
        return true
    }
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.items.count }
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "album", for: indexPath) as! Cell
        let item = self.items[indexPath.row]
        cell.cancelImageLoad?(); cell.cancelImageLoad = nil
        cell.representedId = item.id
        cell.thumbnail.image = nil
        cell.backgroundColor = self.tableView.backgroundColor
        let title = NSMutableAttributedString(string: item.title, attributes: [.font: self.font, .foregroundColor: UIColor(white: self.dark ? 0.9 : 0.1, alpha: 1)])
        title.append(NSAttributedString(string: "(\(item.count))", attributes: [.font: self.font, .foregroundColor: UIColor(white: self.dark ? 0.6 : 0.48, alpha: 1)]))
        cell.nameLabel.attributedText = title
        cell.check.isHidden = !item.selected
        cell.accessibilityLabel = item.title
        cell.accessibilityValue = String(item.count)
        cell.accessibilityTraits = item.selected ? [.button, .selected] : .button
        cell.cancelImageLoad = self.loadThumbnail?(item.id, { [weak cell] image in
            guard let cell, cell.representedId == item.id else { return }
            cell.thumbnail.image = image
        })
        return cell
    }
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard self.active, wegramViewAcceptsActions(self), self.items.indices.contains(indexPath.row) else { return }
        self.invalidate()
        self.select(self.items[indexPath.row].id)
    }
}

public final class WegramPhotoAlbumButton: UIButton {
    public var toggle: () -> Void = {}
    public var options: () -> Void = {}

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.addAction(UIAction { [weak self] _ in
            guard let self, self.isEnabled, wegramViewAcceptsActions(self) else { return }
            self.toggle()
        }, for: .touchUpInside)
        self.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:))))
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    public override var intrinsicContentSize: CGSize { CGSize(width: 44, height: 44) }

    public func update(expanded: Bool, dark: Bool, enabled: Bool, chinese: Bool, moreTitle: String) {
        self.isSelected = expanded
        self.isEnabled = enabled
        self.accessibilityLabel = chinese ? "相册" : "Albums"
        self.accessibilityValue = chinese ? (expanded ? "已展开" : "已收起") : (expanded ? "Expanded" : "Collapsed")
        self.accessibilityHint = chinese ? "轻点切换相册，长按显示更多照片选项" : "Tap to switch albums. Touch and hold for more photo options."
        self.accessibilityCustomActions = [UIAccessibilityCustomAction(name: moreTitle, actionHandler: { [weak self] _ in
            guard let self, self.isEnabled, wegramViewAcceptsActions(self) else { return false }
            self.options()
            return true
        })]
        self.tintColor = UIColor(white: dark ? 0.9 : 0.1, alpha: 1)
        let format = UIGraphicsImageRendererFormat(); format.scale = 3
        let image = UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28), format: format).image { renderer in
            let context = renderer.cgContext
            context.setStrokeColor(UIColor.black.cgColor)
            context.setLineWidth(1.25)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.stroke(CGRect(x: 6, y: expanded ? 4 : 10, width: 16, height: 14))
            let lines: [(CGFloat, CGFloat, CGFloat)] = [(8, expanded ? 21 : 7, 12), (10, expanded ? 24 : 4, 8)]
            for (x, y, width) in lines {
                context.move(to: CGPoint(x: x, y: y))
                context.addLine(to: CGPoint(x: x + width, y: y))
            }
            if expanded {
                context.move(to: CGPoint(x: 10, y: 12))
                context.addLine(to: CGPoint(x: 14, y: 8))
                context.addLine(to: CGPoint(x: 18, y: 12))
            }
            context.strokePath()
        }.withRenderingMode(.alwaysTemplate)
        self.setImage(image, for: .normal)
    }
    @objc private func longPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, self.isEnabled, wegramViewAcceptsActions(self) else { return }
        self.options()
    }
}
