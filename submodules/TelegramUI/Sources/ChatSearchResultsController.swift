import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import SearchBarNode
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import PhotoResources

final class ChatSearchResultsController: ViewController {
    private var controllerNode: ChatSearchResultsControllerNode {
        return self.displayNode as! ChatSearchResultsControllerNode
    }
    
    private let context: AccountContext
    private var presentationData: PresentationData
    private let location: SearchMessagesLocation
    private let searchQuery: String
    private let searchResult: SearchMessagesResult
    private let searchState: SearchMessagesState
        
    private let navigateToMessageIndex: (Int) -> Void
    private let resultsUpdated: (SearchMessagesResult, SearchMessagesState) -> Void
    
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, location: SearchMessagesLocation, searchQuery: String, searchResult: SearchMessagesResult, searchState: SearchMessagesState, navigateToMessageIndex: @escaping (Int) -> Void, resultsUpdated: @escaping (SearchMessagesResult, SearchMessagesState) -> Void) {
        self.context = context
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.location = location
        self.searchQuery = searchQuery
        self.navigateToMessageIndex = navigateToMessageIndex
        self.resultsUpdated = resultsUpdated
        self.searchResult = searchResult
        self.searchState = searchState
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings))
        
        self.navigationPresentation = .modal
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationTheme: presentationData.theme, presentationStrings: presentationData.strings), transition: .immediate)
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = searchQuery
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "___done", style: .done, target: self, action: #selector(donePressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatSearchResultsControllerNode(context: self.context, location: self.location, searchQuery: self.searchQuery, searchResult: self.searchResult, searchState: self.searchState, presentInGlobalOverlay: { [weak self] c in
            self?.presentInGlobalOverlay(c)
        })
        self.controllerNode.resultSelected = { [weak self] messageIndex in
            self?.navigateToMessageIndex(messageIndex)
            self?.dismiss()
        }
        self.controllerNode.resultsUpdated = { [weak self] result, state in
            self?.resultsUpdated(result, state)
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func donePressed() {
        self.dismiss()
    }
}


/// Selects actual Saved Messages and confirms the recipient and optional comment before sending.
final class WegramSavedAttachmentController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let selectMessage: (WegramSavedAttachmentController, EngineMessage, String, WegramSavedAttachmentAction) -> Signal<Bool, NoError>
    private let recipient: EnginePeer
    private weak var confirmation: AlertController?
    private var refreshConfirmation: (() -> Void)?
    private let searchDisposable = MetaDisposable()
    private let pickDisposable = MetaDisposable()
    private var presentationDisposable: Disposable?
    private let searchBar: SearchBarNode
    private let categories = WegramSavedAttachmentCategoriesView()
    private var category = WegramSavedAttachmentCategory.all
    private let loading = UIActivityIndicatorView(style: .medium)
    private let emptyLabel = UILabel()
    private var results: ChatSearchResultsControllerNode?
    private var layout: ContainerViewLayout?
    private var query = ""
    private var generation = 0
    private var closed = false
    private var picking = false
    private(set) var selectionGeneration = 0
    var canAcceptSelection: Bool { !self.closed && self.picking && !self.isBeingDismissed && self.isNodeLoaded && self.view.window != nil }

    init(context: AccountContext, recipient: EnginePeer, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, selectMessage: @escaping (WegramSavedAttachmentController, EngineMessage, String, WegramSavedAttachmentAction) -> Signal<Bool, NoError>) {
        self.context = context
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.selectMessage = selectMessage
        self.recipient = recipient
        let data = self.presentationData
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: data.theme), presentationTheme: data.theme, strings: data.strings, usesWegramAppearance: true, wegramContentBackground: true)
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)))
        self.navigationPresentation = .modal
        self.searchBar.hasCancelButton = false
        self.searchBar.textUpdated = { [weak self] text, _ in self?.search(text) }
        self.presentationDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData) |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self else { return }
            self.presentationData = data
            self.updateAppearance()
        })
        self.updateAppearance()
    }

    required init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        self.searchDisposable.dispose()
        self.pickDisposable.dispose()
        self.presentationDisposable?.dispose()
    }

    override func loadDisplayNode() {
        self.displayNode = ViewControllerTracingNode()
        self.displayNode.addSubnode(self.searchBar)
        self.displayNode.view.addSubview(self.categories)
        self.categories.selectedCategory = { [weak self] category in
            guard let self, !self.closed else { return }
            self.category = category
            self.search(self.query)
        }
        self.displayNode.view.addSubview(self.loading)
        self.displayNode.view.addSubview(self.emptyLabel)
        self.loading.hidesWhenStopped = true
        self.emptyLabel.font = Font.regular(15)
        self.emptyLabel.numberOfLines = 0
        self.emptyLabel.textAlignment = .center
        self.updateAppearance()
        self.search("")
    }

    private func updateAppearance() {
        let data = self.presentationData
        self.title = data.strings.baseLanguageCode.hasPrefix("zh") ? "选择收藏" : "Choose from Favorites"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: data.strings.Common_Cancel, style: .plain, target: self, action: #selector(cancelPressed))
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: data.theme), presentationTheme: data.theme, strings: data.strings)
        guard self.isNodeLoaded else { return }
        self.displayNode.backgroundColor = UIColor(rgb: data.theme.overallDarkAppearance ? 0x202020 : 0xededed)
        self.categories.update(selected: self.category, chinese: data.strings.baseLanguageCode.hasPrefix("zh"), dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.baseDisplaySize)
        let all = self.query.isEmpty && self.category == .all
        self.emptyLabel.text = data.strings.baseLanguageCode.hasPrefix("zh") ? (all ? "暂无收藏" : "没有找到相关收藏") : (all ? "No favorites yet" : "No matching favorites")
        self.emptyLabel.textColor = data.theme.list.itemSecondaryTextColor
        self.results?.updatePresentationData(data)
        self.refreshConfirmation?()
        if let layout = self.layout { self.containerLayoutUpdated(layout, transition: .immediate) }
    }

    private func search(_ query: String) {
        guard !self.closed else { return }
        self.pickDisposable.set(nil)
        self.confirmation?.dismiss()
        self.refreshConfirmation = nil
        self.picking = false
        self.selectionGeneration += 1
        self.query = query
        self.updateAppearance()
        self.generation += 1
        let generation = self.generation
        self.results?.isHidden = true
        self.emptyLabel.isHidden = true
        self.loading.startAnimating()
        let tags = self.category.tags
        let location = SearchMessagesLocation.peer(peerId: self.context.account.peerId, fromId: nil, tags: tags, reactions: nil, threadId: nil, minDate: nil, maxDate: nil)
        let context = self.context
        let signal: Signal<(SearchMessagesResult, SearchMessagesState?), NoError>
        if query.isEmpty {
            signal = wegramSavedAttachmentHistory(context: context, index: nil, tags: tags) |> map { ($0, nil) }
        } else {
            signal = Signal<String, NoError>.single(query)
            |> delay(0.2, queue: .mainQueue())
            |> mapToSignal { query in context.engine.messages.searchMessages(location: location, query: query, state: nil) }
            |> map { ($0.0, Optional($0.1)) }
        }
        self.searchDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] result, state in
            guard let self, !self.closed, self.generation == generation else { return }
            self.loading.stopAnimating()
            self.results?.removeFromSupernode()
            let node = ChatSearchResultsControllerNode(context: context, location: location, searchQuery: query, searchResult: result, searchState: state, pickMessage: { [weak self] message in
                guard let self, self.generation == generation else { return }
                self.pick(message)
            }, presentInGlobalOverlay: { [weak self] controller in self?.presentInGlobalOverlay(controller) })
            self.results = node
            self.displayNode.insertSubnode(node, belowSubnode: self.searchBar)
            self.emptyLabel.isHidden = !result.messages.isEmpty
            self.updateAppearance()
            if let layout = self.layout { self.containerLayoutUpdated(layout, transition: .immediate) }
        }))
    }

    private func pick(_ message: EngineMessage) {
        guard !self.closed, !self.picking, self.view.window != nil, message.id.peerId == self.context.account.peerId else { return }
        self.picking = true
        self.selectionGeneration += 1
        self.searchBar.deactivate(clear: false)
        let generation = self.selectionGeneration
        let content = WegramSavedConfirmationContentNode()
        let avatar = AvatarNode(font: avatarPlaceholderFont(size: 16))
        avatar.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        content.content.avatarHost.addSubview(avatar.view)
        if !message._asMessage().containsSecretMedia {
            let blurred = message.attributes.contains { $0 is MediaSpoilerMessageAttribute }
            for media in message.engineMedia {
                if case let .image(image) = media, let representation = largestRepresentationForPhoto(image), representation.dimensions.width > 0, representation.dimensions.height > 0 {
                    content.content.previewDimensions = representation.dimensions.cgSize
                    content.previewNode.setSignal(chatMessagePhotoThumbnail(account: self.context.account, userLocation: .peer(message.id.peerId), photoReference: .message(message: MessageReference(message._asMessage()), media: image), blurred: blurred))
                    break
                } else if case let .file(file) = media, file.isVideo, !file.isInstantVideo, !file.isSticker, let representation = largestImageRepresentation(file.previewRepresentations), representation.dimensions.width > 0, representation.dimensions.height > 0 {
                    content.content.previewDimensions = representation.dimensions.cgSize
                    content.previewNode.setSignal(chatMessageVideoThumbnail(account: self.context.account, userLocation: .peer(message.id.peerId), fileReference: .message(message: MessageReference(message._asMessage()), media: file), blurred: blurred))
                    break
                }
            }
        }
        var confirmed = false
        let data = self.presentationData
        let theme = AlertControllerTheme(backgroundType: data.theme.overallDarkAppearance ? .dark : .light, backgroundColor: UIColor(rgb: data.theme.overallDarkAppearance ? 0x2c2c2c : 0xffffff), separatorColor: .clear, highlightedItemColor: .clear, primaryColor: data.theme.list.itemPrimaryTextColor, secondaryColor: data.theme.list.itemSecondaryTextColor, accentColor: UIColor(rgb: 0x576b95), contrastColor: .white, destructiveColor: UIColor(rgb: 0xfa5151), disabledColor: data.theme.list.itemDisabledTextColor, controlBorderColor: data.theme.list.itemPlainSeparatorColor, baseFontSize: data.listsFontSize.baseDisplaySize)
        let alert = WegramSavedConfirmationController(theme: theme, contentNode: content)
        self.confirmation = alert
        self.refreshConfirmation = { [weak self, weak content, weak alert] in
            guard let self, let content, let alert else { return }
            let data = self.presentationData
            let formattedDescription = descriptionStringForMessage(contentSettings: self.context.currentContentSettings.with { $0 }, message: message, strings: data.strings, nameDisplayOrder: data.nameDisplayOrder, dateTimeFormat: data.dateTimeFormat, accountPeerId: self.context.account.peerId).0
            let description = wegramSavedAttachmentHasHiddenText(message, preview: formattedDescription) ? (data.strings.baseLanguageCode.hasPrefix("zh") ? "[剧透内容]" : "[Spoiler]") : formattedDescription.string
            content.previewNode.accessibilityLabel = description
            content.content.update(recipient: self.recipient.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder), summary: description, dark: data.theme.overallDarkAppearance, chinese: data.strings.baseLanguageCode.hasPrefix("zh"), fontSize: data.listsFontSize.baseDisplaySize)
            avatar.setPeer(context: self.context, theme: data.theme, peer: self.recipient, clipStyle: .none, displayDimensions: CGSize(width: 40, height: 40))
            alert.theme = AlertControllerTheme(backgroundType: data.theme.overallDarkAppearance ? .dark : .light, backgroundColor: UIColor(rgb: data.theme.overallDarkAppearance ? 0x2c2c2c : 0xffffff), separatorColor: .clear, highlightedItemColor: .clear, primaryColor: data.theme.list.itemPrimaryTextColor, secondaryColor: data.theme.list.itemSecondaryTextColor, accentColor: UIColor(rgb: 0x576b95), contrastColor: .white, destructiveColor: UIColor(rgb: 0xfa5151), disabledColor: data.theme.list.itemDisabledTextColor, controlBorderColor: data.theme.list.itemPlainSeparatorColor, baseFontSize: data.listsFontSize.baseDisplaySize)
            content.requestLayout?(.immediate)
        }
        content.content.cancel = { [weak alert] in alert?.dismissAnimated() }
        let accept: (String, WegramSavedAttachmentAction) -> Void = { [weak self, weak alert] comment, action in
            guard let self, self.canAcceptSelection, self.selectionGeneration == generation else { return }
            confirmed = true
            alert?.dismiss(completion: { [weak self] in
                guard let self, self.canAcceptSelection, self.selectionGeneration == generation else { return }
                self.commitSelection(message, comment: comment, action: action)
            })
        }
        content.content.send = { comment in accept(comment, .send) }
        content.content.options = { comment in accept(comment, .options) }
        alert.willDismiss = { [weak self, weak alert, weak content] in
            content?.content.isUserInteractionEnabled = false
            guard let self, self.confirmation === alert, !confirmed else { return }
            self.picking = false
            self.selectionGeneration += 1
        }
        alert.dismissed = { [weak self, weak alert] _ in
            guard let self, self.confirmation === alert else { return }
            self.confirmation = nil
            self.refreshConfirmation = nil
            if !confirmed { self.picking = false; self.selectionGeneration += 1 }
        }
        self.refreshConfirmation?()
        self.present(alert, in: .window(.root))
    }

    private func commitSelection(_ message: EngineMessage, comment: String, action: WegramSavedAttachmentAction) {
        self.pickDisposable.set((self.selectMessage(self, message, comment, action) |> take(1) |> deliverOnMainQueue).start(next: { [weak self] accepted in
            guard let self, !self.closed else { return }
            if !accepted {
                self.picking = false
                let data = self.presentationData
                self.present(textAlertController(context: self.context, title: nil, text: data.strings.baseLanguageCode.hasPrefix("zh") ? "此收藏暂时无法发送到当前聊天。" : "This favorite cannot be sent to the current chat.", actions: [TextAlertAction(type: .defaultAction, title: data.strings.Common_OK, action: {})]), in: .window(.root))
            }
        }))
    }

    @objc private func cancelPressed() { self.dismiss() }

    override func dismiss(completion: (() -> Void)? = nil) {
        self.closed = true
        self.confirmation?.dismiss()
        self.refreshConfirmation = nil
        self.selectionGeneration += 1
        self.searchDisposable.set(nil)
        self.pickDisposable.set(nil)
        super.dismiss(completion: completion)
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.layout = layout
        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        let categoriesWidth = max(0, layout.size.width - layout.safeInsets.left - layout.safeInsets.right)
        let categoriesHeight = self.categories.preferredHeight(width: categoriesWidth)
        let contentTop = navigationHeight + 60 + categoriesHeight
        self.results?.frame = CGRect(origin: .zero, size: layout.size)
        self.results?.containerLayoutUpdated(layout, navigationBarHeight: contentTop, transition: transition)
        self.searchBar.frame = CGRect(x: 0, y: navigationHeight, width: layout.size.width, height: 52)
        self.searchBar.updateLayout(boundingSize: self.searchBar.bounds.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
        self.categories.frame = CGRect(x: layout.safeInsets.left, y: navigationHeight + 60, width: categoriesWidth, height: categoriesHeight)
        self.loading.center = CGPoint(x: layout.size.width / 2, y: contentTop + 24)
        self.emptyLabel.frame = CGRect(x: layout.safeInsets.left + 24, y: contentTop + 40, width: max(0, layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 48), height: 80)
    }
}

private final class WegramSavedConfirmationController: AlertController {
    override func dismissAnimated() {
        self.willDismiss?()
        super.dismissAnimated()
    }
}
