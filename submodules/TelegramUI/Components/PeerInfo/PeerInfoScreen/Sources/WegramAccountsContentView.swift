import UIKit
import TelegramPresentationData

struct WegramAccountRow: Equatable {
    let id: Int64
    let name: String
    let unreadCount: Int32
    let current: Bool
}

final class WegramAccountCard: UIButton {
    let avatarHost = UIView()
    let nameLabel = UILabel()
    let currentLabel = UILabel()
    let unreadLabel = UILabel()
    init() {
        super.init(frame: .zero)
        self.layer.cornerRadius = 8
        self.avatarHost.layer.cornerRadius = 4
        self.avatarHost.clipsToBounds = true
        for view in [self.avatarHost, self.nameLabel, self.currentLabel, self.unreadLabel] {
            self.addSubview(view)
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
        }
        self.nameLabel.numberOfLines = 1
        self.currentLabel.textAlignment = .center
        self.currentLabel.layer.cornerRadius = 3
        self.currentLabel.clipsToBounds = true
        self.unreadLabel.textAlignment = .center
        self.unreadLabel.layer.cornerRadius = 9
        self.unreadLabel.clipsToBounds = true
        self.unreadLabel.font = .systemFont(ofSize: 12)
        self.unreadLabel.textColor = .white
        self.unreadLabel.backgroundColor = UIColor(red: 0.96, green: 0.29, blue: 0.25, alpha: 1)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    var requiredHeight: CGFloat {
        max(76, self.nameLabel.font.lineHeight + (self.currentLabel.isHidden ? 0 : self.currentLabel.font.lineHeight + 8) + 24)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.avatarHost.frame = CGRect(x: 15, y: (self.bounds.height - 44) / 2, width: 44, height: 44)
        let unreadWidth = self.unreadLabel.isHidden ? 0 : max(18, self.unreadLabel.sizeThatFits(CGSize(width: 70, height: 18)).width + 10)
        self.unreadLabel.frame = CGRect(x: self.bounds.width - 15 - unreadWidth, y: (self.bounds.height - 18) / 2, width: unreadWidth, height: 18)
        let textWidth = max(0, self.bounds.width - 90 - (unreadWidth > 0 ? unreadWidth + 8 : 0))
        let totalHeight = self.nameLabel.font.lineHeight + (self.currentLabel.isHidden ? 0 : self.currentLabel.font.lineHeight + 8)
        self.nameLabel.frame = CGRect(x: 74, y: (self.bounds.height - totalHeight) / 2, width: textWidth, height: self.nameLabel.font.lineHeight)
        self.currentLabel.frame = CGRect(x: 74, y: self.nameLabel.frame.maxY + 4, width: min(textWidth, self.currentLabel.intrinsicContentSize.width + 12), height: self.currentLabel.font.lineHeight + 4)
        for view in self.avatarHost.subviews { view.frame = self.avatarHost.bounds }
    }
}

final class WegramAccountsContentView: UIScrollView {
    let headline = UILabel()
    let logo = UIImageView(image: WegramIcon.chats.image(selected: true)?.withRenderingMode(.alwaysTemplate))
    let divider = UIView()
    let addCard = WegramAccountCard()
    let addSymbol = UIImageView(image: UIImage(systemName: "plus"))
    let loading = UIActivityIndicatorView(style: .medium)
    private(set) var cards: [Int64: WegramAccountCard] = [:]
    private(set) var rows: [WegramAccountRow] = []
    private var loaded = false
    private var chinese = true
    private var dark = false
    private var fontSize: CGFloat = 17
    var select: ((Int64) -> Void)?
    var add: (() -> Void)?
    var configureAvatar: ((Int64, UIView) -> Void)?
    var busy = false { didSet { self.updateState() } }

    init() {
        super.init(frame: .zero)
        self.contentInsetAdjustmentBehavior = .never
        self.alwaysBounceVertical = true
        for view in [self.logo, self.headline, self.divider, self.addCard, self.loading] { self.addSubview(view) }
        self.headline.textAlignment = .center
        self.headline.numberOfLines = 0
        self.headline.accessibilityTraits = .header
        self.logo.isAccessibilityElement = false
        self.addCard.avatarHost.layer.borderWidth = 0.5
        self.addSymbol.contentMode = .center
        self.addCard.avatarHost.addSubview(self.addSymbol)
        self.addCard.accessibilityIdentifier = "Wegram.Settings.AddAccount"
        self.addCard.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.loaded, !self.busy else { return }
            self.add?()
        }), for: .touchUpInside)
        self.update(dark: false, fontSize: 17, chinese: true)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func load(rows: [WegramAccountRow]) {
        var seen = Set<Int64>()
        self.rows = rows.filter { seen.insert($0.id).inserted }.sorted { $0.current && !$1.current }
        self.loaded = true
        let ids = Set(self.rows.map(\.id))
        for id in Array(self.cards.keys) where !ids.contains(id) { self.cards.removeValue(forKey: id)?.removeFromSuperview() }
        for row in self.rows {
            if self.cards[row.id] == nil {
                let card = WegramAccountCard()
                card.accessibilityIdentifier = "Wegram.Settings.Account.\(row.id)"
                card.addAction(UIAction(handler: { [weak self] _ in
                    guard let self, !self.busy, let current = self.rows.first(where: { $0.id == row.id }), !current.current else { return }
                    self.select?(row.id)
                }), for: .touchUpInside)
                self.cards[row.id] = card
                self.addSubview(card)
            }
            if let card = self.cards[row.id] { self.configureAvatar?(row.id, card.avatarHost) }
        }
        self.update(dark: self.dark, fontSize: self.fontSize, chinese: self.chinese)
    }

    func update(dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.dark = dark
        self.fontSize = fontSize
        self.chinese = chinese
        let text = UIColor(white: dark ? 0.82 : 0.1, alpha: 1)
        let gray = UIColor(white: dark ? 0.45 : 0.6, alpha: 1)
        let green = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
        self.backgroundColor = UIColor(white: dark ? 0.07 : 237 / 255, alpha: 1)
        self.logo.tintColor = UIColor(white: dark ? 0.22 : 0.83, alpha: 1)
        self.divider.backgroundColor = self.logo.tintColor
        self.headline.text = chinese ? "轻触头像以切换账号" : "Tap an Avatar to Switch Accounts"
        self.headline.font = .systemFont(ofSize: fontSize * 24 / 17)
        self.headline.textColor = text
        self.addCard.nameLabel.text = chinese ? "添加账号" : "Add Account"
        self.addCard.nameLabel.textColor = gray
        self.addCard.accessibilityLabel = self.addCard.nameLabel.text
        self.addCard.avatarHost.layer.borderColor = self.logo.tintColor.cgColor
        self.addSymbol.tintColor = self.logo.tintColor
        self.addCard.currentLabel.isHidden = true
        self.addCard.unreadLabel.isHidden = true
        for card in Array(self.cards.values) + [self.addCard] {
            card.backgroundColor = UIColor(white: dark ? 0.1 : 1, alpha: 1)
            card.nameLabel.font = .systemFont(ofSize: fontSize)
            card.currentLabel.font = .systemFont(ofSize: max(12, fontSize * 12 / 17))
            card.currentLabel.textColor = green
            card.currentLabel.backgroundColor = green.withAlphaComponent(0.1)
        }
        for row in self.rows {
            guard let card = self.cards[row.id] else { continue }
            card.nameLabel.text = row.name
            card.nameLabel.textColor = text
            card.currentLabel.text = chinese ? "当前使用" : "Current"
            card.currentLabel.isHidden = !row.current
            card.unreadLabel.isHidden = row.unreadCount <= 0
            card.unreadLabel.text = row.unreadCount > 99 ? "99+" : "\(max(0, row.unreadCount))"
            card.accessibilityLabel = row.name
            card.accessibilityValue = [row.current ? (chinese ? "当前使用" : "Current") : nil, row.unreadCount > 0 ? (chinese ? "\(row.unreadCount)条未读" : "\(row.unreadCount) unread") : nil].compactMap { $0 }.joined(separator: ", ")
        }
        self.updateState()
    }
    private func updateState() {
        self.addCard.isEnabled = self.loaded && !self.busy
        self.addCard.alpha = self.addCard.isEnabled ? 1 : 0.45
        for row in self.rows {
            self.cards[row.id]?.isEnabled = !self.busy && !row.current
            self.cards[row.id]?.accessibilityTraits = row.current ? [.button, .selected, .notEnabled] : (self.busy ? [.button, .notEnabled] : .button)
        }
        if !self.loaded || self.busy { self.loading.startAnimating() } else { self.loading.stopAnimating() }
        self.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        self.logo.frame = CGRect(x: (width - 48) / 2, y: 0, width: 48, height: 48)
        let titleHeight = self.headline.sizeThatFits(CGSize(width: max(1, width - 40), height: .greatestFiniteMagnitude)).height
        self.headline.frame = CGRect(x: 20, y: 96, width: width - 40, height: titleHeight)
        self.divider.frame = CGRect(x: (width - 120) / 2, y: self.headline.frame.maxY + 32, width: 120, height: 0.5)
        var y = self.divider.frame.maxY + 36
        for row in self.rows {
            guard let card = self.cards[row.id] else { continue }
            card.frame = CGRect(x: 20, y: y, width: width - 40, height: card.requiredHeight)
            card.layoutIfNeeded()
            y = card.frame.maxY + 10
        }
        self.addCard.frame = CGRect(x: 20, y: y, width: width - 40, height: self.addCard.requiredHeight)
        self.addCard.layoutIfNeeded()
        self.loading.center = CGPoint(x: width / 2, y: self.addCard.frame.maxY + 28)
        self.contentSize = CGSize(width: width, height: self.addCard.frame.maxY + 56)
    }
}
