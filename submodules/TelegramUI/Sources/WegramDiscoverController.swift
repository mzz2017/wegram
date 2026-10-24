import UIKit
import PhotosUI
import WallpaperGalleryScreen
import Postbox
import TelegramStringFormatting
import PresentationDataUtils
import AlertUI
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import SwiftSignalKit
import QrCodeUI
import CallListUI
import StoryContainerScreen
import AvatarNode
import ContextUI

private final class WegramDiscoverTabBarContextReferenceContentSource: ContextReferenceContentSource {
    let keepInPlace: Bool = true
    private let sourceView: ContextExtractedContentContainingView

    init(sourceView: ContextExtractedContentContainingView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView.contentView, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: .top)
    }
}

private struct WegramMomentItem {
    let peer: EnginePeer
    let content: WegramMomentContent
    let media: EngineMedia?
}
private final class WegramRenderedMomentCell: WegramMomentCell {
    let avatar = AvatarNode(font: avatarPlaceholderFont(size: 16))
    let preview = WegramMomentMediaView(frame: .zero)
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.avatar.cornerRadius = 4
        self.avatar.clipsToBounds = true
        self.avatarHost.addSubview(self.avatar.view)
        self.mediaHost.addSubview(self.preview)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func prepareForReuse() {
        super.prepareForReuse()
        self.preview.reset()
    }
}

/// WeChat's discovery layout, backed by Telegram's stories, search and bot apps.
final class WegramDiscoverController: ViewController, UITableViewDataSource, UITableViewDelegate, PHPickerViewControllerDelegate {
    private let context: AccountContext
    private let showsStories: Bool
    private let storyPostingAvailable: Signal<Bool, NoError>
    private let postStory: (ViewController, UIView?) -> Void
    private var postingDisposable: Disposable?
    private var cameraAvailable = false
    private var subscriptionsLoaded = false
    private let openSearch: (ChatListSearchFilter) -> Void
    private let storyProgressDisposable = MetaDisposable()
    private let liveOpenDisposable = MetaDisposable()
    private var presentationData: PresentationData
    private let titleLabel = UILabel()
    private var backButton: ASButtonNode?
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let momentsHeader = WegramMomentsHeaderView(frame: .zero)
    private let ownAvatar = AvatarNode(font: avatarPlaceholderFont(size: 24))
    private var ownPeer: EnginePeer?
    private let coverStore: WegramMomentsCoverStore
    private var coverLoad: Progress?
    private var coverGeneration = 0
    private var ownPeerDisposable: Disposable?
    private var cameraButton: ASButtonNode?
    private var momentActions: WegramMomentActionsOverlay?
    private var moments: [WegramMomentItem] = []
    private var expandedMomentCaptions = Set<WegramStoryInteractionTarget>()
    private var cachedStories: [EnginePeer.Id: [Stories.StoredItem]] = [:]
    private var expiryTimer: SwiftSignalKit.Timer?
    private var foregroundObservers: [NSObjectProtocol] = []
    private let sizingMomentCell = WegramMomentCell(style: .default, reuseIdentifier: nil)
    private var storyItems: [EngineStorySubscriptions.Item] = []
    private var storiesDisposable: Disposable?
    private var presentationDisposable: Disposable?

    init(context: AccountContext, showsStories: Bool = false, openSearch: @escaping (ChatListSearchFilter) -> Void, storyPostingAvailable: Signal<Bool, NoError>, postStory: @escaping (ViewController, UIView?) -> Void) {
        self.storyPostingAvailable = storyPostingAvailable
        self.postStory = postStory
        self.context = context
        self.coverStore = WegramMomentsCoverStore(accountPath: context.account.basePath)
        self.showsStories = showsStories
        self.openSearch = openSearch
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleLabel.text = showsStories ? "朋友圈" : "发现"
        self.titleLabel.font = wegramNavigationTitleFont
        self.titleLabel.textAlignment = .center
        self.titleLabel.accessibilityTraits = .header
        self.navigationItem.titleView = self.titleLabel
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.tabBarItemContextActionType = .always
        self.tabBarItem.title = "发现"
        self.tabBarItem.image = WegramIcon.discover.image()
        self.tabBarItem.selectedImage = WegramIcon.discover.image(selected: true)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            guard let self else { return }
            self.presentationData = data
            self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
            self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
            self.titleLabel.textColor = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
            self.backButton?.setImage(wegramNavigationBackArrowImage(color: WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control), for: .normal)
            self.updateMomentsHeader()
            self.updateCameraButton()
            self.rebuildMoments()
            if self.isNodeLoaded {
                self.updateColors()
                self.tableView.reloadData()
                self.updateEmptyState()
            }
        })
        if showsStories {
            let back = ASButtonNode()
            self.backButton = back
            let backImage = wegramNavigationBackArrowImage(color: WegramNavigationColors(isDark: self.presentationData.theme.overallDarkAppearance).control)
            back.setImage(backImage, for: .normal)
            let imageSize = backImage?.size ?? .zero
            back.contentEdgeInsets = UIEdgeInsets(top: (44 - imageSize.height) / 2, left: 0, bottom: (44 - imageSize.height) / 2, right: 44 - imageSize.width)
            back.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
            let item = UIBarButtonItem(customDisplayNode: back)
            item?.accessibilityLabel = self.presentationData.strings.Common_Back
            item?.target = self
            item?.action = #selector(self.backPressed)
            self.navigationItem.leftBarButtonItem = item
            let subscriptions = context.engine.messages.storySubscriptions(isHidden: false)
            |> mapToSignal { subscriptions -> Signal<(EngineStorySubscriptions, [EnginePeer.Id: [Stories.StoredItem]]), NoError> in
                var peers = subscriptions.items.map { $0.peer.id }
                if let own = subscriptions.accountItem { peers.append(own.peer.id) }
                let keys = Array(Set(peers)).map { PostboxViewKey.storyItems(peerId: $0) }
                return context.account.postbox.combinedView(keys: keys) |> map { views in
                    var cached: [EnginePeer.Id: [Stories.StoredItem]] = [:]
                    for id in peers {
                        if let view = views.views[PostboxViewKey.storyItems(peerId: id)] as? StoryItemsView {
                            cached[id] = view.items.compactMap { $0.value.get(Stories.StoredItem.self) }
                        }
                    }
                    return (subscriptions, cached)
                }
            }
            self.storiesDisposable = (subscriptions |> deliverOnMainQueue).startStrict(next: { [weak self] subscriptions, cached in
                guard let self else { return }
                self.subscriptionsLoaded = true
                self.cachedStories = cached
                self.storyItems = subscriptions.items
                if let own = subscriptions.accountItem, own.storyCount > 0 || own.hasPending || own.hasLiveItems {
                    self.storyItems.insert(own, at: 0)
                }
                self.rebuildMoments()
            })
            for notification in [UIApplication.didBecomeActiveNotification, UIApplication.significantTimeChangeNotification] {
                self.foregroundObservers.append(NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) { [weak self] _ in self?.rebuildMoments() })
            }
            let camera = ASButtonNode()
            self.cameraButton = camera
            camera.addTarget(self, action: #selector(self.publishStory), forControlEvents: .touchUpInside)
            self.updateCameraButton()
            self.postingDisposable = (storyPostingAvailable |> deliverOnMainQueue).startStrict(next: { [weak self] available in
                self?.cameraAvailable = available
                self?.updateCameraButton()
            })
            self.momentsHeader.cover.image = self.coverStore.load()
            self.momentsHeader.changeCover = { [weak self] in self?.changeMomentsCover() }
            self.momentsHeader.openOwnStories = { [weak self] in self?.openOwnStories() }
            self.ownPeerDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)) |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                self?.ownPeer = peer
                self?.updateMomentsHeader()
            })
        }
        self.scrollToTopWithTabBar = { [weak self] in
            guard let self else { return }
            self.tableView.setContentOffset(CGPoint(x: 0, y: -self.tableView.adjustedContentInset.top), animated: true)
        }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        self.storyProgressDisposable.dispose()
        self.liveOpenDisposable.dispose()
        self.expiryTimer?.invalidate()
        self.foregroundObservers.forEach { NotificationCenter.default.removeObserver($0) }
        self.storiesDisposable?.dispose()
        self.presentationDisposable?.dispose()
        self.ownPeerDisposable?.dispose()
        self.postingDisposable?.dispose()
        self.coverLoad?.cancel()
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.tableView.dataSource = self
        self.tableView.register(WegramRenderedMomentCell.self, forCellReuseIdentifier: "moment")
        self.tableView.delegate = self
        self.tableView.rowHeight = self.showsStories ? max(72, self.presentationData.listsFontSize.itemListBaseFontSize * 72 / 17) : 56
        self.tableView.sectionHeaderHeight = 8
        self.tableView.sectionFooterHeight = .leastNormalMagnitude
        self.tableView.separatorInset = self.showsStories ? .zero : UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 0)
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.showsVerticalScrollIndicator = false
        if #available(iOS 15.0, *) { self.tableView.sectionHeaderTopPadding = 0 }
        if self.showsStories {
            self.tableView.tableHeaderView = self.momentsHeader
            self.ownAvatar.cornerRadius = 6
            self.ownAvatar.clipsToBounds = true
            self.momentsHeader.avatarHost.addSubview(self.ownAvatar.view)
            self.updateMomentsHeader()
        }
        self.displayNode.view.addSubview(self.tableView)
        self.updateColors()
        self.updateEmptyState()
        self.displayNodeDidLoad()
    }

    private func updateColors() {
        // Same grouped-list colours as WegramGroupedListColors (PeerInfoScreen); each section here holds
        // one row, so UIKit's separators would only draw the section edges WeChat does not have.
        let dark = self.presentationData.theme.overallDarkAppearance
        let background = UIColor(rgb: dark ? (self.showsStories ? 0x191919 : 0x111111) : (self.showsStories ? 0xffffff : 0xeeeeee))
        self.displayNode.backgroundColor = background
        self.tableView.backgroundColor = background
        self.tableView.separatorColor = self.presentationData.theme.list.itemPlainSeparatorColor
        self.tableView.separatorStyle = self.showsStories ? .singleLine : .none
    }

    private func updateEmptyState() {
        guard self.showsStories, self.moments.isEmpty else {
            self.tableView.backgroundView = nil
            self.tableView.tableFooterView = nil
            return
        }
        if !self.subscriptionsLoaded {
            let activity = UIActivityIndicatorView(style: .medium)
            activity.frame = CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 80)
            activity.startAnimating()
            self.tableView.tableFooterView = activity
            return
        }
        let label = UILabel()
        label.text = self.presentationData.strings.baseLanguageCode.hasPrefix("zh") ? "朋友的新动态会显示在这里" : "New stories from your friends will appear here"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: self.presentationData.listsFontSize.itemListBaseFontSize * 13 / 17)
        label.textColor = self.presentationData.theme.list.itemSecondaryTextColor
        label.numberOfLines = 0
        let width = self.tableView.bounds.width
        let height = max(80, ceil(label.sizeThatFits(CGSize(width: max(1, width - 32), height: .greatestFiniteMagnitude)).height) + 32)
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        label.frame = CGRect(x: 16, y: 16, width: max(0, width - 32), height: height - 32)
        footer.addSubview(label)
        self.tableView.tableFooterView = footer
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.dismissMomentActions()
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let bottom = layout.insets(options: [.input]).bottom
        transition.updateFrame(view: self.tableView, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top - bottom)))
        self.updateMomentsHeader()
        self.updateEmptyState()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // IMG_2442: 发现's first row starts 1pt (3px) below the bar, unlike other grouped pages (IMG_2446).
        return section == 0 ? (self.showsStories ? .leastNormalMagnitude : 1) : 8
    }

    func numberOfSections(in tableView: UITableView) -> Int { self.showsStories ? 1 : 4 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.showsStories ? self.moments.count : 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.showsStories {
            let cell = tableView.dequeueReusableCell(withIdentifier: "moment", for: indexPath) as! WegramRenderedMomentCell
            let moment = self.moments[indexPath.row]
            self.configureMomentCell(cell, moment: moment)
            cell.avatar.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            cell.avatar.updateSize(size: CGSize(width: 40, height: 40))
            cell.avatar.setPeer(context: self.context, theme: self.presentationData.theme, peer: moment.peer, clipStyle: .none, displayDimensions: CGSize(width: 40, height: 40))
            cell.preview.update(context: self.context, media: moment.media, protected: moment.content.protected)
            cell.openAuthor = { [weak self, weak cell] in
                guard let self, let cell, self.view.window != nil,
                      let currentPath = self.tableView.indexPath(for: cell), self.moments.indices.contains(currentPath.row) else { return false }
                let current = self.moments[currentPath.row]
                guard current.content.peerId == moment.content.peerId, current.content.storyId == moment.content.storyId,
                      current.content.isVisible(at: Int64(Date().timeIntervalSince1970)),
                      current.peer.restrictionText(platform: "ios", contentSettings: self.context.currentContentSettings.with { $0 }) == nil else { return false }
                guard let controller = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: nil, peer: current.peer, mode: current.peer.id == self.context.account.peerId ? .myProfile : .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) else { return false }
                self.dismissMomentActions()
                self.push(controller)
                return true
            }
            cell.toggleCaption = { [weak self, weak cell] in
                guard let self, let cell, let target = moment.content.id,
                      self.view.window != nil, let currentPath = self.tableView.indexPath(for: cell),
                      self.moments.indices.contains(currentPath.row) else { return false }
                let current = self.moments[currentPath.row]
                guard current.content.id == target, !current.content.protected,
                      current.content.isVisible(at: Int64(Date().timeIntervalSince1970)) else { return false }
                self.dismissMomentActions()
                if !self.expandedMomentCaptions.insert(target).inserted { self.expandedMomentCaptions.remove(target) }
                self.configureMomentCell(cell, moment: current)
                UIView.performWithoutAnimation {
                    self.tableView.beginUpdates()
                    self.tableView.endUpdates()
                }
                return true
            }
            cell.moreAction = { [weak self, weak cell] in
                guard let self, let cell else { return }
                self.showMomentActions(target: moment.content, source: cell.more)
            }
            return cell
        }
        let cell = (tableView.dequeueReusableCell(withIdentifier: "row") as? WegramDiscoverCell) ?? WegramDiscoverCell()
        cell.backgroundColor = UIColor(rgb: self.presentationData.theme.overallDarkAppearance ? 0x191919 : 0xffffff)
        let lineColor = self.presentationData.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.1) : UIColor(rgb: 0x000000, alpha: 0.1)
        cell.topLine.backgroundColor = lineColor
        cell.bottomLine.backgroundColor = lineColor
        cell.textLabel?.font = Font.regular(self.presentationData.listsFontSize.itemListBaseFontSize)
        cell.textLabel?.textColor = self.presentationData.theme.list.itemPrimaryTextColor
        cell.detailTextLabel?.textColor = self.presentationData.theme.list.itemSecondaryTextColor
        cell.accessoryType = .none
        cell.arrow.tintColor = self.presentationData.theme.list.disclosureArrowColor
        cell.selectedBackgroundView?.backgroundColor = self.presentationData.theme.list.itemHighlightedBackgroundColor
        let titles = ["朋友圈", "扫一扫", "搜一搜", "小程序"]
        let icons: [WegramIcon] = [.moments, .scan, .search, .miniPrograms]
        // WeChat's own fills for these glyphs (Indigo 1485EE, Red FA5151, Purple 6467F0); IMG_2442's pixels match them once read as P3.
        let colors: [UIColor] = [.clear, UIColor(rgb: 0x1485ee), UIColor(rgb: 0xfa5151), UIColor(rgb: 0x6467f0)]
        cell.textLabel?.text = titles[indexPath.section]
        cell.icon.image = icons[indexPath.section].image()
        cell.icon.tintColor = colors[indexPath.section]
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if self.showsStories {
            guard self.moments.indices.contains(indexPath.row) else { return }
            let moment = self.moments[indexPath.row]
            guard moment.content.isVisible(at: Int64(Date().timeIntervalSince1970)) else { self.rebuildMoments(); return }
            if moment.content.live && moment.content.storyId == nil {
                self.liveOpenDisposable.set((self.context.engine.messages.pollAndGetLiveStory(peerId: moment.peer.id) |> deliverOnMainQueue).startStrict(next: { [weak self] id in
                    guard let self, self.isNodeLoaded, self.view.window != nil else { return }
                    guard self.storyItems.contains(where: { $0.peer.id == moment.peer.id }) else { return }
                    if let id { self.openMoment(moment, focus: id) }
                    else {
                        self.rebuildMoments()
                        self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Story_TooltipExpired, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                }))
            } else { self.openMoment(moment, focus: moment.content.storyId) }
        } else {
            switch indexPath.section {
            case 0:
                self.push(WegramDiscoverController(context: self.context, showsStories: true, openSearch: self.openSearch, storyPostingAvailable: self.storyPostingAvailable, postStory: self.postStory))
            case 1:
                self.push(QrCodeScanScreen(context: self.context, subject: .peer, usesWegramAppearance: true))
            case 2:
                self.openSearch(.chats)
            default:
                self.openSearch(.apps)
            }
        }
    }

    // A context menu like the other tabs' long-press menus: the root NavigationController traps on any
    // UIKit `present(_:animated:)`, so a UIAlertController here crashed the app.
    override func tabBarItemContextAction(sourceView: ContextExtractedContentContainingView, gesture: ContextGesture) {
        guard let rootController = self.context.sharedContext.mainWindow?.viewController as? NavigationController else {
            return
        }
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: "通话", icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Call"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] c, _ in
            c?.dismiss(completion: { [weak self] in
                guard let self else { return }
                rootController.pushViewController(CallListController(context: self.context, mode: .navigation))
            })
        })))
        items.append(.action(ContextMenuActionItem(text: "频道", icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Channels"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] c, _ in
            c?.dismiss(completion: { [weak self] in
                self?.openSearch(.channels)
            })
        })))
        let controller = makeContextController(presentationData: self.presentationData, source: .reference(WegramDiscoverTabBarContextReferenceContentSource(sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
        self.context.sharedContext.mainWindow?.presentInGlobalOverlay(controller)
    }

    private func openMoment(_ moment: WegramMomentItem, focus: Int32?, interaction: WegramStoryInteraction? = nil) {
        StoryContainerScreen.openPeerStoriesCustom(
            context: self.context,
            peerId: moment.peer.id,
            focusOnId: focus,
            isHidden: false,
            initialOrder: self.storyItems.map { $0.peer.id },
            singlePeer: false,
            parentController: self,
            transitionIn: { nil },
            transitionOut: { _ in nil },
            setFocusedItem: { _ in },
            setProgress: { [weak self] signal in
                self?.storyProgressDisposable.set(signal.startStrict())
            }, completion: { screen in
                if let interaction, let focus { screen.requestWegramInteraction(interaction, peerId: moment.peer.id, storyId: focus) }
            }
        )
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.rebuildMoments()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.coverGeneration += 1
        self.coverLoad?.cancel()
        self.coverLoad = nil
        self.liveOpenDisposable.set(nil)
        self.storyProgressDisposable.set(nil)
        self.dismissMomentActions()
        self.expiryTimer?.invalidate()
    }

    private func rebuildMoments() {
        guard self.showsStories else { return }
        self.dismissMomentActions()
        let now = Int64(Date().timeIntervalSince1970)
        let chinese = self.presentationData.strings.baseLanguageCode.hasPrefix("zh")
        var moments: [WegramMomentItem] = []
        var nextExpiry: Int64?
        for subscription in self.storyItems {
            let cached = self.cachedStories[subscription.peer.id] ?? []
            var hasCachedLive = false
            for stored in cached {
                let protected: Bool
                let expired: Bool
                let caption: String
                let reacted: Bool
                let media: EngineMedia?
                switch stored {
                case let .item(item):
                    protected = item.isForwardingDisabled || item.entities.contains(where: { if case .Spoiler = $0.type { return true }; return false })
                    expired = item.isExpired
                    caption = item.text
                    reacted = item.myReaction != nil
                    media = item.media.map(EngineMedia.init)
                case .placeholder:
                    protected = false; expired = false; caption = ""; reacted = false; media = nil
                }
                var ratio: CGFloat?
                var video = false
                var live = false
                if let media {
                    switch media {
                    case let .image(image):
                        if let dimensions = largestImageRepresentation(image.representations)?.dimensions.cgSize, dimensions.height > 0 { ratio = dimensions.width / dimensions.height }
                    case let .file(file):
                        video = file.isVideo
                        if let dimensions = file.dimensions?.cgSize, dimensions.height > 0 { ratio = dimensions.width / dimensions.height }
                    case .liveStream: live = true
                    default: break
                    }
                }
                let status = live ? (chinese ? "正在直播，点按查看" : "Live now. Tap to view") : protected ? (chinese ? "受保护的动态，点按查看" : "Protected story. Tap to view") : ((media == nil || ratio == nil) ? (chinese ? "点按查看动态" : "Tap to view story") : "")
                let content = WegramMomentContent(peerId: subscription.peer.id.toInt64(), storyId: stored.id, timestamp: stored.timestamp, expiration: stored.expirationTimestamp, expired: expired, protected: protected, caption: caption, status: status, aspectRatio: ratio, video: video, live: live, reacted: reacted)
                guard content.isVisible(at: now) else { continue }
                hasCachedLive = hasCachedLive || live
                nextExpiry = min(nextExpiry ?? Int64(stored.expirationTimestamp), Int64(stored.expirationTimestamp))
                moments.append(WegramMomentItem(peer: subscription.peer, content: content, media: protected ? nil : media))
            }
            let needsLive = subscription.hasLiveItems && !hasCachedLive
            if (cached.isEmpty && subscription.storyCount > 0) || subscription.hasPending || needsLive {
                let status: String
                if needsLive { status = chinese ? "正在直播，点按查看" : "Live now. Tap to view" }
                else if subscription.hasPending { status = chinese ? "动态正在发布，点按查看" : "Story upload in progress. Tap to view" }
                else { status = chinese ? "点按加载动态" : "Tap to load stories" }
                let content = WegramMomentContent(peerId: subscription.peer.id.toInt64(), storyId: nil, timestamp: subscription.lastTimestamp, expiration: nil, expired: false, protected: false, caption: "", status: status, aspectRatio: nil, video: false, live: needsLive)
                moments.append(WegramMomentItem(peer: subscription.peer, content: content, media: nil))
            }
        }
        moments.sort { WegramMomentContent.comesBefore($0.content, $1.content) }
        self.expandedMomentCaptions.formIntersection(moments.compactMap { $0.content.protected ? nil : $0.content.id })
        self.moments = moments
        self.expiryTimer?.invalidate()
        let untilExpiry = nextExpiry.map { max(1, Double($0 - now)) } ?? 60
        self.expiryTimer = SwiftSignalKit.Timer(timeout: min(60, untilExpiry), repeat: false, completion: { [weak self] in self?.rebuildMoments() }, queue: .mainQueue())
        if self.isNodeLoaded, self.view.window != nil { self.expiryTimer?.start() }
        if self.isNodeLoaded { self.tableView.reloadData(); self.updateEmptyState() }
    }
    private func configureMomentCell(_ cell: WegramMomentCell, moment: WegramMomentItem) {
        let data = self.presentationData
        let date = moment.content.timestamp > 0 ? stringForStoryActivityTimestamp(strings: data.strings, dateTimeFormat: data.dateTimeFormat, relativeTimestamp: moment.content.timestamp, relativeTo: Int32(clamping: Int64(Date().timeIntervalSince1970)), short: true) : ""
        cell.load(moment.content, name: moment.peer.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder), date: date, dark: data.theme.overallDarkAppearance, font: data.listsFontSize.itemListBaseFontSize, actionsAvailable: self.canInteractWithMoment(moment), moreTitle: data.strings.baseLanguageCode.hasPrefix("zh") ? "更多互动" : "More Interactions", captionExpanded: moment.content.id.map { self.expandedMomentCaptions.contains($0) } ?? false, expandTitle: data.strings.baseLanguageCode.hasPrefix("zh") ? "全文" : "Read more", collapseTitle: data.strings.baseLanguageCode.hasPrefix("zh") ? "收起" : "Collapse", authorTitle: data.strings.baseLanguageCode.hasPrefix("zh") ? "查看作者资料" : "View author profile")
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard self.showsStories else { return 56 }
        guard self.moments.indices.contains(indexPath.row) else { return 72 }
        self.configureMomentCell(self.sizingMomentCell, moment: self.moments[indexPath.row])
        return self.sizingMomentCell.measuredHeight(width: tableView.bounds.width)
    }

    private func canInteractWithMoment(_ moment: WegramMomentItem) -> Bool {
        moment.content.storyId != nil && !moment.content.live && moment.peer.id != self.context.account.peerId && !moment.peer.isService
    }
    private func dismissMomentActions() {
        guard let overlay = self.momentActions else { return }
        self.momentActions = nil
        overlay.select = nil
        overlay.close = nil
        overlay.removeFromSuperview()
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
    private func showMomentActions(target: WegramMomentContent, source: UIView) {
        self.dismissMomentActions()
        guard let moment = self.moments.first(where: { $0.content.peerId == target.peerId && $0.content.storyId == target.storyId }), self.canInteractWithMoment(moment), moment.content.isVisible(at: Int64(Date().timeIntervalSince1970)), source.window != nil else { return }
        let overlay = WegramMomentActionsOverlay(frame: self.displayNode.bounds)
        let canReply: Bool
        if case .user = moment.peer { canReply = true } else { canReply = false }
        overlay.load(anchor: source.convert(source.bounds, to: self.displayNode.view), reacted: moment.content.reacted, canReply: canReply, chinese: self.presentationData.strings.baseLanguageCode.hasPrefix("zh"), font: self.presentationData.listsFontSize.itemListBaseFontSize)
        overlay.close = { [weak self] in self?.dismissMomentActions() }
        overlay.select = { [weak self] action in
            guard let self else { return }
            self.dismissMomentActions()
            guard let current = self.moments.first(where: { $0.content.peerId == target.peerId && $0.content.storyId == target.storyId }), self.canInteractWithMoment(current), current.content.isVisible(at: Int64(Date().timeIntervalSince1970)), let id = current.content.storyId else { return }
            self.openMoment(current, focus: id, interaction: action)
        }
        self.displayNode.view.addSubview(overlay)
        self.momentActions = overlay
        overlay.layoutIfNeeded()
        UIAccessibility.post(notification: .screenChanged, argument: overlay.reaction)
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { self.dismissMomentActions() }

    private func updateMomentsHeader() {
        guard self.showsStories else { return }
        let data = self.presentationData
        self.momentsHeader.update(name: self.ownPeer?.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder), dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, chinese: data.strings.baseLanguageCode.hasPrefix("zh"))
        self.ownAvatar.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        self.ownAvatar.updateSize(size: CGSize(width: 64, height: 64))
        if let peer = self.ownPeer { self.ownAvatar.setPeer(context: self.context, theme: data.theme, peer: peer, clipStyle: .none, displayDimensions: CGSize(width: 64, height: 64)) }
        if self.isNodeLoaded {
            let width = self.tableView.bounds.width
            self.momentsHeader.frame = CGRect(x: 0, y: 0, width: width, height: self.momentsHeader.measuredHeight(width: width))
            self.tableView.tableHeaderView = self.momentsHeader
            self.tableView.rowHeight = max(72, data.listsFontSize.itemListBaseFontSize * 72 / 17)
        }
    }
    private func changeMomentsCover() {
        guard self.showsStories, self.ownPeer != nil, self.viewIfLoaded?.window != nil,
              self.navigationController?.topViewController === self, self.coverLoad == nil else { return }
        self.dismissMomentActions()
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let sheet = ActionSheetController(presentationData: data)
        var items: [ActionSheetItem] = [
            ActionSheetTextItem(title: chinese ? "封面仅保存在本机当前账号" : "Cover is saved only for this account on this device"),
            ActionSheetButtonItem(title: chinese ? "从手机相册选择" : "Choose from Photos", color: .accent, action: { [weak self, weak sheet] in
                sheet?.dismissAnimated()
                guard let self, self.viewIfLoaded?.window != nil, self.navigationController?.topViewController === self,
                      self.view.window?.rootViewController?.presentedViewController == nil else { return }
                self.coverGeneration += 1
                var configuration = PHPickerConfiguration()
                configuration.filter = .images
                configuration.selectionLimit = 1
                let picker = PHPickerViewController(configuration: configuration)
                picker.delegate = self
                self.present(picker, animated: true)
            })
        ]
        if self.momentsHeader.cover.image != nil {
            items.append(ActionSheetButtonItem(title: chinese ? "恢复默认封面" : "Reset Cover", color: .accent, action: { [weak self, weak sheet] in
                sheet?.dismissAnimated()
                guard let self, self.viewIfLoaded?.window != nil, self.navigationController?.topViewController === self else { return }
                do {
                    try self.coverStore.reset()
                    self.momentsHeader.cover.image = nil
                } catch { self.coverError() }
            }))
        }
        sheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: data.strings.Common_Cancel, color: .accent, action: { [weak sheet] in sheet?.dismissAnimated() })])
        ])
        self.present(sheet, in: .window(.root))
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: { [weak self] in
            guard let self, self.viewIfLoaded?.window != nil, self.navigationController?.topViewController === self,
                  let result = results.first else { return }
            self.coverGeneration += 1
            let generation = self.coverGeneration
            guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { self.coverError(); return }
            self.coverLoad = result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                Queue.mainQueue().async { [weak self] in
                    guard let self, self.coverGeneration == generation else { return }
                    self.coverLoad = nil
                    guard self.viewIfLoaded?.window != nil, self.navigationController?.topViewController === self else { return }
                    guard let image = object as? UIImage, image.size.width > 0, image.size.height > 0 else { self.coverError(); return }
                    let data = self.presentationData
                    let crop = WegramWallpaperCropController(image: image, presentationData: data, aspectRatio: CGSize(width: 4, height: 3), title: data.strings.baseLanguageCode.hasPrefix("zh") ? "调整封面" : "Adjust Cover")
                    crop.completion = { [weak self, weak crop] prepared, bytes in
                        guard let self, let crop, let navigation = self.navigationController as? NavigationController,
                              navigation.viewControllers.contains(where: { $0 === self }), navigation.topViewController === crop,
                              crop.viewIfLoaded?.window != nil else { return }
                        do {
                            try self.coverStore.save(bytes)
                            self.momentsHeader.cover.image = prepared
                            crop.dismiss()
                        } catch {
                            crop.dismiss()
                            self.coverError()
                        }
                    }
                    self.push(crop)
                }
            }
        })
    }

    private func coverError() {
        let data = self.presentationData
        self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: data), title: nil, text: data.strings.baseLanguageCode.hasPrefix("zh") ? "无法更新封面，请重试" : "Unable to update the cover. Please try again.", actions: [TextAlertAction(type: .defaultAction, title: data.strings.Common_OK, action: {})]), in: .window(.root))
    }

    private func updateCameraButton() {
        guard let camera = self.cameraButton else { return }
        guard self.cameraAvailable else { self.navigationItem.rightBarButtonItem = nil; return }
        let color = WegramNavigationColors(isDark: self.presentationData.theme.overallDarkAppearance).control
        let image = UIImage(systemName: "camera.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))?.withTintColor(color, renderingMode: .alwaysOriginal)
        camera.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        camera.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: (44 - size.width) / 2, bottom: (44 - size.height) / 2, right: (44 - size.width) / 2)
        let item = UIBarButtonItem(customDisplayNode: camera)
        item?.accessibilityLabel = self.presentationData.strings.baseLanguageCode.hasPrefix("zh") ? "发布动态" : "Post a Story"
        item?.target = self
        item?.action = #selector(self.publishStory)
        self.navigationItem.rightBarButtonItem = item
    }
    @objc private func publishStory() {
        guard self.cameraAvailable else { return }
        self.postStory(self, self.cameraButton?.view)
    }

    @objc private func backPressed() { self.dismiss() }

    @objc private func openOwnStories() {
        self.push(self.context.sharedContext.makeMyStoriesController(context: self.context, isArchive: false))
    }
}

private final class WegramDiscoverCell: UITableViewCell {
    let icon = UIImageView()
    let arrow = UIImageView(image: wegramDisclosureArrowImage)
    // Each section holds one row, so the row carries both full-width section lines (IMG_2442).
    let topLine = UIView()
    let bottomLine = UIView()
    init() {
        super.init(style: .default, reuseIdentifier: "row")
        self.selectedBackgroundView = UIView()
        self.addSubview(self.topLine)
        self.addSubview(self.bottomLine)
        self.icon.contentMode = .scaleAspectFit
        self.contentView.addSubview(self.arrow)
        self.contentView.addSubview(self.icon)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.contentView.bounds.width
        let height = self.contentView.bounds.height
        self.arrow.frame = wegramDisclosureArrowFrame(trailingEdge: width, centerY: height / 2)
        self.icon.frame = CGRect(x: 16, y: (height - 24) / 2, width: 24, height: 24)
        if let label = self.textLabel {
            label.frame = CGRect(x: 56, y: (height - label.frame.height) / 2, width: max(0, width - 96), height: label.frame.height)
        }
        let hairline = 1.0 / max(1.0, self.traitCollection.displayScale)
        self.topLine.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: hairline)
        self.bottomLine.frame = CGRect(x: 0, y: self.bounds.height - hairline, width: self.bounds.width, height: hairline)
        self.bringSubviewToFront(self.topLine)
        self.bringSubviewToFront(self.bottomLine)
    }
}
