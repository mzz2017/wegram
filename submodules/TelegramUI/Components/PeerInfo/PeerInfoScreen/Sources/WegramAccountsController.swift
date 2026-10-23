import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import SwiftSignalKit
import TelegramCore
import AccountUtils
import AvatarNode

final class WegramAccountsController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var records: [(AccountContext, EnginePeer, Int32)] = []
    private var currentId: Int64?
    private var loadedAccounts = false
    private var avatars: [Int64: AvatarNode] = [:]
    private let switchAccount: (AccountContext) -> Void
    private let addAccount: () -> Void
    private let manage: () -> Void
    private var presentationDisposable: Disposable?
    private let accountsDisposable = MetaDisposable()
    private let content = WegramAccountsContentView()
    private let titleButton = UIButton(type: .custom)
    private let backButton = ASButtonNode()

    init(context: AccountContext, switchAccount: @escaping (AccountContext) -> Void, addAccount: @escaping () -> Void, manage: @escaping () -> Void) {
        self.switchAccount = switchAccount
        self.addAccount = addAccount
        self.manage = manage
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.Settings.AccountManagement"
        self.titleButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, !self.content.busy else { return }
            self.manage()
        }), for: .touchUpInside)
        let manageNode = ASDisplayNode(viewBlock: { [button = self.titleButton] in button })
        manageNode.style.preferredSize = CGSize(width: 60, height: 44)
        let manageItem = UIBarButtonItem(customDisplayNode: manageNode)
        manageItem?.accessibilityLabel = self.presentationData.strings.baseLanguageCode.hasPrefix("zh") ? "管理账号" : "Manage Accounts"
        self.navigationItem.rightBarButtonItem = manageItem
        self.backButton.style.preferredSize = CGSize(width: 60, height: 44)
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.content.select = { [weak self] id in
            guard let self, !self.content.busy, id != self.currentId,
                let record = self.records.first(where: { $0.0.account.id.int64 == id }) else { return }
            self.content.busy = true
            self.updatePresentation()
            self.switchAccount(record.0)
        }
        self.content.add = { [weak self] in self?.addAccount() }
        self.content.configureAvatar = { [weak self] id, host in
            guard let self, let avatar = self.avatars[id] else { return }
            if avatar.view.superview !== host { host.addSubview(avatar.view) }
            avatar.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
            avatar.updateSize(size: CGSize(width: 44, height: 44))
        }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.accountsDisposable.set((activeAccountsAndPeers(context: context, includePrimary: true) |> deliverOnMainQueue).startStrict(next: { [weak self] primary, records in
            guard let self else { return }
            self.currentId = primary?.0.account.id.int64 ?? self.context.account.id.int64
            self.loadedAccounts = true
            self.records = records
            let ids = Set(records.map { $0.0.account.id.int64 })
            self.avatars = self.avatars.filter { ids.contains($0.key) }
            for (account, _, _) in records where self.avatars[account.account.id.int64] == nil {
                let avatar = AvatarNode(font: avatarPlaceholderFont(size: 18))
                avatar.cornerRadius = 4
                avatar.clipsToBounds = true
                self.avatars[account.account.id.int64] = avatar
            }
            self.updatePresentation()
        }))
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.accountsDisposable.dispose()
    }

    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.titleButton.setTitle(chinese ? "管理" : "Manage", for: .normal)
        self.titleButton.setTitleColor(control, for: .normal)
        self.titleButton.accessibilityHint = chinese ? "打开完整账号设置" : "Open full account settings"
        self.titleButton.isEnabled = !self.content.busy
        self.titleButton.frame = CGRect(x: 0, y: 0, width: 60, height: 44)
        self.navigationItem.rightBarButtonItem?.isEnabled = !self.content.busy
        self.backButton.setTitle(chinese ? "关闭" : "Close", with: Font.regular(17), with: control, for: .normal)
        self.backButton.isUserInteractionEnabled = true
        let backItem = UIBarButtonItem(customDisplayNode: self.backButton)
        backItem?.target = self
        backItem?.action = #selector(self.backPressed)
        backItem?.accessibilityLabel = chinese ? "关闭" : "Close"
        backItem?.isEnabled = true
        self.navigationItem.leftBarButtonItem = backItem
        self.content.update(dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, chinese: chinese)
        for (account, peer, _) in self.records {
            self.avatars[account.account.id.int64]?.setPeer(context: account, theme: data.theme, peer: peer, clipStyle: .none, displayDimensions: CGSize(width: 44, height: 44))
        }
        if self.loadedAccounts {
            self.content.load(rows: self.records.map { WegramAccountRow(id: $0.0.account.id.int64, name: $0.1.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder), unreadCount: $0.2, current: $0.0.account.id.int64 == self.currentId) })
        }
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        if self.isNodeLoaded { self.displayNode.backgroundColor = self.content.backgroundColor }
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.view.addSubview(self.content)
        self.updatePresentation()
        self.displayNodeDidLoad()
    }
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.content.contentInset.bottom = layout.intrinsicInsets.bottom
        self.content.verticalScrollIndicatorInsets.bottom = layout.intrinsicInsets.bottom
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top)))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.content.busy = false
        self.updatePresentation()
    }
    @objc private func backPressed() {
        self.dismiss()
    }
}
