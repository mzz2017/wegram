import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SSignalKit
import SwiftSignalKit
import TelegramPresentationData
import LegacyComponents
import SolidRoundedButtonNode
import RMIntro

public final class AuthorizationSequenceSplashController: ViewController {
    private var controllerNode: AuthorizationSequenceSplashControllerNode {
        return self.displayNode as! AuthorizationSequenceSplashControllerNode
    }
    
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let account: UnauthorizedAccount
    private let theme: PresentationTheme
    
    private let controller: RMIntroViewController?
    
    private var validLayout: ContainerViewLayout?
    
    var nextPressed: ((PresentationStrings?) -> Void)?
    var localizationUpdated: ((PresentationStrings) -> Void)?
    var localizationFailed: (() -> Void)?
    
    private let suggestedLocalization = Promise<SuggestedLocalizationInfo?>()
    private let activateLocalizationDisposable = MetaDisposable()
    
    private let startButton: SolidRoundedButtonNode
    private let welcomeView: WegramWelcomeView?
    private var welcomeStrings: PresentationStrings?
    private var availableLocalizations: [LocalizationInfo] = []
    private weak var languageController: WegramAuthorizationLanguageController?
    private let welcomeLocalizationDisposable = MetaDisposable()
    
    init(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, theme: PresentationTheme, strings: PresentationStrings? = nil) {
        self.accountManager = accountManager
        self.account = account
        self.theme = theme
        self.welcomeStrings = strings
        self.welcomeView = strings.map { WegramWelcomeView(chinese: $0.baseLanguageCode.hasPrefix("zh")) }
        
        self.suggestedLocalization.set(.single(nil)
        |> then(TelegramEngineUnauthorized(account: self.account).localization.currentlySuggestedLocalization(extractKeys: ["Login.ContinueWithLocalization"])))
        let suggestedLocalization = self.suggestedLocalization
        
        let localizationSignal = SSignal(generator: { subscriber in
            let disposable = suggestedLocalization.get().start(next: { localization in
                guard let localization = localization else {
                    return
                }
                
                var continueWithLanguageString: String = "Continue"
                for entry in localization.extractedEntries {
                    switch entry {
                        case let .string(key, value):
                            if key == "Login.ContinueWithLocalization" {
                                continueWithLanguageString = value
                            }
                        default:
                            break
                    }
                }
                
                if let available = localization.availableLocalizations.first, available.languageCode != "en" {
                    let value = TGSuggestedLocalization(info: TGAvailableLocalization(title: available.title, localizedTitle: available.localizedTitle, code: available.languageCode), continueWithLanguageString: continueWithLanguageString, chooseLanguageString: "Choose Language", chooseLanguageOtherString: "Choose Language", englishLanguageNameString: "English")
                    subscriber.putNext(value)
                }
            }, completed: {
                subscriber.putCompletion()
            })
            
            return SBlockDisposable(block: {
                disposable.dispose()
            })
        })
        
        self.controller = strings == nil ? RMIntroViewController(backgroundColor: theme.list.plainBackgroundColor, primaryColor: theme.list.itemPrimaryTextColor, buttonColor: theme.intro.startButtonColor, accentColor: theme.list.itemAccentColor, regularDotColor: theme.intro.dotColor, highlightedDotColor: theme.list.itemAccentColor, suggestedLocalizationSignal: localizationSignal) : nil
        
        self.startButton = SolidRoundedButtonNode(title: "Start Messaging", theme: SolidRoundedButtonTheme(theme: theme), glass: false, height: 50.0, cornerRadius: 50.0 * 0.5, isShimmering: true)
        self.startButton.accessibilityIdentifier = "Auth.Welcome.StartButton"

        super.init(navigationBarPresentationData: nil)
        
        self._hasGlassStyle = self.welcomeView == nil
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = self.welcomeView == nil ? theme.intro.statusBarStyle.style : .White
        
        self.controller?.startMessaging = { [weak self] in
            self?.activateLocalization("en")
        }
        self.controller?.startMessagingInAlternativeLanguage = { [weak self] code in
            if let code = code {
                self?.activateLocalization(code)
            }
        }
        
        self.startButton.pressed = { [weak self] in
            self?.activateLocalization("en")
        }
        
        self.welcomeView?.proceed = { [weak self] in
            self?.activateLocalization(nil)
        }
        self.welcomeView?.languagePressed = { [weak self] in self?.openLanguagePicker() }
        if self.welcomeView != nil {
            self.welcomeLocalizationDisposable.set((self.suggestedLocalization.get() |> deliverOnMainQueue).start(next: { [weak self] info in
                guard let self else { return }
                self.availableLocalizations = info?.availableLocalizations ?? []
                self.languageController?.loadLanguages(self.availableLocalizations)
            }))
        }
        self.controller?.createStartButton = { [weak self] width in
            let _ = self?.startButton.updateLayout(width: width, transition: .immediate)
            return self?.startButton.view
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.activateLocalizationDisposable.dispose()
        self.welcomeLocalizationDisposable.dispose()
    }
    
    public override func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceSplashControllerNode(theme: self.theme)
        if let welcomeView = self.welcomeView {
            self.displayNode.view.addSubview(welcomeView)
        }
        self.displayNodeDidLoad()
    }
    
    func animateIn() {
        if self.welcomeView == nil { self.controller?.animateIn() }
    }
    
    var buttonFrame: CGRect {
        return self.startButton.frame
    }
    
    var buttonTitle: String {
        return self.startButton.title ?? ""
    }
    
    var animationSnapshot: UIView? {
        return self.controller?.createAnimationSnapshot()
    }
    
    var textSnaphot: UIView? {
        return self.controller?.createTextSnapshot()
    }
    
    private func addControllerIfNeeded() {
        guard let controller = self.controller else { return }
        if !controller.isViewLoaded || controller.view.superview == nil {
            self.displayNode.view.addSubview(controller.view)
            if let layout = self.validLayout {
                controller.view.frame = CGRect(origin: CGPoint(), size: layout.size)
            }
            controller.viewDidAppear(false)
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.addControllerIfNeeded()
        self.welcomeView?.enabled = true
        self.controller?.viewWillAppear(false)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controller?.viewDidAppear(animated)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.controller?.viewWillDisappear(animated)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.controller?.viewDidDisappear(animated)
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if let welcomeView = self.welcomeView {
            welcomeView.updateLayout(size: layout.size, topInset: max(layout.statusBarHeight ?? 0, layout.safeInsets.top), bottomInset: layout.insets(options: []).bottom)
            return
        }
        self.validLayout = layout
        let controllerFrame = CGRect(origin: CGPoint(), size: layout.size)
        self.controller?.defaultFrame = controllerFrame
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
        
        self.addControllerIfNeeded()
        if case .immediate = transition {
            self.controller?.view.frame = controllerFrame
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.controller?.view.frame = controllerFrame
            })
        }
    }
    
    private var isCurrentWelcomeScreen: Bool {
        guard let navigationController = self.navigationController else { return false }
        if navigationController.viewControllers.last === self { return true }
        if let languageController = self.languageController, navigationController.viewControllers.last === languageController { return true }
        return false
    }

    private func openLanguagePicker() {
        guard self.welcomeView?.enabled == true, self.navigationController?.viewControllers.last === self, let strings = self.welcomeStrings else { return }
        let controller = WegramAuthorizationLanguageController(theme: self.theme, strings: strings, languages: self.availableLocalizations)
        self.languageController = controller
        controller.apply = { [weak self, weak controller] code in
            guard let self, let controller, self.languageController === controller, self.navigationController?.viewControllers.last === controller else { return }
            self.activateLocalization(code, proceedToPhone: false)
        }
        controller.cancelled = { [weak self] in self?.languageController = nil }
        self.push(controller)
    }

    private func activateLocalization(_ code: String?, proceedToPhone: Bool = true) {
        if let welcomeView = self.welcomeView {
            guard welcomeView.enabled else { return }
            if proceedToPhone, self.navigationController?.viewControllers.last !== self { return }
            welcomeView.enabled = false
        }
        let currentCode = self.accountManager.transaction { transaction -> String in
            if let current = transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self) {
                return current.primaryComponent.languageCode
            } else {
                return "en"
            }
        }
        let suggestedCode = self.suggestedLocalization.get()
        |> map { localization -> String? in
            return localization?.availableLocalizations.first?.languageCode
        }
        
        let _ = (combineLatest(currentCode, suggestedCode)
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] currentCode, suggestedCode in
            guard let strongSelf = self else {
                return
            }
            
            let code = code ?? currentCode
            if let suggestedCode = suggestedCode {
                _ = TelegramEngineUnauthorized(account: strongSelf.account).localization.markSuggestedLocalizationAsSeenInteractively(languageCode: suggestedCode).start()
            }
            
            if currentCode == code {
                strongSelf.completeLocalization(strings: nil, proceedToPhone: proceedToPhone)
                return
            }
            
            strongSelf.controller?.isEnabled = false
            strongSelf.welcomeView?.enabled = false
            strongSelf.startButton.alpha = 0.6
            let accountManager = strongSelf.accountManager
            
            strongSelf.activateLocalizationDisposable.set((TelegramEngineUnauthorized(account: strongSelf.account).localization.downloadAndApplyLocalization(accountManager: accountManager, languageCode: code)
            |> deliverOnMainQueue).start(error: { [weak self] _ in
                guard let self, let welcomeView = self.welcomeView else { return }
                welcomeView.enabled = true
                self.languageController?.setSubmitting(false)
                if self.isCurrentWelcomeScreen { self.localizationFailed?() }
            }, completed: {
                let _ = (accountManager.transaction { transaction -> PresentationStrings? in
                    let localizationSettings: LocalizationSettings?
                    if let current = transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self) {
                        localizationSettings = current
                    } else {
                        localizationSettings = nil
                    }
                    let stringsValue: PresentationStrings
                    if let localizationSettings = localizationSettings {
                        stringsValue = PresentationStrings(primaryComponent: PresentationStrings.Component(languageCode: localizationSettings.primaryComponent.languageCode, localizedName: localizationSettings.primaryComponent.localizedName, pluralizationRulesCode: localizationSettings.primaryComponent.customPluralizationCode, dict: dictFromLocalization(localizationSettings.primaryComponent.localization)), secondaryComponent: localizationSettings.secondaryComponent.flatMap({ PresentationStrings.Component(languageCode: $0.languageCode, localizedName: $0.localizedName, pluralizationRulesCode: $0.customPluralizationCode, dict: dictFromLocalization($0.localization)) }), groupingSeparator: "")
                    } else {
                        stringsValue = defaultPresentationStrings
                    }
                    return stringsValue
                }
                |> deliverOnMainQueue).start(next: { strings in
                    self?.controller?.isEnabled = true
                    self?.startButton.alpha = 1.0
                    self?.completeLocalization(strings: strings, proceedToPhone: proceedToPhone)
                })
            }))
        })
    }
    
    private func completeLocalization(strings: PresentationStrings?, proceedToPhone: Bool) {
        if self.isCurrentWelcomeScreen {
            if let strings {
                self.welcomeStrings = strings
                self.welcomeView?.updateLanguage(chinese: strings.baseLanguageCode.hasPrefix("zh"))
            }
            if proceedToPhone {
                self.nextPressed?(strings)
            } else {
                self.welcomeView?.enabled = true
                if let strings {
                    self.localizationUpdated?(strings)
                }
                self.languageController?.completeSelection()
                self.languageController = nil
            }
        }
    }
}
