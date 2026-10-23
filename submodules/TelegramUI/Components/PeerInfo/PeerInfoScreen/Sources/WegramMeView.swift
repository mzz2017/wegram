import UIKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import AvatarNode
import WallpaperGridScreen

extension PeerInfoScreenImpl {
    func updateWegramMe(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        guard self.isSettings else { return }
        let node = self.controllerNode
        let isRoot = self.parent is TabBarController
        let visible = isRoot && !node.state.isEditing && !node.headerNode.isAvatarExpanded && node.searchDisplayController == nil
        if visible && self.wegramMeView == nil {
            let view = WegramMeView(action: { [weak self] action in
                self?.performWegramMeAction(action)
            }, updateAvatar: { [weak self] avatar, theme, peer in
                guard let self else { return }
                avatar.setPeer(context: self.context, theme: theme, peer: peer, clipStyle: .none, displayDimensions: CGSize(width: 64, height: 64))
            })
            self.wegramMeView = view
            node.view.addSubview(view)
        }
        guard let view = self.wegramMeView else { return }
        view.isHidden = !visible
        node.scrollNode.isHidden = visible
        node.headerNode.isHidden = visible
        node.edgeEffectView.isHidden = visible
        self.navigationBar?.isHidden = visible
        if visible {
            (self.parent as? TabBarController)?.updateBackgroundAlpha(1, transition: .immediate)
            transition.updateFrame(view: view, frame: CGRect(x: layout.safeInsets.left, y: 0, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: layout.size.height))
            view.update(presentationData: self.presentationData, peer: node.data?.peer, topInset: layout.statusBarHeight ?? 0, bottomInset: layout.intrinsicInsets.bottom)
            node.view.bringSubviewToFront(view)
        }
    }

    private func performWegramMeAction(_ action: WegramMeView.Action) {
        switch action {
        case .profile:
            self.push(WegramSettingsController(context: self.context, page: .personal, open: { [weak self] destination in
                guard let self else { return }
                switch destination {
                case .profileAvatar: self.openAvatars(usesWegramProfileLayout: true)
                case .profileUsername: self.controllerNode.openSettings(section: .username, preserveNavigationStack: true)
                case .profilePhone: self.controllerNode.openSettings(section: .phoneNumber, preserveNavigationStack: true)
                case .profileQr: self.controllerNode.openQrCode()
                case .profileName:
                    guard !self.presentAccountFrozenInfoIfNeeded() else { return }
                    self.push(WegramNameController(context: self.context, canEdit: { [weak self] in
                        guard let self else { return false }
                        return !self.presentAccountFrozenInfoIfNeeded()
                    }))
                case .profileBio:
                    guard !self.presentAccountFrozenInfoIfNeeded() else { return }
                    self.push(WegramBioController(context: self.context, canEdit: { [weak self] in
                        guard let self else { return false }
                        return !self.presentAccountFrozenInfoIfNeeded()
                    }))
                case .advanced:
                    guard !self.presentAccountFrozenInfoIfNeeded() else { return }
                    let profile = PeerInfoScreenImpl(context: self.context, updatedPresentationData: self.updatedPresentationData, peerId: self.peerId, avatarInitiallyExpanded: false, isOpenedFromChat: false, reactionSourceMessageId: nil, callMessages: [], isMyProfile: true)
                    self.push(profile)
                default: break
                }
            }, switchAccount: { _ in }))
        case .qrCode:
            self.controllerNode.openQrCode()
        case .status:
            self.controllerNode.openSettings(section: .emojiStatus)
        case .savedMessages:
            self.controllerNode.openSettings(section: .savedMessages)
        case .stories:
            self.controllerNode.openSettings(section: .stories)
        case .stickers:
            self.controllerNode.openSettings(section: .stickers)
        case .cards:
            self.push(PeerInfoScreenImpl(context: self.context, updatedPresentationData: self.updatedPresentationData, peerId: self.peerId, avatarInitiallyExpanded: false, isOpenedFromChat: false, reactionSourceMessageId: nil, callMessages: [], isMyProfile: true, switchToGiftsTarget: .generic))
        case .settings:
            self.push(WegramSettingsController(context: self.context, open: { [weak self] destination in
                guard let self else { return }
                let section: PeerInfoSettingsSection
                switch destination {
                case .securityMore: section = .privacyAndSecurity
                case .privacy:
                    self.push(WegramPrivacyController(context: self.context, requestPublicPhotoSetup: { [weak self] completion in
                        self?.openAvatarForEditing(mode: .fallback, completion: completion)
                    }, requestPublicPhotoRemove: { [weak self] completion in
                        self?.openAvatarRemoval(mode: .fallback, completion: completion)
                    }))
                    return
                case .twoStepVerification: section = .twoStepVerification
                case .deviceManagement:
                    self.push(WegramDevicesController(context: self.context, contexts: self.controllerNode.activeSessionsContextAndCount.get()))
                    return
                case .profileUsername: section = .username
                case .profilePhone: section = .phoneNumber
                case .notifications:
                    self.push(WegramNotificationsController(context: self.context))
                    return
                // Upstream's support prompt: the FAQ and the volunteer support chat, both one tap away.
                case .help: section = .support
                case .about: section = .about
                case .accounts: section = .addAccount
                case .logout: section = .logout
                case .textSize:
                    self.push(WegramTextSizeController(context: self.context))
                    return
                case .wallpaperCamera:
                    if let top = (self.navigationController as? NavigationController)?.topViewController as? ViewController {
                        presentChatWallpaperCamera(context: self.context, from: top)
                    }
                    return
                case .wallpaperPhoto:
                    if let top = (self.navigationController as? NavigationController)?.topViewController as? ViewController {
                        presentCustomChatWallpaper(context: self.context, from: top)
                    }
                    return
                case .wallpaperPresets:
                    self.push(ThemeGridController(context: self.context, usesWegramLayout: true))
                    return
                case .appearance:
                    self.push(WegramDarkModeController(context: self.context))
                    return
                case .language:
                    self.push(WegramLanguageController(context: self.context))
                    return
                case .storage:
                    self.push(WegramStorageController(context: self.context))
                    return
                case .media:
                    self.push(WegramMediaSettingsController(context: self.context))
                    return
                case .stickers: section = .stickers
                case .powerSaving: section = .powerSaving
                case .security, .general, .wallpaper, .profileAvatar, .profileName, .profileQr, .profileMore, .profileBio: return
                case .advanced:
                    let settings = PeerInfoScreenImpl(context: self.context, updatedPresentationData: self.updatedPresentationData, peerId: self.peerId, avatarInitiallyExpanded: false, isOpenedFromChat: false, reactionSourceMessageId: nil, callMessages: [], isSettings: true)
                    settings.parentController = self.parentController
                    self.push(settings)
                    return
                }
                self.controllerNode.openSettings(section: section, preserveNavigationStack: true)
            }, switchAccount: { [weak self] context in
                self?.controllerNode.switchToAccount(id: context.account.id)
            }))
        case .services:
            let chinese = self.presentationData.strings.baseLanguageCode.hasPrefix("zh")
            let menu = ActionSheetController(theme: ActionSheetControllerTheme(wegramTheme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize))
            var active = true
            menu.willDismiss = { active = false }
            let items: [ActionSheetItem] = [(chinese ? "通话" : "Calls", PeerInfoSettingsSection.recentCalls), (chinese ? "设备" : "Devices", .devices), (chinese ? "代理" : "Proxy", .proxy), (chinese ? "聊天分组" : "Chat Folders", .chatFolders)].map { title, section in
                ActionSheetButtonItem(title: title, action: { [weak self, weak menu] in
                    guard active, let self else { return }
                    active = false
                    menu?.dismissAnimated()
                    guard self.wegramMeView?.isHidden == false, self.displayNode.view.window != nil else { return }
                    if case .devices = section {
                        self.push(WegramDevicesController(context: self.context, contexts: self.controllerNode.activeSessionsContextAndCount.get()))
                    } else {
                        self.controllerNode.openSettings(section: section)
                    }
                })
            }
            menu.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { [weak menu] in menu?.dismissAnimated() })])
            ])
            self.present(menu, in: .window(.root))
        }
    }
}
