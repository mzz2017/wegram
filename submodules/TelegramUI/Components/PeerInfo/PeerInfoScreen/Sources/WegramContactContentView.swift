import UIKit
import Display

struct WegramContactContent: Equatable {
    let name: String
    let username: String?
    let about: String?
    let hasPhoto: Bool
    let hasStories: Bool
    let canCall: Bool
}

final class WegramContactActionCell: UITableViewCell {
    let icon = UIImageView()
    let title = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        self.contentView.addSubview(self.icon)
        self.contentView.addSubview(self.title)
        self.title.numberOfLines = 0
        self.title.textAlignment = .center
        self.isAccessibilityElement = true
        self.icon.isAccessibilityElement = false
        self.title.isAccessibilityElement = false
        self.icon.contentMode = .scaleAspectFit
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.contentView.bounds.size
        let iconSide = min(28, self.title.font.pointSize * 22 / 17)
        let width = max(1, size.width - 48 - iconSide)
        let text = self.title.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let x = max(16, (size.width - iconSide - 8 - min(width, text.width)) * 0.5)
        self.icon.frame = CGRect(x: x, y: (size.height - iconSide) * 0.5, width: iconSide, height: iconSide)
        self.title.frame = CGRect(x: self.icon.frame.maxX + 8, y: 12, width: min(width, ceil(text.width)), height: max(0, size.height - 24))
    }
}

/// 朋友资料 / 朋友圈 row: title on the first line, an optional two-line description below it, and the
/// chevron aligned with the title (IMG_2444), which a `.subtitle` cell cannot do.
final class WegramContactDetailsCell: UITableViewCell {
    static let inset: CGFloat = 16
    let title = UILabel()
    let detail = UILabel()
    let arrow = UIImageView(image: wegramDisclosureArrowImage)
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        for view in [self.title, self.detail, self.arrow] { self.contentView.addSubview(view) }
        self.detail.numberOfLines = 2
        self.isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    static func detailText(_ text: String, font: UIFont, color: UIColor) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = round(font.pointSize * 17 / 14)
        style.maximumLineHeight = style.minimumLineHeight
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }
    static func height(width: CGFloat, titleFont: UIFont, detail: NSAttributedString?) -> CGFloat {
        let titleHeight = ceil(titleFont.lineHeight)
        guard let detail, detail.length > 0 else { return max(56, titleHeight + 2 * inset) }
        let lineHeight = (detail.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.minimumLineHeight ?? 17
        let measured = detail.boundingRect(with: CGSize(width: max(1, width - 2 * inset), height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height
        return ceil(inset + titleHeight + 8 + min(lineHeight * 2, ceil(measured)) + inset)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.contentView.bounds.size
        let inset = WegramContactDetailsCell.inset
        let titleHeight = ceil(self.title.font.lineHeight)
        let hasDetail = (self.detail.attributedText?.length ?? 0) > 0
        let titleY = hasDetail ? inset : floor((size.height - titleHeight) / 2)
        // IMG_2444: the title's and the description's labels share the 16pt inset once each first glyph's side
        // bearing is taken off its ink (朋 at 50px, 添 and 友 at 50px).
        self.title.frame = CGRect(x: inset, y: titleY, width: max(1, size.width - inset - 44), height: titleHeight)
        let detailWidth = max(1, size.width - 2 * inset)
        let detailHeight = hasDetail ? ceil(self.detail.sizeThatFits(CGSize(width: detailWidth, height: .greatestFiniteMagnitude)).height) : 0
        self.detail.frame = CGRect(x: inset, y: self.title.frame.maxY + 8, width: detailWidth, height: detailHeight)
        self.arrow.frame = wegramDisclosureArrowFrame(trailingEdge: size.width, centerY: self.title.frame.midY)
    }
}

final class WegramContactContentView: UIView, UITableViewDataSource, UITableViewDelegate {
    enum Action: Equatable { case back, edit, more, avatar, details, stories, message, call }
    let table = UITableView(frame: .zero, style: .grouped)
    let navigation = UIView()
    let back = UIButton(type: .custom)
    let edit = UIButton(type: .custom)
    let more = UIButton(type: .custom)
    let profile = UIView()
    let avatar = UIButton(type: .custom)
    let avatarHost = UIView()
    let name = UILabel()
    let username = UILabel()
    private(set) var content: WegramContactContent?
    private(set) var rows: [[Action]] = []
    private var dark = false
    private var chinese = true
    private var fontSize: CGFloat = 17
    private var statusHeight: CGFloat = 0
    private var lastWidth: CGFloat = 0
    var open: ((Action) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.table)
        self.addSubview(self.navigation)
        self.navigation.addSubview(self.back)
        self.navigation.addSubview(self.edit)
        self.navigation.addSubview(self.more)
        self.profile.addSubview(self.avatar)
        self.avatar.addSubview(self.avatarHost)
        self.profile.addSubview(self.name)
        self.profile.addSubview(self.username)
        self.avatar.layer.cornerRadius = 6
        self.avatar.clipsToBounds = true
        self.avatarHost.isUserInteractionEnabled = false
        self.avatarHost.accessibilityElementsHidden = true
        self.name.numberOfLines = 0
        self.name.accessibilityTraits = .header
        self.username.numberOfLines = 0
        self.table.dataSource = self
        self.table.delegate = self
        self.table.register(WegramContactActionCell.self, forCellReuseIdentifier: "contactAction")
        self.table.register(WegramContactDetailsCell.self, forCellReuseIdentifier: "contactDetails")
        self.table.contentInsetAdjustmentBehavior = .never
        self.table.sectionHeaderHeight = 8
        self.table.sectionFooterHeight = .leastNormalMagnitude
        self.table.separatorStyle = .none
        self.table.cellLayoutMarginsFollowReadableWidth = false
        self.table.showsVerticalScrollIndicator = false
        self.back.accessibilityIdentifier = "Wegram.Contact.Back"
        self.edit.accessibilityIdentifier = "Wegram.Contact.Edit"
        self.more.accessibilityIdentifier = "Wegram.Contact.More"
        self.avatar.accessibilityIdentifier = "Wegram.Contact.Avatar"
        for (button, action) in [(self.back, Action.back), (self.edit, .edit), (self.more, .more), (self.avatar, .avatar)] {
            button.addAction(UIAction(handler: { [weak self] _ in self?.perform(action) }), for: .touchUpInside)
        }
        self.load(nil, dark: false, fontSize: 17, chinese: true, statusHeight: 0, bottomInset: 0)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var foreground: UIColor { UIColor(white: self.dark ? 0.85 : 0.1, alpha: 1) }
    // IMG_2444: the 微信号 line is FG_1 (ink 114 on white) and the 朋友资料 description FG_2 (ink 177).
    private var secondary: UIColor { UIColor(white: self.dark ? 1 : 0, alpha: self.dark ? 0.5 : 0.55) }
    private var tertiary: UIColor { UIColor(white: self.dark ? 1 : 0, alpha: 0.3) }
    // WegramGroupedListColors: #191919 / #FFFFFF rows on #111111 / #EEEEEE.
    private var rowColor: UIColor { UIColor(white: self.dark ? 0x19 / 255 : 1, alpha: 1) }
    private var accent: UIColor { self.dark ? UIColor(red: 0.49, green: 0.56, blue: 0.66, alpha: 1) : UIColor(red: 0.34, green: 0.42, blue: 0.58, alpha: 1) }

    func load(_ content: WegramContactContent?, dark: Bool, fontSize: CGFloat, chinese: Bool, statusHeight: CGFloat, bottomInset: CGFloat) {
        let changed = self.content != content || self.dark != dark || self.fontSize != fontSize || self.chinese != chinese
        self.content = content
        self.dark = dark
        self.fontSize = fontSize
        self.chinese = chinese
        self.statusHeight = statusHeight
        self.rows = content.map { value in
            [[.details]] + (value.hasStories ? [[.stories]] : []) + [[.message] + (value.canCall ? [.call] : [])]
        } ?? []
        self.backgroundColor = UIColor(white: dark ? 0x11 / 255 : 0xEE / 255, alpha: 1)
        self.table.backgroundColor = self.backgroundColor
        self.profile.backgroundColor = self.rowColor
        self.navigation.backgroundColor = self.rowColor
        self.table.contentInset.bottom = bottomInset
        self.table.verticalScrollIndicatorInsets.bottom = bottomInset
        self.name.text = content?.name
        // IMG_2444: the system font Semibold 21pt, from glyph pitch and ink weight (as on 我).
        self.name.font = .systemFont(ofSize: fontSize * 21 / 17, weight: .semibold)
        self.name.textColor = self.foreground
        // IMG_2444 at 3x: the detail line is 15pt, and its full-width colon is drawn where CoreText places it but
        // the value follows 0.55em sooner (the colon advances about 0.58em where it would advance more than a full em).
        let detailFont = UIFont.systemFont(ofSize: fontSize * 15 / 17)
        self.username.font = detailFont
        self.username.textColor = self.secondary
        self.username.attributedText = content?.username.flatMap { username -> NSAttributedString? in
            if username.isEmpty {
                return nil
            }
            let attributes: [NSAttributedString.Key: Any] = [.font: detailFont, .foregroundColor: self.secondary]
            guard chinese else {
                return NSAttributedString(string: "Username: " + username, attributes: attributes)
            }
            let text = NSMutableAttributedString(string: "微信号：" + username, attributes: attributes)
            text.addAttribute(.kern, value: -detailFont.pointSize * 0.55, range: NSRange(location: 3, length: 1))
            return text
        }
        self.avatar.backgroundColor = UIColor(white: dark ? 0.2 : 0.9, alpha: 1)
        self.avatar.isEnabled = content?.hasPhoto == true
        self.avatar.accessibilityLabel = chinese ? "查看头像" : "View Profile Photo"
        self.avatar.accessibilityValue = content?.name
        self.avatar.accessibilityTraits = self.avatar.isEnabled ? .button : [.button, .notEnabled]
        self.more.isEnabled = content != nil
        self.edit.isEnabled = content != nil
        self.edit.accessibilityLabel = chinese ? "设置备注" : "Edit Contact"
        self.edit.setImage(WegramContactContentView.editImage(color: self.foreground), for: .normal)
        self.more.accessibilityLabel = chinese ? "更多资料与管理" : "More Profile and Management"
        self.more.accessibilityHint = chinese ? "完整资料、共享媒体及更多操作" : "Full profile, shared media and more actions"
        self.back.accessibilityLabel = chinese ? "返回" : "Back"
        self.back.setImage(wegramNavigationBackArrowImage(color: .black)?.withRenderingMode(.alwaysTemplate), for: .normal)
        self.more.setImage(UIImage(systemName: "ellipsis", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)), for: .normal)
        self.back.tintColor = self.foreground
        self.more.tintColor = self.foreground
        if changed { self.table.reloadData() }
        self.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let top = self.statusHeight + 44
        self.navigation.frame = CGRect(x: 0, y: 0, width: width, height: top)
        // IMG_2444: the chevron's left edge sits 16pt in.
        // IMG_2444 draws the chevron 3pt below the centre of the 44pt bar and the right-side icons 2pt below.
        let iconY = self.statusHeight + 3
        // Puts the shared chevron where WeGram's navigation bar draws it (IMG_2444 matches IMG_2446).
        self.back.frame = CGRect(x: -1, y: iconY - 2 / 3, width: 44, height: 44)
        // IMG_2444: the ellipsis centre sits 28pt from the right edge, the edit icon's 67pt.
        self.more.frame = CGRect(x: max(52, width - 50), y: iconY - 1, width: 44, height: 44)
        self.edit.frame = CGRect(x: max(96, width - 89), y: iconY - 1, width: 44, height: 44)
        self.table.frame = CGRect(x: 0, y: top, width: width, height: max(0, self.bounds.height - top))
        // IMG_2444: every line's label edge is 95pt in (ink minus each glyph's side bearing), 16pt from the right.
        let textWidth = max(1, width - 111)
        let nameHeight = ceil(self.name.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        let usernameHeight = self.username.text == nil ? 0 : ceil(self.username.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        // IMG_2444 at 3x: the avatar's top is 29.33pt into the header, the name's line is centred 10.83pt below it
        // and the username's 39pt below it; a name that wraps pushes the username down by its extra lines.
        let nameY = 29.33 + 10.83 - ceil(self.name.font.lineHeight) / 2
        let usernameY = 29.33 + 39 - ceil(self.username.font.lineHeight) / 2 + max(0, nameHeight - ceil(self.name.font.lineHeight))
        // The header's bottom line sits 102pt below the avatar's top (688px in IMG_2444).
        let headerHeight = max(131.33, usernameY + usernameHeight + 31)
        self.avatar.frame = CGRect(x: 16, y: 29.33, width: 64, height: 64)
        self.avatarHost.frame = self.avatar.bounds
        for view in self.avatarHost.subviews { view.frame = self.avatarHost.bounds }
        self.name.frame = CGRect(x: 95, y: nameY, width: textWidth, height: nameHeight)
        self.username.frame = CGRect(x: 95, y: usernameY, width: textWidth, height: usernameHeight)
        if self.profile.frame.size != CGSize(width: width, height: headerHeight) {
            self.profile.frame = CGRect(x: 0, y: 0, width: width, height: headerHeight)
            self.table.tableHeaderView = self.profile
        }
        if self.lastWidth != width {
            self.lastWidth = width
            self.table.reloadData()
        }
    }
    func scrollToTop() { self.table.setContentOffset(CGPoint(x: 0, y: -self.table.adjustedContentInset.top), animated: true) }
    private func perform(_ action: Action) {
        if action == .back { self.open?(action); return }
        guard let content else { return }
        if action == .avatar && !content.hasPhoto { return }
        if action == .stories && !content.hasStories { return }
        if action == .call && !content.canCall { return }
        self.open?(action)
    }
    func numberOfSections(in tableView: UITableView) -> Int { self.rows.count }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { section == 0 ? .leastNormalMagnitude : 8 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.rows[section].count }
    private func title(_ action: Action) -> String {
        switch action {
        case .details: return self.chinese ? "朋友资料" : "Contact Info"
        case .stories: return self.chinese ? "朋友圈" : "Moments"
        case .message: return self.chinese ? "发消息" : "Message"
        case .call: return self.chinese ? "音视频通话" : "Audio / Video Call"
        default: return ""
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let action = self.rows[indexPath.section][indexPath.row]
        let cell: UITableViewCell
        if action == .message || action == .call {
            let row = tableView.dequeueReusableCell(withIdentifier: "contactAction", for: indexPath) as! WegramContactActionCell
            row.title.text = self.title(action)
            row.title.font = .systemFont(ofSize: self.fontSize, weight: .medium)
            row.title.textColor = self.accent
            row.icon.image = UIImage(systemName: action == .message ? "bubble.left" : "video", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
            row.icon.tintColor = self.accent
            row.separatorInset = .zero
            cell = row
        } else {
            let row = tableView.dequeueReusableCell(withIdentifier: "contactDetails", for: indexPath) as! WegramContactDetailsCell
            row.title.text = self.title(action)
            row.title.font = self.detailsTitleFont(action)
            row.title.textColor = self.foreground
            row.detail.attributedText = self.detailsText(action)
            row.arrow.tintColor = UIColor(white: self.dark ? 1 : 0, alpha: 0.3)
            cell = row
        }
        cell.backgroundColor = self.rowColor
        self.applyLines(to: cell, at: indexPath)
        let selected = UIView()
        selected.backgroundColor = UIColor(white: self.dark ? 0.16 : 0.9, alpha: 1)
        cell.selectedBackgroundView = selected
        cell.accessibilityLabel = self.title(action)
        cell.accessibilityValue = action == .details ? self.detailsSubtitle : nil
        cell.accessibilityTraits = .button
        return cell
    }
    // WeChat describes what 朋友资料 holds; this row opens Telegram's full profile, so the fallback says that
    // rather than promising WeChat's remark/tag/permission editor. A bio, when set, is shown instead.
    private var detailsSubtitle: String? {
        if let about = self.content?.about, !about.isEmpty { return about }
        return self.chinese ? "电话、简介、共享媒体及备注名等完整资料。" : "Phone, bio, shared media, contact name and more."
    }

    private func detailsTitleFont(_ action: Action) -> UIFont {
        // IMG_2444: 朋友资料 is a 15pt semibold title over 14pt grey description lines on a 17pt pitch.
        return .systemFont(ofSize: self.fontSize * 15 / 17, weight: action == .details ? .semibold : .regular)
    }
    private func detailsText(_ action: Action) -> NSAttributedString? {
        guard action == .details, let text = self.detailsSubtitle, !text.isEmpty else { return nil }
        return WegramContactDetailsCell.detailText(text, font: .systemFont(ofSize: self.fontSize * 14 / 17), color: self.tertiary)
    }
    // WeChat's 设置备注 glyph (IMG_2444): an outlined person whose right shoulder is cut by an outlined pencil,
    // on WeChat's 24pt icon grid. No SF Symbol has this shape.
    private static func editImage(color: UIColor) -> UIImage? {
        let size = CGSize(width: 24, height: 24)
        return UIGraphicsImageRenderer(size: size).image { _ in
            color.setStroke()
            let person = UIBezierPath()
            person.move(to: CGPoint(x: 11.2, y: 20.2))
            person.addLine(to: CGPoint(x: 3, y: 20.2))
            person.addCurve(to: CGPoint(x: 8.4, y: 15), controlPoint1: CGPoint(x: 3, y: 17.4), controlPoint2: CGPoint(x: 6.8, y: 16.2))
            person.addCurve(to: CGPoint(x: 7.3, y: 8.2), controlPoint1: CGPoint(x: 7.6, y: 13.4), controlPoint2: CGPoint(x: 7.3, y: 10.8))
            person.addCurve(to: CGPoint(x: 14.3, y: 8.2), controlPoint1: CGPoint(x: 7.3, y: 2.6), controlPoint2: CGPoint(x: 14.3, y: 2.6))
            person.addCurve(to: CGPoint(x: 13.2, y: 15), controlPoint1: CGPoint(x: 14.3, y: 10.8), controlPoint2: CGPoint(x: 14, y: 13.4))
            person.addCurve(to: CGPoint(x: 15.2, y: 16), controlPoint1: CGPoint(x: 13.9, y: 15.4), controlPoint2: CGPoint(x: 14.6, y: 15.6))
            let pencil = UIBezierPath()
            for (index, point) in [CGPoint(x: 0, y: 0), CGPoint(x: 3.2, y: -1.9), CGPoint(x: 11.5, y: -1.9), CGPoint(x: 11.5, y: 1.9), CGPoint(x: 3.2, y: 1.9)].enumerated() {
                if index == 0 { pencil.move(to: point) } else { pencil.addLine(to: point) }
            }
            pencil.close()
            pencil.apply(CGAffineTransform(rotationAngle: -.pi / 4).concatenating(CGAffineTransform(translationX: 13.2, y: 21.8)))
            for path in [person, pencil] {
                path.lineWidth = 1.2
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
        }.withRenderingMode(.alwaysOriginal)
    }

    private func applyLines(to cell: UITableViewCell, at indexPath: IndexPath) {
        let topTag = 0x7767_7470, bottomTag = 0x7767_6274
        let top = cell.viewWithTag(topTag) ?? { let v = UIView(); v.tag = topTag; cell.addSubview(v); return v }()
        let bottom = cell.viewWithTag(bottomTag) ?? { let v = UIView(); v.tag = bottomTag; cell.addSubview(v); return v }()
        let color = UIColor(white: self.dark ? 1 : 0, alpha: 0.1)
        top.backgroundColor = color
        bottom.backgroundColor = color
        let hairline = 1.0 / max(1.0, self.traitCollection.displayScale)
        let width = self.table.bounds.width
        // A dequeued cell may still be 44pt tall here; with a flexible top margin the line has to start at
        // the cell's current bottom or the resize to the row height pushes it out of the cell.
        let height = cell.bounds.height
        let topInset: CGFloat = indexPath.section == 0 ? 16 : 0
        top.isHidden = indexPath.row != 0
        top.frame = CGRect(x: topInset, y: 0, width: max(0, width - topInset), height: hairline)
        bottom.frame = CGRect(x: 0, y: height - hairline, width: width, height: hairline)
        top.autoresizingMask = [.flexibleWidth]
        bottom.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let action = self.rows[indexPath.section][indexPath.row]
        let width = max(1, tableView.bounds.width - 80)
        if action == .details || action == .stories {
            return WegramContactDetailsCell.height(width: tableView.bounds.width, titleFont: self.detailsTitleFont(action), detail: self.detailsText(action))
        }
        let textHeight = (self.title(action) as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [.font: UIFont.systemFont(ofSize: self.fontSize)], context: nil).height
        return max(56, ceil(textHeight) + 24)
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard self.rows.indices.contains(indexPath.section), self.rows[indexPath.section].indices.contains(indexPath.row) else { return }
        self.perform(self.rows[indexPath.section][indexPath.row])
    }
}
