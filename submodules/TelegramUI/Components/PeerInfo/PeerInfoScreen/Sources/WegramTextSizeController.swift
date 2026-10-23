import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import SwiftSignalKit

final class WegramTextSizeController: ViewController {
    private var safeBottom: CGFloat = 0
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private let settingsDisposable = MetaDisposable()
    private let saveDisposable = MetaDisposable()
    private let content = WegramTextSizeContentView()
    private let titleLabel = UILabel()
    private let cancelButton = ASButtonNode()

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleLabel.font = wegramNavigationTitleFont
        self.titleLabel.textAlignment = .center
        self.titleLabel.accessibilityTraits = .header
        self.navigationItem.titleView = self.titleLabel
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.content.save = { [weak self] in self?.saveSize() }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.settingsDisposable.set((context.sharedContext.accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationThemeSettings])) |> take(1) |> deliverOnMainQueue).startStrict(next: { [weak self] view in
            guard let self else { return }
            let settings = view.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? .defaultSettings
            self.content.load(previewSize: (settings.useSystemFont ? self.presentationData.chatFontSize : settings.fontSize).baseDisplaySize)
            self.updatePresentation()
        }))
        self.updatePresentation()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.settingsDisposable.dispose()
        self.saveDisposable.dispose()
    }

    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let control = WegramNavigationColors(isDark: data.theme.overallDarkAppearance).control
        self.titleLabel.text = chinese ? "设置字体大小" : "Set Text Size"
        self.titleLabel.textColor = control
        self.cancelButton.setTitle(data.strings.Common_Cancel, with: Font.regular(17), with: control, for: .normal)
        self.cancelButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        let cancelItem = UIBarButtonItem(customDisplayNode: self.cancelButton)
        cancelItem?.target = self
        cancelItem?.action = #selector(self.cancelPressed)
        cancelItem?.accessibilityLabel = data.strings.Common_Cancel
        cancelItem?.isEnabled = !self.content.submitting
        self.navigationItem.leftBarButtonItem = cancelItem
        self.cancelButton.isUserInteractionEnabled = !self.content.submitting
        self.content.update(isDark: data.theme.overallDarkAppearance, chinese: chinese, doneTitle: data.strings.Common_Done, safeBottom: self.safeBottom)
        self.navigationItem.rightBarButtonItem = self.content.makeSaveItem()
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
        self.safeBottom = layout.intrinsicInsets.bottom
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.content.update(isDark: self.presentationData.theme.overallDarkAppearance, chinese: self.presentationData.strings.baseLanguageCode.hasPrefix("zh"), doneTitle: self.presentationData.strings.Common_Done, safeBottom: layout.intrinsicInsets.bottom)
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top)))
    }

    private func saveSize() {
        guard self.content.canSave else { return }
        let draft = self.content.draft
        // An untouched page must not flatten independent list/chat sizes or system mode.
        guard draft.selection != nil else { self.dismiss(); return }
        self.content.submitting = true
        self.updatePresentation()
        self.saveDisposable.set((updatePresentationThemeSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { draft.applying(to: $0) }) |> deliverOnMainQueue).startStrict(completed: { [weak self] in self?.dismiss() }))
    }

    @objc private func cancelPressed() {
        guard !self.content.submitting else { return }
        self.dismiss()
    }
}
