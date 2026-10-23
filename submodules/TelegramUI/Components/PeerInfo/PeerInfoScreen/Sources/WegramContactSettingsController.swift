import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData

/// WeChat's contact 设置 page (IMG_2446), opened from ••• on the contact profile. Each row runs Telegram's own
/// flow. WeChat's 设置权限 and 设为星标朋友 have no Telegram counterpart and are left out rather than shown dead.
/// 置顶消息 replaces the ••• menu that used to carry the chat's hidden pinned messages, so it shows only when the
/// profile was opened from a chat that has them. 发起秘密聊天 is Telegram's secret chat, otherwise four steps deep
/// (full profile → More), shown under the same conditions as Telegram's menu item.
final class WegramContactSettingsController: ViewController, UITableViewDataSource, UITableViewDelegate {
    enum Row: Equatable {
        case editRemark
        case share
        case pinned(String)
        case secretChat(String)
        case block
        case report
        case delete
    }
    struct Actions {
        let editRemark: () -> Void
        let share: (() -> Void)?
        let pinned: (title: String, open: () -> Void)?
        let secretChat: (() -> Void)?
        let setBlocked: (Bool) -> Void
        let report: () -> Void
        let delete: () -> Void
    }

    private let presentationData: PresentationData
    private let actions: Actions
    private let table = UITableView(frame: .zero, style: .grouped)
    // WeChat's classic 51x31 switch; iOS 26's UISwitch is wider and glass.
    private let blockSwitch = WegramAppearanceSwitch()
    private let backButton = ASButtonNode()
    private var sections: [[Row]] = []
    private var isBlocked = false
    private var blockedDisposable: Disposable?

    init(presentationData: PresentationData, isBlocked: Signal<Bool, NoError>, actions: Actions) {
        self.presentationData = presentationData
        self.actions = actions
        let dark = presentationData.theme.overallDarkAppearance
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: presentationData.theme).withUpdatedBackgroundColor(WegramGroupedListColors.background(dark: dark)).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        self.title = self.chinese ? "设置" : "Settings"
        self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
        // IMG_2446: a bare chevron, as on WeGram's other pushed pages (WegramAboutController).
        let image = wegramNavigationBackArrowImage(color: WegramNavigationColors(isDark: dark).control)
        self.backButton.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: 0, bottom: (44 - size.height) / 2, right: 44 - size.width)
        self.backButton.accessibilityLabel = presentationData.strings.Common_Back
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        let backItem = UIBarButtonItem(customDisplayNode: self.backButton)
        backItem?.accessibilityLabel = presentationData.strings.Common_Back
        backItem?.target = self
        backItem?.action = #selector(self.backPressed)
        self.navigationItem.leftBarButtonItem = backItem
        var sections: [[Row]] = [[.editRemark]]
        if actions.share != nil { sections.append([.share]) }
        if let pinned = actions.pinned { sections.append([.pinned(pinned.title)]) }
        if actions.secretChat != nil { sections.append([.secretChat(presentationData.strings.UserInfo_StartSecretChat)]) }
        sections += [[.block], [.report], [.delete]]
        self.sections = sections
        self.blockSwitch.onTintColor = UIColor(rgb: 0x07c160)
        self.blockSwitch.offTintColor = UIColor(white: dark ? 0.22 : 0.9, alpha: 1)
        self.blockSwitch.onTitle = self.chinese ? "已开启" : "On"
        self.blockSwitch.offTitle = self.chinese ? "已关闭" : "Off"
        self.blockSwitch.accessibilityLabel = self.chinese ? "加入黑名单" : "Block"
        self.blockSwitch.addAction(UIAction(handler: { [weak self] _ in
            guard let self else { return }
            let wanted = self.blockSwitch.isOn
            // The switch shows the account's real state; Telegram's confirmation decides whether it changes.
            self.blockSwitch.isOn = self.isBlocked
            self.actions.setBlocked(wanted)
        }), for: .valueChanged)
        self.blockedDisposable = (isBlocked |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            guard let self else { return }
            self.isBlocked = value
            self.blockSwitch.isOn = value
        })
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func backPressed() { self.dismiss() }
    deinit { self.blockedDisposable?.dispose() }

    private var chinese: Bool { self.presentationData.strings.baseLanguageCode.hasPrefix("zh") }
    private var dark: Bool { self.presentationData.theme.overallDarkAppearance }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = WegramGroupedListColors.background(dark: self.dark)
        self.table.backgroundColor = WegramGroupedListColors.background(dark: self.dark)
        self.table.separatorStyle = .none
        self.table.dataSource = self
        self.table.delegate = self
        self.table.contentInsetAdjustmentBehavior = .never
        self.table.sectionHeaderTopPadding = 0
        self.table.sectionFooterHeight = .leastNormalMagnitude
        // A grouped table otherwise reserves a 35pt header above the first section.
        self.table.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        self.table.cellLayoutMarginsFollowReadableWidth = false
        self.displayNode.view.addSubview(self.table)
        self.displayNodeDidLoad()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.table.contentInset.bottom = layout.intrinsicInsets.bottom
        transition.updateFrame(view: self.table, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top)))
    }

    private func title(_ row: Row) -> String {
        switch row {
        case .editRemark: return self.chinese ? "编辑备注" : "Edit Remark"
        case .share: return self.chinese ? "推荐给朋友" : "Recommend to Friends"
        case let .pinned(title): return title
        case let .secretChat(title): return title
        case .block: return self.chinese ? "加入黑名单" : "Block"
        case .report: return self.chinese ? "投诉" : "Report"
        case .delete: return self.chinese ? "删除联系人" : "Delete Contact"
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int { self.sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.sections[section].count }
    // IMG_2446: rows sit directly under the bar, then 8pt gaps.
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { section == 0 ? .leastNormalMagnitude : 8 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { .leastNormalMagnitude }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { UIView() }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 56 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = self.sections[indexPath.section][indexPath.row]
        let cell = WegramSettingsCell()
        cell.backgroundColor = WegramGroupedListColors.row(dark: self.dark)
        cell.separatorLine.backgroundColor = WegramGroupedListColors.separator(dark: self.dark)
        cell.sectionPosition = (indexPath.row == 0, indexPath.row == self.sections[indexPath.section].count - 1)
        cell.textLabel?.text = self.title(row)
        cell.textLabel?.font = .systemFont(ofSize: self.presentationData.listsFontSize.itemListBaseFontSize)
        cell.textLabel?.textColor = UIColor(white: self.dark ? 1 : 0, alpha: self.dark ? 0.8 : 0.9)
        cell.arrow.tintColor = UIColor(white: self.dark ? 1 : 0, alpha: 0.3)
        cell.selectedBackgroundView?.backgroundColor = UIColor(white: self.dark ? 1 : 0, alpha: 0.05)
        cell.accessibilityTraits = .button
        switch row {
        case .block:
            cell.accessoryView = self.blockSwitch
            cell.selectionStyle = .none
            cell.accessibilityTraits = []
        case .delete:
            cell.centered = true
            cell.textLabel?.textColor = UIColor(rgb: 0xfa5151)
        default:
            break
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch self.sections[indexPath.section][indexPath.row] {
        case .editRemark: self.actions.editRemark()
        case .share: self.actions.share?()
        case .pinned: self.actions.pinned?.open()
        case .secretChat: self.actions.secretChat?()
        case .block: break
        case .report: self.actions.report()
        case .delete: self.actions.delete()
        }
    }
}
