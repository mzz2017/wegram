import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import SwiftSignalKit

final class WegramGroupDescriptionViewer: ViewController {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private var peer: EnginePeer?
    private var text: String?
    private var presentationData: PresentationData
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private let fullDetails: () -> ViewController?
    private let content = WegramGroupDescriptionView()
    private let titleLabel = UILabel()
    private var presentationDisposable: Disposable?
    private let peerDisposable = MetaDisposable()
    private let resolveDisposable = MetaDisposable()
    private var openedFallback = false
    private var hadPeer = false

    init(context: AccountContext, peerId: EnginePeer.Id, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, fullDetails: @escaping () -> ViewController?) {
        self.context = context
        self.peerId = peerId
        self.updatedPresentationData = updatedPresentationData
        self.fullDetails = fullDetails
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleLabel.font = wegramNavigationTitleFont
        self.titleLabel.textAlignment = .center
        self.titleLabel.accessibilityTraits = .header
        self.navigationItem.titleView = self.titleLabel
        self.content.openLink = { [weak self] action, item in
            guard let self, self.isCurrent, wegramIsOrdinaryJoinedGroup(peer: self.peer) else { return }
            self.context.sharedContext.handleTextLinkAction(context: self.context, peerId: self.peerId, navigateDisposable: self.resolveDisposable, controller: self, action: action, itemLink: item)
        }
        self.presentationDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData) |> deliverOnMainQueue).start(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.peerDisposable.set((context.account.viewTracker.peerView(peerId, updateData: true) |> deliverOnMainQueue).start(next: { [weak self] view in
            guard let self else { return }
            self.peer = view.peers[self.peerId].map(EnginePeer.init)
            if self.peer != nil { self.hadPeer = true }
            if let data = view.cachedData as? CachedGroupData { self.text = data.about ?? "" }
            else if let data = view.cachedData as? CachedChannelData { self.text = data.about ?? "" }
            else { self.text = nil }
            self.updatePresentation()
        }))
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.peerDisposable.dispose()
        self.resolveDisposable.dispose()
    }
    private var isCurrent: Bool {
        self.isNodeLoaded && self.view.window != nil && (self.navigationController as? NavigationController)?.topViewController === self
    }
    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.view.addSubview(self.content)
        self.displayNodeDidLoad()
        self.updatePresentation()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updatePresentation()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.resolveDisposable.set(nil)
    }
    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        self.title = chinese ? "群介绍" : "Group Description"
        self.titleLabel.text = self.title
        self.titleLabel.textColor = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        let more = UIBarButtonItem(title: "•••", style: .plain, target: self, action: #selector(self.morePressed))
        more.accessibilityLabel = data.strings.Common_More
        var items = [more]
        if wegramCanEditGroupDescription(context: self.context, peer: self.peer) {
            items.append(UIBarButtonItem(title: data.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed)))
        }
        self.navigationItem.rightBarButtonItems = items
        guard self.isNodeLoaded else { return }
        let invalid = self.hadPeer && !wegramIsOrdinaryJoinedGroup(peer: self.peer)
        self.content.isHidden = invalid
        if invalid {
            self.resolveDisposable.set(nil)
            if self.isCurrent, !self.openedFallback, let controller = self.fullDetails() {
                self.openedFallback = true
                self.replace(with: controller)
            }
            return
        }
        self.content.update(text: self.peer == nil ? nil : self.text, dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, title: self.title ?? "", emptyText: chinese ? "暂无群介绍" : "No group description", openTitle: data.strings.Conversation_LinkDialogOpen, moreTitle: data.strings.Common_More)
        self.displayNode.backgroundColor = self.content.backgroundColor
    }
    @objc private func morePressed() {
        guard self.isCurrent, let controller = self.fullDetails() else { return }
        self.push(controller)
    }
    @objc private func editPressed() {
        guard self.isCurrent else { return }
        if self.context.isFrozen {
            self.push(self.context.sharedContext.makeAccountFreezeInfoScreen(context: self.context))
            return
        }
        guard let peer = self.peer, wegramCanEditGroupDescription(context: self.context, peer: peer) else { return }
        self.push(WegramGroupDescriptionController(context: self.context, peer: peer, updatedPresentationData: self.updatedPresentationData))
    }
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: max(0, layout.size.width - layout.safeInsets.left - layout.safeInsets.right), height: max(0, layout.size.height - top)))
        self.content.textView.contentInset.bottom = max(layout.safeInsets.bottom, layout.intrinsicInsets.bottom)
        self.content.textView.verticalScrollIndicatorInsets.bottom = self.content.textView.contentInset.bottom
    }
}
