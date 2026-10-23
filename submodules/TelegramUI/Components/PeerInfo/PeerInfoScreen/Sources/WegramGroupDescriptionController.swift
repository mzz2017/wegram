import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit

final class WegramGroupDescriptionController: ViewController {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private var peer: EnginePeer?
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private let peerDisposable = MetaDisposable()
    private let saveDisposable = MetaDisposable()
    private let content = WegramBioContentView()
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
        self.content.textView.textContentType = nil
        self.content.textView.accessibilityIdentifier = "Wegram.Group.Description"
        self.content.saveButton.accessibilityIdentifier = "Wegram.Group.SaveDescription"
        self.content.counterLabel.accessibilityIdentifier = "Wegram.Group.DescriptionRemaining"
        self.content.allowsEditing = false
        self.content.save = { [weak self] in self?.saveDescription() }
        self.content.saveButton.addSubview(self.activity)
        self.activity.center = CGPoint(x: 32, y: 22)
        self.activity.isUserInteractionEnabled = false
        self.presentationDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData) |> deliverOnMainQueue).start(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.peerDisposable.set((context.account.viewTracker.peerView(peer.id, updateData: true) |> deliverOnMainQueue).start(next: { [weak self] view in
            guard let self else { return }
            let wasEditable = self.content.textView.isEditable
            self.peer = view.peers[self.peerId].map(EnginePeer.init)
            if let cached = view.cachedData as? CachedGroupData {
                self.content.setBio(cached.about ?? "")
            } else if let cached = view.cachedData as? CachedChannelData {
                self.content.setBio(cached.about ?? "")
            }
            self.updatePresentation()
            if !wasEditable && self.content.textView.isEditable && self.isNodeLoaded && self.view.window != nil {
                self.content.textView.becomeFirstResponder()
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

    private var canEditDescription: Bool {
        return wegramCanEditGroupDescription(context: self.context, peer: self.peer)
    }

    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        self.titleLabel.text = chinese ? "群介绍" : "Group Description"
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
        self.content.allowsEditing = self.canEditDescription
        self.content.update(isDark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, maximumLength: 255, title: chinese ? "群介绍" : "Group Description", doneTitle: data.strings.Common_Done, remainingTitle: chinese ? "剩余字数" : "Characters remaining")
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
        if self.content.textView.isEditable { self.content.textView.becomeFirstResponder() }
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let bottom = layout.insets(options: [.input]).bottom
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top - bottom)))
    }

    private func saveDescription() {
        guard self.isNodeLoaded, self.view.window != nil, (self.navigationController as? NavigationController)?.topViewController === self else { return }
        if self.context.isFrozen {
            self.push(self.context.sharedContext.makeAccountFreezeInfoScreen(context: self.context))
            return
        }
        guard self.canEditDescription, self.content.canSave else { return }
        let description = self.content.text
        self.content.submitting = true
        self.activity.startAnimating()
        self.updatePresentation()
        self.saveDisposable.set((self.context.engine.peers.updatePeerDescription(peerId: self.peerId, description: description.isEmpty ? nil : description) |> deliverOnMainQueue).start(error: { [weak self] _ in
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

func wegramCanEditGroupDescription(context: AccountContext, peer: EnginePeer?) -> Bool {
    guard !context.isFrozen, let peer, wegramIsOrdinaryJoinedGroup(peer: peer) else { return false }
    return canEditPeerInfo(context: context, peer: peer, chatLocation: .peer(id: peer.id), threadData: nil)
}
