import UIKit
import Display

struct WegramDeviceRow: Equatable {
    let id: Int64
    let name: String
    let passwordPending: Bool
    var isCurrent: Bool { self.id == 0 }
}

final class WegramDeviceCell: UITableViewCell {
    let name = UILabel()
    let badge = UILabel()
    let arrow = UIImageView(image: wegramDisclosureArrowImage)
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        for view in [self.name, self.badge, self.arrow] { self.contentView.addSubview(view) }
        self.isAccessibilityElement = true
        self.selectedBackgroundView = UIView()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.contentView.bounds.width
        let badgeWidth = min(width * 0.35, self.badge.sizeThatFits(self.contentView.bounds.size).width)
        self.arrow.frame = wegramDisclosureArrowFrame(trailingEdge: width, centerY: self.contentView.bounds.height / 2)
        self.badge.frame = CGRect(x: width - 42 - badgeWidth, y: 0, width: badgeWidth, height: self.contentView.bounds.height)
        self.name.frame = CGRect(x: 16, y: 0, width: max(0, width - 58 - (badgeWidth > 0 ? badgeWidth + 12 : 0)), height: self.contentView.bounds.height)
    }
}

final class WegramDevicesContentView: UIView, UITableViewDataSource, UITableViewDelegate {
    let table = UITableView(frame: .zero, style: .plain)
    let explanation = UILabel()
    let activity = UIActivityIndicatorView(style: .medium)
    let emptyLabel = UILabel()
    private(set) var rows: [WegramDeviceRow] = []
    private var loading = true
    private var dark = false
    private var chinese = true
    private var fontSize: CGFloat = 17
    var open: ((Int64) -> Void)?
    var remove: ((Int64) -> Void)?
    var busy = false { didSet { self.updateState() } }
    var hasEditableDevices: Bool { self.rows.contains { !$0.isCurrent } }

    init() {
        super.init(frame: .zero)
        self.table.dataSource = self
        self.table.delegate = self
        self.table.register(WegramDeviceCell.self, forCellReuseIdentifier: "device")
        self.table.contentInsetAdjustmentBehavior = .never
        self.table.sectionHeaderTopPadding = 0
        self.table.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        self.table.tableFooterView = UIView()
        self.explanation.numberOfLines = 0
        self.emptyLabel.numberOfLines = 0
        self.emptyLabel.textAlignment = .center
        self.table.tableHeaderView = UIView()
        self.table.tableHeaderView?.addSubview(self.explanation)
        self.addSubview(self.table)
        self.addSubview(self.activity)
        self.addSubview(self.emptyLabel)
        self.updateState()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func load(rows: [WegramDeviceRow], loading: Bool) {
        var seen = Set<Int64>()
        let unique = rows.filter { seen.insert($0.id).inserted }
        self.rows = unique.filter { $0.isCurrent } + unique.filter { !$0.isCurrent }
        self.loading = loading
        if !self.hasEditableDevices { self.table.setEditing(false, animated: false) }
        self.updateState()
        self.setNeedsLayout()
    }
    func update(dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.dark = dark
        self.fontSize = fontSize
        self.chinese = chinese
        self.backgroundColor = UIColor(white: dark ? 0.1 : 237 / 255, alpha: 1)
        self.table.backgroundColor = self.backgroundColor
        self.table.separatorColor = UIColor(white: dark ? 0.2 : 0.94, alpha: 1)
        self.explanation.text = chinese ? "你可以查看已登录的设备，并退出其他设备上的登录。" : "Review signed-in devices and log out other sessions."
        self.explanation.font = .systemFont(ofSize: max(13, fontSize * 13 / 17))
        self.explanation.textColor = UIColor(white: dark ? 0.45 : 0.6, alpha: 1)
        self.activity.color = self.explanation.textColor
        self.activity.accessibilityLabel = chinese ? "加载设备" : "Loading Devices"
        self.emptyLabel.font = .systemFont(ofSize: fontSize)
        self.emptyLabel.textColor = self.explanation.textColor
        self.emptyLabel.text = chinese ? "暂无登录设备" : "No Signed-in Devices"
        self.updateState()
        self.setNeedsLayout()
    }
    func setEditing(_ editing: Bool) {
        guard !self.busy else { return }
        self.table.setEditing(editing && self.hasEditableDevices, animated: true)
    }
    private func updateState() {
        self.table.isUserInteractionEnabled = !self.busy
        self.table.reloadData()
        self.emptyLabel.isHidden = self.loading || !self.rows.isEmpty
        if (self.loading && self.rows.isEmpty) || self.busy { self.activity.startAnimating() } else { self.activity.stopAnimating() }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.table.frame = self.bounds
        let width = self.bounds.width
        let textHeight = ceil(self.explanation.sizeThatFits(CGSize(width: max(1, width - 32), height: .greatestFiniteMagnitude)).height)
        let header = self.table.tableHeaderView!
        let headerHeight = max(44, textHeight + 16)
        self.explanation.frame = CGRect(x: 16, y: 8, width: width - 32, height: textHeight)
        if header.frame.width != width || header.frame.height != headerHeight {
            header.frame = CGRect(x: 0, y: 0, width: width, height: headerHeight)
            self.table.tableHeaderView = header
        }
        self.activity.center = CGPoint(x: width / 2, y: max(headerHeight + 24, self.bounds.height / 2))
        self.emptyLabel.frame = CGRect(x: 20, y: headerHeight + 40, width: max(0, width - 40), height: max(80, self.fontSize * 4))
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.rows.count }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { max(56, ceil(self.fontSize * 56 / 17)) }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "device", for: indexPath) as! WegramDeviceCell
        let row = self.rows[indexPath.row]
        cell.name.text = row.name
        cell.name.font = .systemFont(ofSize: self.fontSize)
        cell.name.textColor = UIColor(white: self.dark ? 0.82 : 0.1, alpha: 1)
        cell.badge.text = row.passwordPending ? (self.chinese ? "待验证" : "Pending") : (row.isCurrent ? (self.chinese ? "当前设备" : "Current") : nil)
        cell.badge.font = .systemFont(ofSize: max(13, self.fontSize * 13 / 17))
        cell.badge.textColor = UIColor(white: self.dark ? 0.45 : 0.6, alpha: 1)
        cell.arrow.tintColor = UIColor(white: self.dark ? 1 : 0, alpha: 0.3)
        cell.arrow.isHidden = tableView.isEditing
        cell.backgroundColor = UIColor(white: self.dark ? 0.14 : 1, alpha: 1)
        cell.selectedBackgroundView?.backgroundColor = UIColor(white: self.dark ? 0.2 : 0.95, alpha: 1)
        cell.accessibilityLabel = [row.name, cell.badge.text].compactMap { $0 }.joined(separator: ", ")
        cell.accessibilityIdentifier = "Wegram.Device." + String(row.id)
        cell.accessibilityTraits = self.busy ? [.button, .notEnabled] : .button
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !self.busy, self.rows.indices.contains(indexPath.row) else { return }
        self.open?(self.rows[indexPath.row].id)
    }
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        self.rows.indices.contains(indexPath.row) && !self.rows[indexPath.row].isCurrent && !self.busy
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, self.tableView(tableView, canEditRowAt: indexPath) else { return }
        self.remove?(self.rows[indexPath.row].id)
    }
}
