import UIKit
import Display

enum WegramSavedAttachmentAction: Equatable { case send, options }

final class WegramSavedConfirmationView: UIView {
    let heading = UILabel()
    let recipient = UILabel()
    let avatarHost = UIView()
    let summary = UITextView()
    let previewHost = UIView()
    var previewDimensions: CGSize?
    let comment = UITextField()
    let cancelButton = UIButton(type: .custom)
    let sendButton = UIButton(type: .custom)
    private let separator = UIView()
    private let middleSeparator = UIView()
    var cancel: () -> Void = {}
    var send: (String) -> Void = { _ in }
    var options: (String) -> Void = { _ in }
    private var completed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        for child in [self.heading, self.avatarHost, self.recipient, self.summary, self.previewHost, self.comment, self.separator, self.middleSeparator, self.cancelButton, self.sendButton] { self.addSubview(child) }
        self.heading.numberOfLines = 0
        self.recipient.numberOfLines = 2
        self.avatarHost.layer.cornerRadius = 4
        self.avatarHost.clipsToBounds = true
        self.previewHost.isUserInteractionEnabled = false
        self.summary.isEditable = false
        self.summary.isSelectable = true
        self.summary.textContainerInset = .zero
        self.summary.textContainer.lineFragmentPadding = 0
        self.summary.backgroundColor = .clear
        self.comment.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        self.comment.leftViewMode = .always
        self.comment.returnKeyType = .done
        self.comment.addAction(UIAction { [weak self] _ in self?.comment.resignFirstResponder() }, for: .editingDidEndOnExit)
        self.cancelButton.addAction(UIAction { [weak self] _ in
            guard let self, self.available else { return }
            self.completed = true
            self.endEditing(true)
            self.cancel()
        }, for: .touchUpInside)
        self.sendButton.addAction(UIAction { [weak self] _ in
            guard let self, self.available else { return }
            self.completed = true
            self.endEditing(true)
            self.send(self.comment.text ?? "")
        }, for: .touchUpInside)
        let press = UILongPressGestureRecognizer(target: self, action: #selector(optionsPressed(_:)))
        self.sendButton.addGestureRecognizer(press)
        self.sendButton.accessibilityIdentifier = "Wegram.FavoriteConfirmation.Send"
        self.cancelButton.accessibilityIdentifier = "Wegram.FavoriteConfirmation.Cancel"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var available: Bool { !self.completed && !self.isHidden && self.alpha > 0 && self.isUserInteractionEnabled }

    @discardableResult func requestOptions() -> Bool {
        guard self.available else { return false }
        self.completed = true
        self.endEditing(true)
        self.options(self.comment.text ?? "")
        return true
    }

    @objc private func optionsPressed(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { self.requestOptions() }
    }

    func update(recipient: String, summary: String, dark: Bool, chinese: Bool, fontSize: CGFloat) {
        self.backgroundColor = UIColor(rgb: dark ? 0x2c2c2c : 0xffffff)
        let ink = UIColor(rgb: dark ? 0xd0d0d0 : 0x181818)
        self.heading.text = chinese ? "发送给：" : "Send to:"
        self.heading.font = Font.semibold(fontSize)
        self.heading.textColor = ink
        self.recipient.text = recipient
        self.recipient.font = Font.regular(fontSize)
        self.recipient.textColor = ink
        self.summary.text = summary
        self.summary.font = Font.regular(fontSize * 14 / 17)
        self.summary.textColor = UIColor(rgb: dark ? 0x999999 : 0x666666)
        self.comment.font = Font.regular(fontSize * 14 / 17)
        self.comment.textColor = ink
        self.comment.backgroundColor = UIColor(rgb: dark ? 0x393939 : 0xf7f7f7)
        self.comment.attributedPlaceholder = NSAttributedString(string: chinese ? "给朋友留言" : "Add a comment", attributes: [.foregroundColor: UIColor(rgb: dark ? 0x777777 : 0xb2b2b2)])
        self.comment.accessibilityLabel = chinese ? "给朋友留言" : "Add a comment"
        self.cancelButton.setTitle(chinese ? "取消" : "Cancel", for: .normal)
        self.sendButton.setTitle(chinese ? "发送" : "Send", for: .normal)
        self.sendButton.accessibilityHint = chinese ? "长按编辑转发选项" : "Touch and hold to edit forwarding options"
        self.sendButton.accessibilityCustomActions = [UIAccessibilityCustomAction(name: chinese ? "转发选项" : "Forwarding Options", actionHandler: { [weak self] _ in self?.requestOptions() ?? false })]
        for button in [self.cancelButton, self.sendButton] { button.titleLabel?.font = Font.medium(fontSize) }
        self.cancelButton.setTitleColor(ink, for: .normal)
        self.sendButton.setTitleColor(UIColor(rgb: dark ? 0x7d90a9 : 0x576b95), for: .normal)
        for line in [self.separator, self.middleSeparator] { line.backgroundColor = UIColor(white: dark ? 1 : 0, alpha: 0.08) }
        self.setNeedsLayout()
    }

    func preferredHeight(width: CGFloat) -> CGFloat {
        let textWidth = max(0, width - 40)
        let title = ceil(self.heading.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        let name = max(40, ceil(self.recipient.sizeThatFits(CGSize(width: max(0, textWidth - 52), height: .greatestFiniteMagnitude)).height))
        let preview = self.previewDimensions.map { $0.aspectFitted(CGSize(width: textWidth, height: 166)).height } ?? min(166, max(60, ceil(self.summary.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)))
        return 20 + title + 12 + name + 20 + preview + 16 + max(36, ceil((self.comment.font?.lineHeight ?? 18) + 16)) + 20 + 58
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let titleHeight = ceil(self.heading.sizeThatFits(CGSize(width: max(0, width - 40), height: .greatestFiniteMagnitude)).height)
        self.heading.frame = CGRect(x: 20, y: 20, width: max(0, width - 40), height: titleHeight)
        let nameHeight = max(40, ceil(self.recipient.sizeThatFits(CGSize(width: max(0, width - 92), height: .greatestFiniteMagnitude)).height))
        let recipientY = self.heading.frame.maxY + 12
        self.avatarHost.frame = CGRect(x: 20, y: recipientY + (nameHeight - 40) / 2, width: 40, height: 40)
        self.avatarHost.subviews.forEach { $0.frame = self.avatarHost.bounds }
        self.recipient.frame = CGRect(x: 72, y: recipientY, width: max(0, width - 92), height: nameHeight)
        let footerY = max(0, self.bounds.height - 58)
        let commentHeight = max(36, ceil((self.comment.font?.lineHeight ?? 18) + 16))
        self.comment.frame = CGRect(x: 20, y: max(recipientY + nameHeight + 20, footerY - 20 - commentHeight), width: max(0, width - 40), height: commentHeight)
        let summaryY = recipientY + nameHeight + 20
        self.summary.frame = CGRect(x: 20, y: summaryY, width: max(0, width - 40), height: max(0, self.comment.frame.minY - 16 - summaryY))
        self.previewHost.frame = self.summary.frame
        self.previewHost.isHidden = self.previewDimensions == nil
        self.summary.isHidden = self.previewDimensions != nil
        self.separator.frame = CGRect(x: 0, y: footerY, width: width, height: UIScreenPixel)
        self.middleSeparator.frame = CGRect(x: floor(width / 2), y: footerY, width: UIScreenPixel, height: 58)
        self.cancelButton.frame = CGRect(x: 0, y: footerY, width: floor(width / 2), height: 58)
        self.sendButton.frame = CGRect(x: floor(width / 2), y: footerY, width: width - floor(width / 2), height: 58)
    }
}

final class WegramSavedConfirmationContentNode: AlertContentNode {
    override var containerCornerRadius: CGFloat { return 4 }
    let content = WegramSavedConfirmationView()
    let previewNode = TransformImageNode()
    private let scroll = UIScrollView()
    override init() {
        super.init()
        self.view.addSubview(self.scroll)
        self.scroll.addSubview(self.content)
        self.content.previewHost.addSubview(self.previewNode.view)
    }
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let width = max(0, min(320, size.width))
        let contentHeight = self.content.preferredHeight(width: width)
        let height = min(contentHeight, size.height)
        self.scroll.frame = CGRect(x: 0, y: 0, width: width, height: height)
        self.scroll.contentSize = CGSize(width: width, height: contentHeight)
        self.content.frame = CGRect(x: 0, y: 0, width: width, height: contentHeight)
        self.content.setNeedsLayout()
        self.content.layoutIfNeeded()
        if let dimensions = self.content.previewDimensions {
            let bounds = self.content.previewHost.bounds
            let fitted = dimensions.aspectFitted(bounds.size)
            self.previewNode.frame = CGRect(x: floor((bounds.width - fitted.width) / 2), y: 0, width: fitted.width, height: fitted.height)
            self.previewNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 0), imageSize: fitted, boundingSize: fitted, intrinsicInsets: .zero))()
        }
        return CGSize(width: width, height: height)
    }
}
