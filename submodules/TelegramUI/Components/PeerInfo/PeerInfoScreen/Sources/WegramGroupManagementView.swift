import UIKit

final class WegramGroupManagementView: UIView, UITableViewDataSource, UITableViewDelegate {
    let table = UITableView(frame: .zero, style: .grouped)
    var open: ((WegramGroupManagementAction) -> Void)?
    private var sections: [[WegramGroupManagementAction]] = []
    private var dark = false
    private var chinese = true
    private var fontSize: CGFloat = 17
    private var pendingRequests = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.table)
        self.table.dataSource = self
        self.table.delegate = self
        self.table.contentInsetAdjustmentBehavior = .never
        self.table.sectionHeaderHeight = 8
        self.table.sectionFooterHeight = .leastNormalMagnitude
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(actions: [WegramGroupManagementAction], pendingRequests: Int, dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.sections = [actions.filter { $0 != .more }, actions.filter { $0 == .more }].filter { !$0.isEmpty }
        self.pendingRequests = max(0, pendingRequests)
        self.dark = dark
        self.chinese = chinese
        self.fontSize = fontSize
        self.backgroundColor = UIColor(white: dark ? 0.07 : 0.93, alpha: 1)
        self.table.backgroundColor = self.backgroundColor
        self.table.separatorColor = UIColor(white: dark ? 0.2 : 0.9, alpha: 1)
        self.table.reloadData()
    }
    private func title(_ action: WegramGroupManagementAction) -> String {
        switch action {
        case .administrators: return self.chinese ? "群管理员" : "Group Administrators"
        case .permissions: return self.chinese ? "成员权限" : "Member Permissions"
        case .requests: return self.chinese ? "入群申请" : "Join Requests"
        case .more: return self.chinese ? "更多管理" : "More Management"
        }
    }
    func numberOfSections(in tableView: UITableView) -> Int { self.sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.sections[section].count }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let text = self.title(self.sections[indexPath.section][indexPath.row])
        let detail: CGFloat = self.sections[indexPath.section][indexPath.row] == .requests ? min(tableView.bounds.width * 0.4, (String(self.pendingRequests) as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: self.fontSize)]).width) : 0
        let size = (text as NSString).boundingRect(with: CGSize(width: max(1, tableView.bounds.width - 58 - detail), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: self.fontSize)], context: nil).size
        return max(56, ceil(size.height) + 24)
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { .leastNormalMagnitude }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let action = self.sections[indexPath.section][indexPath.row]
        let cell = WegramSettingsCell()
        cell.backgroundColor = UIColor(white: self.dark ? 0.1 : 1, alpha: 1)
        cell.selectedBackgroundView?.backgroundColor = UIColor(white: self.dark ? 1 : 0, alpha: 0.06)
        cell.textLabel?.text = self.title(action)
        cell.textLabel?.font = .systemFont(ofSize: self.fontSize)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.textColor = UIColor(white: self.dark ? 0.82 : 0.1, alpha: 1)
        cell.detailTextLabel?.font = .systemFont(ofSize: self.fontSize)
        cell.detailTextLabel?.textColor = .systemRed
        cell.detailTextLabel?.text = action == .requests ? String(self.pendingRequests) : nil
        cell.arrow.tintColor = UIColor(white: self.dark ? 1 : 0, alpha: 0.3)
        cell.separatorInset.left = 16
        cell.isAccessibilityElement = true
        cell.accessibilityIdentifier = "Wegram.Group.Management.\(action)"
        cell.accessibilityLabel = self.title(action)
        cell.accessibilityValue = cell.detailTextLabel?.text
        cell.accessibilityTraits = .button
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !self.isHidden, self.sections.indices.contains(indexPath.section), self.sections[indexPath.section].indices.contains(indexPath.row) else { return }
        self.open?(self.sections[indexPath.section][indexPath.row])
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.table.frame = self.bounds
    }
}
