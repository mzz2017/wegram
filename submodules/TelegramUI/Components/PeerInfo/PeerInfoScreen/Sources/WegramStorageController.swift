import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit
import SettingsUI
import StorageUsageScreen

final class WegramStorageController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private let statsDisposable = MetaDisposable()
    private let foregroundDisposable = MetaDisposable()
    private var pageVisible = false
    private let clearDisposable = MetaDisposable()
    private var idleDisposable: Disposable?
    private var generation = 0
    private var summary: WegramStorageSummary?
    private let content = WegramStorageContentView()
    private let titleButton = UIButton(type: .custom)
    private let backButton = ASButtonNode()
    private let moreButton = ASButtonNode()
    private weak var confirmation: ViewController?

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.Storage.MoreSettings"
        self.titleButton.addAction(UIAction(handler: { [weak self] _ in self?.morePressed() }), for: .touchUpInside)
        self.navigationItem.titleView = self.titleButton
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.moreButton.addTarget(self, action: #selector(self.morePressed), forControlEvents: .touchUpInside)
        self.content.clear = { [weak self] in self?.requestClear() }
        self.content.manage = { [weak self] in
            guard let self, !self.content.busy, self.summary != nil else { return }
            self.push(StorageUsageScreen(context: self.context, makeStorageUsageExceptionsScreen: { [context = self.context] category in storageUsageExceptionsScreen(context: context, category: category) }))
        }
        self.attemptNavigation = { [weak self] _ in !(self?.content.busy ?? false) }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.foregroundDisposable.set((context.sharedContext.applicationBindings.applicationInForeground |> deliverOnMainQueue).startStrict(next: { [weak self] foreground in
            guard let self, foreground, self.pageVisible, !self.content.busy else { return }
            self.reloadStats()
        }))
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.statsDisposable.dispose()
        self.foregroundDisposable.dispose()
        self.clearDisposable.dispose()
        self.idleDisposable?.dispose()
    }
    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.titleButton.setTitle(chinese ? "存储空间" : "Storage", for: .normal)
        self.titleButton.setTitleColor(control, for: .normal)
        self.titleButton.accessibilityHint = chinese ? "打开数据用量、自动下载与更多存储设置" : "Open data usage, automatic download and more storage settings"
        self.titleButton.isEnabled = !self.content.busy
        self.titleButton.sizeToFit()
        self.titleButton.bounds.size.height = 44
        let image = wegramNavigationBackArrowImage(color: control)
        self.backButton.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: 0, bottom: (44 - size.height) / 2, right: 44 - size.width)
        self.backButton.isUserInteractionEnabled = !self.content.busy
        let backItem = UIBarButtonItem(customDisplayNode: self.backButton)
        backItem?.target = self
        backItem?.action = #selector(self.backPressed)
        backItem?.accessibilityLabel = data.strings.Common_Back
        backItem?.isEnabled = !self.content.busy
        self.navigationItem.leftBarButtonItem = backItem
        // The visible way to the full Telegram page; the title tap does the same.
        self.moreButton.setImage(WegramIcon.chatMore.image()?.withTintColor(control, renderingMode: .alwaysOriginal), for: .normal)
        self.moreButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        self.moreButton.accessibilityLabel = chinese ? "更多存储设置" : "More Storage Settings"
        self.moreButton.isUserInteractionEnabled = !self.content.busy
        let moreItem = UIBarButtonItem(customDisplayNode: self.moreButton)
        moreItem?.accessibilityLabel = self.moreButton.accessibilityLabel
        moreItem?.target = self
        moreItem?.action = #selector(self.morePressed)
        moreItem?.isEnabled = !self.content.busy
        self.navigationItem.rightBarButtonItem = moreItem
        self.content.formatBytes = { dataSizeString($0, formatting: DataSizeStringFormatting(presentationData: data)) }
        self.content.update(dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, chinese: chinese)
        self.content.load(summary: self.summary)
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
        self.pageVisible = true
        if !self.content.busy { self.reloadStats() }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.pageVisible = false
        if !self.content.busy {
            self.generation += 1
            self.statsDisposable.set(nil)
        }
    }
    private func reloadStats() {
        self.generation += 1
        let generation = self.generation
        self.summary = nil
        self.updatePresentation()
        self.statsDisposable.set((self.context.engine.resources.collectStorageUsageStats() |> take(1) |> deliverOnMainQueue).startStrict(next: { [weak self] stats in
            guard let self, self.generation == generation else { return }
            self.summary = WegramStorageSummary(stats: stats)
            self.updatePresentation()
        }))
    }
    private func requestClear() {
        guard !self.content.busy, let summary = self.summary, summary.cacheBytes > 0, self.confirmation == nil else { return }
        let categories = summary.clearCategories
        let controller = storageUsageClearConfirmationController(context: self.context, clearTitle: self.presentationData.strings.StorageManagement_ClearAll, confirmed: { [weak self] in self?.commitClear(categories: categories) })
        self.confirmation = controller
        self.present(controller, in: .window(.root))
    }
    private func commitClear(categories: [StorageUsageStats.CategoryKey]) {
        guard !self.content.busy, !categories.isEmpty else { return }
        self.generation += 1
        self.statsDisposable.set(nil)
        self.content.busy = true
        self.content.setProgress(nil)
        self.idleDisposable = self.context.sharedContext.applicationBindings.pushIdleTimerExtension()
        self.updatePresentation()
        self.clearDisposable.set((self.context.engine.resources.clearStorage(peerId: nil, categories: categories, includeMessages: [], excludeMessages: []) |> deliverOnMainQueue).startStrict(next: { [weak self] progress in
            self?.content.setProgress(progress)
        }, completed: { [weak self] in
            guard let self else { return }
            self.idleDisposable?.dispose()
            self.idleDisposable = nil
            self.content.busy = false
            // Reload actual sizes; the NoError worker does not prove each file was removed.
            self.reloadStats()
        }))
    }
    @objc private func morePressed() {
        guard !self.content.busy else { return }
        self.push(dataAndStorageController(context: self.context))
    }
    @objc private func backPressed() {
        guard !self.content.busy else { return }
        self.dismiss()
    }
}
