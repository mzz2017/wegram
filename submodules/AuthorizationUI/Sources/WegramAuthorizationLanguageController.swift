import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import WegramLanguageUI

final class WegramAuthorizationLanguageController: ViewController {
    let content = WegramLanguageContentView()
    private let strings: PresentationStrings
    private let activeCode: String
    private let cancelButton = ASButtonNode()
    private var closed = false
    var apply: ((String) -> Void)?
    var cancelled: (() -> Void)?

    init(theme: PresentationTheme, strings: PresentationStrings, languages: [LocalizationInfo]) {
        self.strings = strings
        self.activeCode = strings.primaryComponent.languageCode
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: theme), strings: NavigationBarStrings(presentationStrings: strings)))
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
        let title = UILabel()
        title.text = strings.baseLanguageCode.hasPrefix("zh") ? "设置语言" : strings.Settings_AppLanguage
        title.font = wegramNavigationTitleFont
        title.textAlignment = .center
        title.textColor = WegramNavigationColors(isDark: theme.overallDarkAppearance).control
        title.accessibilityTraits = .header
        title.accessibilityIdentifier = "Auth.Language.Title"
        title.sizeToFit()
        self.navigationItem.titleView = title
        self.cancelButton.setTitle(strings.Common_Cancel, with: Font.regular(17), with: title.textColor, for: .normal)
        self.cancelButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        let cancel = UIBarButtonItem(customDisplayNode: self.cancelButton)
        cancel?.target = self
        cancel?.action = #selector(self.cancelPressed)
        cancel?.accessibilityLabel = strings.Common_Cancel
        self.navigationItem.leftBarButtonItem = cancel
        self.content.update(dark: theme.overallDarkAppearance, fontSize: 17, doneTitle: strings.Common_Done, loadingTitle: strings.Channel_NotificationLoading)
        self.content.saveButton.accessibilityIdentifier = "Auth.Language.Done"
        self.content.save = { [weak self] info in
            guard let self, !self.closed, !self.content.submitting else { return }
            self.setSubmitting(true)
            self.apply?(info.languageCode)
        }
        let done = self.content.makeSaveItem()
        done?.target = self
        done?.action = #selector(self.donePressed)
        self.navigationItem.rightBarButtonItem = done
        self.attemptNavigation = { [weak self] _ in !(self?.content.submitting ?? false) }
        self.loadLanguages(languages)
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func loadLanguages(_ languages: [LocalizationInfo]) {
        guard !self.closed else { return }
        var available = languages
        if !available.contains(where: { $0.languageCode == "en" }) {
            available.insert(LocalizationInfo(languageCode: "en", baseLanguageCode: nil, customPluralizationCode: nil, title: "English", localizedTitle: "English", isOfficial: true, totalStringCount: 0, translatedStringCount: 0, platformUrl: ""), at: 0)
        }
        if !available.contains(where: { $0.languageCode == self.activeCode }) {
            available.insert(LocalizationInfo(languageCode: self.activeCode, baseLanguageCode: nil, customPluralizationCode: nil, title: self.strings.primaryComponent.localizedName, localizedTitle: self.strings.primaryComponent.localizedName, isOfficial: false, totalStringCount: 0, translatedStringCount: 0, platformUrl: ""), at: 0)
        }
        let priority = ["zh-hans", "zh-hant", "en"]
        let ordered = priority.flatMap { code in available.filter { $0.languageCode == code } } + available.filter { !priority.contains($0.languageCode) }
        self.content.load(official: ordered, saved: [], activeCode: self.activeCode)
    }

    func setSubmitting(_ value: Bool) {
        guard !self.closed else { return }
        self.content.submitting = value
        self.cancelButton.isUserInteractionEnabled = !value
        self.navigationItem.leftBarButtonItem?.isEnabled = !value
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = self.content.backgroundColor
        self.displayNode.view.addSubview(self.content)
        self.displayNodeDidLoad()
    }
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.content.table.contentInset.bottom = layout.intrinsicInsets.bottom
        self.content.table.verticalScrollIndicatorInsets.bottom = layout.intrinsicInsets.bottom
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: max(0, layout.size.width - layout.safeInsets.left - layout.safeInsets.right), height: max(0, layout.size.height - top)))
    }
    func completeSelection() {
        guard !self.closed else { return }
        self.closed = true
        self.apply = nil
        self.cancelled = nil
        self.dismiss()
    }

    @objc private func donePressed() {
        self.content.saveButton.sendActions(for: .touchUpInside)
    }
    @objc private func cancelPressed() {
        guard !self.closed, !self.content.submitting else { return }
        self.closed = true
        let cancelled = self.cancelled
        self.apply = nil
        self.cancelled = nil
        cancelled?()
        self.dismiss()
    }
}
