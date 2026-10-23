import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit

final class WegramNameController: ViewController {
    private let context: AccountContext
    private let canEdit: () -> Bool
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private let peerDisposable = MetaDisposable()
    private let saveDisposable = MetaDisposable()
    private let content = WegramNameContentView()
    private let titleLabel = UILabel()
    private let cancelButton = ASButtonNode()
    private let activity = UIActivityIndicatorView(style: .medium)

    init(context: AccountContext, canEdit: @escaping () -> Bool) {
        self.context = context
        self.canEdit = canEdit
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleLabel.font = wegramNavigationTitleFont
        self.titleLabel.textAlignment = .center
        self.titleLabel.accessibilityTraits = .header
        self.navigationItem.titleView = self.titleLabel
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.content.save = { [weak self] in self?.saveName() }
        self.content.saveButton.addSubview(self.activity)
        self.activity.center = CGPoint(x: 32, y: 22)
        self.activity.isUserInteractionEnabled = false
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.peerDisposable.set((context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)) |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
            guard let self, case let .user(user) = peer else { return }
            self.content.setName(firstName: user.firstName ?? "", lastName: user.lastName ?? "")
            if self.isNodeLoaded && self.view.window != nil { self.content.firstNameField.becomeFirstResponder() }
        }))
        self.updatePresentation()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.peerDisposable.dispose()
        self.saveDisposable.dispose()
    }

    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        self.titleLabel.text = chinese ? "设置名字" : "Set Name"
        self.titleLabel.textColor = control
        self.cancelButton.setTitle(data.strings.Common_Cancel, with: Font.regular(17), with: control, for: .normal)
        self.cancelButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        self.cancelButton.accessibilityLabel = data.strings.Common_Cancel
        let cancelItem = UIBarButtonItem(customDisplayNode: self.cancelButton)
        cancelItem?.target = self
        cancelItem?.action = #selector(self.cancelPressed)
        cancelItem?.accessibilityLabel = data.strings.Common_Cancel
        self.navigationItem.leftBarButtonItem = cancelItem
        self.content.update(isDark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, doneTitle: data.strings.Common_Done, firstNameTitle: data.strings.UserInfo_FirstNamePlaceholder, lastNameTitle: data.strings.UserInfo_LastNamePlaceholder)
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

    private func saveName() {
        guard self.content.canSave, self.canEdit() else { return }
        let firstName = self.content.firstName
        let lastName = self.content.lastName
        self.content.submitting = true
        self.activity.startAnimating()
        self.updatePresentation()
        // The upstream API completes even on failure; inspect its committed local result.
        self.saveDisposable.set((self.context.engine.accountData.updateAccountPeerName(firstName: firstName, lastName: lastName) |> deliverOnMainQueue).startStrict(completed: { [weak self] in
            guard let self else { return }
            self.peerDisposable.set((self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId)) |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                guard let self else { return }
                self.content.submitting = false
                self.activity.stopAnimating()
                self.updatePresentation()
                if case let .user(user) = peer, (user.firstName ?? "") == firstName, (user.lastName ?? "") == lastName {
                    self.view.endEditing(true)
                    self.dismiss()
                } else {
                    self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }))
        }))
    }

    @objc private func cancelPressed() {
        self.view.endEditing(true)
        self.dismiss()
    }
}
