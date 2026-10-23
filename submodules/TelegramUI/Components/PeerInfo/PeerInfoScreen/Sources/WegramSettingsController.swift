import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import AccountUtils
import AvatarNode
import TelegramCore
import TelegramPresentationData
import SwiftSignalKit

final class WegramSettingsController: ViewController, UITableViewDataSource, UITableViewDelegate {
    private let context: AccountContext
    private let page: WegramSettingsPage
    private let open: (WegramSettingsDestination) -> Void
    private let switchAccount: (AccountContext) -> Void
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private var peerDisposable: Disposable?
    private var profileBio: String?
    private var profilePeer: EnginePeer?
    private var profileAvatar: AvatarNode?
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let titleLabel = UILabel()
    private let backButton = ASButtonNode()
    private let moreButton = ASButtonNode()

    init(context: AccountContext, page: WegramSettingsPage = .root, open: @escaping (WegramSettingsDestination) -> Void, switchAccount: @escaping (AccountContext) -> Void) {
        self.context = context
        self.page = page
        self.open = open
        self.switchAccount = switchAccount
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleLabel.font = wegramNavigationTitleFont
        self.titleLabel.textAlignment = .center
        self.titleLabel.accessibilityTraits = .header
        self.navigationItem.titleView = self.titleLabel
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.moreButton.addTarget(self, action: #selector(self.morePressed), forControlEvents: .touchUpInside)
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            guard let self else { return }
            self.presentationData = data
            self.updatePresentation()
        })
        if page.isPersonal {
            self.peerDisposable = (combineLatest(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)), context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.AboutText(id: context.account.peerId))) |> deliverOnMainQueue).startStrict(next: { [weak self] peer, about in
                guard let self else { return }
                self.profilePeer = peer
                if case let .known(text) = about { self.profileBio = text ?? "" }
                if self.isNodeLoaded { self.tableView.reloadData() }
            })
        } else if page == .security {
            self.peerDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)) |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                guard let self else { return }
                self.profilePeer = peer
                if self.isNodeLoaded { self.tableView.reloadData() }
            })
        }
        self.updatePresentation()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        self.presentationDisposable?.dispose()
        self.peerDisposable?.dispose()
    }

    private var chinese: Bool { self.presentationData.strings.baseLanguageCode.hasPrefix("zh") }

    private func updatePresentation() {
        let data = self.presentationData
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.titleLabel.text = self.page.title(chinese: self.chinese)
        self.titleLabel.textColor = control
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        let image = wegramNavigationBackArrowImage(color: control)
        self.backButton.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: 0, bottom: (44 - size.height) / 2, right: 44 - size.width)
        self.backButton.accessibilityLabel = data.strings.Common_Back
        let backItem = UIBarButtonItem(customDisplayNode: self.backButton)
        backItem?.accessibilityLabel = data.strings.Common_Back
        backItem?.target = self
        backItem?.action = #selector(self.backPressed)
        self.navigationItem.leftBarButtonItem = backItem
        self.moreButton.setImage(WegramIcon.chatMore.image()?.withTintColor(control, renderingMode: .alwaysOriginal), for: .normal)
        self.moreButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        self.moreButton.accessibilityLabel = self.page.isPersonal ? (self.chinese ? "完整资料" : "Full Profile") : (self.page == .wallpaper ? (self.chinese ? "更多背景设置" : "More Background Settings") : WegramSettingsDestination.advanced.title(chinese: self.chinese))
        let moreItem = UIBarButtonItem(customDisplayNode: self.moreButton)
        moreItem?.accessibilityLabel = self.moreButton.accessibilityLabel
        moreItem?.target = self
        moreItem?.action = #selector(self.morePressed)
        self.navigationItem.rightBarButtonItem = self.page == .security ? nil : moreItem
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: data.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        if self.isNodeLoaded {
            let background = WegramGroupedListColors.background(dark: data.theme.overallDarkAppearance)
            self.displayNode.backgroundColor = background
            self.tableView.backgroundColor = background
            self.tableView.rowHeight = max(56, ceil(data.listsFontSize.itemListBaseFontSize * 56 / 17))
            self.tableView.reloadData()
        }
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.sectionHeaderHeight = 8
        self.tableView.sectionFooterHeight = .leastNormalMagnitude
        self.tableView.separatorStyle = .none
        if #available(iOS 15.0, *) { self.tableView.sectionHeaderTopPadding = 0 }
        self.displayNode.view.addSubview(self.tableView)
        self.updatePresentation()
        self.displayNodeDidLoad()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let bottom = layout.insets(options: [.input]).bottom
        transition.updateFrame(view: self.tableView, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top - bottom)))
    }

    func numberOfSections(in tableView: UITableView) -> Int { self.page.sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.page.sections[section].count }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.page.sections[indexPath.section][indexPath.row] == .profileAvatar {
            return max(64, 64 * self.presentationData.listsFontSize.itemListBaseFontSize / 17) + 24
        }
        return self.tableView.rowHeight
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { section == 0 ? .leastNormalMagnitude : 8 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: "setting") as? WegramSettingsCell) ?? WegramSettingsCell()
        let destination = self.page.sections[indexPath.section][indexPath.row]
        let theme = self.presentationData.theme
        cell.backgroundColor = WegramGroupedListColors.row(dark: theme.overallDarkAppearance)
        cell.separatorLine.backgroundColor = WegramGroupedListColors.separator(dark: theme.overallDarkAppearance)
        cell.sectionPosition = (indexPath.row == 0, indexPath.row == self.page.sections[indexPath.section].count - 1)
        cell.textLabel?.text = destination.title(chinese: self.chinese)
        cell.textLabel?.font = Font.regular(self.presentationData.listsFontSize.itemListBaseFontSize)
        cell.textLabel?.textColor = theme.list.itemPrimaryTextColor
        cell.detailTextLabel?.font = Font.regular(self.presentationData.listsFontSize.itemListBaseFontSize)
        cell.detailTextLabel?.textColor = theme.list.itemSecondaryTextColor
        cell.detailTextLabel?.text = destination == .about ? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String : nil
        cell.avatarLayout = nil
        cell.avatarContent = nil
        cell.valueIcon.image = nil
        if self.page.isPersonal || self.page == .security {
            switch destination {
            case .profileAvatar:
                if self.profileAvatar == nil {
                    let avatar = AvatarNode(font: avatarPlaceholderFont(size: 26))
                    avatar.cornerRadius = 6
                    avatar.clipsToBounds = true
                    avatar.isAccessibilityElement = false
                    self.profileAvatar = avatar
                }
                if let avatar = self.profileAvatar, let peer = self.profilePeer {
                    let diameter = max(64, 64 * self.presentationData.listsFontSize.itemListBaseFontSize / 17)
                    avatar.setPeer(context: self.context, theme: theme, peer: peer, clipStyle: .none, displayDimensions: CGSize(width: diameter, height: diameter))
                    avatar.font = avatarPlaceholderFont(size: diameter * 26 / 64)
                    cell.avatarLayout = { [weak avatar] size in avatar?.updateSize(size: size) }
                    cell.avatarContent = avatar.view
                }
            case .profileName:
                cell.detailTextLabel?.text = self.profilePeer?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)
            case .profileUsername:
                cell.detailTextLabel?.text = self.profilePeer?.addressName.flatMap { $0.isEmpty ? nil : $0 } ?? (self.profilePeer == nil ? nil : (self.chinese ? "未设置" : "Not Set"))
            case .profileQr:
                cell.valueIcon.image = UIImage(systemName: "qrcode")
                cell.valueIcon.tintColor = theme.list.itemSecondaryTextColor
            case .profileBio:
                cell.detailTextLabel?.text = self.profileBio
            case .profilePhone:
                if case let .user(user) = self.profilePeer, let phone = user.phone, !phone.isEmpty {
                    cell.detailTextLabel?.text = phone.hasPrefix("+") ? phone : "+" + phone
                }
            default: break
            }
        }
        cell.centered = destination == .accounts || destination == .logout
        cell.arrow.tintColor = theme.list.disclosureArrowColor
        cell.selectedBackgroundView?.backgroundColor = theme.list.itemHighlightedBackgroundColor
        cell.accessibilityIdentifier = "Wegram.Settings.\(destination)"
        let loadingIdentity = self.page == .security && self.profilePeer == nil && (destination == .profilePhone || destination == .profileUsername)
        cell.isUserInteractionEnabled = !loadingIdentity
        cell.accessibilityTraits = loadingIdentity ? [.button, .notEnabled] : .button
        if loadingIdentity { cell.textLabel?.textColor = theme.list.itemSecondaryTextColor }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let destination = self.page.sections[indexPath.section][indexPath.row]
        if self.page == .security && self.profilePeer == nil && (destination == .profilePhone || destination == .profileUsername) { return }
        switch destination {
        case .security:
            self.push(WegramSettingsController(context: self.context, page: .security, open: self.open, switchAccount: self.switchAccount))
        case .general, .profileMore, .wallpaper:
            self.push(WegramSettingsController(context: self.context, page: destination == .general ? .general : (destination == .wallpaper ? .wallpaper : .personalMore), open: self.open, switchAccount: self.switchAccount))
        case .accounts:
            self.showAccounts()
        default:
            self.open(destination)
        }
    }

    private func showAccounts() {
        self.push(WegramAccountsController(context: self.context, switchAccount: self.switchAccount, addAccount: { [weak self] in
            self?.open(.accounts)
        }, manage: { [weak self] in
            self?.open(.advanced)
        }))
    }

    @objc private func backPressed() { self.dismiss() }
    @objc private func morePressed() { self.open(self.page == .wallpaper ? .wallpaperPresets : .advanced) }
}
