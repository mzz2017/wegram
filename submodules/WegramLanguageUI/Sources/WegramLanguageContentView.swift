import UIKit
import AsyncDisplayKit
import Display
import TelegramCore

public struct WegramLanguageDraft {
    public private(set) var languages: [LocalizationInfo] = []
    public private(set) var activeCode: String?
    public private(set) var selectedCode: String?
    private var userSelected = false

    mutating func update(official: [LocalizationInfo], saved: [LocalizationInfo], activeCode: String) {
        var seen = Set<String>()
        self.languages = (official + saved).filter { !$0.languageCode.isEmpty && seen.insert($0.languageCode).inserted }
        self.activeCode = activeCode
        if !self.userSelected { self.selectedCode = activeCode }
    }

    mutating func select(code: String) {
        guard self.languages.contains(where: { $0.languageCode == code }) else { return }
        self.selectedCode = code
        self.userSelected = true
    }

    var selected: LocalizationInfo? { self.languages.first { $0.languageCode == self.selectedCode } }
}

final class WegramLanguageCell: UITableViewCell {
    let name = UILabel()
    let check = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        self.contentView.addSubview(self.name)
        self.contentView.addSubview(self.check)
        self.name.numberOfLines = 0
        self.check.contentMode = .center
        self.check.tintColor = UIColor(red: 60 / 255, green: 130 / 255, blue: 217 / 255, alpha: 1)
        self.check.isAccessibilityElement = false
        self.isAccessibilityElement = true
        self.selectedBackgroundView = UIView()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.name.frame = CGRect(x: 20, y: 8, width: max(0, self.contentView.bounds.width - 80), height: max(0, self.contentView.bounds.height - 16))
        self.check.frame = CGRect(x: self.contentView.bounds.width - 52, y: (self.contentView.bounds.height - 28) / 2, width: 28, height: 28)
    }
}

public final class WegramLanguageContentView: UIView, UITableViewDataSource, UITableViewDelegate {
    public let table = UITableView(frame: .zero, style: .plain)
    public let saveButton = WegramNameSaveButton()
    public let activity = UIActivityIndicatorView(style: .medium)
    public private(set) var draft = WegramLanguageDraft()
    private var fontSize: CGFloat = 17
    private var dark = false
    private var saveItem: UIBarButtonItem?
    private lazy var saveNode: ASDisplayNode = {
        let node = ASDisplayNode(viewBlock: { [button = self.saveButton] in button })
        node.style.preferredSize = CGSize(width: 64, height: 44)
        return node
    }()
    public var save: ((LocalizationInfo) -> Void)?
    /// The visible way to the full language list (search, translation, language packs); the title tap does the same.
    public var openMore: (() -> Void)?
    public var moreTitle = "" { didSet { self.table.reloadData() } }
    public var submitting = false { didSet { self.updateState() } }
    public var canSave: Bool { !self.submitting && self.draft.activeCode != nil && self.draft.selected != nil }

    public init() {
        super.init(frame: .zero)
        self.table.dataSource = self
        self.table.delegate = self
        self.table.register(WegramLanguageCell.self, forCellReuseIdentifier: "language")
        self.table.contentInsetAdjustmentBehavior = .never
        self.table.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        self.table.sectionHeaderTopPadding = 0
        self.table.tableFooterView = UIView()
        self.addSubview(self.table)
        self.addSubview(self.activity)
        self.saveButton.accessibilityIdentifier = "Wegram.Settings.SaveLanguage"
        self.saveButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.canSave, let info = self.draft.selected else { return }
            self.save?(info)
        }), for: .touchUpInside)
        self.updateState()
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func load(official: [LocalizationInfo], saved: [LocalizationInfo], activeCode: String) {
        self.draft.update(official: official, saved: saved, activeCode: activeCode)
        self.table.reloadData()
        self.updateState()
    }

    public func update(dark: Bool, fontSize: CGFloat, doneTitle: String, loadingTitle: String) {
        self.dark = dark
        self.fontSize = fontSize
        self.backgroundColor = UIColor(white: dark ? 0.1 : 1, alpha: 1)
        self.table.backgroundColor = self.backgroundColor
        self.table.separatorColor = UIColor(white: dark ? 0.2 : 0.9, alpha: 1)
        self.activity.color = dark ? .lightGray : .gray
        self.activity.accessibilityLabel = loadingTitle
        self.saveButton.setTitle(doneTitle, for: .normal)
        self.saveButton.accessibilityLabel = doneTitle
        self.saveItem?.accessibilityLabel = doneTitle
        self.table.reloadData()
        self.setNeedsLayout()
    }

    public func makeSaveItem() -> UIBarButtonItem? {
        let item = UIBarButtonItem(customDisplayNode: self.saveNode)
        item?.accessibilityLabel = self.saveButton.accessibilityLabel
        item?.isEnabled = self.canSave
        self.saveItem = item
        return item
    }

    private func updateState() {
        self.saveButton.isEnabled = self.canSave
        self.saveItem?.isEnabled = self.canSave
        self.table.isUserInteractionEnabled = !self.submitting
        if self.draft.languages.isEmpty || self.submitting { self.activity.startAnimating() } else { self.activity.stopAnimating() }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.table.frame = self.bounds
        self.activity.center = CGPoint(x: self.bounds.midX, y: self.submitting ? 32 : self.bounds.midY)
    }
    public func numberOfSections(in tableView: UITableView) -> Int { self.openMore == nil || self.draft.languages.isEmpty ? 1 : 2 }
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? self.draft.languages.count : 1 }
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { section == 0 ? 0 : 8 }
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section > 0 else { return nil }
        let view = UIView()
        view.backgroundColor = UIColor(white: self.dark ? 0.06 : 0.93, alpha: 1)
        return view
    }
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.section == 0 else { return 56 }
        let name = self.draft.languages[indexPath.row].localizedTitle
        let text = name.isEmpty ? self.draft.languages[indexPath.row].title : name
        let size = (text as NSString).boundingRect(with: CGSize(width: max(1, self.bounds.width - 80), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: self.fontSize)], context: nil).size
        return max(56, ceil(size.height) + 24)
    }
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "language", for: indexPath) as! WegramLanguageCell
        cell.backgroundColor = self.backgroundColor
        cell.selectedBackgroundView?.backgroundColor = UIColor(white: self.dark ? 0.2 : 0.95, alpha: 1)
        cell.name.font = .systemFont(ofSize: self.fontSize)
        cell.name.textColor = UIColor(white: self.dark ? 0.82 : 0.1, alpha: 1)
        guard indexPath.section == 0 else {
            cell.name.text = self.moreTitle
            cell.check.isHidden = true
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityLabel = self.moreTitle
            cell.accessibilityIdentifier = "Wegram.Language.More"
            cell.accessibilityTraits = .button
            return cell
        }
        cell.accessoryType = .none
        let info = self.draft.languages[indexPath.row]
        let selected = info.languageCode == self.draft.selectedCode
        let text = info.localizedTitle.isEmpty ? info.title : info.localizedTitle
        cell.name.text = text
        cell.check.isHidden = !selected
        cell.accessibilityLabel = text
        cell.accessibilityIdentifier = "Wegram.Language." + info.languageCode
        cell.accessibilityTraits = selected ? [.button, .selected] : .button
        return cell
    }
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !self.submitting else { return }
        guard indexPath.section == 0 else {
            self.openMore?()
            return
        }
        guard self.draft.languages.indices.contains(indexPath.row) else { return }
        self.draft.select(code: self.draft.languages[indexPath.row].languageCode)
        self.table.reloadData()
        self.updateState()
    }
}
