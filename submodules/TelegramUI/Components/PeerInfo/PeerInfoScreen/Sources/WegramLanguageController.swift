import UIKit
import WegramLanguageUI
import AsyncDisplayKit
import Display
import AccountContext
import Postbox
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit
import SettingsUI

final class WegramLanguageController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private let listDisposable = MetaDisposable()
    private let syncDisposable = MetaDisposable()
    private let applyDisposable = MetaDisposable()
    private let content = WegramLanguageContentView()
    private let titleButton = UIButton(type: .custom)
    private let cancelButton = ASButtonNode()
    private var confirmationVisible = false

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.Settings.MoreLanguageSettings"
        self.titleButton.addAction(UIAction(handler: { [weak self] _ in self?.openMore() }), for: .touchUpInside)
        self.navigationItem.titleView = self.titleButton
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.content.save = { [weak self] info in self?.save(info) }
        self.content.openMore = { [weak self] in self?.openMore() }
        self.attemptNavigation = { [weak self] _ in !(self?.content.submitting ?? false) }
        self.presentationDisposable = (context.sharedContext.presentationData |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            self?.presentationData = data
            self?.updatePresentation()
        })
        self.listDisposable.set((combineLatest(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.LocalizationList()), context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.localizationSettings])) |> deliverOnMainQueue).startStrict(next: { [weak self] state, sharedData in
            guard let self else { return }
            let settings = sharedData.entries[SharedDataKeys.localizationSettings]?.get(LocalizationSettings.self)
            self.content.load(official: state.availableOfficialLocalizations, saved: state.availableSavedLocalizations, activeCode: settings?.primaryComponent.languageCode ?? self.presentationData.strings.primaryComponent.languageCode)
            self.updatePresentation()
        }))
        self.syncDisposable.set(context.engine.localization.synchronizedLocalizationListState().startStrict())
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.presentationDisposable?.dispose()
        self.listDisposable.dispose()
        self.syncDisposable.dispose()
        self.applyDisposable.dispose()
    }

    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let colors = WegramNavigationColors(isDark: data.theme.overallDarkAppearance)
        self.titleButton.setTitle(chinese ? "设置语言" : "Set Language", for: .normal)
        self.titleButton.setTitleColor(colors.control, for: .normal)
        self.titleButton.accessibilityHint = chinese ? "打开更多语言与翻译设置" : "Open more language and translation settings"
        self.titleButton.isEnabled = !self.content.submitting
        self.titleButton.sizeToFit()
        self.titleButton.bounds.size.height = 44
        self.cancelButton.setTitle(data.strings.Common_Cancel, with: Font.regular(17), with: colors.control, for: .normal)
        self.cancelButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        self.cancelButton.isUserInteractionEnabled = !self.content.submitting
        let cancelItem = UIBarButtonItem(customDisplayNode: self.cancelButton)
        cancelItem?.target = self
        cancelItem?.action = #selector(self.cancelPressed)
        cancelItem?.accessibilityLabel = data.strings.Common_Cancel
        cancelItem?.isEnabled = !self.content.submitting
        self.navigationItem.leftBarButtonItem = cancelItem
        self.content.moreTitle = chinese ? "更多语言与翻译" : "More Languages and Translation"
        self.content.update(dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.itemListBaseFontSize, doneTitle: data.strings.Common_Done, loadingTitle: data.strings.Channel_NotificationLoading)
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
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.content.table.contentInset.bottom = layout.intrinsicInsets.bottom
        self.content.table.verticalScrollIndicatorInsets.bottom = layout.intrinsicInsets.bottom
        transition.updateFrame(view: self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top)))
    }

    private func save(_ info: LocalizationInfo) {
        guard self.content.canSave, !self.confirmationVisible else { return }
        guard info.languageCode != self.content.draft.activeCode else { self.dismiss(); return }
        if info.isOfficial {
            self.apply(info)
        } else {
            self.confirmationVisible = true
            let sheet = ActionSheetController(theme: ActionSheetControllerTheme(wegramTheme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize))
            sheet.setItemGroups([
                ActionSheetItemGroup(items: [ActionSheetTextItem(title: info.localizedTitle), ActionSheetButtonItem(title: self.presentationData.strings.ApplyLanguage_ChangeLanguageAction, action: { [weak self, weak sheet] in
                    sheet?.dismissAnimated()
                    self?.confirmationVisible = false
                    self?.apply(info)
                })]),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { [weak self, weak sheet] in
                    self?.confirmationVisible = false
                    sheet?.dismissAnimated()
                })])
            ])
            sheet.dismissed = { [weak self] _ in self?.confirmationVisible = false }
            self.present(sheet, in: .window(.root))
        }
    }

    private func apply(_ info: LocalizationInfo) {
        guard self.content.canSave else { return }
        self.content.submitting = true
        self.updatePresentation()
        self.applyDisposable.set((self.context.engine.localization.downloadAndApplyLocalization(accountManager: self.context.sharedContext.accountManager, languageCode: info.languageCode) |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
            guard let self else { return }
            self.content.submitting = false
            self.updatePresentation()
            self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }, completed: { [weak self] in
            guard let self else { return }
            self.content.submitting = false
            self.context.engine.messages.refreshAttachMenuBots()
            self.dismiss()
        }))
    }
    private func openMore() {
        guard !self.content.submitting, !self.confirmationVisible else { return }
        self.push(LocalizationListController(context: self.context))
    }
    @objc private func cancelPressed() {
        guard !self.content.submitting else { return }
        self.dismiss()
    }
}
