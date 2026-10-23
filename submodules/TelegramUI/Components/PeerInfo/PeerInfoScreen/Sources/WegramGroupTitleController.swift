import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit

final class WegramGroupTitleController: ViewController {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private var peer: EnginePeer?
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private let peerDisposable = MetaDisposable()
    private let saveDisposable = MetaDisposable()
    private let content = WegramNameContentView()
    private let titleLabel = UILabel()
    private let cancelButton = ASButtonNode()
    private let activity = UIActivityIndicatorView(style: .medium)

    init(context: AccountContext, peer: EnginePeer, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?) {
        self.context = context
        self.peerId = peer.id
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleLabel.font = wegramNavigationTitleFont
        self.titleLabel.textAlignment = .center
        self.titleLabel.accessibilityTraits = .header
        self.navigationItem.titleView = self.titleLabel
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.content.firstNameField.textContentType = nil
        self.content.firstNameField.accessibilityIdentifier = "Wegram.Group.Title"
        self.content.saveButton.accessibilityIdentifier = "Wegram.Group.SaveTitle"
        self.content.setName(firstName: peer.compactDisplayTitle, lastName: "")
        self.content.allowsEditing = false
        self.content.save = { [weak self] in self?.saveTitle() }
        self.content.saveButton.addSubview(self.activity)
        self.activity.center = CGPoint(x: 32, y: 22)
        self.activity.isUserInteractionEnabled = false
        self.presentationDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData) |> deliverOnMainQueue).start(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.peerDisposable.set((context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id)) |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self else { return }
            let wasEditable = self.content.allowsEditing
            self.peer = peer
            self.updatePresentation()
            if !wasEditable && self.content.firstNameField.isEnabled && self.isNodeLoaded && self.view.window != nil {
                self.content.firstNameField.becomeFirstResponder()
            }
        }))
        self.updatePresentation()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.peerDisposable.dispose()
        self.saveDisposable.dispose()
    }

    private var canEditTitle: Bool {
        guard !self.context.isFrozen, let peer = self.peer, !peer.isScam, !peer.isFake, !peer.isVerified else { return false }
        switch peer {
        case let .legacyGroup(group):
            guard group.membership == .Member, group.migrationReference == nil else { return false }
        case let .channel(channel):
            guard case .group = channel.info, channel.participationStatus == .member, !channel.isForumOrMonoForum, channel.restrictionInfo == nil else { return false }
        default: return false
        }
        return canEditPeerInfo(context: self.context, peer: peer, chatLocation: .peer(id: self.peerId), threadData: nil)
    }

    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        self.titleLabel.text = chinese ? "修改群聊名称" : "Edit Group Name"
        self.titleLabel.textColor = control
        self.cancelButton.setTitle(data.strings.Common_Cancel, with: Font.regular(17), with: control, for: .normal)
        self.cancelButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        self.cancelButton.accessibilityLabel = data.strings.Common_Cancel
        self.cancelButton.isEnabled = !self.content.submitting
        let cancelItem = UIBarButtonItem(customDisplayNode: self.cancelButton)
        cancelItem?.target = self
        cancelItem?.action = #selector(self.cancelPressed)
        cancelItem?.accessibilityLabel = data.strings.Common_Cancel
        cancelItem?.isEnabled = !self.content.submitting
        self.navigationItem.leftBarButtonItem = cancelItem
        self.content.allowsEditing = self.canEditTitle
        self.content.update(isDark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, doneTitle: data.strings.Common_Done, firstNameTitle: data.strings.GroupInfo_GroupNamePlaceholder, lastNameTitle: "")
        self.navigationItem.rightBarButtonItem = self.content.makeSaveItem()
        self.activity.color = control
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        if self.isNodeLoaded { self.displayNode.backgroundColor = self.content.backgroundColor }
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.view.addSubview(self.content)
        self.updatePresentation()
        self.displayNodeDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.content.firstNameField.isEnabled { self.content.firstNameField.becomeFirstResponder() }
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let bottom = layout.insets(options: [.input]).bottom
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top - bottom)))
    }

    private func saveTitle() {
        guard self.isNodeLoaded, self.view.window != nil, (self.navigationController as? NavigationController)?.topViewController === self else { return }
        if self.context.isFrozen {
            self.push(self.context.sharedContext.makeAccountFreezeInfoScreen(context: self.context))
            return
        }
        guard self.canEditTitle, self.content.canSave else { return }
        let title = self.content.firstName
        if self.peer?.compactDisplayTitle == title {
            self.view.endEditing(true)
            self.dismiss()
            return
        }
        self.content.submitting = true
        self.activity.startAnimating()
        self.updatePresentation()
        self.saveDisposable.set((self.context.engine.peers.updatePeerTitle(peerId: self.peerId, title: title) |> deliverOnMainQueue).start(error: { [weak self] _ in
            guard let self else { return }
            self.content.submitting = false
            self.activity.stopAnimating()
            self.updatePresentation()
            guard self.isNodeLoaded, self.view.window != nil, (self.navigationController as? NavigationController)?.topViewController === self else { return }
            self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }, completed: { [weak self] in
            guard let self else { return }
            self.content.submitting = false
            self.activity.stopAnimating()
            self.updatePresentation()
            guard (self.navigationController as? NavigationController)?.topViewController === self else { return }
            self.view.endEditing(true)
            self.dismiss()
        }))
    }

    @objc private func cancelPressed() {
        guard !self.content.submitting else { return }
        self.view.endEditing(true)
        self.dismiss()
    }
}
