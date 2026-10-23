import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import AvatarNode

/// The root settings surface; account state and destinations stay in PeerInfoScreen.
final class WegramMeView: UIView, UITableViewDataSource, UITableViewDelegate {
    enum Action {
        case profile, qrCode, status, services, savedMessages, stories, cards, stickers, settings

        func title(chinese: Bool) -> String {
            switch self {
            case .profile: return chinese ? "个人资料" : "Profile"
            case .qrCode: return chinese ? "我的二维码" : "My QR Code"
            case .status: return chinese ? "状态" : "Status"
            case .services: return chinese ? "服务" : "Services"
            case .savedMessages: return chinese ? "收藏" : "Favorites"
            case .stories: return chinese ? "朋友圈" : "Moments"
            case .cards: return chinese ? "卡包" : "Cards"
            case .stickers: return chinese ? "表情" : "Stickers"
            case .settings: return chinese ? "设置" : "Settings"
            }
        }
    }

    private let updateAvatar: (AvatarNode, PresentationTheme, EnginePeer) -> Void
    private let action: (Action) -> Void
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let profile = UIView()
    // WeChat ends the 我 header with a line and an 8pt gap before 服务 (IMG_2443); built into the header
    // so it does not depend on UIKit's first-section spacing.
    private let profileGap = UIView()
    private let profileGapLine = UIView()
    private let profileButton = UIButton(type: .custom)
    private let avatar = AvatarNode(font: avatarPlaceholderFont(size: 26))
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let qrButton = UIButton(type: .custom)
    private let profileArrow = UIImageView()
    private let statusButton = WegramStatusPill(type: .custom)
    private var presentationData: PresentationData?
    private var peer: EnginePeer?
    private var topInset: CGFloat = 0
    private let rows: [[Action]] = [[.services], [.savedMessages, .stories, .cards, .stickers], [.settings]]

    init(action: @escaping (Action) -> Void, updateAvatar: @escaping (AvatarNode, PresentationTheme, EnginePeer) -> Void) {
        self.updateAvatar = updateAvatar
        self.action = action
        super.init(frame: .zero)
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.sectionHeaderHeight = 8
        self.tableView.sectionFooterHeight = .leastNormalMagnitude
        self.tableView.separatorStyle = .none
        self.tableView.showsVerticalScrollIndicator = false
        self.addSubview(self.tableView)
        self.profileButton.addTarget(self, action: #selector(self.openProfile), for: .touchUpInside)
        self.profileButton.accessibilityLabel = "个人资料"
        self.profile.isAccessibilityElement = false
        self.nameLabel.isAccessibilityElement = false
        self.usernameLabel.isAccessibilityElement = false
        self.avatar.isAccessibilityElement = false
        self.profile.addSubnode(self.avatar)
        self.avatar.clipsToBounds = true
        self.avatar.cornerRadius = 6
        self.profile.addSubview(self.profileGap)
        self.profileGap.addSubview(self.profileGapLine)
        self.profileGap.isAccessibilityElement = false
        self.profile.addSubview(self.nameLabel)
        self.profile.addSubview(self.usernameLabel)
        self.profile.addSubview(self.profileArrow)
        self.profileArrow.image = wegramDisclosureArrowImage
        self.profile.addSubview(self.profileButton)
        self.qrButton.setImage(WegramMeView.qrImage, for: .normal)
        self.qrButton.accessibilityLabel = "我的二维码"
        self.qrButton.addTarget(self, action: #selector(self.openQrCode), for: .touchUpInside)
        self.profile.addSubview(self.qrButton)
        self.statusButton.setTitle(Action.status.title(chinese: true), for: .normal)
        self.statusButton.titleLabel?.font = .systemFont(ofSize: 14)
        self.statusButton.layer.cornerRadius = 12
        self.statusButton.layer.borderWidth = 0.5
        self.statusButton.addTarget(self, action: #selector(self.openStatus), for: .touchUpInside)
        self.profile.addSubview(self.statusButton)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(presentationData: PresentationData, peer: EnginePeer?, topInset: CGFloat, bottomInset: CGFloat) {
        let changed = self.presentationData?.theme !== presentationData.theme || self.presentationData?.listsFontSize != presentationData.listsFontSize || self.presentationData?.strings !== presentationData.strings
        self.presentationData = presentationData
        let theme = presentationData.theme
        let chinese = presentationData.strings.baseLanguageCode.hasPrefix("zh")
        self.profileButton.accessibilityLabel = Action.profile.title(chinese: chinese)
        self.qrButton.accessibilityLabel = Action.qrCode.title(chinese: chinese)
        self.statusButton.setTitle(Action.status.title(chinese: chinese), for: .normal)
        self.statusButton.titleLabel?.font = .systemFont(ofSize: 14 * presentationData.listsFontSize.itemListBaseFontSize / 17)
        let dark = theme.overallDarkAppearance
        let headerColor = WegramGroupedListColors.row(dark: dark)
        self.backgroundColor = headerColor
        self.profile.backgroundColor = headerColor
        self.profileGap.backgroundColor = WegramGroupedListColors.background(dark: dark)
        self.profileGapLine.backgroundColor = WegramGroupedListColors.separator(dark: dark)
        self.tableView.backgroundColor = WegramGroupedListColors.background(dark: dark)
        self.tableView.contentInset.bottom = bottomInset
        self.tableView.rowHeight = max(56, floor(presentationData.listsFontSize.itemListBaseFontSize * 56 / 17))
        // IMG_2443: the name is the system font Semibold 21pt in FG_0 and the WeChat ID 17pt in FG_1 (glyph pitch
        // and ink weight against renders of the system font's PingFang UI Display cascade); the QR glyph is
        // Link_100 and the pill's outline Separator_1.
        let secondary = UIColor(white: dark ? 1 : 0, alpha: dark ? 0.5 : 0.55)
        self.nameLabel.font = .systemFont(ofSize: presentationData.listsFontSize.itemListBaseFontSize * 21 / 17, weight: .semibold)
        self.nameLabel.textColor = theme.list.itemPrimaryTextColor
        self.usernameLabel.font = .systemFont(ofSize: presentationData.listsFontSize.itemListBaseFontSize)
        self.usernameLabel.textColor = secondary
        self.profileArrow.tintColor = theme.list.disclosureArrowColor
        self.qrButton.tintColor = UIColor(rgb: dark ? 0x7d90a9 : 0x576b95)
        self.statusButton.setTitleColor(secondary, for: .normal)
        self.statusButton.plus.tintColor = secondary
        self.statusButton.layer.borderColor = UIColor(white: dark ? 1 : 0, alpha: 0.15).cgColor
        if let peer {
            self.nameLabel.text = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            self.usernameLabel.text = peer.addressName.flatMap { $0.isEmpty ? nil : (chinese ? "微信号：\($0)" : "Username: \($0)") } ?? (chinese ? "未设置微信号" : "Username not set")
            self.profileButton.accessibilityValue = [self.nameLabel.text, self.usernameLabel.text].compactMap { $0 }.joined(separator: chinese ? "，" : ", ")
            if self.peer != peer || changed {
                self.updateAvatar(self.avatar, theme, peer)
            }
        }
        self.peer = peer
        self.topInset = topInset
        if changed { self.tableView.reloadData() }
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.tableView.frame = self.bounds
        let width = self.bounds.width
        let scale = max(1, (self.presentationData?.listsFontSize.itemListBaseFontSize ?? 17) / 17)
        // IMG_2443 at 3x, in points below the avatar's top: the name's ink is centred 17.67 down with the QR glyph
        // beside it, the WeChat ID and chevron 49.5 down, the pill spans 68–92, then 32pt to the section line.
        let avatarY = self.topInset + 66 + 1 / 3
        let textX: CGFloat = 112
        let nameHeight = ceil(self.nameLabel.font.lineHeight)
        let nameCenter = avatarY + 17.67 * scale
        let usernameHeight = ceil(self.usernameLabel.font.lineHeight)
        let usernameCenter = avatarY + 49.42 * scale
        let statusY = avatarY + 68 * scale
        let statusHeight = 24 * scale
        let statusWidth = min(max(0, width - textX - 16), self.statusButton.fittingWidth(height: statusHeight))
        let gapHeight: CGFloat = 8
        let contentHeight = statusY + statusHeight + 32
        let height = contentHeight + gapHeight
        let hairline = 1.0 / max(1.0, self.traitCollection.displayScale)
        self.profileGap.frame = CGRect(x: 0, y: contentHeight, width: width, height: gapHeight)
        self.profileGapLine.frame = CGRect(x: 0, y: 0, width: width, height: hairline)
        if self.profile.frame.size != CGSize(width: width, height: height) {
            self.profile.frame = CGRect(x: 0, y: 0, width: width, height: height)
            self.tableView.tableHeaderView = self.profile
        }
        self.avatar.frame = CGRect(x: 28, y: avatarY, width: 64, height: 64)
        self.profileButton.frame = CGRect(x: 16, y: avatarY, width: max(0, width - 32), height: max(64, usernameCenter + usernameHeight / 2 - avatarY))
        self.nameLabel.frame = CGRect(x: textX, y: nameCenter - nameHeight / 2, width: max(0, width - textX - 48), height: nameHeight)
        self.usernameLabel.frame = CGRect(x: textX, y: usernameCenter - usernameHeight / 2, width: max(0, width - textX - 38), height: usernameHeight)
        // The 17pt glyph's ink starts 35.17pt in from the trailing edge; the button keeps a 44pt target around it.
        self.qrButton.frame = CGRect(x: width - 35.17 + 8.5 - 22, y: nameCenter - 22, width: 44, height: 44)
        self.profileArrow.frame = wegramDisclosureArrowFrame(trailingEdge: width, centerY: usernameCenter)
        self.statusButton.frame = CGRect(x: textX, y: statusY, width: statusWidth, height: statusHeight)
        self.statusButton.layer.cornerRadius = statusHeight / 2
    }

    func scrollToTop() {
        self.tableView.setContentOffset(.zero, animated: true)
    }

    func numberOfSections(in tableView: UITableView) -> Int { self.rows.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.rows[section].count }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? .leastNormalMagnitude : 8
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: "setting") as? WegramSettingsCell) ?? WegramSettingsCell()
        let row = self.rows[indexPath.section][indexPath.row]
        if let data = self.presentationData {
            cell.backgroundColor = WegramGroupedListColors.row(dark: data.theme.overallDarkAppearance)
            cell.separatorLine.backgroundColor = WegramGroupedListColors.separator(dark: data.theme.overallDarkAppearance)
            cell.textLabel?.textColor = data.theme.list.itemPrimaryTextColor
            cell.textLabel?.font = .systemFont(ofSize: data.listsFontSize.itemListBaseFontSize)
            cell.arrow.tintColor = data.theme.list.disclosureArrowColor
            let selected = UIView()
            selected.backgroundColor = data.theme.list.itemHighlightedBackgroundColor
            cell.selectedBackgroundView = selected
        }
        cell.textLabel?.text = row.title(chinese: self.presentationData?.strings.baseLanguageCode.hasPrefix("zh") ?? true)
        // IMG_2443 shows 朋友圈 with the same aperture as 发现, at the same size.
        cell.imageView?.image = row == .stories ? Self.momentsImage : Self.icon(for: row)
        cell.sectionPosition = (indexPath.row == 0, indexPath.row == self.rows[indexPath.section].count - 1)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.action(self.rows[indexPath.section][indexPath.row])
    }

    @objc private func openProfile() { self.action(.profile) }
    @objc private func openQrCode() { self.action(.qrCode) }
    @objc private func openStatus() { self.action(.status) }

    // The glyph's 24pt grid at 1:1, like the row's other 24pt icons (the shared image is a 28pt canvas).
    private static let momentsImage: UIImage? = generateImage(CGSize(width: 24, height: 24), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        if let image = WegramIcon.moments.image()?.cgImage {
            context.draw(image, in: CGRect(origin: .zero, size: size))
        }
    })

    // Redrawn from measured primitives: 服务, 表情 and 设置 traced from IMG_2443 at 3x, 卡包 from WeChat's
    // card glyph. All on WeChat's 24pt grid with its 1.2pt stroke and its own fills.
    private static func icon(for action: Action) -> UIImage? {
        return generateImage(CGSize(width: 24, height: 24), rotatedContext: { _, context in
            context.clear(CGRect(x: 0, y: 0, width: 24, height: 24))
            context.setLineWidth(1.2)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            let green = UIColor(rgb: 0x00c777)
            func lines(_ points: [CGPoint], color: UIColor, close: Bool = false) {
                guard let first = points.first else { return }
                context.setStrokeColor(color.cgColor)
                context.move(to: first)
                for point in points.dropFirst() { context.addLine(to: point) }
                if close { context.closePath() }
                context.strokePath()
            }
            switch action {
            case .services:
                // A 18.8 x 15.8pt bubble whose tail breaks the ellipse at its lower left.
                let center = CGPoint(x: 12, y: 11.5)
                let radii = CGSize(width: 9.4, height: 7.9)
                func angle(atX x: CGFloat) -> CGFloat {
                    let t = (x - center.x) / radii.width
                    return atan2(sqrt(max(0, 1 - t * t)), t)
                }
                let start = angle(atX: 8.9)
                let end = angle(atX: 5.8) - 2 * .pi
                var points: [CGPoint] = []
                for i in 0 ... 90 {
                    let t = start + (end - start) * CGFloat(i) / 90
                    points.append(CGPoint(x: center.x + radii.width * cos(t), y: center.y + radii.height * sin(t)))
                }
                points.append(CGPoint(x: 5.7, y: 20.35))
                points.append(CGPoint(x: 8.7, y: 18.9))
                lines(points, color: green, close: true)
                // The tick tapers from its foot and runs out into the bubble's right side.
                context.setFillColor(green.cgColor)
                context.move(to: CGPoint(x: 6.53, y: 9.95))
                context.addLine(to: CGPoint(x: 8.38, y: 14.08))
                context.addQuadCurve(to: CGPoint(x: 9.3, y: 14.37), control: CGPoint(x: 8.7, y: 14.55))
                context.addLine(to: CGPoint(x: 20.58, y: 7.63))
                context.addLine(to: CGPoint(x: 19.91, y: 6.79))
                context.addLine(to: CGPoint(x: 10.07, y: 11.19))
                context.addQuadCurve(to: CGPoint(x: 9.18, y: 11.09), control: CGPoint(x: 9.65, y: 11.35))
                context.addLine(to: CGPoint(x: 7.03, y: 9.53))
                context.addQuadCurve(to: CGPoint(x: 6.53, y: 9.95), control: CGPoint(x: 6.45, y: 9.4))
                context.closePath()
                context.fillPath()
            case .savedMessages:
                // Isometric cube traced from IMG_2443: 8.33pt half-width, 30° edges, 1.3pt stroke; WeChat's
                // Indigo / Yellow / Red faces.
                context.setLineWidth(1.3)
                let halfWidth: CGFloat = 8.33
                let rise = halfWidth * tan(.pi / 6)
                // Centred 1/3pt below the box centre, where IMG_2443 draws it.
                func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 12 + x, y: 12.33 + y) }
                lines([point(-halfWidth, -rise), point(-halfWidth, rise), point(0, 2 * rise)], color: UIColor(rgb: 0xffc300))
                lines([point(0, 0), point(0, 2 * rise)], color: UIColor(rgb: 0xffc300))
                lines([point(halfWidth, -rise), point(halfWidth, rise), point(0, 2 * rise)], color: UIColor(rgb: 0xfa5151))
                lines([point(-halfWidth, -rise), point(0, -2 * rise), point(halfWidth, -rise), point(0, 0)], color: UIColor(rgb: 0x1485ee), close: true)
            case .cards:
                // A tilted card with the edge of a second one showing above it.
                lines([CGPoint(x: 3.6, y: 6.93), CGPoint(x: 20.4, y: 4.6), CGPoint(x: 20.4, y: 8.23)], color: green)
                lines([CGPoint(x: 3.6, y: 7.03), CGPoint(x: 21.4, y: 9.33), CGPoint(x: 21.4, y: 19.73), CGPoint(x: 3.6, y: 17.43)], color: UIColor(rgb: 0x1588f4), close: true)
            case .stickers:
                let yellow = UIColor(rgb: 0xffbb00)
                context.setStrokeColor(yellow.cgColor)
                context.strokeEllipse(in: CGRect(x: 2.6, y: 2.6, width: 18.8, height: 18.8))
                context.setFillColor(yellow.cgColor)
                context.fillEllipse(in: CGRect(x: 7, y: 7.4, width: 3, height: 3.2))
                context.fillEllipse(in: CGRect(x: 14, y: 7.4, width: 3, height: 3.2))
                // A D-shaped mouth: flat top, 10.5pt wide and 5pt deep.
                context.move(to: CGPoint(x: 6.77, y: 13))
                context.addLine(to: CGPoint(x: 17.23, y: 13))
                context.saveGState()
                context.translateBy(x: 12, y: 13)
                context.scaleBy(x: 1, y: 4.95 / 5.23)
                context.addArc(center: .zero, radius: 5.23, startAngle: 0, endAngle: .pi, clockwise: false)
                context.restoreGState()
                context.closePath()
                context.strokePath()
            case .settings:
                // Eight square teeth (9.3pt to the tip, 3pt wide) on a 6.8pt body, corners rounded 0.8pt,
                // around a 6.8pt hole.
                let blue = UIColor(rgb: 0x1485ee)
                context.setStrokeColor(blue.cgColor)
                context.strokeEllipse(in: CGRect(x: 8.6, y: 8.6, width: 6.8, height: 6.8))
                var points: [CGPoint] = []
                for k in 0 ..< 8 {
                    let a = CGFloat(k) * .pi / 4 - .pi / 2
                    let u = CGPoint(x: cos(a), y: sin(a))
                    let v = CGPoint(x: -sin(a), y: cos(a))
                    func p(_ r: CGFloat, _ t: CGFloat) -> CGPoint { CGPoint(x: 12 + u.x * r + v.x * t, y: 12 + u.y * r + v.y * t) }
                    points += [p(6.8, -1.5), p(9.3, -1.5), p(9.3, 1.5), p(6.8, 1.5)]
                }
                let last = points[points.count - 1]
                context.move(to: CGPoint(x: (last.x + points[0].x) / 2, y: (last.y + points[0].y) / 2))
                for i in 0 ..< points.count {
                    context.addArc(tangent1End: points[i], tangent2End: points[(i + 1) % points.count], radius: 0.8)
                }
                context.closePath()
                context.strokePath()
            default:
                break
            }
        })?.withRenderingMode(.alwaysOriginal)
    }
}


extension WegramMeView {
    /// WeChat's header QR glyph, traced from IMG_2443 at 3x: 1pt strokes, rounded 1pt at the stroke centre. The
    /// source draws its squares about 4% taller than wide, and so does this.
    static let qrImage: UIImage? = generateImage(CGSize(width: 17, height: 17), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setStrokeColor(UIColor.black.cgColor)
        context.setFillColor(UIColor.black.cgColor)
        context.setLineWidth(1)
        for rect in [
            CGRect(x: 0.5, y: 0.5, width: 8, height: 8.33),
            CGRect(x: 11.5, y: 0.5, width: 4.33, height: 4.67),
            CGRect(x: 0.5, y: 11.5, width: 4.33, height: 4.67),
            CGRect(x: 11.5, y: 11.5, width: 4.33, height: 4.67)
        ] {
            context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 1).cgPath)
        }
        context.strokePath()
        for origin in [CGPoint(x: 3.67, y: 3.83), CGPoint(x: 11, y: 7.5), CGPoint(x: 14.67, y: 7.5), CGPoint(x: 7.33, y: 11.17), CGPoint(x: 7.33, y: 14.83)] {
            context.fill(CGRect(origin: origin, size: CGSize(width: 1.67, height: 1.67)))
        }
    })?.withRenderingMode(.alwaysTemplate)
}

/// WeChat's ＋ 状态 pill (IMG_2443): 24pt tall, a drawn 11.33pt plus centred 16pt in, the title from 26pt.
final class WegramStatusPill: UIButton {
    private static let plusImage: UIImage? = generateImage(CGSize(width: 34 / 3, height: 34 / 3), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: 0, y: size.height / 2))
        context.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.move(to: CGPoint(x: size.width / 2, y: 0))
        context.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        context.strokePath()
    })?.withRenderingMode(.alwaysTemplate)

    let plus = UIImageView(image: WegramStatusPill.plusImage)

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.plus.isUserInteractionEnabled = false
        self.plus.contentMode = .scaleToFill
        self.addSubview(self.plus)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var titleSize: CGSize {
        self.titleLabel?.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)) ?? .zero
    }

    func fittingWidth(height: CGFloat) -> CGFloat {
        let scale = height / 24
        return ceil(26 * scale + ceil(self.titleSize.width) + 8 * scale)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = self.bounds.height / 24
        let side = 34 / 3 * scale
        self.plus.frame = CGRect(x: 16 * scale - side / 2, y: (self.bounds.height - side) / 2, width: side, height: side)
        let size = self.titleSize
        self.titleLabel?.frame = CGRect(x: 26 * scale, y: (self.bounds.height - ceil(size.height)) / 2, width: max(0, min(ceil(size.width), self.bounds.width - 26 * scale)), height: ceil(size.height))
    }
}
