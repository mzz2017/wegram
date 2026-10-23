import UIKit

struct WegramBlockedRow: Equatable {
    let id: Int64
    let name: String
    let username: String?
}

final class WegramBlockedCell: UITableViewCell {
    let avatarHost = UIView()
    let name = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        self.contentView.addSubview(self.avatarHost)
        self.contentView.addSubview(self.name)
        self.avatarHost.layer.cornerRadius = 4
        self.avatarHost.clipsToBounds = true
        self.avatarHost.isUserInteractionEnabled = false
        self.isAccessibilityElement = true
        self.name.isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.avatarHost.frame = CGRect(x: 16, y: (self.contentView.bounds.height - 40) / 2, width: 40, height: 40)
        self.name.frame = CGRect(x: 68, y: 0, width: max(0, self.contentView.bounds.width - 84), height: self.contentView.bounds.height)
        for view in self.avatarHost.subviews { view.frame = self.avatarHost.bounds }
    }
}

final class WegramBlockedContentView: UIView, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    let table = UITableView(frame: .zero, style: .plain)
    let searchField = UITextField()
    let status = UILabel()
    let moreButton = UIButton(type: .custom)
    let activity = UIActivityIndicatorView(style: .medium)
    private(set) var rows: [WegramBlockedRow] = []
    private(set) var visibleRows: [WegramBlockedRow] = []
    private var canLoadMore = true
    private var loading = true
    private var dark = false
    private var chinese = true
    private var fontSize: CGFloat = 17
    var query: String { self.searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    var busy = false { didSet { self.updateRows() } }
    var removeTitle = "移出黑名单"
    var open: ((Int64) -> Void)?
    var remove: ((Int64) -> Void)?
    var loadMore: (() -> Void)?
    var configureAvatar: ((Int64, UIView) -> Void)?

    init() {
        super.init(frame: .zero)
        self.table.dataSource = self
        self.table.delegate = self
        self.table.register(WegramBlockedCell.self, forCellReuseIdentifier: "blocked")
        self.table.contentInsetAdjustmentBehavior = .never
        self.table.keyboardDismissMode = .interactive
        self.table.separatorInset = UIEdgeInsets(top: 0, left: 68, bottom: 0, right: 0)
        self.table.tableFooterView = UIView()
        self.table.tableFooterView?.addSubview(self.moreButton)
        self.table.tableHeaderView = UIView()
        self.table.tableHeaderView?.addSubview(self.searchField)
        let searchTap = UITapGestureRecognizer(target: self, action: #selector(self.focusSearch))
        searchTap.cancelsTouchesInView = false
        self.table.tableHeaderView?.addGestureRecognizer(searchTap)
        self.searchField.delegate = self
        self.searchField.clearButtonMode = .whileEditing
        self.searchField.autocorrectionType = .no
        self.searchField.autocapitalizationType = .none
        self.searchField.returnKeyType = .search
        self.searchField.layer.cornerRadius = 5
        self.searchField.accessibilityIdentifier = "Wegram.Blocked.Search"
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.contentMode = .center
        icon.frame = CGRect(x: 0, y: 0, width: 32, height: 36)
        self.searchField.leftView = icon
        self.searchField.leftViewMode = .always
        self.searchField.addAction(UIAction(handler: { [weak self] _ in self?.updateRows() }), for: .editingChanged)
        self.status.numberOfLines = 0
        self.status.textAlignment = .center
        self.moreButton.addAction(UIAction(handler: { [weak self] _ in self?.requestMore() }), for: .touchUpInside)
        self.moreButton.accessibilityIdentifier = "Wegram.Blocked.LoadMore"
        self.addSubview(self.table)
        self.table.tableFooterView?.addSubview(self.status)
        self.table.tableFooterView?.addSubview(self.activity)
        self.update(dark: false, fontSize: 17, chinese: true)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func load(rows: [WegramBlockedRow], loading: Bool, canLoadMore: Bool) {
        var seen = Set<Int64>()
        self.rows = rows.filter { seen.insert($0.id).inserted }
        self.loading = loading
        self.canLoadMore = canLoadMore
        self.updateRows()
    }
    func update(dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.dark = dark
        self.fontSize = fontSize
        self.chinese = chinese
        let background = UIColor(white: dark ? 0.07 : 237 / 255, alpha: 1)
        self.backgroundColor = background
        self.table.backgroundColor = background
        self.table.separatorColor = UIColor(white: dark ? 0.16 : 0.94, alpha: 1)
        self.table.tableHeaderView?.backgroundColor = background
        self.searchField.backgroundColor = UIColor(white: dark ? 0.15 : 1, alpha: 1)
        self.searchField.textColor = UIColor(white: dark ? 0.82 : 0.1, alpha: 1)
        self.searchField.tintColor = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
        self.searchField.leftView?.tintColor = .gray
        self.searchField.font = .systemFont(ofSize: fontSize)
        self.searchField.placeholder = chinese ? "搜索" : "Search"
        self.searchField.accessibilityLabel = self.searchField.placeholder
        self.status.font = .systemFont(ofSize: max(13, fontSize * 13 / 17))
        self.status.textColor = .gray
        self.moreButton.titleLabel?.font = self.status.font
        self.moreButton.setTitle(chinese ? "继续加载" : "Load More", for: .normal)
        self.moreButton.setTitleColor(self.searchField.tintColor, for: .normal)
        self.updateRows()
        self.setNeedsLayout()
    }
    private func updateRows() {
        let query = self.query
        self.visibleRows = self.rows.filter { query.isEmpty || $0.name.localizedStandardContains(query) || ($0.username?.localizedStandardContains(query) ?? false) }
        self.table.isUserInteractionEnabled = !self.busy
        self.searchField.isEnabled = !self.busy
        self.table.reloadData()
        self.status.isHidden = !self.visibleRows.isEmpty || self.loading || self.busy
        self.status.text = self.canLoadMore ? (self.chinese ? "仍有用户未加载，继续加载以查找更多。" : "More users are not loaded yet. Load more to continue searching.") : (query.isEmpty ? (self.chinese ? "暂无黑名单用户" : "No Blocked Users") : (self.chinese ? "未找到相关用户" : "No Results"))
        self.moreButton.isHidden = !self.canLoadMore
        self.moreButton.isEnabled = !self.loading && !self.busy
        if self.loading || self.busy { self.activity.startAnimating() } else { self.activity.stopAnimating() }
        self.setNeedsLayout()
    }
    private func requestMore() {
        guard self.canLoadMore, !self.loading, !self.busy else { return }
        self.loadMore?()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.table.frame = self.bounds
        let width = self.bounds.width
        let fieldHeight = max(36, self.fontSize + 12)
        let header = self.table.tableHeaderView!
        self.searchField.frame = CGRect(x: 8, y: 8, width: max(0, width - 16), height: fieldHeight)
        if header.frame.size != CGSize(width: width, height: fieldHeight + 16) {
            header.frame = CGRect(x: 0, y: 0, width: width, height: fieldHeight + 16)
            self.table.tableHeaderView = header
        }
        let footer = self.table.tableFooterView!
        var footerHeight: CGFloat = 12
        if !self.status.isHidden {
            let textHeight = self.status.sizeThatFits(CGSize(width: max(1, width - 40), height: .greatestFiniteMagnitude)).height
            self.status.frame = CGRect(x: 20, y: footerHeight, width: max(0, width - 40), height: textHeight)
            footerHeight = self.status.frame.maxY + 12
        }
        if !self.moreButton.isHidden {
            self.moreButton.frame = CGRect(x: 20, y: footerHeight, width: max(0, width - 40), height: 44)
            footerHeight = self.moreButton.frame.maxY + 6
        }
        if self.activity.isAnimating {
            self.activity.center = CGPoint(x: width / 2, y: footerHeight + 18)
            footerHeight += 36
        }
        if self.status.isHidden && self.moreButton.isHidden && !self.activity.isAnimating { footerHeight = 0 }
        if footer.frame.size != CGSize(width: width, height: footerHeight) {
            footer.frame = CGRect(x: 0, y: 0, width: width, height: footerHeight)
            self.table.tableFooterView = footer
        }
    }
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.visibleRows.count }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { max(56, ceil(self.fontSize * 56 / 17)) }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "blocked", for: indexPath) as! WegramBlockedCell
        let row = self.visibleRows[indexPath.row]
        cell.name.text = row.name
        cell.name.font = .systemFont(ofSize: self.fontSize)
        cell.name.textColor = self.searchField.textColor
        cell.backgroundColor = UIColor(white: self.dark ? 0.1 : 1, alpha: 1)
        cell.accessibilityLabel = row.name
        cell.accessibilityIdentifier = "Wegram.Blocked.\(row.id)"
        cell.accessibilityTraits = self.busy ? [.button, .notEnabled] : .button
        cell.accessibilityCustomActions = [UIAccessibilityCustomAction(name: self.removeTitle, actionHandler: { [weak self] _ in self?.requestRemove(row.id) ?? false })]
        self.configureAvatar?(row.id, cell.avatarHost)
        return cell
    }
    @discardableResult func requestRemove(_ id: Int64) -> Bool {
        guard !self.busy, self.rows.contains(where: { $0.id == id }) else { return false }
        self.remove?(id)
        return true
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !self.busy, self.visibleRows.indices.contains(indexPath.row) else { return }
        self.open?(self.visibleRows[indexPath.row].id)
    }
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !self.busy, self.visibleRows.indices.contains(indexPath.row) else { return nil }
        let id = self.visibleRows[indexPath.row].id
        let action = UIContextualAction(style: .destructive, title: self.removeTitle, handler: { [weak self] _, _, completion in completion(self?.requestRemove(id) ?? false) })
        let configuration = UISwipeActionsConfiguration(actions: [action])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard self.query.isEmpty, !self.rows.isEmpty, scrollView.isDragging || scrollView.isDecelerating,
            scrollView.contentOffset.y + scrollView.bounds.height - scrollView.adjustedContentInset.bottom > scrollView.contentSize.height - 40 else { return }
        self.requestMore()
    }
    @objc private func focusSearch() { if !self.busy { self.searchField.becomeFirstResponder() } }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { textField.resignFirstResponder(); return true }
}
