import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import AvatarNode

/// WeChat 8's 发起群聊 (dark references IMG_2467/2468, 402x874pt at 3x): a contact picker with
/// round check circles, square avatars, an A-Z index and a 完成 (n) pill. Choosing one contact opens that chat,
/// choosing several continues into Telegram's group-creation form (a title is mandatory there). WeChat's rows
/// with no Telegram counterpart (选择一个已有的群, 面对面建群, 选择群聊中的朋友, 选择企业微信联系人) are left out.
final class WegramStartChatController: ViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    private struct Section {
        let title: String
        var peers: [EnginePeer]
    }

    private static let green = UIColor(rgb: 0x07c160)
    private static let rowHeight: CGFloat = 192.0 / 3.0
    private static let avatarSize: CGFloat = 40.0
    private static let fieldHeight: CGFloat = 36.0

    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private var contactsDisposable: Disposable?
    private let createDisposable = MetaDisposable()

    private var contacts: [EnginePeer] = []
    private var sections: [Section] = []
    private var selected: [EnginePeer] = []
    private var query = ""

    private let cancelButton = WegramFixedButtonNode(size: CGSize(width: 56.0, height: 44.0))
    private let doneButton = WegramFixedButtonNode(size: CGSize(width: 52.0, height: 32.0))
    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let header = UIView()
    private let field = UIView()
    private let fieldGlyph = UIImageView()
    private let chips = UIScrollView()
    private let textField = UITextField()
    private let indexView = UIView()
    private var indexLabels: [UILabel] = []
    private var validLayout: ContainerViewLayout?

    private var chinese: Bool {
        return self.presentationData.strings.baseLanguageCode.hasPrefix("zh")
    }

    private func text(_ zh: String, _ en: String) -> String {
        return self.chinese ? zh : en
    }

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: WegramStartChatController.navigationBarData(self.presentationData))

        self.titleLabel.font = wegramNavigationTitleFont
        self.titleLabel.textAlignment = .center
        self.titleLabel.accessibilityTraits = .header
        self.navigationItem.titleView = self.titleLabel

        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed))
        if let item = UIBarButtonItem(customDisplayNode: self.cancelButton) {
            item.target = self
            item.action = #selector(self.cancelPressed)
            item.accessibilityLabel = self.presentationData.strings.Common_Cancel
            self.navigationItem.leftBarButtonItem = item
        }
        self.doneButton.addTarget(self, action: #selector(self.donePressed))
        if let item = UIBarButtonItem(customDisplayNode: self.doneButton) {
            item.target = self
            item.action = #selector(self.donePressed)
            self.navigationItem.rightBarButtonItem = item
        }

        self.presentationDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            self.presentationData = presentationData
            self.updatePresentation()
        })
        self.contactsDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Contacts.List(includePresences: false))
        |> deliverOnMainQueue).startStrict(next: { [weak self] list in
            guard let self else {
                return
            }
            self.contacts = list.peers.filter { peer in
                if case let .user(user) = peer {
                    return !user.isDeleted && user.id != self.context.account.peerId && user.botInfo == nil
                }
                return false
            }
            self.rebuildSections()
        })
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDisposable?.dispose()
        self.contactsDisposable?.dispose()
        self.createDisposable.dispose()
    }

    private struct Palette {
        let background: UIColor
        let groupBackground: UIColor
        let field: UIColor
        let separator: UIColor
        let primary: UIColor
        let secondary: UIColor
        let placeholder: UIColor
        let circle: UIColor
        let disabledPill: UIColor

        init(dark: Bool) {
            self.background = UIColor(rgb: dark ? 0x191919 : 0xffffff)
            self.groupBackground = UIColor(rgb: dark ? 0x111111 : 0xededed)
            self.field = UIColor(rgb: dark ? 0x111111 : 0xf3f3f3)
            self.separator = UIColor(white: dark ? 1.0 : 0.0, alpha: 0.1)
            self.primary = UIColor(white: dark ? 1.0 : 0.0, alpha: dark ? 0.8 : 0.9)
            self.secondary = UIColor(white: dark ? 1.0 : 0.0, alpha: 0.5)
            self.placeholder = UIColor(white: dark ? 1.0 : 0.0, alpha: 0.3)
            self.circle = UIColor(white: dark ? 1.0 : 0.0, alpha: dark ? 0.3 : 0.25)
            self.disabledPill = UIColor(white: dark ? 1.0 : 0.0, alpha: dark ? 0.1 : 0.06)
        }
    }

    private static func navigationBarData(_ presentationData: PresentationData) -> NavigationBarPresentationData {
        let palette = Palette(dark: presentationData.theme.overallDarkAppearance)
        return NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: presentationData.theme).withUpdatedBackgroundColor(palette.background).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: presentationData.strings))
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.separatorStyle = .none
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.keyboardDismissMode = .onDrag
        self.tableView.sectionHeaderTopPadding = 0.0
        self.tableView.rowHeight = WegramStartChatController.rowHeight
        self.displayNode.view.addSubview(self.tableView)

        self.field.layer.cornerRadius = 6.0
        self.field.clipsToBounds = true
        self.fieldGlyph.contentMode = .center
        self.field.addSubview(self.fieldGlyph)
        self.chips.showsHorizontalScrollIndicator = false
        self.field.addSubview(self.chips)
        self.textField.returnKeyType = .search
        self.textField.autocorrectionType = .no
        self.textField.autocapitalizationType = .none
        self.textField.tintColor = WegramStartChatController.green
        self.textField.delegate = self
        self.textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
        self.field.addSubview(self.textField)
        self.header.addSubview(self.field)

        self.displayNode.view.addSubview(self.indexView)
        self.indexView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.indexPanned(_:))))
        self.indexView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.indexPanned(_:))))
        self.updatePresentation()
        self.displayNodeDidLoad()
    }

    private func updatePresentation() {
        let data = self.presentationData
        let dark = data.theme.overallDarkAppearance
        let palette = Palette(dark: dark)
        let control = WegramNavigationColors(isDark: dark).control
        let scale = data.listsFontSize.itemListBaseFontSize / 17.0

        self.navigationBar?.updatePresentationData(WegramStartChatController.navigationBarData(data), transition: .immediate)
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        self.titleLabel.text = self.text("发起群聊", "New Group Chat")
        self.titleLabel.textColor = control
        self.titleLabel.sizeToFit()
        self.cancelButton.leftAligned = true
        self.cancelButton.setTitle(NSAttributedString(string: data.strings.Common_Cancel, attributes: [.font: Font.regular(17.0), .foregroundColor: control]))
        self.updateDone()

        guard self.isNodeLoaded else {
            return
        }
        self.displayNode.backgroundColor = palette.background
        self.tableView.backgroundColor = palette.background
        self.field.backgroundColor = palette.field
        self.fieldGlyph.image = WegramStartChatController.magnifier(color: palette.placeholder)
        self.textField.font = Font.regular(17.0 * scale)
        self.textField.textColor = palette.primary
        self.textField.keyboardAppearance = dark ? .dark : .light
        self.textField.attributedPlaceholder = NSAttributedString(string: data.strings.Common_Search, attributes: [.font: Font.regular(17.0 * scale), .foregroundColor: palette.placeholder])
        self.rebuildIndex()
        self.tableView.reloadData()
        self.relayout()
    }

    private func updateDone() {
        let dark = self.presentationData.theme.overallDarkAppearance
        let palette = Palette(dark: dark)
        let count = self.selected.count
        let title = self.text("完成", "Done") + (count > 0 ? " (\(count))" : "")
        self.doneButton.setTitle(NSAttributedString(string: title, attributes: [.font: Font.regular(15.0), .foregroundColor: count > 0 ? UIColor.white : palette.placeholder]))
        self.doneButton.fill = count > 0 ? WegramStartChatController.green : palette.disabledPill
        self.doneButton.radius = 4.0
        self.doneButton.isEnabled = count > 0
        self.doneButton.fixedSize = CGSize(width: count > 0 ? (self.chinese ? 78.0 : 84.0) : 52.0, height: 32.0)
        self.navigationItem.rightBarButtonItem?.accessibilityLabel = title
        self.navigationItem.rightBarButtonItem?.isEnabled = count > 0
    }

    // MARK: - Data

    private func sectionKey(_ peer: EnginePeer) -> String {
        let name = peer.compactDisplayTitle
        let mutable = NSMutableString(string: String(name.prefix(1)))
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        if let first = (mutable as String).uppercased().first, first.isASCII, first.isLetter {
            return String(first)
        }
        return "#"
    }

    private func rebuildSections() {
        let needle = self.query.lowercased()
        var buckets: [String: [EnginePeer]] = [:]
        for peer in self.contacts {
            if !needle.isEmpty, !peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder).lowercased().contains(needle), !(peer.addressName ?? "").lowercased().contains(needle) {
                continue
            }
            buckets[self.sectionKey(peer), default: []].append(peer)
        }
        self.sections = buckets.keys.sorted(by: { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }).map { key in
            Section(title: key, peers: buckets[key]!.sorted(by: { $0.compactDisplayTitle.localizedCaseInsensitiveCompare($1.compactDisplayTitle) == .orderedAscending }))
        }
        if self.isNodeLoaded {
            self.rebuildIndex()
            self.tableView.reloadData()
            self.relayout()
        }
    }

    private func rebuildIndex() {
        for label in self.indexLabels {
            label.removeFromSuperview()
        }
        let palette = Palette(dark: self.presentationData.theme.overallDarkAppearance)
        self.indexLabels = self.sections.map { section in
            let label = UILabel()
            label.text = section.title
            label.font = Font.medium(11.0)
            label.textColor = palette.secondary
            label.textAlignment = .center
            self.indexView.addSubview(label)
            return label
        }
        self.indexView.isHidden = self.sections.isEmpty || !self.query.isEmpty
    }

    // MARK: - Layout

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.validLayout = layout
        self.relayout()
    }

    private func relayout() {
        guard self.isNodeLoaded, let layout = self.validLayout else {
            return
        }
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let width = layout.size.width
        self.tableView.frame = CGRect(x: 0.0, y: top, width: width, height: layout.size.height - top)
        self.tableView.contentInset.bottom = layout.intrinsicInsets.bottom

        // IMG_2467/2468: the box is 36pt tall; with chosen contacts it grows to hold a row of 40pt squares.
        let selecting = !self.selected.isEmpty
        let fieldHeight = selecting ? 56.0 : WegramStartChatController.fieldHeight
        self.header.frame = CGRect(x: 0.0, y: 0.0, width: width, height: fieldHeight + 20.0)
        self.field.frame = CGRect(x: 8.0, y: 4.0, width: width - 16.0, height: fieldHeight)
        self.fieldGlyph.isHidden = selecting
        self.fieldGlyph.frame = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        let chipsWidth = min(CGFloat(self.selected.count) * 52.0 + 8.0, self.field.bounds.width - 100.0)
        if selecting {
            self.chips.frame = CGRect(x: 8.0, y: 8.0, width: chipsWidth, height: 40.0)
            self.chips.contentSize = CGSize(width: CGFloat(self.selected.count) * 52.0, height: 40.0)
            self.textField.frame = CGRect(x: 8.0 + chipsWidth + 4.0, y: 0.0, width: self.field.bounds.width - chipsWidth - 24.0, height: fieldHeight)
        } else {
            self.chips.frame = .zero
            self.fieldGlyph.isHidden = false
            self.fieldGlyph.frame = CGRect(x: 11.0, y: 10.0, width: 16.0, height: 16.0)
            self.textField.frame = CGRect(x: 37.0, y: 0.0, width: self.field.bounds.width - 45.0, height: fieldHeight)
        }
        self.tableView.tableHeaderView = self.header

        let count = max(1, self.indexLabels.count)
        let step: CGFloat = min(12.1, (layout.size.height - top - layout.intrinsicInsets.bottom - 40.0) / CGFloat(count))
        let indexHeight = step * CGFloat(count)
        self.indexView.frame = CGRect(x: width - 24.0 - layout.safeInsets.right, y: top + floor((layout.size.height - top - indexHeight) / 2.0), width: 24.0, height: indexHeight)
        for (i, label) in self.indexLabels.enumerated() {
            label.frame = CGRect(x: 0.0, y: CGFloat(i) * step, width: 20.0, height: step)
        }
        self.updateChips()
    }

    private func updateChips() {
        self.chips.subviews.forEach { $0.removeFromSuperview() }
        let theme = self.presentationData.theme
        for (i, peer) in self.selected.enumerated() {
            let node = AvatarNode(font: avatarPlaceholderFont(size: 16.0))
            node.setPeer(accountPeerId: self.context.account.peerId, postbox: self.context.account.postbox, network: self.context.account.network, contentSettings: self.context.currentContentSettings.with { $0 }, theme: theme, peer: peer, clipStyle: .none, displayDimensions: CGSize(width: 40.0, height: 40.0))
            node.frame = CGRect(x: CGFloat(i) * 52.0, y: 0.0, width: 40.0, height: 40.0)
            node.view.layer.cornerRadius = 4.0
            node.view.clipsToBounds = true
            self.chips.addSubview(node.view)
        }
    }

    private static func magnifier(color: UIColor) -> UIImage? {
        return generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.4)
            context.setLineCap(.round)
            let radius = size.width * 0.36
            let center = CGPoint(x: 0.7 + radius, y: 0.7 + radius)
            context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0))
            context.move(to: CGPoint(x: center.x + radius * 0.7071, y: center.y + radius * 0.7071))
            context.addLine(to: CGPoint(x: size.width - 0.7, y: size.height - 0.7))
            context.strokePath()
        })
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].peers.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36.0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let palette = Palette(dark: self.presentationData.theme.overallDarkAppearance)
        let view = UIView()
        view.backgroundColor = palette.background
        let label = UILabel(frame: CGRect(x: 16.0, y: 0.0, width: 200.0, height: 36.0))
        label.font = Font.regular(14.0 * self.presentationData.listsFontSize.itemListBaseFontSize / 17.0)
        label.textColor = palette.secondary
        label.text = self.sections[section].title
        view.addSubview(label)
        return view
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: "row") as? WegramStartChatCell) ?? WegramStartChatCell()
        let data = self.presentationData
        let palette = Palette(dark: data.theme.overallDarkAppearance)
        let peer = self.sections[indexPath.section].peers[indexPath.row]
        let isSelected = self.selected.contains(where: { $0.id == peer.id })
        cell.backgroundColor = palette.background
        cell.selectedBackgroundView?.backgroundColor = data.theme.list.itemHighlightedBackgroundColor
        cell.name.text = peer.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder)
        cell.name.font = Font.regular(17.0 * data.listsFontSize.itemListBaseFontSize / 17.0)
        cell.name.textColor = palette.primary
        cell.separator.backgroundColor = palette.separator
        cell.setChecked(isSelected, green: WegramStartChatController.green, ring: palette.circle)
        cell.avatar.setPeer(accountPeerId: self.context.account.peerId, postbox: self.context.account.postbox, network: self.context.account.network, contentSettings: self.context.currentContentSettings.with { $0 }, theme: data.theme, peer: peer, clipStyle: .none, displayDimensions: CGSize(width: 40.0, height: 40.0))
        cell.accessibilityLabel = cell.name.text
        cell.accessibilityTraits = isSelected ? [.button, .selected] : .button
        cell.setNeedsLayout()
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let peer = self.sections[indexPath.section].peers[indexPath.row]
        if let index = self.selected.firstIndex(where: { $0.id == peer.id }) {
            self.selected.remove(at: index)
        } else {
            self.selected.append(peer)
        }
        self.updateDone()
        self.relayout()
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    // MARK: - Actions

    @objc private func textChanged() {
        self.query = (self.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.rebuildSections()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    @objc private func indexPanned(_ recognizer: UIGestureRecognizer) {
        guard !self.sections.isEmpty else {
            return
        }
        let y = recognizer.location(in: self.indexView).y
        let index = max(0, min(self.sections.count - 1, Int(y / max(1.0, self.indexView.bounds.height / CGFloat(self.sections.count)))))
        self.tableView.scrollToRow(at: IndexPath(row: 0, section: index), at: .top, animated: false)
    }

    @objc private func cancelPressed() {
        self.dismiss()
    }

    @objc private func donePressed() {
        guard let navigationController = self.navigationController as? NavigationController, !self.selected.isEmpty else {
            return
        }
        if self.selected.count == 1, let peer = self.selected.first {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
            return
        }
        let controller = self.context.sharedContext.makeCreateGroupController(context: self.context, peerIds: self.selected.map { $0.id }, initialTitle: nil, mode: .generic, completion: nil)
        navigationController.pushViewController(controller)
    }
}

/// A bar button whose size does not depend on its title, so the 完成 pill can change width with its count.
private final class WegramShiftedButton: UIButton {
    var titleShift: CGFloat = 0.0 {
        didSet { self.setNeedsLayout() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let label = self.titleLabel {
            label.frame = label.frame.offsetBy(dx: self.titleShift, dy: 0.0)
        }
    }
}

private final class WegramFixedButtonNode: ASDisplayNode {
    var fixedSize: CGSize {
        didSet {
            self.invalidateCalculatedLayout()
        }
    }
    private(set) var button: UIButton?
    private var pending: [(Any, Selector)] = []
    private var title = NSAttributedString()
    var isEnabled = true {
        didSet { self.button?.isEnabled = self.isEnabled }
    }
    var radius: CGFloat = 0.0 {
        didSet { self.button?.layer.cornerRadius = self.radius }
    }
    var fill: UIColor? {
        didSet { self.button?.backgroundColor = self.fill }
    }
    var leftAligned = false

    init(size: CGSize) {
        self.fixedSize = size
        super.init()
        self.setViewBlock({ WegramShiftedButton(type: .custom) })
    }

    override func didLoad() {
        super.didLoad()
        let button = self.view as! UIButton
        self.button = button
        button.contentHorizontalAlignment = self.leftAligned ? .left : .center
        button.setAttributedTitle(self.title, for: .normal)
        button.isEnabled = self.isEnabled
        button.layer.cornerRadius = self.radius
        button.backgroundColor = self.fill
        for (target, action) in self.pending {
            button.addTarget(target, action: action, for: .touchUpInside)
        }
    }

    func addTarget(_ target: Any, action: Selector) {
        self.pending.append((target, action))
        self.button?.addTarget(target, action: action, for: .touchUpInside)
    }

    func setTitle(_ title: NSAttributedString) {
        self.title = title
        self.button?.setAttributedTitle(title, for: .normal)
        (self.button as? WegramShiftedButton)?.titleShift = self.leftAligned ? -11.0 : 0.0
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return self.fixedSize
    }
}

private final class WegramStartChatCell: UITableViewCell {
    let circle = UIImageView()
    let avatar = AvatarNode(font: avatarPlaceholderFont(size: 16.0))
    let name = UILabel()
    let separator = UIView()
    private var green = UIColor.green
    private var ring = UIColor.gray

    init() {
        super.init(style: .default, reuseIdentifier: "row")
        self.selectedBackgroundView = UIView()
        self.contentView.addSubview(self.circle)
        self.avatar.view.layer.cornerRadius = 4.0
        self.avatar.view.clipsToBounds = true
        self.contentView.addSubview(self.avatar.view)
        self.name.numberOfLines = 2
        self.contentView.addSubview(self.name)
        self.addSubview(self.separator)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setChecked(_ checked: Bool, green: UIColor, ring: UIColor) {
        self.circle.image = generateImage(CGSize(width: 24.0, height: 24.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            if checked {
                context.setFillColor(green.cgColor)
                context.fillEllipse(in: CGRect(origin: .zero, size: size))
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(1.6)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.move(to: CGPoint(x: 6.5, y: 12.5))
                context.addLine(to: CGPoint(x: 10.5, y: 16.5))
                context.addLine(to: CGPoint(x: 17.5, y: 8.0))
                context.strokePath()
            } else {
                context.setStrokeColor(ring.cgColor)
                context.setLineWidth(1.0)
                context.strokeEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
            }
        })
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.contentView.bounds.width
        let height = self.contentView.bounds.height
        // IMG_2467 at 3x: a 24pt circle at 16pt, a 40pt square avatar at 56pt, the name from 83pt.
        self.circle.frame = CGRect(x: 16.0, y: floorToScreenPixels((height - 24.0) / 2.0), width: 24.0, height: 24.0)
        self.avatar.frame = CGRect(x: 56.0, y: floorToScreenPixels((height - 40.0) / 2.0), width: 40.0, height: 40.0)
        self.name.frame = CGRect(x: 108.0, y: 0.0, width: max(0.0, width - 108.0 - 40.0), height: height)
        self.separator.frame = CGRect(x: 108.0, y: height - UIScreenPixel, width: max(0.0, width - 108.0), height: UIScreenPixel)
    }
}
