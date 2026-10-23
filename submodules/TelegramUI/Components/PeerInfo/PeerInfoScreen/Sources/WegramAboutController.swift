import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import AppBundle
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit

final class WegramAboutController: ViewController {
    private let context: AccountContext
    private let backButton = ASButtonNode()
    private var content: WegramAboutContentView?
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            guard let self else { return }
            self.presentationData = data
            self.updatePresentation()
        })
        self.updatePresentation()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { self.presentationDisposable?.dispose() }

    private var chinese: Bool { self.presentationData.strings.baseLanguageCode.hasPrefix("zh") }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        let content = WegramAboutContentView(action: { [weak self] action in self?.open(action) })
        self.content = content
        self.displayNode.view.addSubview(content)
        self.updatePresentation()
        self.displayNodeDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updatePresentation()
    }

    private func updatePresentation() {
        let data = self.presentationData
        let isDark = data.theme.overallDarkAppearance
        let control = WegramNavigationColors(isDark: isDark).control
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme).withUpdatedBackgroundColor(isDark ? UIColor(white: 0.1, alpha: 1) : .white), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        let image = wegramNavigationBackArrowImage(color: control)
        self.backButton.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: 0, bottom: (44 - size.height) / 2, right: 44 - size.width)
        self.backButton.accessibilityLabel = data.strings.Common_Back
        let item = UIBarButtonItem(customDisplayNode: self.backButton)
        item?.accessibilityLabel = data.strings.Common_Back
        item?.target = self
        item?.action = #selector(self.backPressed)
        self.navigationItem.leftBarButtonItem = item
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        guard self.isNodeLoaded else { return }
        self.displayNode.backgroundColor = isDark ? UIColor(white: 0.1, alpha: 1) : .white
        let icons = self.context.sharedContext.applicationBindings.getAvailableAlternateIcons()
        let selected = self.context.sharedContext.applicationBindings.getAlternateIconName()
        let icon = icons.first(where: { selected == nil ? $0.isDefault : $0.name == selected })
        let imageName = icon?.imageName ?? "BlueIcon"
        self.content?.update(
            icon: UIImage(named: imageName, in: getAppBundle(), compatibleWith: nil),
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
            chinese: self.chinese, isDark: isDark, fontSize: data.listsFontSize.itemListBaseFontSize
        )
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let bottom = layout.insets(options: [.input]).bottom
        if let content = self.content {
            transition.updateFrame(view: content, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top - bottom)))
        }
    }

    private func open(_ action: WegramAboutContentView.Action) {
        let url: String
        switch action {
        case .features:
            let text = self.chinese ? "再次点击左下角“微信”可以选择聊天分组。\n\n聊天列表左上角星标提供收藏、下载、通话、频道、归档和代理入口。\n\n在“我 → 设置”右上角打开更多设置，可访问完整设置。" : "Tap the selected 微信 tab again to choose a chat folder.\n\nThe star on the chat list opens Saved Messages, downloads, calls, channels, archived chats and proxies.\n\nOpen More Settings at the top right of Settings for all settings."
            self.present(textAlertController(context: self.context, title: self.chinese ? "功能介绍" : "Features", text: text, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            return
        case .help: url = "https://telegram.org/faq"
        case .source: url = "https://github.com/TelegramMessenger/Telegram-iOS"
        case .terms: url = "https://telegram.org/tos"
        case .privacy: url = "https://telegram.org/privacy"
        }
        self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: false, presentationData: self.presentationData, navigationController: self.navigationController as? NavigationController, dismissInput: {})
    }

    @objc private func backPressed() { self.dismiss() }
}
