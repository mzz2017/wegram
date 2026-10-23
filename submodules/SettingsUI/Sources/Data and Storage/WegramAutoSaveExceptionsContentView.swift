import UIKit

struct WegramAutoSaveExceptionRow: Equatable {
    let id: Int64
    let name: String
    let summary: String
}

final class WegramAutoSaveExceptionCell: UITableViewCell {
    let avatarHost = UIView()
    let name = UILabel()
    let summary = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        self.contentView.addSubview(self.avatarHost)
        self.contentView.addSubview(self.name)
        self.contentView.addSubview(self.summary)
        self.avatarHost.layer.cornerRadius = 4
        self.avatarHost.clipsToBounds = true
        self.avatarHost.isUserInteractionEnabled = false
        self.name.numberOfLines = 0
        self.summary.numberOfLines = 0
        self.isAccessibilityElement = true
        self.name.isAccessibilityElement = false
        self.summary.isAccessibilityElement = false
        self.avatarHost.accessibilityElementsHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = max(0, self.contentView.bounds.width - 84)
        let nameHeight = self.name.sizeThatFits(CGSize(width: max(1, width), height: .greatestFiniteMagnitude)).height
        let summaryHeight = self.summary.sizeThatFits(CGSize(width: max(1, width), height: .greatestFiniteMagnitude)).height
        let gap: CGFloat = self.summary.text?.isEmpty == false ? 4 : 0
        let top = max(8, (self.contentView.bounds.height - nameHeight - gap - summaryHeight) / 2)
        self.avatarHost.frame = CGRect(x: 16, y: (self.contentView.bounds.height - 40) / 2, width: 40, height: 40)
        self.name.frame = CGRect(x: 68, y: top, width: width, height: nameHeight)
        self.summary.frame = CGRect(x: 68, y: self.name.frame.maxY + gap, width: width, height: summaryHeight)
        for view in self.avatarHost.subviews { view.frame = self.avatarHost.bounds }
    }
}

final class WegramAutoSaveExceptionsContentView: UIView, UITableViewDataSource, UITableViewDelegate {
    let table = UITableView(frame: .zero, style: .plain)
    let status = UILabel()
    let activity = UIActivityIndicatorView(style: .medium)
    private(set) var rows: [WegramAutoSaveExceptionRow] = []
    private(set) var loaded = false
    private var dark = false
    private var fontSize: CGFloat = 17
    private var addTitle = ""
    private var deleteAllTitle = ""
    private var deleteTitle = ""
    private var emptyTitle = ""
    var add: (() -> Void)?
    var open: ((Int64) -> Void)?
    var remove: ((Int64) -> Void)?
    var deleteAll: (() -> Void)?
    var configureAvatar: ((Int64, UIView) -> Void)?

    init() {
        super.init(frame: .zero)
        self.table.dataSource = self
        self.table.delegate = self
        self.table.contentInsetAdjustmentBehavior = .never
        self.table.sectionHeaderTopPadding = 0
        self.table.separatorInset = UIEdgeInsets(top: 0, left: 68, bottom: 0, right: 0)
        self.table.register(WegramAutoSaveExceptionCell.self, forCellReuseIdentifier: "peer")
        self.table.register(UITableViewCell.self, forCellReuseIdentifier: "action")
        self.table.tableFooterView = UIView()
        self.table.tableFooterView?.addSubview(self.status)
        self.table.tableFooterView?.addSubview(self.activity)
        self.status.numberOfLines = 0
        self.status.textAlignment = .center
        self.addSubview(self.table)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(dark: Bool, fontSize: CGFloat, addTitle: String, deleteAllTitle: String, deleteTitle: String, emptyTitle: String) {
        self.dark = dark
        self.fontSize = fontSize
        self.addTitle = addTitle
        self.deleteAllTitle = deleteAllTitle
        self.deleteTitle = deleteTitle
        self.emptyTitle = emptyTitle
        self.backgroundColor = UIColor(white: dark ? 0.07 : 237 / 255, alpha: 1)
        self.table.backgroundColor = self.backgroundColor
        self.table.separatorColor = UIColor(white: dark ? 0.16 : 0.94, alpha: 1)
        self.status.font = .systemFont(ofSize: fontSize * 13 / 17)
        self.status.textColor = .gray
        self.reload()
    }
    func load(rows: [WegramAutoSaveExceptionRow], loaded: Bool) {
        self.rows = rows
        self.loaded = loaded
        self.reload()
    }
    private func reload() {
        self.status.text = self.emptyTitle
        self.status.isHidden = !self.loaded || !self.rows.isEmpty
        if self.loaded { self.activity.stopAnimating() } else { self.activity.startAnimating() }
        self.table.reloadData()
        self.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let widthChanged = self.table.bounds.width != self.bounds.width
        self.table.frame = self.bounds
        if widthChanged { self.table.reloadData() }
        let footer = self.table.tableFooterView!
        let textWidth = max(1, self.bounds.width - 32)
        let textHeight = self.status.isHidden ? 0 : self.status.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
        self.status.frame = CGRect(x: 16, y: 24, width: textWidth, height: textHeight)
        self.activity.center = CGPoint(x: self.bounds.width / 2, y: 42)
        let height: CGFloat = self.activity.isAnimating ? 80 : (textHeight == 0 ? 0 : textHeight + 48)
        let size = CGSize(width: self.bounds.width, height: height)
        if footer.frame.size != size {
            footer.frame = CGRect(origin: .zero, size: size)
            self.table.tableFooterView = footer
        }
    }
    func numberOfSections(in tableView: UITableView) -> Int { 3 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard self.loaded else { return 0 }
        switch section { case 0: return 1; case 1: return self.rows.count; default: return self.rows.isEmpty ? 0 : 1 }
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        self.tableView(tableView, numberOfRowsInSection: section) == 0 ? 0 : 8
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = self.backgroundColor
        return view
    }
    private func height(_ text: String, font: CGFloat, width: CGFloat) -> CGFloat {
        ceil((text as NSString).boundingRect(with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: font)], context: nil).height)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            let row = self.rows[indexPath.row]
            let width = tableView.bounds.width - 84
            return max(56, self.height(row.name, font: self.fontSize, width: width) + (row.summary.isEmpty ? 0 : 4 + self.height(row.summary, font: self.fontSize * 13 / 17, width: width)) + 16)
        }
        return max(56, self.height(indexPath.section == 0 ? self.addTitle : self.deleteAllTitle, font: self.fontSize, width: tableView.bounds.width - 32) + 24)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let color = UIColor(white: self.dark ? 0.82 : 0.1, alpha: 1)
        let cell: UITableViewCell
        if indexPath.section == 1 {
            let peerCell = tableView.dequeueReusableCell(withIdentifier: "peer", for: indexPath) as! WegramAutoSaveExceptionCell
            let row = self.rows[indexPath.row]
            peerCell.name.text = row.name
            peerCell.name.font = .systemFont(ofSize: self.fontSize)
            peerCell.name.textColor = color
            peerCell.summary.text = row.summary
            peerCell.summary.font = .systemFont(ofSize: self.fontSize * 13 / 17)
            peerCell.summary.textColor = .gray
            peerCell.accessibilityLabel = row.name
            peerCell.accessibilityValue = row.summary
            peerCell.accessibilityIdentifier = "Wegram.AutoSave.Exception.\(row.id)"
            peerCell.accessibilityCustomActions = [UIAccessibilityCustomAction(name: self.deleteTitle, actionHandler: { [weak self] _ in self?.requestRemove(row.id) ?? false })]
            self.configureAvatar?(row.id, peerCell.avatarHost)
            cell = peerCell
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "action", for: indexPath)
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.font = .systemFont(ofSize: self.fontSize)
            cell.textLabel?.text = indexPath.section == 0 ? self.addTitle : self.deleteAllTitle
            cell.textLabel?.textColor = indexPath.section == 0 ? UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1) : UIColor(red: 0.98, green: 0.31, blue: 0.32, alpha: 1)
            cell.textLabel?.textAlignment = indexPath.section == 0 ? .left : .center
            cell.accessibilityLabel = cell.textLabel?.text
            cell.accessibilityIdentifier = indexPath.section == 0 ? "Wegram.AutoSave.AddException" : "Wegram.AutoSave.DeleteAllExceptions"
            cell.separatorInset = .zero
            cell.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        }
        cell.backgroundColor = UIColor(white: self.dark ? 0.1 : 1, alpha: 1)
        let selection = UIView()
        selection.backgroundColor = UIColor(white: self.dark ? 0.15 : 0.94, alpha: 1)
        cell.selectedBackgroundView = selection
        cell.isAccessibilityElement = true
        cell.accessibilityTraits = .button
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard self.loaded else { return }
        switch indexPath.section {
        case 0: self.add?()
        case 1:
            guard self.rows.indices.contains(indexPath.row) else { return }
            self.open?(self.rows[indexPath.row].id)
        default:
            guard !self.rows.isEmpty else { return }
            self.deleteAll?()
        }
    }
    @discardableResult func requestRemove(_ id: Int64) -> Bool {
        guard self.loaded, self.rows.contains(where: { $0.id == id }) else { return false }
        self.remove?(id)
        return true
    }
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard self.loaded, indexPath.section == 1, self.rows.indices.contains(indexPath.row) else { return nil }
        let id = self.rows[indexPath.row].id
        let action = UIContextualAction(style: .destructive, title: self.deleteTitle, handler: { [weak self] _, _, completion in completion(self?.requestRemove(id) ?? false) })
        let configuration = UISwipeActionsConfiguration(actions: [action])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
