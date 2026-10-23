import Foundation
import UIKit
import AsyncDisplayKit
import Markdown
import AvatarNode
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ItemListPeerActionItem
import ItemListAvatarAndNameInfoItem
import ItemListPeerItem

private enum MediaType {
    case photo
    case video
}

private final class SaveIncomingMediaControllerArguments {
    let context: AccountContext
    let toggle: (MediaType) -> Void
    let updateMaximumVideoSize: (Int64) -> Void
    let openAddException: () -> Void
    let openPeerMenu: (EnginePeer) -> Void
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let deletePeer: (EnginePeer.Id) -> Void
    let deleteAllExceptions: () -> Void
    
    init(context: AccountContext, toggle: @escaping (MediaType) -> Void, updateMaximumVideoSize: @escaping (Int64) -> Void, openAddException: @escaping () -> Void, openPeerMenu: @escaping (EnginePeer) -> Void, setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void, deletePeer: @escaping (EnginePeer.Id) -> Void, deleteAllExceptions: @escaping () -> Void) {
        self.context = context
        self.toggle = toggle
        self.updateMaximumVideoSize = updateMaximumVideoSize
        self.openAddException = openAddException
        self.openPeerMenu = openPeerMenu
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.deletePeer = deletePeer
        self.deleteAllExceptions = deleteAllExceptions
    }
}

enum SaveIncomingMediaSection: ItemListSectionId {
    case peer
    case mediaTypes
    case videoSize
    case exceptions
    case deleteAllExceptions
}

public enum SaveIncomingMediaEntryTag: ItemListItemTag, Equatable {
    case maxVideoSize
    case addException
    case deleteExceptions
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? SaveIncomingMediaEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum SaveIncomingMediaEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case peer
        
        case typesHeader
        case typePhotos
        case typeVideos
        case typesInfo
        
        case videoSizeHeader
        case videoSize
        case videoInfo
        
        case exceptionsHeader
        case addException
        case exceptionItem(EnginePeer.Id)
        
        case deleteAllExceptions
    }
    
    case peer(peer: EnginePeer, presence: EnginePeer.Presence?)
    
    case typesHeader(String)
    case typePhotos(String, Bool)
    case typeVideos(String, Bool)
    case typesInfo(String)
    
    case videoSizeHeader(String)
    case videoSize(decimalSeparator: String, text: String, value: Int64)
    case videoInfo(String)
    
    case exceptionsHeader(String)
    case addException(String)
    case exceptionItem(index: Int, peer: EnginePeer, label: String)
    
    case deleteAllExceptions(String)
    
    var section: ItemListSectionId {
        switch self {
        case .peer:
            return SaveIncomingMediaSection.peer.rawValue
        case .typesHeader, .typePhotos, .typeVideos, .typesInfo:
            return SaveIncomingMediaSection.mediaTypes.rawValue
        case .videoSizeHeader, .videoSize, .videoInfo:
            return SaveIncomingMediaSection.videoSize.rawValue
        case .exceptionsHeader, .addException, .exceptionItem:
            return SaveIncomingMediaSection.exceptions.rawValue
        case .deleteAllExceptions:
            return SaveIncomingMediaSection.deleteAllExceptions.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .peer:
            return .peer
        case .typesHeader:
            return .typesHeader
        case .typePhotos:
            return .typePhotos
        case .typeVideos:
            return .typeVideos
        case .typesInfo:
            return .typesInfo
        case .videoSizeHeader:
            return .videoSizeHeader
        case .videoSize:
            return .videoSize
        case .videoInfo:
            return .videoInfo
        case .exceptionsHeader:
            return .exceptionsHeader
        case .addException:
            return .addException
        case let .exceptionItem(_, peer, _):
            return .exceptionItem(peer.id)
        case .deleteAllExceptions:
            return .deleteAllExceptions
        }
    }
    
    var sortIndex: Int {
        switch self {
        case .peer:
            return 0
        case .typesHeader:
            return 1
        case .typePhotos:
            return 2
        case .typeVideos:
            return 3
        case .typesInfo:
            return 4
        case .videoSizeHeader:
            return 5
        case .videoSize:
            return 6
        case .videoInfo:
            return 7
        case .exceptionsHeader:
            return 8
        case .addException:
            return 9
        case let .exceptionItem(index, _, _):
            return 100 + index
        case .deleteAllExceptions:
            return 100000
        }
    }
    
    static func <(lhs: SaveIncomingMediaEntry, rhs: SaveIncomingMediaEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SaveIncomingMediaControllerArguments
        switch self {
        case let .peer(peer, presence):
            return ItemListAvatarAndNameInfoItem(
                itemContext: .accountContext(arguments.context),
                presentationData: presentationData,
                systemStyle: .glass,
                dateTimeFormat: PresentationDateTimeFormat(),
                mode: .generic,
                peer: peer,
                presence: presence,
                memberCount: nil,
                state: ItemListAvatarAndNameInfoItemState(),
                sectionId: self.section,
                style: .blocks(withTopInset: true, withExtendedBottomInset: false),
                editingNameUpdated: { _ in
                },
                avatarTapped: {
                }
            )
        case let .typesHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .typePhotos(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.photosLightBlue, title: title, value: value, sectionId: self.section, style: .blocks, updated: { _ in
                arguments.toggle(.photo)
            })
        case let .typeVideos(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.videosBlue, title: title, value: value, sectionId: self.section, style: .blocks, updated: { _ in
                arguments.toggle(.video)
            })
        case let .typesInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .videoSizeHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .videoSize(decimalSeparator, text, size):
            return AutodownloadSizeLimitItem(theme: presentationData.theme, strings: presentationData.strings, systemStyle: .glass, decimalSeparator: decimalSeparator, text: text, value: size, range: nil/*2 * 1024 * 1024 ..< (4 * 1024 * 1024 * 1024)*/, sectionId: self.section, updated: { value in
                arguments.updateMaximumVideoSize(value)
            }, tag: SaveIncomingMediaEntryTag.maxVideoSize)
        case let .videoInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .exceptionsHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .addException(title):
            let icon: UIImage? = PresentationResourcesItemList.createGroupIcon(presentationData.theme)
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: icon, title: title, alwaysPlain: false, sectionId: self.section, height: .generic, editing: false, action: {
                arguments.openAddException()
            }, tag: SaveIncomingMediaEntryTag.addException)
        case let .exceptionItem(_, peer, label):
            return ItemListPeerItem(
                presentationData: presentationData,
                systemStyle: .glass,
                dateTimeFormat: PresentationDateTimeFormat(),
                nameDisplayOrder: .firstLast,
                context: arguments.context,
                peer: peer,
                height: .generic,
                aliasHandling: .threatSelfAsSaved,
                nameColor: .primary,
                presence: nil,
                text: .text(label, .secondary),
                label: .none,
                editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: false),
                revealOptions: ItemListPeerItemRevealOptions(options: [ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                    arguments.deletePeer(peer.id)
                })]),
                switchValue: nil,
                enabled: true,
                selectable: true,
                sectionId: self.section,
                action: {
                    arguments.openPeerMenu(peer)
                },
                setPeerIdWithRevealedOptions: { lhs, rhs in
                    arguments.setPeerIdWithRevealedOptions(lhs, rhs)
                },
                removePeer: { id in
                    arguments.deletePeer(id)
                }
            )
            /*return ItemListDisclosureItem(presentationData: presentationData, icon: nil, context: arguments.context, iconPeer: peer, title: peer.displayTitle(strings: presentationData.strings, displayOrder: .firstLast), enabled: true, titleFont: .bold, label: label, labelStyle: .detailText, additionalDetailLabel: nil, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                arguments.openPeerMenu(peer)
            }, tag: nil)*/
        case let .deleteAllExceptions(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.deleteAllExceptions()
            }, tag: SaveIncomingMediaEntryTag.deleteExceptions)
        }
    }
}

private func saveIncomingMediaControllerEntries(presentationData: PresentationData, scope: SaveIncomingMediaScope, state: SaveIncomingMediaControllerState, peer: EnginePeer?, peerPresence: EnginePeer.Presence?, configuration: MediaAutoSaveConfiguration, exceptions: [MediaAutoSaveSettings.ExceptionItem], autosaveExceptionPeers: [EnginePeer.Id: EnginePeer?]) -> [SaveIncomingMediaEntry] {
    var entries: [SaveIncomingMediaEntry] = []
    
    if case .peer = scope, let peer {
        entries.append(.peer(peer: peer, presence: peerPresence))
    }
    
    entries.append(.typesHeader(presentationData.strings.Autosave_TypesSection))
    
    entries.append(.typePhotos(presentationData.strings.Autosave_TypePhoto, configuration.photo))
    entries.append(.typeVideos(presentationData.strings.Autosave_TypeVideo, configuration.video))
    entries.append(.typesInfo(presentationData.strings.Autosave_TypesInfo))
    
    if configuration.video {
        let sizeText: String
        if configuration.maximumVideoSize == Int64.max {
            sizeText = autodownloadDataSizeString(1536 * 1024 * 1024, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
        } else {
            sizeText = autodownloadDataSizeString(configuration.maximumVideoSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
        }
        
        let text = presentationData.strings.AutoDownloadSettings_UpTo(sizeText).string
        
        entries.append(.videoSizeHeader(presentationData.strings.Autosave_VideoSizeSection))
        entries.append(.videoSize(decimalSeparator: presentationData.dateTimeFormat.decimalSeparator, text: text, value: configuration.maximumVideoSize))
        entries.append(.videoInfo(presentationData.strings.Autosave_VideoInfo(sizeText).string))
    }
    
    if case let .peerType(peerType) = scope {
        var filteredExceptions: [(EnginePeer, MediaAutoSaveConfiguration)] = []
        for exception in exceptions {
            guard let maybeExceptionPeer = autosaveExceptionPeers[exception.id], let exceptionPeer = maybeExceptionPeer else {
                continue
            }
            let peerTypeValue: AutomaticSaveIncomingPeerType
            switch exceptionPeer {
            case .user, .secretChat:
                peerTypeValue = .privateChats
            case .legacyGroup:
                peerTypeValue = .groups
            case let .channel(channel):
                if case .broadcast = channel.info {
                    peerTypeValue = .channels
                } else {
                    peerTypeValue = .groups
                }
            case .community:
                continue
            }
            
            if peerTypeValue == peerType {
                filteredExceptions.append((exceptionPeer, exception.configuration))
            }
        }
        
        if filteredExceptions.isEmpty {
            entries.append(.exceptionsHeader(presentationData.strings.Autosave_ExceptionsSection))
        } else {
            entries.append(.exceptionsHeader(presentationData.strings.Notifications_CategoryExceptions(Int32(filteredExceptions.count)).uppercased()))
        }
        
        entries.append(.addException(presentationData.strings.Autosave_AddException))
        
        var index = 0
        for (exceptionPeer, exceptionConfiguration) in filteredExceptions {
            var label = ""
            if exceptionConfiguration.photo {
                if !label.isEmpty {
                    label.append(", ")
                }
                label.append(presentationData.strings.Settings_AutosaveMediaPhoto)
            } else {
                if !label.isEmpty {
                    label.append(", ")
                }
                label.append(presentationData.strings.Settings_AutosaveMediaNoPhoto)
            }
            if exceptionConfiguration.video {
                if !label.isEmpty {
                    label.append(", ")
                }
                label.append(presentationData.strings.Settings_AutosaveMediaVideo(dataSizeString(Int(exceptionConfiguration.maximumVideoSize), formatting: DataSizeStringFormatting(presentationData: presentationData))).string)
            } else {
                if !label.isEmpty {
                    label.append(", ")
                }
                label.append(presentationData.strings.Settings_AutosaveMediaNoVideo)
            }
            
            entries.append(.exceptionItem(index: index, peer: exceptionPeer, label: label))
            index += 1
        }
        
        if !filteredExceptions.isEmpty {
            entries.append(.deleteAllExceptions(presentationData.strings.Autosave_DeleteAllExceptions))
        }
    }
    
    return entries
}

public enum SaveIncomingMediaScope {
    case peer(EnginePeer.Id)
    case addPeer(id: EnginePeer.Id, completion: (MediaAutoSaveConfiguration) -> Void)
    case peerType(AutomaticSaveIncomingPeerType)
}

private struct SaveIncomingMediaControllerState: Equatable {
    var pendingConfiguration: MediaAutoSaveConfiguration = .default
    var peerIdWithOptions: EnginePeer.Id?
}

private func saveIncomingMediaScopeSettings(presentationData: PresentationData, scope: SaveIncomingMediaScope, state: SaveIncomingMediaControllerState, mediaAutoSaveSettings: MediaAutoSaveSettings) -> (configuration: MediaAutoSaveConfiguration, exceptions: [MediaAutoSaveSettings.ExceptionItem], title: String) {
    let configuration: MediaAutoSaveConfiguration
    var exceptions: [MediaAutoSaveSettings.ExceptionItem] = []
    let title: String
    switch scope {
    case let .peer(id):
        if let data = mediaAutoSaveSettings.exceptions.first(where: { $0.id == id }) {
            configuration = data.configuration
        } else {
            configuration = .default
        }
        title = presentationData.strings.Autosave_Exception
    case .addPeer:
        configuration = state.pendingConfiguration
        title = presentationData.strings.Autosave_AddException
    case let .peerType(peerType):
        exceptions = mediaAutoSaveSettings.exceptions
        switch peerType {
        case .privateChats:
            configuration = mediaAutoSaveSettings.configurations[.users] ?? .default
            title = presentationData.strings.Notifications_PrivateChats
        case .groups:
            configuration = mediaAutoSaveSettings.configurations[.groups] ?? .default
            title = presentationData.strings.Notifications_GroupChats
        case .channels:
            configuration = mediaAutoSaveSettings.configurations[.channels] ?? .default
            title = presentationData.strings.Notifications_Channels
        }
    }

    return (configuration, exceptions, title)
}


public func saveIncomingMediaController(context: AccountContext, scope: SaveIncomingMediaScope, focusOnItemTag: SaveIncomingMediaEntryTag? = nil, wegramStyle: Bool = false) -> ViewController {
    let stateValue = Atomic(value: SaveIncomingMediaControllerState())
    let statePromise = ValuePromise<SaveIncomingMediaControllerState>(stateValue.with { $0 })
    let updateState: ((SaveIncomingMediaControllerState) -> SaveIncomingMediaControllerState) -> Void = { f in
        var changed = false
        let value = stateValue.modify { current in
            let updated = f(current)
            if updated != current {
                changed = true
            }
            return updated
        }
        if changed {
            statePromise.set(value)
        }
    }
    
    var pushController: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var dismiss: (() -> Void)?
    
    let arguments = SaveIncomingMediaControllerArguments(
        context: context,
        toggle: { type in
            if case .addPeer = scope {
                updateState { state in
                    var state = state
                    
                    switch type {
                    case .photo:
                        state.pendingConfiguration.photo = !state.pendingConfiguration.photo
                    case .video:
                        state.pendingConfiguration.video = !state.pendingConfiguration.video
                    }
                    
                    return state
                }
            } else {
                let _ = updateMediaAutoSaveSettingsInteractively(account: context.account, { settings in
                    var settings = settings
                    
                    switch scope {
                    case let .peer(peerId):
                        if let index = settings.exceptions.firstIndex(where: { $0.id == peerId }) {
                            switch type {
                            case .photo:
                                settings.exceptions[index].configuration.photo = !settings.exceptions[index].configuration.photo
                            case .video:
                                settings.exceptions[index].configuration.video = !settings.exceptions[index].configuration.video
                            }
                        }
                    case .addPeer:
                        break
                    case let .peerType(peerType):
                        let mappedType: MediaAutoSaveSettings.PeerType
                        switch peerType {
                        case .privateChats:
                            mappedType = .users
                        case .groups:
                            mappedType = .groups
                        case .channels:
                            mappedType = .channels
                        }
                        var current = settings.configurations[mappedType] ?? .default
                        
                        switch type {
                        case .photo:
                            current.photo = !current.photo
                        case .video:
                            current.video = !current.video
                        }
                        
                        settings.configurations[mappedType] = current
                    }
                    
                    return settings
                }).start()
            }
        },
        updateMaximumVideoSize: { value in
            if case .addPeer = scope {
                updateState { state in
                    var state = state
                    
                    state.pendingConfiguration.maximumVideoSize = value
                    
                    return state
                }
            } else {
                let _ = updateMediaAutoSaveSettingsInteractively(account: context.account, { settings in
                    var settings = settings
                    
                    switch scope {
                    case let .peer(peerId):
                        if let index = settings.exceptions.firstIndex(where: { $0.id == peerId }) {
                            settings.exceptions[index].configuration.maximumVideoSize = value
                        }
                    case .addPeer:
                        break
                    case let .peerType(peerType):
                        let mappedType: MediaAutoSaveSettings.PeerType
                        switch peerType {
                        case .privateChats:
                            mappedType = .users
                        case .groups:
                            mappedType = .groups
                        case .channels:
                            mappedType = .channels
                        }
                        var current = settings.configurations[mappedType] ?? .default
                        current.maximumVideoSize = value
                        settings.configurations[mappedType] = current
                    }
                    
                    return settings
                }).start()
            }
        },
        openAddException: {
            guard case let .peerType(peerType) = scope else {
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var filter: ChatListNodePeersFilter = [.excludeRecent, .doNotSearchMessages, .removeSearchHeader]
            switch peerType {
            case .groups:
                filter.insert(.onlyGroups)
            case .privateChats:
                filter.insert(.onlyPrivateChats)
                filter.insert(.excludeSecretChats)
            case .channels:
                filter.insert(.onlyChannels)
            }
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: filter, hasContactSelector: false, title: presentationData.strings.Notifications_AddExceptionTitle))
            controller.peerSelected = { [weak controller] peer, _ in
                let peerId = peer.id
                
                let preferences = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.mediaAutoSaveSettings))
                |> map { entry -> MediaAutoSaveSettings in
                    return entry?.get(MediaAutoSaveSettings.self) ?? MediaAutoSaveSettings.default
                }
                
                let _ = (preferences
                |> take(1)
                |> deliverOnMainQueue).start(next: { settings in
                    if settings.exceptions.contains(where: { $0.id == peerId }) {
                        guard let controller = controller, let navigationController = controller.navigationController as? NavigationController else {
                            return
                        }
                        var controllers = navigationController.viewControllers
                        controllers = controllers.filter { item in
                            if item === controller {
                                return false
                            }
                            return true
                        }
                        controllers.append(saveIncomingMediaController(context: context, scope: .peer(peerId), wegramStyle: wegramStyle))
                        navigationController.setViewControllers(controllers, animated: true)
                    } else {
                        var dismissAll: (() -> Void)?
                        let exceptionController = saveIncomingMediaController(context: context, scope: .addPeer(id: peerId, completion: { configuration in
                            let _ = updateMediaAutoSaveSettingsInteractively(account: context.account, { settings in
                                var settings = settings
                                
                                settings.exceptions.removeAll(where: { $0.id == peerId })
                                settings.exceptions.insert(MediaAutoSaveSettings.ExceptionItem(id: peerId, configuration: configuration), at: 0)
                                
                                return settings
                            }).start()
                            
                            dismissAll?()
                        }), wegramStyle: wegramStyle)
                        controller?.push(exceptionController)
                        
                        dismissAll = { [weak exceptionController] in
                            guard let exceptionController = exceptionController else {
                                return
                            }
                            guard let navigationController = exceptionController.navigationController as? NavigationController else {
                                return
                            }
                            var controllers = navigationController.viewControllers
                            controllers = controllers.filter { item in
                                if item === exceptionController || item === controller {
                                    return false
                                }
                                return true
                            }
                            navigationController.setViewControllers(controllers, animated: true)
                        }
                    }
                })
            }
            pushController?(controller)
        },
        openPeerMenu: { peer in
            pushController?(saveIncomingMediaController(context: context, scope: .peer(peer.id), wegramStyle: wegramStyle))
        },
        setPeerIdWithRevealedOptions: { itemId, fromItemId in
            updateState { state in
                var state = state
                if (itemId == nil && fromItemId == state.peerIdWithOptions) || (itemId != nil && fromItemId == nil) {
                    state.peerIdWithOptions = itemId
                }
                return state
            }
        },
        deletePeer: { id in
            let _ = updateMediaAutoSaveSettingsInteractively(account: context.account, { settings in
                var settings = settings
                
                settings.exceptions.removeAll(where: { $0.id == id })
                
                return settings
            }).start()
        },
        deleteAllExceptions: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = wegramStyle ? ActionSheetController(theme: ActionSheetControllerTheme(wegramTheme: presentationData.theme, fontSize: presentationData.listsFontSize)) : ActionSheetController(presentationData: presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Autosave_DeleteAllExceptions, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    let _ = updateMediaAutoSaveSettingsInteractively(account: context.account, { settings in
                        var settings = settings
                        
                        settings.exceptions.removeAll()
                        
                        return settings
                    }).start()
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            presentControllerImpl?(actionSheet)
        }
    )
    
    let preferences = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.mediaAutoSaveSettings))
    |> map { entry -> MediaAutoSaveSettings in
        return entry?.get(MediaAutoSaveSettings.self) ?? MediaAutoSaveSettings.default
    }
    
    let peer: Signal<(EnginePeer?, EnginePeer.Presence?), NoError>
    switch scope {
    case let .peer(id):
        peer = context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: id),
            TelegramEngine.EngineData.Item.Peer.Presence(id: id)
        )
    case let .addPeer(id, _):
        peer = context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: id),
            TelegramEngine.EngineData.Item.Peer.Presence(id: id)
        )
    default:
        peer = .single((nil, nil))
    }
    
    let autosaveExceptionPeers: Signal<[EnginePeer.Id: EnginePeer?], NoError> = preferences
    |> mapToSignal { mediaAutoSaveSettings -> Signal<[EnginePeer.Id: EnginePeer?], NoError> in
        let peerIds = mediaAutoSaveSettings.exceptions.map(\.id)
        return context.engine.data.get(EngineDataMap(
            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))
        ))
    }
    
    struct StoredState {
        var entryCount: Int
        var hasVideo: Bool
    }
    
    let previousState = Atomic<StoredState?>(value: nil)
    
    let source = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get(), preferences, peer, autosaveExceptionPeers)
    |> deliverOnMainQueue

    let complete: () -> Void = {
        switch scope {
        case let .addPeer(_, completion):
            let configuration = stateValue.with({ $0 }).pendingConfiguration
            completion(configuration)
        default:
            dismiss?()
        }
    }
    let isPeerType: Bool
    switch scope { case .peerType: isPeerType = true; default: isPeerType = false }
    if wegramStyle, focusOnItemTag == nil || (isPeerType && focusOnItemTag == .addException) {
        let controller = WegramSaveIncomingMediaController(context: context, scope: scope, arguments: arguments, source: source, exceptionsOnly: focusOnItemTag == .addException, complete: isPeerType ? nil : complete)
        if !isPeerType { controller.navigationPresentation = .modal }
        pushController = { [weak controller] c in controller?.push(c) }
        presentControllerImpl = { [weak controller] c in controller?.present(c, in: .window(.root)) }
        dismiss = { [weak controller] in controller?.dismiss() }
        return controller
    }
    let signal = source |> map { presentationData, state, mediaAutoSaveSettings, peer, autosaveExceptionPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var rightButton: ItemListNavigationButton?
        
        switch scope {
        case .peer, .addPeer:
            rightButton = ItemListNavigationButton(content: .icon(.done), style: .bold, enabled: true, action: complete)
        default:
            break
        }
        
        let values = saveIncomingMediaScopeSettings(presentationData: presentationData, scope: scope, state: state, mediaAutoSaveSettings: mediaAutoSaveSettings)
        let configuration = values.configuration
        let exceptions = values.exceptions
        let title = values.title

        let entries = saveIncomingMediaControllerEntries(presentationData: presentationData, scope: scope, state: state, peer: peer.0, peerPresence: peer.1, configuration: configuration, exceptions: exceptions, autosaveExceptionPeers: autosaveExceptionPeers)
        
        var animateChanges = false
        let storedState = StoredState(
            entryCount: entries.count,
            hasVideo: entries.contains(where: { entry in
                switch entry {
                case .videoSize:
                    return true
                default:
                    return false
                }
            })
        )
        if let previous = previousState.swap(storedState) {
            if previous.entryCount > storedState.entryCount || previous.hasVideo != storedState.hasVideo {
                animateChanges = true
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: focusOnItemTag, emptyStateItem: nil, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    switch scope {
    case .peer, .addPeer:
        controller.navigationPresentation = .modal
    default:
        break
    }
    
    pushController = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    dismiss = { [weak controller] in
        controller?.dismiss()
    }
    
    if let focusOnItemTag {
        var didFocusOnItem = false
        controller.afterTransactionCompleted = { [weak controller] in
            if !didFocusOnItem, let controller {
                controller.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ItemListItemNode, let tag = itemNode.tag, tag.isEqual(to: focusOnItemTag) {
                        didFocusOnItem = true
                        itemNode.displayHighlight()
                    }
                }
            }
        }
    }
    
    return controller
}


private typealias WegramSaveIncomingMediaSource = (PresentationData, SaveIncomingMediaControllerState, MediaAutoSaveSettings, (EnginePeer?, EnginePeer.Presence?), [EnginePeer.Id: EnginePeer?])

private final class WegramSaveIncomingMediaController: ViewController {
    private let context: AccountContext
    private let scope: SaveIncomingMediaScope
    private let arguments: SaveIncomingMediaControllerArguments
    private var presentationData: PresentationData
    private let sourceDisposable = MetaDisposable()
    private let content = WegramDownloadCategoryContentView()
    private let exceptionsContent = WegramAutoSaveExceptionsContentView()
    private let exceptionsOnly: Bool
    private let complete: (() -> Void)?
    private let doneButton = WegramNameSaveButton()
    private lazy var doneNode: ASDisplayNode = {
        let node = ASDisplayNode(viewBlock: { [button = self.doneButton] in button })
        node.style.preferredSize = CGSize(width: 64, height: 44)
        return node
    }()
    private let peerAvatar = AvatarNode(font: avatarPlaceholderFont(size: 16))
    private var exceptionPeers: [EnginePeer] = []
    private var avatars: [ObjectIdentifier: AvatarNode] = [:]
    private let titleButton = UIButton(type: .custom)
    private let backButton = ASButtonNode()
    private var current: WegramSaveIncomingMediaSource?
    private var loaded = false
    private var hasVideoSize = false

    init(context: AccountContext, scope: SaveIncomingMediaScope, arguments: SaveIncomingMediaControllerArguments, source: Signal<WegramSaveIncomingMediaSource, NoError>, exceptionsOnly: Bool, complete: (() -> Void)?) {
        self.complete = complete
        self.exceptionsOnly = exceptionsOnly
        self.context = context
        self.scope = scope
        self.arguments = arguments
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: self.presentationData.theme), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.titleButton.titleLabel?.font = wegramNavigationTitleFont
        self.titleButton.accessibilityIdentifier = "Wegram.AutoSave.OriginalSettings"
        self.titleButton.addAction(UIAction(handler: { [weak self] _ in self?.openOriginal(focus: self?.exceptionsOnly == true ? .addException : nil) }), for: .touchUpInside)
        self.navigationItem.titleView = self.titleButton
        self.doneButton.accessibilityIdentifier = "Wegram.AutoSave.Done"
        self.doneButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.loaded else { return }
            self.complete?()
        }), for: .touchUpInside)
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.content.toggle = { [weak self] field in
            guard let self, self.loaded else { return }
            switch field {
            case .photo: self.arguments.toggle(.photo)
            case .video: self.arguments.toggle(.video)
            default: return
            }
        }
        self.content.adjustSize = { [weak self] bytes in
            guard let self, self.loaded, self.hasVideoSize else { return }
            self.arguments.updateMaximumVideoSize(bytes)
        }
        self.content.openAction = { [weak self] in
            guard let self, self.loaded else { return }
            self.push(saveIncomingMediaController(context: self.context, scope: self.scope, focusOnItemTag: .addException, wegramStyle: true))
        }
        self.exceptionsContent.add = { [weak self] in
            guard let self, self.loaded else { return }
            self.arguments.openAddException()
        }
        self.exceptionsContent.open = { [weak self] id in
            guard let self, self.loaded, let peer = self.exceptionPeers.first(where: { $0.id.toInt64() == id }) else { return }
            self.arguments.openPeerMenu(peer)
        }
        self.exceptionsContent.remove = { [weak self] id in
            guard let self, self.loaded, let peer = self.exceptionPeers.first(where: { $0.id.toInt64() == id }) else { return }
            self.arguments.deletePeer(peer.id)
        }
        self.exceptionsContent.deleteAll = { [weak self] in
            guard let self, self.loaded, !self.exceptionPeers.isEmpty else { return }
            self.arguments.deleteAllExceptions()
        }
        self.exceptionsContent.configureAvatar = { [weak self] id, host in
            guard let self, let peer = self.exceptionPeers.first(where: { $0.id.toInt64() == id }) else { return }
            let key = ObjectIdentifier(host)
            let avatar = self.avatars[key] ?? AvatarNode(font: avatarPlaceholderFont(size: 16))
            self.avatars[key] = avatar
            avatar.cornerRadius = 4
            avatar.clipsToBounds = true
            if avatar.view.superview !== host { host.addSubview(avatar.view) }
            avatar.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            avatar.updateSize(size: CGSize(width: 40, height: 40))
            avatar.setPeer(context: self.context, theme: self.presentationData.theme, peer: peer, clipStyle: .none, displayDimensions: CGSize(width: 40, height: 40))
        }
        self.sourceDisposable.set(source.startStrict(next: { [weak self] value in
            self?.current = value
            self?.presentationData = value.0
            self?.updatePresentation()
        }))
        self.updatePresentation()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { self.sourceDisposable.dispose() }
    private func openOriginal(focus: SaveIncomingMediaEntryTag?) {
        self.push(saveIncomingMediaController(context: self.context, scope: self.scope, focusOnItemTag: focus))
    }
    private func updatePresentation() {
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let dark = data.theme.overallDarkAppearance
        let font = data.listsFontSize.itemListBaseFontSize
        let color = WegramNavigationColors(isDark: dark).control
        self.content.update(dark: dark, fontSize: font, chinese: chinese)
        self.content.formatSize = { autodownloadDataSizeString($0, decimalSeparator: data.dateTimeFormat.decimalSeparator) }
        var headerPeer: EnginePeer?
        var heading = ""
        var sectionInfo = ""
        var footer = ""
        var title = chinese ? "自动保存到相册" : "Save to Photos"
        var rules: [WegramDownloadToggle] = []
        var sizeHeading = ""
        var size: WegramDownloadSize?
        var exceptionCount = 0
        var hasExceptions = false
        var exceptionRows: [WegramAutoSaveExceptionRow] = []
        var addTitle = data.strings.Autosave_AddException
        var deleteAllTitle = data.strings.Autosave_DeleteAllExceptions
        self.exceptionPeers = []
        if let current = self.current {
            let values = saveIncomingMediaScopeSettings(presentationData: data, scope: self.scope, state: current.1, mediaAutoSaveSettings: current.2)
            title = values.title
            for entry in saveIncomingMediaControllerEntries(presentationData: data, scope: self.scope, state: current.1, peer: current.3.0, peerPresence: current.3.1, configuration: values.configuration, exceptions: values.exceptions, autosaveExceptionPeers: current.4) {
                switch entry {
                case let .peer(peer, _): headerPeer = peer
                case let .typesHeader(text): heading = text
                case let .typePhotos(text, value): rules.append(WegramDownloadToggle(field: .photo, title: text, value: value, enabled: true))
                case let .typeVideos(text, value): rules.append(WegramDownloadToggle(field: .video, title: text, value: value, enabled: true))
                case let .typesInfo(text): sectionInfo = text
                case let .videoSizeHeader(text): sizeHeading = text
                case let .videoSize(decimal, text, bytes):
                    size = WegramDownloadSize(heading: sizeHeading, text: text, bytes: bytes, minimum: autodownloadDataSizeString(512 * 1024, decimalSeparator: decimal), maximum: autodownloadDataSizeString(1536 * 1024 * 1024, decimalSeparator: decimal))
                case let .videoInfo(text): footer = text
                case let .addException(text):
                    hasExceptions = true
                    addTitle = text
                case let .exceptionItem(_, peer, label):
                    exceptionCount += 1
                    self.exceptionPeers.append(peer)
                    exceptionRows.append(WegramAutoSaveExceptionRow(id: peer.id.toInt64(), name: peer.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder), summary: label))
                case let .deleteAllExceptions(text): deleteAllTitle = text
                default: break
                }
            }
        }
        self.loaded = self.current != nil
        self.exceptionsContent.update(dark: dark, fontSize: font, addTitle: addTitle, deleteAllTitle: deleteAllTitle, deleteTitle: data.strings.Common_Delete, emptyTitle: chinese ? "暂无例外" : "No Exceptions")
        self.exceptionsContent.load(rows: exceptionRows, loaded: self.loaded)
        if self.exceptionsOnly { title = data.strings.Autosave_ExceptionsSection }
        self.hasVideoSize = size != nil
        let action = hasExceptions ? WegramMediaRuleAction(title: chinese ? "例外" : "Exceptions", value: "\(exceptionCount)") : nil
        self.content.load(heading: heading, rules: rules, size: size, footer: footer, sectionInfo: sectionInfo, action: action, peerName: headerPeer?.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder))
        if let headerPeer {
            self.peerAvatar.cornerRadius = 4
            self.peerAvatar.clipsToBounds = true
            let host = self.content.peerHeader.avatarHost
            if self.peerAvatar.view.superview !== host { host.addSubview(self.peerAvatar.view) }
            self.peerAvatar.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            self.peerAvatar.updateSize(size: CGSize(width: 40, height: 40))
            self.peerAvatar.setPeer(context: self.context, theme: data.theme, peer: headerPeer, clipStyle: .none, displayDimensions: CGSize(width: 40, height: 40))
        }
        let gray = UIColor(rgb: dark ? 0x888888 : 0x777777)
        let attributes = MarkdownAttributes(body: MarkdownAttributeSet(font: Font.regular(font * 13 / 17), textColor: gray), bold: MarkdownAttributeSet(font: Font.semibold(font * 13 / 17), textColor: gray), link: MarkdownAttributeSet(font: Font.regular(font * 13 / 17), textColor: UIColor(rgb: 0x07c160)), linkAttribute: { _ in nil })
        self.content.sectionInfo.attributedText = parseMarkdownIntoAttributedString(sectionInfo, attributes: attributes)
        self.content.footer.attributedText = parseMarkdownIntoAttributedString(footer, attributes: attributes)
        self.titleButton.setTitle(title, for: .normal)
        self.titleButton.setTitleColor(color, for: .normal)
        self.titleButton.isUserInteractionEnabled = self.complete == nil
        self.titleButton.accessibilityTraits = self.complete == nil ? .button : .header
        self.titleButton.accessibilityHint = self.complete == nil ? (chinese ? "打开完整自动保存与例外管理" : "Open full automatic saving and exception management") : nil
        self.doneButton.setTitle(data.strings.Common_Done, for: .normal)
        self.doneButton.accessibilityLabel = data.strings.Common_Done
        self.doneButton.isEnabled = self.loaded
        self.doneButton.accessibilityTraits = self.loaded ? .button : [.button, .notEnabled]
        if self.complete != nil {
            let done = UIBarButtonItem(customDisplayNode: self.doneNode)
            done?.isEnabled = self.loaded
            done?.accessibilityLabel = data.strings.Common_Done
            self.navigationItem.rightBarButtonItem = done
        }
        self.titleButton.sizeToFit()
        self.titleButton.bounds.size.height = 44
        let image = wegramNavigationBackArrowImage(color: color)
        self.backButton.setImage(image, for: .normal)
        let backSize = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - backSize.height) / 2, left: 0, bottom: (44 - backSize.height) / 2, right: 44 - backSize.width)
        let back = UIBarButtonItem(customDisplayNode: self.backButton)
        back?.target = self
        back?.action = #selector(self.backPressed)
        back?.accessibilityLabel = data.strings.Common_Back
        self.navigationItem.leftBarButtonItem = back
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: data.theme), strings: NavigationBarStrings(presentationStrings: data.strings)), transition: .immediate)
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        if self.isNodeLoaded { self.displayNode.backgroundColor = self.content.backgroundColor }
    }
    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.view.addSubview(self.exceptionsOnly ? self.exceptionsContent : self.content)
        self.updatePresentation()
        self.displayNodeDidLoad()
    }
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.content.contentInset.bottom = layout.intrinsicInsets.bottom
        self.content.verticalScrollIndicatorInsets.bottom = layout.intrinsicInsets.bottom
        self.exceptionsContent.table.contentInset.bottom = layout.intrinsicInsets.bottom
        self.exceptionsContent.table.verticalScrollIndicatorInsets.bottom = layout.intrinsicInsets.bottom
        transition.updateFrame(view: self.exceptionsOnly ? self.exceptionsContent : self.content, frame: CGRect(x: layout.safeInsets.left, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(0, layout.size.height - top)))
    }
    @objc private func backPressed() { self.dismiss() }
}
