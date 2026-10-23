import UIKit
import Display
import TelegramCore
import ItemListVenueItem
import ChatMessageItemCommon
import TelegramPresentationData
import TelegramStringFormatting
import ChatPresentationInterfaceState

enum WegramSavedAttachmentCategory: CaseIterable, Equatable {
    case all, links, files, media, music, voice

    var tags: EngineMessage.Tags? {
        switch self {
        case .all: return nil
        case .links: return .webPage
        case .files: return .file
        case .media: return .photoOrVideo
        case .music: return .music
        case .voice: return .voice
        }
    }

    func title(chinese: Bool) -> String {
        switch self {
        case .all: return chinese ? "全部" : "All"
        case .links: return chinese ? "链接" : "Links"
        case .files: return chinese ? "文件" : "Files"
        case .media: return chinese ? "图片与视频" : "Photos & Videos"
        case .music: return chinese ? "音乐" : "Music"
        case .voice: return chinese ? "语音" : "Voice"
        }
    }
}

final class WegramSavedAttachmentCategoriesView: UIView {
    let buttons = WegramSavedAttachmentCategory.allCases.map { _ in UIButton(type: .custom) }
    private let surface = UIView()
    private let separators = (0 ..< 4).map { _ in UIView() }
    private var selected = WegramSavedAttachmentCategory.all
    var selectedCategory: (WegramSavedAttachmentCategory) -> Void = { _ in }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.surface)
        self.surface.layer.cornerRadius = 4
        for (index, button) in self.buttons.enumerated() {
            self.surface.addSubview(button)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button, !self.isHidden, self.alpha > 0, self.isUserInteractionEnabled, button.isEnabled else { return }
                let category = WegramSavedAttachmentCategory.allCases[index]
                guard self.selected != category else { return }
                self.selectedCategory(category)
            }, for: .touchUpInside)
        }
        for separator in self.separators { self.surface.addSubview(separator) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(selected: WegramSavedAttachmentCategory, chinese: Bool, dark: Bool, fontSize: CGFloat) {
        self.selected = selected
        self.surface.backgroundColor = UIColor(rgb: dark ? 0x2c2c2c : 0xffffff)
        for (index, category) in WegramSavedAttachmentCategory.allCases.enumerated() {
            let button = self.buttons[index]
            button.setTitle(category.title(chinese: chinese), for: .normal)
            button.titleLabel?.font = Font.regular(fontSize * 15 / 17)
            button.setTitleColor(UIColor(rgb: category == selected ? 0x07c160 : (dark ? 0xa2b1cf : 0x576b95)), for: .normal)
            button.accessibilityTraits = category == selected ? [.button, .selected] : .button
        }
        for separator in self.separators { separator.backgroundColor = UIColor(rgb: dark ? 0x393939 : 0xededed) }
        self.setNeedsLayout()
    }

    private func rowHeight(width: CGFloat) -> CGFloat {
        let columnWidth = max(0, (width - 16) / 3 - 12)
        return self.buttons.reduce(CGFloat(44)) { max($0, ceil($1.titleLabel?.sizeThatFits(CGSize(width: columnWidth, height: .greatestFiniteMagnitude)).height ?? 0) + 16) }
    }
    func preferredHeight(width: CGFloat) -> CGFloat { return 24 + self.rowHeight(width: width) * 2 + 8 }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.surface.frame = CGRect(x: 8, y: 0, width: max(0, self.bounds.width - 16), height: max(0, self.bounds.height - 8))
        let rowHeight = self.rowHeight(width: self.bounds.width)
        let columnWidth = self.surface.bounds.width / 3
        for (index, button) in self.buttons.enumerated() {
            button.frame = CGRect(x: CGFloat(index % 3) * columnWidth, y: 12 + CGFloat(index / 3) * rowHeight, width: columnWidth, height: rowHeight)
        }
        for (index, separator) in self.separators.enumerated() {
            separator.frame = CGRect(x: CGFloat(index % 2 + 1) * columnWidth, y: 12 + CGFloat(index / 2) * rowHeight + (rowHeight - 12) / 2, width: 1 / UIScreenScale, height: 12)
        }
    }
}

final class WegramSavedAttachmentCardView: UIControl {
    let card = UIView()
    let title = UILabel()
    let subtitle = UILabel()
    let metadata = UILabel()
    let dateLabel = UILabel()
    let thumbnailHost = UIView()
    var hasThumbnail = false
    var pressed: () -> Void = {}
    private var cardColor = UIColor.white
    private var highlightedColor = UIColor(rgb: 0xf2f2f2)

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.card)
        self.card.layer.cornerRadius = 4
        self.card.isUserInteractionEnabled = false
        for child in [self.title, self.subtitle, self.metadata, self.dateLabel, self.thumbnailHost] { self.card.addSubview(child) }
        self.title.numberOfLines = 2
        self.subtitle.numberOfLines = 2
        self.metadata.numberOfLines = 1
        self.thumbnailHost.clipsToBounds = true
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.addAction(UIAction { [weak self] _ in
            guard let self, !self.isHidden, self.alpha > 0, self.isEnabled, self.isUserInteractionEnabled else { return }
            self.pressed()
        }, for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isHighlighted: Bool {
        didSet { self.card.backgroundColor = self.isHighlighted ? self.highlightedColor : self.cardColor }
    }
    func update(title: String, subtitle: String, source: String, date: String, hasThumbnail: Bool, dark: Bool, fontSize: CGFloat, query: String = "", highlightContent: Bool = true) {
        self.hasThumbnail = hasThumbnail
        self.title.text = title
        self.subtitle.text = subtitle
        self.metadata.text = source
        self.dateLabel.text = date
        self.accessibilityLabel = [title, subtitle, source, date].filter { !$0.isEmpty }.joined(separator: ", ")
        self.title.font = Font.regular(fontSize * 16 / 17)
        self.subtitle.font = Font.regular(fontSize * 13 / 17)
        self.metadata.font = Font.regular(fontSize * 11 / 17)
        self.dateLabel.font = self.metadata.font
        self.title.textColor = UIColor(rgb: dark ? 0xd0d0d0 : 0x181818)
        self.subtitle.textColor = UIColor(rgb: dark ? 0x999999 : 0xb2b2b2)
        self.metadata.textColor = UIColor(rgb: dark ? 0x777777 : 0xb2b2b2)
        self.dateLabel.textColor = self.metadata.textColor
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentQuery: String? = highlightContent && !needle.isEmpty ? needle : nil
        self.title.attributedText = WegramVenueRowLayout.title(wegramSavedAttachmentSearchSnippet(title, query: contentQuery), query: contentQuery, font: self.title.font, color: self.title.textColor)
        self.subtitle.attributedText = WegramVenueRowLayout.title(wegramSavedAttachmentSearchSnippet(subtitle, query: contentQuery), query: contentQuery, font: self.subtitle.font, color: self.subtitle.textColor)
        self.metadata.attributedText = WegramVenueRowLayout.title(source, query: needle.isEmpty ? nil : needle, font: self.metadata.font, color: self.metadata.textColor)
        self.backgroundColor = UIColor(rgb: dark ? 0x202020 : 0xededed)
        self.cardColor = UIColor(rgb: dark ? 0x2c2c2c : 0xffffff)
        self.highlightedColor = UIColor(rgb: dark ? 0x393939 : 0xf2f2f2)
        self.card.backgroundColor = self.isHighlighted ? self.highlightedColor : self.cardColor
        self.thumbnailHost.isHidden = !hasThumbnail
        self.setNeedsLayout()
    }
    private func bodyHeight(width: CGFloat) -> CGFloat {
        let textWidth = max(0, width - 16 - 36 - (self.hasThumbnail ? 68 : 0))
        let titleHeight = ceil(self.title.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        let subtitleHeight = self.subtitle.text?.isEmpty == false ? 4 + ceil(self.subtitle.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height) : 0
        return max(self.hasThumbnail ? 56 : 40, titleHeight + subtitleHeight)
    }
    func preferredHeight(width: CGFloat) -> CGFloat {
        return 18 + self.bodyHeight(width: width) + 12 + ceil(self.metadata.font.lineHeight) + 18 + 8
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.card.frame = CGRect(x: 8, y: 0, width: max(0, self.bounds.width - 16), height: max(0, self.bounds.height - 8))
        self.thumbnailHost.frame = CGRect(x: 18, y: 18, width: 56, height: 56)
        let x: CGFloat = self.hasThumbnail ? 86 : 18
        let width = max(0, self.card.bounds.width - 18 - x)
        self.title.frame = CGRect(x: x, y: 18, width: width, height: ceil(self.title.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
        self.subtitle.frame = CGRect(x: x, y: self.title.frame.maxY + 4, width: width, height: self.subtitle.text?.isEmpty == false ? ceil(self.subtitle.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height) : 0)
        let available = max(0, self.card.bounds.width - 36)
        let dateWidth = min(available, ceil(self.dateLabel.sizeThatFits(CGSize(width: available, height: .greatestFiniteMagnitude)).width))
        let requestedGap: CGFloat = self.metadata.text?.isEmpty == false && dateWidth > 0 ? 8 : 0
        let sourceWidth = min(max(0, available - dateWidth - requestedGap), ceil(self.metadata.sizeThatFits(CGSize(width: available, height: .greatestFiniteMagnitude)).width))
        let gap: CGFloat = sourceWidth > 0 && dateWidth > 0 ? 8 : 0
        let y = 18 + self.bodyHeight(width: self.bounds.width) + 12
        self.metadata.frame = CGRect(x: 18, y: y, width: sourceWidth, height: ceil(self.metadata.font.lineHeight))
        self.dateLabel.frame = CGRect(x: 18 + sourceWidth + gap, y: y, width: dateWidth, height: ceil(self.metadata.font.lineHeight))
    }
}

func wegramSavedAttachmentDate(timestamp: Int32, now: Date = Date(), calendar: Calendar = .current, chinese: Bool) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let start = calendar.startOfDay(for: now)
    if calendar.isDate(date, inSameDayAs: now) { return chinese ? "今天" : "Today" }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: start), calendar.isDate(date, inSameDayAs: yesterday) { return chinese ? "昨天" : "Yesterday" }
    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: start).day ?? -1
    if (2 ... 6).contains(days) {
        if chinese { return ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"][calendar.component(.weekday, from: date) - 1] }
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    if chinese {
        let prefix = parts.year == calendar.component(.year, from: now) ? "" : "\(parts.year ?? 0)年"
        return "\(prefix)\(parts.month ?? 0)月\(parts.day ?? 0)日"
    }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

func wegramSavedAttachmentSource(forwardInfo: EngineMessage.ForwardInfo?, author: EnginePeer?) -> String {
    if let forwardInfo {
        if let peer = forwardInfo.source ?? forwardInfo.author { return EnginePeer(peer).compactDisplayTitle }
        return forwardInfo.authorSignature ?? ""
    }
    return author?.compactDisplayTitle ?? ""
}

func wegramSavedAttachmentSearchSnippet(_ text: String, query: String?) -> String {
    guard let query, !query.isEmpty else { return text }
    let source = text as NSString
    let match = source.range(of: query, options: .caseInsensitive)
    guard match.location != NSNotFound, match.length > 0,
          let range = Range(source.rangeOfComposedCharacterSequences(for: match), in: text) else { return text }
    let start = text.index(range.lowerBound, offsetBy: -4, limitedBy: text.startIndex) ?? text.startIndex
    let end = text.index(range.upperBound, offsetBy: 48, limitedBy: text.endIndex) ?? text.endIndex
    return (start > text.startIndex ? "…" : "") + String(text[start ..< end]) + (end < text.endIndex ? "…" : "")
}

struct WegramSavedAttachmentLocation {
    let title: String
    let subtitle: String

    init?(map: TelegramMediaMap, caption: String, captionIsHidden: Bool, strings: PresentationStrings) {
        guard !captionIsHidden, WegramMapMessageLayout.supports(map) else { return nil }
        self.title = WegramMapMessageLayout.title(map, fallback: strings.Message_Location)
        let address = WegramMapMessageLayout.address(map)
        self.subtitle = [address, caption].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n")
    }
}

struct WegramSavedAttachmentLink {
    let title: String
    let subtitle: String
    let image: TelegramMediaImage?

    init?(webpage: TelegramMediaWebpage, caption: String, captionIsHidden: Bool) {
        guard !captionIsHidden, case let .Loaded(content) = webpage.content,
              WegramLinkPreviewLayout.supports(content) else { return nil }
        func text(_ value: String?) -> String? {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        let title = text(content.title) ?? text(content.text) ?? content.displayUrl
        self.title = title
        let caption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let comment = caption.isEmpty || caption == content.url || caption == content.displayUrl ? nil : caption
        let summary = text(content.text).flatMap { $0 == title ? nil : $0 }
        self.subtitle = [comment, summary].compactMap { $0 }.joined(separator: "\n")
        self.image = content.image
    }
}

struct WegramSavedAttachmentDocument {
    let title: String
    let subtitle: String
    let icon: UIImage

    init?(file: TelegramMediaFile, caption: String, captionIsHidden: Bool, strings: PresentationStrings, decimalSeparator: String) {
        guard WegramFileMessageLayout.supports(file) else { return nil }
        self.title = file.fileName.flatMap { $0.isEmpty ? nil : $0 } ?? strings.Message_File
        let type = file.fileName.map { ($0 as NSString).pathExtension.uppercased() } ?? ""
        let size = file.size.flatMap { $0 >= 0 ? dataSizeString($0, formatting: DataSizeStringFormatting(strings: strings, decimalSeparator: decimalSeparator)) : nil }
        let details = [type.isEmpty ? nil : type, size].compactMap { $0 }.joined(separator: " ")
        let captionText = captionIsHidden ? (strings.baseLanguageCode.hasPrefix("zh") ? "[剧透内容]" : "[Spoiler]") : caption
        self.subtitle = [details, captionText].filter { !$0.isEmpty }.joined(separator: "\n")
        self.icon = WegramFileMessageLayout.icon(fileName: file.fileName).withRenderingMode(.alwaysOriginal)
    }
}


final class WegramChatSearchCategoriesView: UIView {
    static let tags: [EngineMessage.Tags?] = [nil, .photoOrVideo, .file, .webPage, .music, .voiceOrInstantVideo]
    let buttons = WegramChatSearchCategoriesView.tags.map { _ in UIButton(type: .custom) }
    private let title = UILabel()
    private let scroll = UIScrollView()
    private let separators = (0..<4).map { _ in UIView() }
    var bottomInset: CGFloat = 0 {
        didSet {
            if self.bottomInset != oldValue { self.setNeedsLayout() }
        }
    }
    var selectedCategory: ((EngineMessage.Tags?) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.scroll)
        self.scroll.addSubview(self.title)
        self.title.textAlignment = .center
        self.title.numberOfLines = 0
        for (index, button) in self.buttons.enumerated() {
            self.scroll.addSubview(button)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.accessibilityIdentifier = "Wegram.Search.Category.\(index)"
            button.addAction(UIAction { [weak self] _ in
                guard let self, !self.isHidden, self.alpha > 0.01, self.isUserInteractionEnabled else { return }
                self.selectedCategory?(Self.tags[index])
            }, for: .touchUpInside)
        }
        for separator in self.separators { self.scroll.addSubview(separator) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(strings: PresentationStrings, dark: Bool, fontSize: CGFloat) {
        self.backgroundColor = UIColor(rgb: dark ? 0x111111 : 0xededed)
        self.title.text = strings.baseLanguageCode.hasPrefix("zh") ? "快速搜索聊天内容" : "Search chat content"
        self.title.font = Font.regular(fontSize * 14 / 17)
        self.title.textColor = UIColor(rgb: dark ? 0x777777 : 0xb2b2b2)
        for (index, button) in self.buttons.enumerated() {
            let title = Self.tags[index].flatMap { ChatSearchData(mediaTags: $0).mediaTitle(strings: strings) } ?? (strings.baseLanguageCode.hasPrefix("zh") ? "日期" : strings.Chat_JumpToDate)
            button.setTitle(title, for: .normal)
            button.setTitleColor(UIColor(rgb: dark ? 0xa2b1cf : 0x576b95), for: .normal)
            button.titleLabel?.font = Font.regular(fontSize)
        }
        for separator in self.separators { separator.backgroundColor = UIColor(rgb: dark ? 0x292929 : 0xe5e5e5) }
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.scroll.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: max(0, self.bounds.height - self.bottomInset))
        let side: CGFloat = min(40, self.bounds.width / 10)
        let column = max(0, (self.bounds.width - side * 2) / 3)
        let titleHeight = ceil(self.title.sizeThatFits(CGSize(width: max(1, self.bounds.width - 32), height: .greatestFiniteMagnitude)).height)
        self.title.frame = CGRect(x: 16, y: 40, width: max(0, self.bounds.width - 32), height: titleHeight)
        let rowHeight = self.buttons.reduce(CGFloat(44)) { max($0, ceil($1.titleLabel?.sizeThatFits(CGSize(width: max(1, column - 8), height: .greatestFiniteMagnitude)).height ?? 0) + 16) }
        let top = self.title.frame.maxY + 16
        for (index, button) in self.buttons.enumerated() {
            button.frame = CGRect(x: side + CGFloat(index % 3) * column, y: top + CGFloat(index / 3) * (rowHeight + 4), width: column, height: rowHeight)
        }
        for (index, separator) in self.separators.enumerated() {
            separator.frame = CGRect(x: side + CGFloat(index % 2 + 1) * column, y: top + CGFloat(index / 2) * (rowHeight + 4) + (rowHeight - 14) / 2, width: UIScreenPixel, height: 14)
        }
        self.scroll.contentSize = CGSize(width: self.bounds.width, height: top + (rowHeight + 4) * 2 + 24)
    }
}
