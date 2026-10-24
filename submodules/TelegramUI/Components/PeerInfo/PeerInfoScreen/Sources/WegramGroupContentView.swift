import UIKit
import Display

func wegramGroupPreviewMembers<Member>(_ members: [Member], canAddMembers: Bool, expanded: Bool = false, columns: Int = 6, isOwner: (Member) -> Bool) -> [Member] {
    let limit = expanded ? members.count : max(1, columns * 3 - (canAddMembers ? 1 : 0))
    var preview = Array(members.prefix(limit))
    guard let ownerIndex = members.firstIndex(where: isOwner), ownerIndex != 0 else { return preview }
    if ownerIndex < preview.count { preview.remove(at: ownerIndex) }
    else { preview.removeLast() }
    preview.insert(members[ownerIndex], at: 0)
    return preview
}

struct WegramGroupContent: Equatable {
    struct Member: Equatable {
        let id: Int64
        let name: String
    }
    let name: String
    let about: String?
    let members: [Member]
    let memberCount: Int
    let canAddMembers: Bool
    let hasMoreMembers: Bool
    let canShowQRCode: Bool
    let isPinned: Bool?
    let pinIsBusy: Bool
    let isMuted: Bool
    var canClearHistory = false
    var canManageGroup = false
    var managementRequestCount = 0
    /// A broadcast channel: its one tile is the channel itself, and there is no name row or member search.
    var isChannel = false
}

private final class WegramGroupMemberRowCell: UITableViewCell {
    private var buttons: [UIButton] = []
    private var labels: [UILabel] = []
    private(set) var avatarHosts: [(Int64, UIView)] = []
    var select: ((Int64?) -> Void)?
    var releaseAvatars: (() -> Void)?
    private var columns = 5
    private var labelHeight: CGFloat = 16

    deinit { self.releaseAvatars?() }
    override func prepareForReuse() {
        super.prepareForReuse()
        self.releaseAvatars?()
        self.releaseAvatars = nil
        self.select = nil
    }
    func update(members: [WegramGroupContent.Member], includeAdd: Bool, columns: Int, dark: Bool, fontSize: CGFloat, addTitle: String) {
        self.releaseAvatars?()
        self.releaseAvatars = nil
        for view in self.buttons { view.removeFromSuperview() }
        for view in self.labels { view.removeFromSuperview() }
        self.buttons.removeAll()
        self.labels.removeAll()
        self.avatarHosts.removeAll()
        self.columns = columns
        let font = UIFont.systemFont(ofSize: max(13, fontSize * 13 / 17))
        self.labelHeight = ceil(font.lineHeight)
        self.selectionStyle = .none
        self.backgroundColor = UIColor(white: dark ? 0.1 : 1, alpha: 1)
        for index in 0..<(members.count + (includeAdd ? 1 : 0)) {
            let id = index < members.count ? members[index].id : nil
            let button = UIButton(type: .custom)
            button.accessibilityLabel = index < members.count ? members[index].name : addTitle
            button.accessibilityIdentifier = id.map { "Wegram.Group.Member.\($0)" } ?? "Wegram.Group.AddMember"
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button, self.buttons.contains(where: { $0 === button }) else { return }
                self.select?(id)
            }, for: .touchUpInside)
            self.contentView.addSubview(button)
            self.buttons.append(button)
            if let id {
                let host = UIView()
                host.backgroundColor = UIColor(white: 0.6, alpha: 0.15)
                host.layer.cornerRadius = 4
                host.clipsToBounds = true
                host.isUserInteractionEnabled = false
                button.addSubview(host)
                self.avatarHosts.append((id, host))
                let label = UILabel()
                label.text = members[index].name
                label.textAlignment = .center
                label.font = font
                label.textColor = UIColor(white: 0.55, alpha: 1)
                label.isAccessibilityElement = false
                self.contentView.addSubview(label)
                self.labels.append(label)
            } else {
                button.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .light)), for: .normal)
                button.tintColor = UIColor(white: 0.55, alpha: 1)
                button.layer.borderColor = UIColor(white: dark ? 0.2 : 0.9, alpha: 1).cgColor
                button.layer.borderWidth = 1
                button.layer.cornerRadius = 4
            }
        }
        self.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let slotWidth = max(0, self.contentView.bounds.width - 32) / CGFloat(self.columns)
        for (index, button) in self.buttons.enumerated() {
            let x = 16 + CGFloat(index) * slotWidth
            button.frame = CGRect(x: x + (slotWidth - 48) / 2, y: 8, width: 48, height: 48)
            if index < self.labels.count { self.labels[index].frame = CGRect(x: x, y: 62, width: slotWidth, height: self.labelHeight) }
        }
        for (_, host) in self.avatarHosts { host.frame = CGRect(x: 0, y: 0, width: 48, height: 48) }
    }
}

private final class WegramGroupActionCell: UITableViewCell {
    override func layoutSubviews() {
        super.layoutSubviews()
        self.textLabel?.frame = self.contentView.bounds.insetBy(dx: 16, dy: 12)
    }
}

final class WegramGroupContentView: UIView, UITableViewDataSource, UITableViewDelegate {
    enum Action: Equatable {
        case back, more, details, about, qr, search, searchMembers, addMember, allMembers, clearHistory, leave, management
        case member(Int64)
        case mute(Bool)
        case pin(Bool)
    }
    var open: ((Action) -> Void)?
    var configureAvatar: ((Int64, UIView) -> Void)?
    var releaseAvatar: ((Int64, UIView) -> Void)?
    var loadMore: (() -> Bool)?
    private(set) var membersExpanded = false
    private var membersLoading = false
    private var requestedMemberCount: Int?
    private var lastExpandedColumns = 6
    var memberColumns: Int { self.columns }
    private var previewLimit: Int { self.columns * 3 - (self.content?.canAddMembers == true ? 1 : 0) }
    private var columns: Int { min(6, max(1, Int(max(0, self.bounds.width - 32) / 56))) }
    private var memberRowHeight: CGFloat { 48 + 6 + ceil(UIFont.systemFont(ofSize: max(13, self.fontSize * 13 / 17)).lineHeight) + 16 }
    private var expandedMemberRows: Int { ((self.content?.members.count ?? 0) + (self.content?.canAddMembers == true ? 1 : 0) + self.columns - 1) / self.columns }
    let table = UITableView(frame: .zero, style: .grouped)
    private let header = UIView()
    private let title = UILabel()
    private let back = UIButton(type: .custom)
    private let memberSearch = UIButton(type: .custom)
    private let grid = UIView()
    private let add = UIButton(type: .custom)
    private let allMembers = UIButton(type: .custom)
    private var memberButtons: [Int64: UIButton] = [:]
    private var memberLabels: [Int64: UILabel] = [:]
    private(set) var avatarHosts: [Int64: UIView] = [:]
    private var content: WegramGroupContent?
    private var rows: [[Action]] = []
    private var dark = false
    private var chinese = true
    private var fontSize: CGFloat = 17
    private var statusHeight: CGFloat = 0
    private var bottomInset: CGFloat = 0
    private var foreground: UIColor { UIColor(white: self.dark ? 0.82 : 0.094, alpha: 1) }
    private var secondary: UIColor { UIColor(white: 0.55, alpha: 1) }
    private var rowColor: UIColor { UIColor(white: self.dark ? 0.1 : 1, alpha: 1) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.accessibilityViewIsModal = true
        self.addSubview(self.table)
        self.addSubview(self.header)
        self.header.addSubview(self.title)
        self.header.addSubview(self.back)
        self.header.addSubview(self.memberSearch)
        self.table.dataSource = self
        self.table.delegate = self
        self.table.register(WegramGroupMemberRowCell.self, forCellReuseIdentifier: "expandedMemberRow")
        self.table.contentInsetAdjustmentBehavior = .never
        self.table.sectionHeaderHeight = 8
        self.table.sectionFooterHeight = .leastNormalMagnitude
        self.table.tableHeaderView = self.grid
        self.title.font = .systemFont(ofSize: 17)
        self.title.textAlignment = .center
        self.title.accessibilityTraits = .header
        self.back.accessibilityIdentifier = "Wegram.Group.Back"
        self.memberSearch.accessibilityIdentifier = "Wegram.Group.SearchMembers"
        self.add.accessibilityIdentifier = "Wegram.Group.AddMember"
        self.back.addAction(UIAction(handler: { [weak self] _ in self?.perform(.back) }), for: .touchUpInside)
        self.memberSearch.addAction(UIAction(handler: { [weak self] _ in self?.perform(.searchMembers) }), for: .touchUpInside)
        self.add.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.content?.canAddMembers == true else { return }
            self.perform(.addMember)
        }), for: .touchUpInside)
        self.grid.addSubview(self.add)
        self.grid.addSubview(self.allMembers)
        self.allMembers.accessibilityIdentifier = "Wegram.Group.AllMembers"
        self.allMembers.addAction(UIAction(handler: { [weak self] _ in
            guard let self, !self.allMembers.isHidden else { return }
            self.perform(.allMembers)
        }), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(_ content: WegramGroupContent, dark: Bool, fontSize: CGFloat, chinese: Bool, statusHeight: CGFloat, bottomInset: CGFloat, membersLoading: Bool = false) {
        if self.content?.members.count != content.members.count { self.requestedMemberCount = nil }
        let loadingChanged = self.membersLoading != membersLoading
        self.membersLoading = membersLoading
        let changed = loadingChanged || self.content != content || self.dark != dark || self.fontSize != fontSize || self.chinese != chinese
        self.content = content
        self.dark = dark
        self.fontSize = fontSize
        self.chinese = chinese
        self.statusHeight = statusHeight
        self.bottomInset = bottomInset
        self.rows = [(content.isChannel ? [] : [.details]) + (content.canShowQRCode ? [.qr] : []) + [.about] + (content.canManageGroup ? [.management] : []), [.search], [.mute(content.isMuted)] + (content.isPinned.map { [.pin($0)] } ?? []), [.more], (content.canClearHistory ? [.clearHistory] : []) + [.leave]]
        self.title.text = (chinese ? "聊天信息" : "Chat Info") + (content.isChannel ? "" : " (\(content.memberCount))")
        self.memberSearch.isHidden = content.isChannel
        self.title.textColor = self.foreground
        self.header.backgroundColor = UIColor(white: dark ? 0.082 : 0.929, alpha: 1)
        self.backgroundColor = self.header.backgroundColor
        self.table.backgroundColor = self.backgroundColor
        self.table.separatorColor = UIColor(white: dark ? 0.2 : 0.9, alpha: 1)
        self.grid.backgroundColor = self.rowColor
        self.back.setImage(wegramNavigationBackArrowImage(color: .black)?.withRenderingMode(.alwaysTemplate), for: .normal)
        self.memberSearch.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)), for: .normal)
        self.back.tintColor = self.foreground
        self.memberSearch.tintColor = self.foreground
        self.back.accessibilityLabel = chinese ? "返回" : "Back"
        self.memberSearch.accessibilityLabel = chinese ? "搜索群成员" : "Search Group Members"
        self.add.accessibilityLabel = chinese ? "添加成员" : "Add Members"
        self.add.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .light)), for: .normal)
        self.add.tintColor = self.secondary
        self.add.layer.borderColor = self.table.separatorColor?.cgColor
        self.add.layer.borderWidth = 1
        self.add.layer.cornerRadius = 4
        self.add.isHidden = self.membersExpanded || !content.canAddMembers
        self.allMembers.setTitle(chinese ? "更多群成员" : "More Group Members", for: .normal)
        self.allMembers.setTitleColor(self.secondary, for: .normal)
        self.allMembers.titleLabel?.font = .systemFont(ofSize: max(14, fontSize * 14 / 17))
        self.allMembers.isHidden = self.membersExpanded || (!content.hasMoreMembers && content.memberCount <= min(content.members.count, self.previewLimit))
        let members = self.membersExpanded ? [] : Array(content.members.prefix(self.previewLimit))
        for id in Array(self.memberButtons.keys) where !members.contains(where: { $0.id == id }) {
            self.memberButtons.removeValue(forKey: id)?.removeFromSuperview()
            self.memberLabels.removeValue(forKey: id)?.removeFromSuperview()
            self.avatarHosts.removeValue(forKey: id)
        }
        for member in members {
            let button: UIButton
            let label: UILabel
            if let current = self.memberButtons[member.id], let currentLabel = self.memberLabels[member.id] {
                button = current; label = currentLabel
            } else {
                button = UIButton(type: .custom)
                label = UILabel()
                label.textAlignment = .center
                self.grid.addSubview(button)
                self.grid.addSubview(label)
                let host = UIView()
                host.isUserInteractionEnabled = false
                host.backgroundColor = UIColor(white: 0.6, alpha: 0.15)
                host.layer.cornerRadius = 4
                host.clipsToBounds = true
                button.addSubview(host)
                self.avatarHosts[member.id] = host
                self.memberButtons[member.id] = button
                self.memberLabels[member.id] = label
                button.addAction(UIAction(handler: { [weak self, weak button] _ in
                    guard let self, let button, self.memberButtons[member.id] === button else { return }
                    self.perform(.member(member.id))
                }), for: .touchUpInside)
            }
            button.accessibilityIdentifier = "Wegram.Group.Member.\(member.id)"
            button.accessibilityLabel = member.name
            label.isAccessibilityElement = false
            label.text = member.name
            label.textColor = self.secondary
            label.font = .systemFont(ofSize: max(13, fontSize * 13 / 17))
        }
        if changed { self.table.reloadData() }
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let navHeight = self.statusHeight + 44
        self.header.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: navHeight)
        // Puts the shared chevron where WeGram's navigation bar draws it.
        self.back.frame = CGRect(x: -1, y: self.statusHeight + 7 / 3, width: 44, height: 44)
        self.memberSearch.frame = CGRect(x: self.bounds.width - 48, y: self.statusHeight, width: 44, height: 44)
        self.title.frame = CGRect(x: 52, y: self.statusHeight, width: max(0, self.bounds.width - 104), height: 44)
        self.table.frame = CGRect(x: 0, y: navHeight, width: self.bounds.width, height: max(0, self.bounds.height - navHeight))
        self.table.contentInset.bottom = self.bottomInset
        if self.membersExpanded {
            self.table.tableHeaderView = nil
            if self.lastExpandedColumns != self.columns {
                self.lastExpandedColumns = self.columns
                self.table.reloadData()
            }
            return
        }
        let members = Array((self.content?.members ?? []).prefix(self.previewLimit))
        let columns = self.columns
        let slotWidth = max(0, self.bounds.width - 32) / CGFloat(columns)
        let labelHeight = ceil(UIFont.systemFont(ofSize: max(13, self.fontSize * 13 / 17)).lineHeight)
        let rowHeight = 48 + 6 + labelHeight + 16
        for (index, member) in members.enumerated() {
            let x = 16 + CGFloat(index % columns) * slotWidth
            let y = 16 + CGFloat(index / columns) * rowHeight
            self.memberButtons[member.id]?.frame = CGRect(x: x + (slotWidth - 48) / 2, y: y, width: 48, height: 48)
            self.avatarHosts[member.id]?.frame = CGRect(x: 0, y: 0, width: 48, height: 48)
            self.memberLabels[member.id]?.frame = CGRect(x: x, y: y + 54, width: slotWidth, height: labelHeight)
        }
        let count = members.count + (self.content?.canAddMembers == true ? 1 : 0)
        self.add.frame = CGRect(x: 16 + CGFloat(members.count % columns) * slotWidth + (slotWidth - 48) / 2, y: 16 + CGFloat(members.count / columns) * rowHeight, width: 48, height: 48)
        let gridHeight = 16 + CGFloat((count + columns - 1) / columns) * rowHeight
        let allMembersHeight = max(44, ceil(self.allMembers.titleLabel?.font.lineHeight ?? 17) + 16)
        self.allMembers.frame = CGRect(x: 16, y: gridHeight, width: max(0, self.bounds.width - 32), height: allMembersHeight)
        let height = gridHeight + (self.allMembers.isHidden ? 0 : allMembersHeight)
        if self.table.tableHeaderView !== self.grid || self.grid.frame.size != CGSize(width: self.bounds.width, height: height) {
            self.grid.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: height)
            self.table.tableHeaderView = self.grid
        }
    }

    private func perform(_ action: Action) {
        guard !self.isHidden else { return }
        self.open?(action)
    }
    func scrollToTop() { self.table.setContentOffset(.zero, animated: true) }
    func setMembersExpanded(_ expanded: Bool) {
        guard self.membersExpanded != expanded else { return }
        self.membersExpanded = expanded
        self.requestedMemberCount = nil
        self.table.setContentOffset(.zero, animated: false)
        self.table.reloadData()
        self.setNeedsLayout()
    }
    func requestExpandedMembersIfNeeded() {
        guard self.membersExpanded, !self.isHidden, !self.membersLoading, self.content?.hasMoreMembers == true,
              let count = self.content?.members.count, count > 0, self.requestedMemberCount != count,
              self.table.bounds.height > 0,
              self.table.rect(forSection: 0).maxY - self.table.contentOffset.y - self.table.bounds.height < 200 else { return }
        self.requestedMemberCount = count
        if self.loadMore?() != true { self.requestedMemberCount = nil }
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { self.requestedMemberCount = nil }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { self.requestExpandedMembersIfNeeded() }
    private func settingsIndexPath(_ path: IndexPath) -> IndexPath? {
        if self.membersExpanded && path.section == 0 { return nil }
        let section = path.section - (self.membersExpanded ? 1 : 0)
        guard self.rows.indices.contains(section), self.rows[section].indices.contains(path.row) else { return nil }
        return IndexPath(row: path.row, section: section)
    }
    func numberOfSections(in tableView: UITableView) -> Int { self.rows.count + (self.membersExpanded ? 1 : 0) }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.membersExpanded && section == 0 { return self.expandedMemberRows + 1 }
        return self.rows[section - (self.membersExpanded ? 1 : 0)].count
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { self.membersExpanded && section == 0 ? .leastNormalMagnitude : 8 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { .leastNormalMagnitude }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.membersExpanded && indexPath.section == 0 {
            return indexPath.row < self.expandedMemberRows ? self.memberRowHeight : max(44, ceil(UIFont.systemFont(ofSize: self.fontSize).lineHeight) + 16)
        }
        if let path = self.settingsIndexPath(indexPath), let title = self.destructiveTitle(self.rows[path.section][path.row]) {
            let size = (title as NSString).boundingRect(with: CGSize(width: max(1, tableView.bounds.width - 32), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: self.fontSize)], context: nil).size
            return max(56, ceil(size.height) + 24)
        }
        return max(56, ceil(UIFont.systemFont(ofSize: self.fontSize).lineHeight) + 24)
    }
    private func destructiveTitle(_ action: Action) -> String? {
        switch action {
        case .clearHistory: return self.chinese ? "清空聊天记录" : "Clear Chat History"
        case .leave:
            if self.content?.isChannel == true { return self.chinese ? "退出频道" : "Leave Channel" }
            return self.chinese ? "退出群聊" : "Leave Group"
        default: return nil
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.membersExpanded && indexPath.section == 0 {
            if indexPath.row == self.expandedMemberRows {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = self.rowColor
                cell.textLabel?.text = self.chinese ? "收起" : "Collapse"
                cell.textLabel?.font = .systemFont(ofSize: self.fontSize)
                cell.textLabel?.textColor = self.secondary
                cell.textLabel?.textAlignment = .center
                cell.accessibilityIdentifier = "Wegram.Group.CollapseMembers"
                cell.accessibilityTraits = .button
                if self.membersLoading {
                    let activity = UIActivityIndicatorView(style: .medium)
                    activity.startAnimating()
                    cell.accessoryView = activity
                    cell.accessibilityValue = self.chinese ? "正在加载更多成员" : "Loading members"
                }
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "expandedMemberRow", for: indexPath) as! WegramGroupMemberRowCell
            let members = self.content?.members ?? []
            let start = indexPath.row * self.columns
            let end = min(members.count, start + self.columns)
            let slice = start < end ? Array(members[start..<end]) : []
            let add = self.content?.canAddMembers == true && start <= members.count && members.count < start + self.columns
            cell.update(members: slice, includeAdd: add, columns: self.columns, dark: self.dark, fontSize: self.fontSize, addTitle: self.chinese ? "添加成员" : "Add Members")
            cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
            return cell
        }
        guard let settingsPath = self.settingsIndexPath(indexPath) else { return UITableViewCell() }
        let action = self.rows[settingsPath.section][settingsPath.row]
        let cell: UITableViewCell = self.destructiveTitle(action) == nil ? UITableViewCell(style: .value1, reuseIdentifier: nil) : WegramGroupActionCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = self.rowColor
        cell.textLabel?.font = .systemFont(ofSize: self.fontSize)
        cell.detailTextLabel?.font = .systemFont(ofSize: self.fontSize)
        cell.textLabel?.textColor = self.foreground
        cell.detailTextLabel?.textColor = self.secondary
        cell.separatorInset.left = 16
        switch action {
        case .details:
            cell.textLabel?.text = self.chinese ? "群聊名称" : "Group Name"
            cell.detailTextLabel?.text = self.content?.name
        case .about:
            if self.content?.isChannel == true {
                cell.textLabel?.text = self.chinese ? "频道简介" : "Channel Description"
            } else {
                cell.textLabel?.text = self.chinese ? "群介绍" : "Group Description"
            }
            cell.detailTextLabel?.text = self.content?.about.map { $0.isEmpty ? (self.chinese ? "未设置" : "Not Set") : $0 }
            cell.accessibilityIdentifier = "Wegram.Group.About"
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = cell.textLabel?.text
            cell.accessibilityValue = cell.detailTextLabel?.text ?? (self.chinese ? "正在加载" : "Loading")
            cell.accessibilityTraits = .button
        case .management:
            cell.textLabel?.text = self.chinese ? "群管理" : "Group Management"
            let count = self.content?.managementRequestCount ?? 0
            cell.detailTextLabel?.text = count > 0 ? String(count) : nil
            cell.detailTextLabel?.textColor = .systemRed
            cell.accessibilityIdentifier = "Wegram.Group.Management"
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = cell.textLabel?.text
            cell.accessibilityValue = cell.detailTextLabel?.text
            cell.accessibilityTraits = .button
        case .qr:
            if self.content?.isChannel == true {
                cell.textLabel?.text = self.chinese ? "频道二维码" : "Channel QR Code"
            } else {
                cell.textLabel?.text = self.chinese ? "群二维码" : "Group QR Code"
            }
        case .search: cell.textLabel?.text = self.chinese ? "查找聊天内容" : "Search Chat History"
        case .more: cell.textLabel?.text = self.chinese ? "更多设置" : "More Settings"
        case .clearHistory, .leave:
            cell.textLabel?.text = self.destructiveTitle(action)
            cell.textLabel?.numberOfLines = 0
            cell.separatorInset.right = 16
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = UIColor(rgb: 0xfa5151)
            cell.accessibilityIdentifier = action == .clearHistory ? "Wegram.Group.ClearHistory" : "Wegram.Group.Leave"
            cell.accessibilityTraits = .button
        case let .mute(value), let .pin(value):
            let isPin: Bool
            if case .pin = action { isPin = true } else { isPin = false }
            cell.textLabel?.text = isPin ? (self.chinese ? "置顶聊天" : "Sticky on Top") : (self.chinese ? "消息免打扰" : "Mute Notifications")
            let control = WegramAppearanceSwitch()
            control.isOn = value
            control.isEnabled = !isPin || self.content?.pinIsBusy != true
            control.accessibilityIdentifier = isPin ? "Wegram.Group.Pin" : "Wegram.Group.Mute"
            control.onTintColor = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
            control.offTintColor = UIColor(white: self.dark ? 0.35 : 0.9, alpha: 1)
            control.onTitle = self.chinese ? "已开启" : "On"
            control.offTitle = self.chinese ? "已关闭" : "Off"
            control.accessibilityLabel = cell.textLabel?.text
            control.addAction(UIAction(handler: { [weak self, weak control, weak cell] _ in
                guard let self, let control, let cell, control.isEnabled, self.table.cellForRow(at: indexPath) === cell else { return }
                self.perform(isPin ? .pin(control.isOn) : .mute(control.isOn))
            }), for: .valueChanged)
            cell.accessoryView = control
            cell.selectionStyle = .none
        default: break
        }
        if cell.accessoryView == nil && action != .clearHistory && action != .leave {
            let arrow = UIImageView(image: wegramDisclosureArrowImage)
            arrow.tintColor = UIColor(white: self.dark ? 1 : 0, alpha: 0.3)
            cell.accessoryView = arrow
        }
        return cell
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? WegramGroupMemberRowCell else { return }
        cell.select = { [weak self, weak cell] id in
            guard let self, let cell, self.membersExpanded, self.table.cellForRow(at: indexPath) === cell else { return }
            if let id {
                guard self.content?.members.contains(where: { $0.id == id }) == true else { return }
                self.perform(.member(id))
            } else if self.content?.canAddMembers == true { self.perform(.addMember) }
        }
        for (id, host) in cell.avatarHosts { self.configureAvatar?(id, host) }
        let hosts = cell.avatarHosts
        cell.releaseAvatars = { [weak self] in
            for (id, host) in hosts { self?.releaseAvatar?(id, host) }
        }
    }
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? WegramGroupMemberRowCell else { return }
        cell.releaseAvatars?()
        cell.releaseAvatars = nil
        cell.select = nil
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if self.membersExpanded && indexPath.section == 0 {
            if indexPath.row == self.expandedMemberRows { self.perform(.allMembers) }
            return
        }
        guard let settingsPath = self.settingsIndexPath(indexPath) else { return }
        let action = self.rows[settingsPath.section][settingsPath.row]
        if case .mute = action { return }
        if case .pin = action { return }
        self.perform(action)
    }
}
