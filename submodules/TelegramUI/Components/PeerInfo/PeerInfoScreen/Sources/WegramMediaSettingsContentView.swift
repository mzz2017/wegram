import UIKit
import Display
import TelegramUIPreferences

enum WegramMediaSetting: String, CaseIterable {
    case cellular, wifi, privateChats, groups, channels, editedPhotos, calls
    case master, photos, videos, files
    var isToggle: Bool { self == .editedPhotos || self == .calls || self == .master }
    func applying(_ value: Bool, to settings: GeneratedMediaStoreSettings) -> GeneratedMediaStoreSettings {
        return self == .editedPhotos ? settings.withUpdatedStoreEditedPhotos(value) : settings
    }
    func applying(_ value: Bool, to settings: VoiceCallSettings) -> VoiceCallSettings {
        var result = settings
        if self == .calls { result.dataSaving = value ? .always : .never }
        return result
    }
    func applying(_ value: Bool, to settings: MediaAutoDownloadSettings, network: MediaAutoDownloadNetworkType) -> MediaAutoDownloadSettings {
        var result = settings
        if self == .master {
            switch network {
            case .cellular: result.cellular.enabled = value
            case .wifi: result.wifi.enabled = value
            }
        }
        return result
    }
    func title(chinese: Bool) -> String {
        switch self {
        case .cellular: return chinese ? "移动网络" : "Mobile Data"
        case .wifi: return "Wi-Fi"
        case .privateChats: return chinese ? "私聊中接收的媒体" : "Media Received in Private Chats"
        case .groups: return chinese ? "群聊中接收的媒体" : "Media Received in Groups"
        case .channels: return chinese ? "频道中接收的媒体" : "Media Received in Channels"
        case .editedPhotos: return chinese ? "编辑后的照片" : "Edited Photos"
        case .calls: return chinese ? "节省通话流量" : "Use Less Data for Calls"
        case .master: return chinese ? "自动下载" : "Automatic Download"
        case .photos: return chinese ? "照片" : "Photos"
        case .videos: return chinese ? "视频" : "Videos"
        case .files: return chinese ? "文件" : "Files"
        }
    }
}

final class WegramMediaSettingsCell: UITableViewCell {
    let name = UILabel()
    let summary = UILabel()
    let toggle = WegramAppearanceSwitch()
    let arrow = UIImageView(image: wegramDisclosureArrowImage)
    init() {
        super.init(style: .default, reuseIdentifier: nil)
        self.name.numberOfLines = 0
        self.name.isAccessibilityElement = false
        self.summary.isAccessibilityElement = false
        self.summary.numberOfLines = 0
        self.contentView.addSubview(self.summary)
        self.arrow.isAccessibilityElement = false
        self.contentView.addSubview(self.name)
        self.contentView.addSubview(self.toggle)
        self.contentView.addSubview(self.arrow)
        self.selectedBackgroundView = UIView()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.contentView.bounds.width
        let height = self.contentView.bounds.height
        self.toggle.frame = CGRect(x: max(16, width - 16 - 51), y: floor((height - 44) / 2), width: 51, height: 44)
        self.arrow.frame = wegramDisclosureArrowFrame(trailingEdge: width, centerY: height / 2)
        let textWidth = max(0, width - (self.toggle.isHidden ? 58 : 99))
        if self.summary.text?.isEmpty == false {
            let nameHeight = ceil(self.name.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
            self.name.frame = CGRect(x: 16, y: 12, width: textWidth, height: nameHeight)
            self.summary.frame = CGRect(x: 16, y: self.name.frame.maxY + 4, width: textWidth, height: max(0, height - self.name.frame.maxY - 16))
        } else {
            self.name.frame = CGRect(x: 16, y: 12, width: textWidth, height: max(0, height - 24))
            self.summary.frame = .zero
        }
    }
}

final class WegramMediaSettingsContentView: UIView, UITableViewDataSource, UITableViewDelegate {
    let table = UITableView(frame: .zero, style: .grouped)
    static let sections: [[WegramMediaSetting]] = [[.cellular, .wifi], [.privateChats, .groups, .channels, .editedPhotos], [.calls]]
    static let automaticDownloadSections: [[WegramMediaSetting]] = [[.master], [.photos, .videos, .files]]
    var automaticDownload = false
    private var sections: [[WegramMediaSetting]] { self.automaticDownload ? Self.automaticDownloadSections : Self.sections }
    private var summaries: [WegramMediaSetting: String] = [:]
    private var voiceInfo = ""
    var open: ((WegramMediaSetting) -> Void)?
    var change: ((WegramMediaSetting, Bool) -> Void)?
    private var values: [WegramMediaSetting: Bool]?
    private var chinese = true
    private var dark = false
    private var fontSize: CGFloat = 17
    private var callScope = ""
    var busy = false { didSet { self.table.reloadData() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.table.dataSource = self
        self.table.delegate = self
        self.table.contentInsetAdjustmentBehavior = .never
        self.table.sectionHeaderTopPadding = 0
        self.table.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        self.addSubview(self.table)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let widthChanged = self.table.bounds.width != self.bounds.width
        self.table.frame = self.bounds
        if widthChanged { self.table.reloadData() }
    }
    func update(dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.dark = dark
        self.fontSize = fontSize
        self.chinese = chinese
        self.backgroundColor = UIColor(rgb: dark ? 0x111111 : 0xeeeeee)
        self.table.backgroundColor = self.backgroundColor
        self.table.separatorColor = UIColor(rgb: dark ? 0x383838 : 0xe5e5e5)
        self.table.reloadData()
    }
    func load(editedPhotos: Bool?, lessCallData: Bool?, callScope: String) {
        if let editedPhotos, let lessCallData { self.values = [.editedPhotos: editedPhotos, .calls: lessCallData] }
        else { self.values = nil }
        self.callScope = callScope
        self.table.reloadData()
    }
    func loadAutomaticDownload(enabled: Bool?, summaries: [WegramMediaSetting: String], voiceInfo: String) {
        self.values = enabled.map { [.master: $0] }
        self.summaries = summaries
        self.voiceInfo = voiceInfo
        self.table.reloadData()
    }
    private func canOpen(_ field: WegramMediaSetting) -> Bool {
        return !self.busy && !field.isToggle && (!self.automaticDownload || self.values?[.master] == true)
    }
    func numberOfSections(in tableView: UITableView) -> Int { self.sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.sections[section].count }
    private func note(_ section: Int) -> String {
        if self.automaticDownload {
            if section == 1 { return self.chinese ? "媒体类型" : "Media Types" }
            return self.chinese ? "开启后，按以下规则自动下载媒体。" : "When enabled, media downloads automatically using the rules below."
        }
        switch section {
        case 0: return self.chinese ? "按网络分别设置照片、视频和文件的自动下载。" : "Choose automatic downloads for photos, videos and files on each network."
        case 1: return self.chinese ? "分别设置接收媒体的自动保存。编辑后的照片按开关保存到系统相册。" : "Configure automatic saving of received media separately. Edited photos are saved to Photos when enabled."
        default: return self.values == nil ? (self.chinese ? "正在加载…" : "Loading…") : self.callScope
        }
    }
    private func textHeight(_ text: String, size: CGFloat) -> CGFloat {
        return ceil((text as NSString).boundingRect(with: CGSize(width: max(1, self.bounds.width - 32), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: size)], context: nil).height)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let field = self.sections[indexPath.section][indexPath.row]
        let text = field.title(chinese: self.chinese)
        let width = max(1, self.bounds.width - (field.isToggle ? 99 : 58))
        let height = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: self.fontSize)], context: nil).height
        let summary = self.summaries[field] ?? ""
        let summaryHeight = summary.isEmpty ? 0 : ceil((summary as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: self.fontSize * 13 / 17)], context: nil).height) + 4
        return max(56, ceil(height) + summaryHeight + 24)
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { self.textHeight(self.note(section), size: self.fontSize * 13 / 17) + 24 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { self.automaticDownload && section == 1 && !self.voiceInfo.isEmpty ? self.textHeight(self.voiceInfo, size: self.fontSize * 13 / 17) + 24 : 8 }
    private func headerLabel(_ text: String, header: Bool = true) -> UIView {
        let view = UIView()
        view.backgroundColor = self.backgroundColor
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: self.fontSize * 13 / 17)
        label.textColor = UIColor(rgb: self.dark ? 0x888888 : 0x777777)
        label.numberOfLines = 0
        label.frame = CGRect(x: 16, y: header ? 16 : 8, width: max(0, self.bounds.width - 32), height: self.textHeight(text, size: self.fontSize * 13 / 17))
        label.accessibilityTraits = header ? .header : .staticText
        view.addSubview(label)
        return view
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { self.headerLabel(self.note(section)) }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if self.automaticDownload && section == 1 && !self.voiceInfo.isEmpty { return self.headerLabel(self.voiceInfo, header: false) }
        let view = UIView()
        view.backgroundColor = self.backgroundColor
        return view
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let field = self.sections[indexPath.section][indexPath.row]
        let cell = WegramMediaSettingsCell()
        cell.backgroundColor = UIColor(rgb: self.dark ? 0x191919 : 0xffffff)
        cell.selectedBackgroundView?.backgroundColor = UIColor(rgb: self.dark ? 0x292929 : 0xe5e5e5)
        let title = field.title(chinese: self.chinese)
        cell.name.text = title
        cell.name.font = .systemFont(ofSize: self.fontSize)
        cell.summary.text = self.summaries[field]
        cell.summary.font = .systemFont(ofSize: self.fontSize * 13 / 17)
        cell.summary.textColor = UIColor(rgb: self.dark ? 0x888888 : 0x777777)
        cell.name.alpha = field.isToggle || self.canOpen(field) ? 1 : 0.45
        cell.summary.alpha = cell.name.alpha
        cell.name.textColor = UIColor(rgb: self.dark ? 0xcfcfcf : 0x191919)
        cell.arrow.tintColor = UIColor(white: self.dark ? 1 : 0, alpha: 0.3)
        cell.toggle.isHidden = !field.isToggle
        cell.arrow.isHidden = field.isToggle
        cell.isAccessibilityElement = !field.isToggle
        cell.accessibilityLabel = title
        cell.accessibilityTraits = self.canOpen(field) || field.isToggle ? .button : [.button, .notEnabled]
        cell.accessibilityValue = self.summaries[field]
        cell.accessibilityIdentifier = "Wegram.Media.\(field.rawValue).Row"
        cell.toggle.accessibilityIdentifier = "Wegram.Media.\(field.rawValue)"
        cell.toggle.accessibilityLabel = title
        cell.toggle.onTitle = self.chinese ? "开启" : "On"
        cell.toggle.offTitle = self.chinese ? "关闭" : "Off"
        cell.toggle.onTintColor = UIColor(rgb: 0x07c160)
        cell.toggle.offTintColor = UIColor(rgb: self.dark ? 0x393939 : 0xdddddd)
        cell.toggle.isOn = self.values?[field] ?? false
        cell.toggle.isEnabled = self.values != nil && !self.busy
        if field.isToggle && self.values == nil { cell.toggle.accessibilityValue = self.chinese ? "正在加载" : "Loading" }
        if field == .calls { cell.toggle.accessibilityHint = self.callScope }
        cell.selectionStyle = self.canOpen(field) ? .default : .none
        cell.toggle.addAction(UIAction(handler: { [weak self, weak toggle = cell.toggle] _ in
            guard let self, !self.busy, self.values != nil, let toggle, toggle.isEnabled else { return }
            self.change?(field, toggle.isOn)
        }), for: .valueChanged)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let field = self.sections[indexPath.section][indexPath.row]
        guard self.canOpen(field) else { return }
        self.open?(field)
    }
}
