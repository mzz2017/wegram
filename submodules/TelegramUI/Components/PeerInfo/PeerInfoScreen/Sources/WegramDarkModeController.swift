import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import SwiftSignalKit
import SettingsUI

final class WegramDarkModeController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var settings: PresentationThemeSettings?
    private var presentationDisposable: Disposable?
    private let settingsDisposable = MetaDisposable()
    private let saveDisposable = MetaDisposable()
    private let content = WegramDarkModeContentView()
    private let titleButton = UIButton(type: .custom)
    private let backButton = ASButtonNode()

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.Settings.MoreAppearanceSettings"
        // The title is plain text: WeGram does not expose Telegram's theme settings.
        self.titleButton.isUserInteractionEnabled = false
        self.titleButton.accessibilityTraits = .header
        self.navigationItem.titleView = self.titleButton
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.content.change = { [weak self] mode in self?.change(mode) }
        self.attemptNavigation = { [weak self] _ in !(self?.content.submitting ?? false) }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.settingsDisposable.set((context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings]) |> deliverOnMainQueue).startStrict(next: { [weak self] view in
            guard let self else { return }
            self.settings = view.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? .defaultSettings
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
        self.titleButton.setTitle(chinese ? "深色模式" : "Dark Mode", for: .normal)
        self.titleButton.setTitleColor(control, for: .normal)
        self.titleButton.isEnabled = !self.content.submitting
        self.titleButton.sizeToFit()
        self.titleButton.bounds.size.height = 44
        let image = wegramNavigationBackArrowImage(color: control)
        self.backButton.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: 0, bottom: (44 - size.height) / 2, right: 44 - size.width)
        self.backButton.isUserInteractionEnabled = !self.content.submitting
        let backItem = UIBarButtonItem(customDisplayNode: self.backButton)
        backItem?.target = self
        backItem?.action = #selector(self.backPressed)
        backItem?.accessibilityLabel = data.strings.Common_Back
        backItem?.isEnabled = !self.content.submitting
        self.navigationItem.leftBarButtonItem = backItem
        self.content.update(dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, chinese: chinese)
        if let settings = self.settings { self.content.load(mode: WegramDarkMode.current(settings: settings, resolvedDark: data.theme.overallDarkAppearance)) }
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

    private func change(_ mode: WegramDarkMode) {
        guard self.settings != nil, !self.content.submitting, mode != .advanced else { return }
        self.content.submitting = true
        self.updatePresentation()
        self.saveDisposable.set((updatePresentationThemeSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { mode.applying(to: $0) }) |> deliverOnMainQueue).startStrict(completed: { [weak self] in
            guard let self else { return }
            self.content.submitting = false
            self.updatePresentation()
        }))
    }
    @objc private func backPressed() {
        guard !self.content.submitting else { return }
        self.dismiss()
    }
}
