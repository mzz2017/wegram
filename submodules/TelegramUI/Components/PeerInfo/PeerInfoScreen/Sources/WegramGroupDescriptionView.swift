import UIKit
import Display
import AccountContext
import TextFormat

final class WegramGroupDescriptionTextView: UITextView {
    override func copy(_ sender: Any?) {
        let text = (self.text ?? "") as NSString
        let range = self.selectedRange
        guard range.location != NSNotFound, range.length > 0, range.location <= text.length, range.length <= text.length - range.location else { return }
        UIPasteboard.general.string = text.substring(with: range)
    }
}

final class WegramGroupDescriptionView: UIView, UITextViewDelegate {
    let textView = WegramGroupDescriptionTextView()
    let activity = UIActivityIndicatorView(style: .medium)
    var openLink: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    private var links: [URL: TextLinkItem] = [:]
    private var generation = 0
    private struct Configuration: Equatable {
        let text: String?
        let dark: Bool
        let fontSize: CGFloat
        let emptyText: String
    }
    private var configuration: Configuration?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.textView.isEditable = false
        self.textView.isSelectable = true
        self.textView.delegate = self
        self.textView.dataDetectorTypes = []
        self.textView.backgroundColor = .clear
        self.textView.contentInsetAdjustmentBehavior = .never
        self.textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        self.textView.textContainer.lineFragmentPadding = 0
        self.textView.accessibilityIdentifier = "Wegram.Group.DescriptionText"
        self.addSubview(self.textView)
        self.addSubview(self.activity)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(text: String?, dark: Bool, fontSize: CGFloat, title: String, emptyText: String, openTitle: String, moreTitle: String) {
        self.openTitle = openTitle
        self.moreTitle = moreTitle
        self.backgroundColor = UIColor(white: dark ? 0.1 : 1, alpha: 1)
        self.activity.color = UIColor(white: dark ? 0.7 : 0.4, alpha: 1)
        self.textView.accessibilityLabel = title
        if text == nil { self.activity.startAnimating() } else { self.activity.stopAnimating() }
        let key = Configuration(text: text, dark: dark, fontSize: fontSize, emptyText: emptyText)
        guard self.configuration != key else { return }
        self.configuration = key
        self.generation += 1
        self.links.removeAll()
        let font = UIFont.systemFont(ofSize: fontSize)
        let foreground = UIColor(white: dark ? 0.82 : 0.1, alpha: 1)
        let linkColor = UIColor(red: dark ? 125.0 / 255 : 87.0 / 255, green: dark ? 144.0 / 255 : 107.0 / 255, blue: dark ? 169.0 / 255 : 149.0 / 255, alpha: 1)
        let value: NSAttributedString
        if let text, !text.isEmpty {
            let entities = generateTextEntities(text, enabledTypes: [.internalUrl, .mention, .hashtag])
            value = stringWithAppliedEntities(text, entities: entities, baseColor: foreground, linkColor: linkColor, baseFont: font, linkFont: font, boldFont: font, italicFont: font, boldItalicFont: font, fixedFont: font, blockQuoteFont: font, message: nil)
        } else {
            value = NSAttributedString(string: text == nil ? "" : emptyText, attributes: [.font: font, .foregroundColor: UIColor(white: 0.6, alpha: 1)])
        }
        let attributed = NSMutableAttributedString(attributedString: value)
        value.enumerateAttributes(in: NSRange(location: 0, length: value.length)) { attributes, range, _ in
            let item: TextLinkItem?
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                item = .url(url: url, concealed: false)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                item = .mention(mention)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                item = .hashtag(hashtag.peerName, hashtag.hashtag)
            } else { item = nil }
            if let item, let url = URL(string: "wegram-description://\(self.generation)/\(range.location)") {
                self.links[url] = item
                attributed.addAttribute(.link, value: url, range: range)
            }
        }
        self.textView.linkTextAttributes = [.foregroundColor: linkColor]
        self.textView.attributedText = attributed
        self.textView.isUserInteractionEnabled = text != nil
    }

    func activateLink(_ url: URL, action: TextLinkItemActionType) {
        guard !self.isHidden, self.textView.isUserInteractionEnabled, let item = self.links[url] else { return }
        self.openLink?(action, item)
    }

    private var openTitle = "Open"
    private var moreTitle = "More"
    @available(iOS 17.0, *)
    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard case let .link(url) = textItem.content, self.links[url] != nil else { return nil }
        return UIAction(title: self.openTitle) { [weak self] _ in self?.activateLink(url, action: .tap) }
    }
    @available(iOS 17.0, *)
    func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
        guard case let .link(url) = textItem.content, self.links[url] != nil else { return nil }
        return UITextItem.MenuConfiguration(preview: nil, menu: UIMenu(children: [
            UIAction(title: self.openTitle) { [weak self] _ in self?.activateLink(url, action: .tap) },
            UIAction(title: self.moreTitle) { [weak self] _ in self?.activateLink(url, action: .longTap) }
        ]))
    }
    @available(iOS, introduced: 10.0, deprecated: 17.0)
    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if interaction == .invokeDefaultAction { self.activateLink(url, action: .tap) }
        else if interaction == .presentActions { self.activateLink(url, action: .longTap) }
        return false
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.textView.frame = self.bounds
        self.activity.center = CGPoint(x: self.bounds.midX, y: 40)
    }
}
