import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit

final class WegramBioController: ViewController {
    private let context: AccountContext
    private let canEdit: () -> Bool
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private let peerDisposable = MetaDisposable()
    private let saveDisposable = MetaDisposable()
    private let content = WegramBioContentView()
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
        self.content.save = { [weak self] in self?.saveBio() }
        self.content.saveButton.addSubview(self.activity)
        self.activity.center = CGPoint(x: 32, y: 22)
        self.activity.isUserInteractionEnabled = false
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.peerDisposable.set((context.account.viewTracker.peerView(context.account.peerId, updateData: true) |> deliverOnMainQueue).startStrict(next: { [weak self] view in
            guard let self, let data = view.cachedData as? CachedUserData else { return }
            let wasEditable = self.content.textView.isEditable
            self.content.setBio(data.about ?? "")
            if !wasEditable && self.isNodeLoaded && self.view.window != nil { self.content.textView.becomeFirstResponder() }
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
        let isDark = data.theme.overallDarkAppearance
        let title = data.strings.baseLanguageCode.hasPrefix("zh") ? "设置个性签名" : "Set Bio"
        let control = WegramNavigationColors(isDark: isDark).control
        let theme = NavigationBarTheme(wegramTheme: data.theme).withUpdatedBackgroundColor(isDark ? UIColor(white: 0.1, alpha: 1) : .white)
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: theme, strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        self.titleLabel.text = title
        self.titleLabel.textColor = control
        self.cancelButton.setTitle(data.strings.Common_Cancel, with: Font.regular(17), with: control, for: .normal)
        self.cancelButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        self.cancelButton.accessibilityLabel = data.strings.Common_Cancel
        let cancelItem = UIBarButtonItem(customDisplayNode: self.cancelButton)
        cancelItem?.target = self
        cancelItem?.action = #selector(self.cancelPressed)
        cancelItem?.accessibilityLabel = data.strings.Common_Cancel
        self.navigationItem.leftBarButtonItem = cancelItem
        self.content.update(isDark: isDark, fontSize: data.listsFontSize.itemListBaseFontSize, maximumLength: Int(self.context.userLimits.maxAboutLength), title: title, doneTitle: data.strings.Common_Done, remainingTitle: data.strings.baseLanguageCode.hasPrefix("zh") ? "剩余字数" : "Characters remaining")
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

    private func saveBio() {
        self.updatePresentation()
        guard self.content.canSave, self.canEdit() else { return }
        let bio = self.content.text
        self.content.submitting = true
        self.activity.startAnimating()
        self.updatePresentation()
        self.saveDisposable.set((self.context.engine.accountData.updateAbout(about: bio) |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
            guard let self else { return }
            self.content.submitting = false
            self.activity.stopAnimating()
            self.updatePresentation()
            self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }, completed: { [weak self] in
            guard let self else { return }
            self.view.endEditing(true)
            self.dismiss()
        }))
    }

    @objc private func cancelPressed() {
        self.view.endEditing(true)
        self.dismiss()
    }
}
