import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import AppBundle
import CoreLocation
import PresentationDataUtils
import OpenInExternalAppUI
import DeviceAccess
import UndoUI
import MapKit
import AvatarNode

public class LocationViewParams {
    let sendLiveLocation: (TelegramMediaMap) -> Void
    let stopLiveLocation: (EngineMessage.Id?) -> Void
    let openUrl: (String) -> Void
    let openPeer: (EnginePeer) -> Void
    let showAll: Bool
    let allowMessageSaving: Bool
        
    public init(sendLiveLocation: @escaping (TelegramMediaMap) -> Void, stopLiveLocation: @escaping (EngineMessage.Id?) -> Void, openUrl: @escaping (String) -> Void, openPeer: @escaping (EnginePeer) -> Void, showAll: Bool = false, allowMessageSaving: Bool = false) {
        self.sendLiveLocation = sendLiveLocation
        self.stopLiveLocation = stopLiveLocation
        self.openUrl = openUrl
        self.openPeer = openPeer
        self.showAll = showAll
        self.allowMessageSaving = allowMessageSaving
    }
}

final class LocationViewInteraction {
    let toggleMapModeSelection: () -> Void
    let updateMapMode: (LocationMapMode) -> Void
    let toggleTrackingMode: () -> Void
    let goToCoordinate: (CLLocationCoordinate2D) -> Void
    let requestDirections: (TelegramMediaMap, String?, OpenInLocationDirections) -> Void
    let share: () -> Void
    let setupProximityNotification: (Bool, EngineMessage.Id?) -> Void
    let sendLiveLocation: (Int32?, Bool, EngineMessage.Id?) -> Void
    let stopLiveLocation: () -> Void
    let present: (ViewController) -> Void
    
    init(toggleMapModeSelection: @escaping () -> Void, updateMapMode: @escaping (LocationMapMode) -> Void, toggleTrackingMode: @escaping () -> Void, goToCoordinate: @escaping (CLLocationCoordinate2D) -> Void, requestDirections: @escaping (TelegramMediaMap, String?, OpenInLocationDirections) -> Void, share: @escaping () -> Void, setupProximityNotification: @escaping (Bool, EngineMessage.Id?) -> Void, sendLiveLocation: @escaping (Int32?, Bool, EngineMessage.Id?) -> Void, stopLiveLocation: @escaping () -> Void, present: @escaping (ViewController) -> Void) {
        self.toggleMapModeSelection = toggleMapModeSelection
        self.updateMapMode = updateMapMode
        self.toggleTrackingMode = toggleTrackingMode
        self.goToCoordinate = goToCoordinate
        self.requestDirections = requestDirections
        self.share = share
        self.setupProximityNotification = setupProximityNotification
        self.sendLiveLocation = sendLiveLocation
        self.stopLiveLocation = stopLiveLocation
        self.present = present
    }
}

public final class LocationViewController: ViewController {
    private var controllerNode: LocationViewControllerNode {
        return self.displayNode as! LocationViewControllerNode
    }
    private let context: AccountContext
    public var subject: EngineMessage
    private var basePresentationData: PresentationData
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var currentMapMode: LocationMapMode = .map
    private var showAll: Bool
    private let isPreview: Bool
    private let allowMessageSaving: Bool
    private let wegramOpenUrl: (String) -> Void
    private let wegramSaveDisposable = MetaDisposable()
    private var wegramSaveInFlight = false
    private weak var wegramSaveSheet: ViewController?
    private weak var wegramTaxiSheet: ActionSheetController?
    private weak var wegramLocationShareSheet: ActionSheetController?
    private let wegramRecentPeersDisposable = MetaDisposable()
    private let wegramCopyDisposable = MetaDisposable()
    
    private let locationManager = LocationManager()
    
    private var interaction: LocationViewInteraction?
        
    public var dismissed: () -> Void = {}

    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        subject: EngineMessage,
        isPreview: Bool = false,
        params: LocationViewParams
    ) {
        self.context = context
        self.subject = subject
        self.showAll = params.showAll
        self.isPreview = isPreview
        self.allowMessageSaving = params.allowMessageSaving
        self.wegramOpenUrl = params.openUrl
        
        let initialPresentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.basePresentationData = initialPresentationData
        self.presentationData = LocationViewController.effectivePresentationData(initialPresentationData, mapMode: .map)
                     
        super.init(navigationBarPresentationData: nil)
        
        self._hasGlassStyle = true
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationPresentation = .modal
                
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self, strongSelf.basePresentationData.theme !== presentationData.theme else {
                return
            }
            strongSelf.basePresentationData = presentationData
            strongSelf.updateEffectivePresentationData(animated: true)
        })
                
        self.interaction = LocationViewInteraction(toggleMapModeSelection: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = !state.displayingMapModeOptions
                return state
            }
        }, updateMapMode: { [weak self] mode in
            guard let strongSelf = self else {
                return
            }
            strongSelf.currentMapMode = mode
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.mapMode = mode
                state.displayingMapModeOptions = false
                return state
            }
            strongSelf.updateEffectivePresentationData(animated: true)
        }, toggleTrackingMode: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                switch state.trackingMode {
                    case .none:
                        state.trackingMode = .follow
                    case .follow:
                        state.trackingMode = .followWithHeading
                    case .followWithHeading:
                        state.trackingMode = .none
                }
                return state
            }
        }, goToCoordinate: { [weak self] coordinate in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                state.selectedLocation = .coordinate(coordinate, false)
                return state
            }
        }, requestDirections: { [weak self] location, peerName, directions in
            guard let strongSelf = self else {
                return
            }
            let item: OpenInItem = .location(location: location, directions: directions)
            let openInOptions = availableOpenInOptions(context: context, item: item)
            if openInOptions.count == 1, let action = openInOptions.first?.action() {
                if case let .openLocation(latitude, longitude, directions) = action {
                    let placemark = MKPlacemark(coordinate: CLLocationCoordinate2DMake(latitude, longitude), addressDictionary: [:])
                    let mapItem = MKMapItem(placemark: placemark)
                    if let title = location.venue?.title {
                        mapItem.name = title
                    } else if let peerName = peerName {
                        mapItem.name = peerName
                    }
                    
                    if let directions = directions {
                        let options = [ MKLaunchOptionsDirectionsModeKey: directions.launchOptions ]
                        MKMapItem.openMaps(with: [MKMapItem.forCurrentLocation(), mapItem], launchOptions: options)
                    } else {
                        mapItem.openInMaps(launchOptions: nil)
                    }
                }
            } else {
                strongSelf.push(OpenInOptionsScreen(context: context, updatedPresentationData: updatedPresentationData, item: .location(location: location, directions: directions), additionalAction: nil, openUrl: params.openUrl))
            }
        }, share: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let location = getLocation(from: strongSelf.subject) {
                let shareAction = OpenInControllerAction(title: strongSelf.presentationData.strings.Conversation_ContextMenuShare, action: {
                    strongSelf.present(context.sharedContext.makeShareController(context: context, params: ShareControllerParams(subject: .mapMedia(location), externalShare: true)), in: .window(.root), with: nil)
                })
                strongSelf.push(OpenInOptionsScreen(context: context, updatedPresentationData: updatedPresentationData, item: .location(location: location, directions: nil), additionalAction: shareAction, openUrl: params.openUrl))
            }
        }, setupProximityNotification: { [weak self] reset, messageId in
            guard let strongSelf = self else {
                return
            }
            
            if reset {
                if let messageId = messageId {
                    strongSelf.controllerNode.updateState { state in
                        var state = state
                        state.cancellingProximityRadius = true
                        return state
                    }
                    
                    let _ = context.engine.messages.requestEditLiveLocation(messageId: messageId, stop: false, coordinate: nil, heading: nil, proximityNotificationRadius: 0, extendPeriod: nil).start(completed: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        Queue.mainQueue().after(0.5) {
                            strongSelf.controllerNode.updateState { state in
                                var state = state
                                state.cancellingProximityRadius = false
                                return state
                            }
                        }
                    })
                    
                    strongSelf.dismissAllTooltips()
                    strongSelf.present(
                        UndoOverlayController(
                            presentationData: strongSelf.presentationData,
                            content: .setProximityAlert(
                                title: strongSelf.presentationData.strings.Location_ProximityAlertCancelled,
                                text: "",
                                cancelled: true
                            ),
                            elevatedLayout: false,
                            action: { action in
                                return true
                            }
                        ),
                        in: .current
                    )
                }
            } else {
                DeviceAccess.authorizeAccess(to: .location(.live), locationManager: strongSelf.locationManager, presentationData: strongSelf.presentationData, present: { c, a in
                    strongSelf.present(c, in: .window(.root), with: a)
                }, openSettings: {
                    context.sharedContext.applicationBindings.openSettings()
                }, { [weak self] authorized in
                    guard let strongSelf = self, authorized else {
                        return
                    }
                    strongSelf.controllerNode.setProximityIndicator(radius: 0)
                    
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.subject.id.peerId))
                    |> mapToSignal { peer -> Signal<EnginePeer, NoError> in
                        if let peer {
                            return .single(peer)
                        } else {
                            return .never()
                        }
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                        guard let strongSelf = self else {
                            return
                        }

                        var compactDisplayTitle: String?
                        if case .user = peer {
                            compactDisplayTitle = peer.compactDisplayTitle
                        }

                        let controller = LocationDistancePickerScreen(context: context, style: .default, compactDisplayTitle: compactDisplayTitle, distances: strongSelf.controllerNode.headerNode.mapNode.distancesToAllAnnotations, updated: { [weak self] distance in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.controllerNode.setProximityIndicator(radius: distance)
                        }, completion: { [weak self] distance, completion in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if let messageId = messageId {
                                strongSelf.controllerNode.updateState { state in
                                    var state = state
                                    state.updatingProximityRadius = distance
                                    return state
                                }
                                
                                let _ = context.engine.messages.requestEditLiveLocation(messageId: messageId, stop: false, coordinate: nil, heading: nil, proximityNotificationRadius: distance, extendPeriod: nil).start(completed: { [weak self] in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    Queue.mainQueue().after(0.5) {
                                        strongSelf.controllerNode.updateState { state in
                                            var state = state
                                            state.updatingProximityRadius = nil
                                            return state
                                        }
                                    }
                                })
                                
                                var text: String
                                let distanceString = shortStringForDistance(strings: strongSelf.presentationData.strings, distance: distance)
                                if let compactDisplayTitle = compactDisplayTitle {
                                    text = strongSelf.presentationData.strings.Location_ProximityAlertSetText(compactDisplayTitle, distanceString).string
                                } else {
                                    text = strongSelf.presentationData.strings.Location_ProximityAlertSetTextGroup(distanceString).string
                                }
                                
                                strongSelf.dismissAllTooltips()
                                strongSelf.present(
                                    UndoOverlayController(
                                        presentationData: strongSelf.presentationData,
                                        content: .setProximityAlert(
                                            title: strongSelf.presentationData.strings.Location_ProximityAlertSetTitle,
                                            text: text,
                                            cancelled: false
                                        ),
                                        elevatedLayout: false,
                                        action: { action in
                                            return true
                                        }
                                    ),
                                    in: .current
                                )
                            } else {
                                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: updatedPresentationData, title: strongSelf.presentationData.strings.Location_LiveLocationRequired_Title, text: strongSelf.presentationData.strings.Location_LiveLocationRequired_Description, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Location_LiveLocationRequired_ShareLocation, action: {
                                    completion()
                                    strongSelf.interaction?.sendLiveLocation(distance, false, nil)
                                }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {})], actionLayout: .vertical), in: .window(.root))
                            }
                            completion()
                        }, willDismiss: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.controllerNode.setProximityIndicator(radius: nil)
                            }
                        })
                        strongSelf.present(controller, in: .window(.root))
                    })
                })
            }
        }, sendLiveLocation: { [weak self] distance, extend, messageId in
            guard let strongSelf = self else {
                return
            }
            DeviceAccess.authorizeAccess(to: .location(.live), locationManager: strongSelf.locationManager, presentationData: strongSelf.presentationData, present: { c, a in
                strongSelf.present(c, in: .window(.root), with: a)
            }, openSettings: {
                context.sharedContext.applicationBindings.openSettings()
            }, { [weak self] authorized in
                guard let strongSelf = self, authorized else {
                    return
                }
                
                if let distance = distance {
                    let _ = (strongSelf.controllerNode.coordinate
                    |> deliverOnMainQueue).start(next: { coordinate in
                        params.sendLiveLocation(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: 30 * 60, proximityNotificationRadius: distance))
                    })
                    
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.subject.id.peerId))
                    |> mapToSignal { peer -> Signal<EnginePeer, NoError> in
                        if let peer {
                            return .single(peer)
                        } else {
                            return .never()
                        }
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                        guard let strongSelf = self else {
                            return
                        }

                        var compactDisplayTitle: String?
                        if case .user = peer {
                            compactDisplayTitle = peer.compactDisplayTitle
                        }

                        var text: String
                        let distanceString = shortStringForDistance(strings: strongSelf.presentationData.strings, distance: distance)
                        if let compactDisplayTitle = compactDisplayTitle {
                            text = strongSelf.presentationData.strings.Location_ProximityAlertSetText(compactDisplayTitle, distanceString).string
                        } else {
                            text = strongSelf.presentationData.strings.Location_ProximityAlertSetTextGroup(distanceString).string
                        }
                        
                        strongSelf.dismissAllTooltips()
                        strongSelf.present(
                            UndoOverlayController(
                                presentationData: strongSelf.presentationData,
                                content: .setProximityAlert(
                                    title: strongSelf.presentationData.strings.Location_ProximityAlertSetTitle,
                                    text: text,
                                    cancelled: false
                                ),
                                elevatedLayout: false,
                                action: { action in
                                    return true
                                }
                            ),
                            in: .current
                        )
                    })
                } else {
                    let _  = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: subject.id.peerId))
                    |> mapToSignal { peer -> Signal<EnginePeer, NoError> in
                        if let peer {
                            return .single(peer)
                        } else {
                            return .never()
                        }
                    }
                    |> deliverOnMainQueue).start(next: { peer in
                        var title: String
                        if extend {
                            title = strongSelf.presentationData.strings.Map_LiveLocationExtendDescription
                        } else {
                            title = strongSelf.presentationData.strings.Map_LiveLocationGroupNewDescription
                            if case .user = peer {
                                title = strongSelf.presentationData.strings.Map_LiveLocationPrivateNewDescription(peer.compactDisplayTitle).string
                            }
                        }

                        let sourceView = strongSelf.controllerNode.liveLocationActionSourceView(extend: extend) ?? strongSelf.view
                        let controller = makeLiveLocationDurationContextController(
                            presentationData: strongSelf.presentationData,
                            sourceView: sourceView!,
                            title: title,
                            selectPeriod: { [weak self] period in
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                if extend {
                                    if let messageId {
                                        let _ = context.engine.messages.requestEditLiveLocation(messageId: messageId, stop: false, coordinate: nil, heading: nil, proximityNotificationRadius: nil, extendPeriod: period).start()
                                    }
                                } else {
                                    let _ = (strongSelf.controllerNode.coordinate
                                    |> deliverOnMainQueue).start(next: { coordinate in
                                        params.sendLiveLocation(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: period))
                                    })
                                    
                                    strongSelf.controllerNode.showAll()
                                }
                            }
                        )
                        strongSelf.presentInGlobalOverlay(controller)
                    })
                }
            })
        }, stopLiveLocation: { [weak self] in
            params.stopLiveLocation(nil)
            self?.dismiss()
        }, present: { [weak self] c in
            if let strongSelf = self {
                strongSelf.present(c, in: .window(.root))
            }
        })
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.scrollToTop()
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.wegramSaveDisposable.dispose()
        self.wegramRecentPeersDisposable.dispose()
        self.wegramCopyDisposable.dispose()
    }

    private static func effectivePresentationData(_ presentationData: PresentationData, mapMode: LocationMapMode) -> PresentationData {
        switch mapMode {
        case .satellite, .hybrid:
            if presentationData.theme.overallDarkAppearance {
                return presentationData
            }
            let darkTheme = customizeDefaultDarkPresentationTheme(
                theme: defaultDarkPresentationTheme,
                editing: false,
                title: nil,
                accentColor: presentationData.theme.list.itemAccentColor,
                backgroundColors: [],
                bubbleColors: [],
                animateBubbleColors: false,
                wallpaper: nil,
                baseColor: nil
            )
            return presentationData.withUpdated(theme: darkTheme)
        case .map:
            return presentationData
        }
    }

    private func updateEffectivePresentationData(animated: Bool) {
        let presentationData = LocationViewController.effectivePresentationData(self.basePresentationData, mapMode: self.currentMapMode)
        self.presentationData = presentationData
        self.statusBar.updateStatusBarStyle(presentationData.theme.rootController.statusBarStyle.style, animated: animated)

        if self.isNodeLoaded {
            self.controllerNode.updatePresentationData(presentationData)
        }
    }

    public func goToUserLocation(visibleRadius: Double? = nil) {
        
    }
    
    private func dismissAllTooltips() {
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    
    override public func loadDisplayNode() {
        super.loadDisplayNode()
        guard let interaction = self.interaction else {
            return
        }
        
        self.displayNode = LocationViewControllerNode(context: self.context, controller: self, presentationData: self.presentationData, subject: self.subject, interaction: interaction, locationManager: self.locationManager, isPreview: self.isPreview)
        self.displayNodeDidLoad()
        
        self.controllerNode.onAnnotationsReady = { [weak self] in
            guard let strongSelf = self, strongSelf.showAll else {
                return
            }
            strongSelf.controllerNode.showAll()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
            
    var canSaveWegramLocation: Bool {
        return self.allowMessageSaving && self.canOpenWegramOptions && !self.context.isFrozen && self.subject.id.peerId.namespace != Namespaces.Peer.SecretChat && !self.subject._asMessage().isCopyProtected()
    }

    func saveWegramLocation() {
        self.forwardWegramLocation(to: self.context.account.peerId, saving: true)
    }

    private func forwardWegramLocation(to peerId: EnginePeer.Id?, saving: Bool = false) {
        guard self.canSaveWegramLocation, self.view.window != nil, !self.wegramSaveInFlight, self.wegramSaveSheet == nil else { return }
        self.wegramSaveInFlight = true
        let messageId = self.subject.id
        self.wegramSaveDisposable.set((combineLatest(
            self.context.sharedContext.chatAvailableMessageActions(engine: self.context.engine, accountPeerId: self.context.account.peerId, messageIds: [messageId], keepUpdated: false) |> take(1),
            self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
        ) |> deliverOnMainQueue).start(next: { [weak self] actions, message in
            guard let self else { return }
            self.wegramSaveInFlight = false
            guard self.canSaveWegramLocation, self.subject.id == messageId, self.view.window != nil, self.wegramSaveSheet == nil else { return }
            guard actions.options.contains(.forward), !actions.isCopyProtected, let message, !message._asMessage().isCopyProtected() else {
                self.wegramLocationUnavailable(chinese: "此消息不支持转发或收藏。", english: "This message cannot be forwarded or saved.")
                return
            }
            let controller = self.context.sharedContext.makeShareController(context: self.context, params: ShareControllerParams(subject: .messages([message._asMessage()]), externalShare: false, immediatePeerId: peerId, forcedActionTitle: saving ? (self.presentationData.strings.baseLanguageCode.hasPrefix("zh") ? "收藏" : "Save") : nil))
            self.wegramSaveSheet = controller
            self.present(controller, in: .window(.root))
        }, completed: { [weak self] in self?.wegramSaveInFlight = false }))
    }

    private func copyWegramLocation() {
        guard self.canSaveWegramLocation else { return }
        let messageId = self.subject.id
        self.wegramCopyDisposable.set((self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId)) |> deliverOnMainQueue).start(next: { [weak self] message in
            guard let self, self.canSaveWegramLocation, self.view.window != nil, self.subject.id == messageId, let message, !message._asMessage().isCopyProtected(), let location = getLocation(from: message) else { return }
            let coordinates = String(format: "%.6f, %.6f", locale: Locale(identifier: "en_US_POSIX"), location.latitude, location.longitude)
            UIPasteboard.general.string = [location.venue?.title, location.venue?.address, coordinates].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        }))
    }

    func presentWegramLocationShare() {
        guard self.canOpenWegramOptions, self.view.window != nil, self.wegramLocationShareSheet == nil, let location = getLocation(from: self.subject), location.liveBroadcastingTimeout == nil else { return }
        let messageId = self.subject.id
        let data = self.presentationData
        let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
        let sheet = ActionSheetController(theme: WegramLocationShareItem.theme(ActionSheetControllerTheme(wegramTheme: data.theme, fontSize: data.listsFontSize)))
        let content = WegramLocationShareView()
        let item = WegramLocationShareItem(content: content, dark: data.theme.overallDarkAppearance, fontSize: data.listsFontSize.baseDisplaySize, chinese: chinese, canForward: self.canSaveWegramLocation)
        var peers: [EnginePeer] = []
        var avatars: [AvatarNode] = []
        var active = true
        var pending: WegramLocationShareAction?
        sheet.willDismiss = { [weak self] in
            active = false
            self?.wegramRecentPeersDisposable.set(nil)
        }
        sheet.dismissed = { [weak self] _ in
            // Keep avatar image subscriptions alive for the visible sheet only.
            _ = avatars
            DispatchQueue.main.async { [weak self] in
                guard let self, let action = pending, self.canOpenWegramOptions, self.view.window != nil, self.subject.id == messageId else { return }
                switch action {
                case let .peer(index):
                    guard peers.indices.contains(index) else { return }
                    self.forwardWegramLocation(to: peers[index].id)
                case .forward:
                    self.forwardWegramLocation(to: nil)
                case .copy:
                    self.copyWegramLocation()
                case .cancel: break
                case .improve:
                    self.wegramLocationUnavailable(chinese: "此地点未提供可修改信息的服务。", english: "This location does not provide a service for editing its information.")
                }
            }
        }
        content.perform = { [weak self, weak sheet] action in
            guard active, let self, self.canOpenWegramOptions, self.view.window != nil, self.subject.id == messageId else { return }
            if action != .improve && action != .cancel && !self.canSaveWegramLocation { return }
            pending = action == .cancel ? nil : action
            active = false
            sheet?.dismissAnimated()
        }
        sheet.setItemGroups([ActionSheetItemGroup(items: [item])])
        self.wegramLocationShareSheet = sheet
        self.present(sheet, in: .window(.root))
        if self.canSaveWegramLocation {
            self.wegramRecentPeersDisposable.set((self.context.engine.messages.chatList(group: .root, count: 40) |> take(1) |> deliverOnMainQueue).start(next: { [weak self, weak sheet, weak content] list in
                guard let self, let sheet, let content, active, self.wegramLocationShareSheet === sheet, self.canSaveWegramLocation, self.subject.id == messageId else { return }
                var seen = Set<EnginePeer.Id>()
                peers = list.items.reversed().compactMap { entry -> EnginePeer? in
                    guard let peer = entry.renderedPeer.peer, peer.id != self.context.account.peerId, seen.insert(peer.id).inserted, canSendMessagesToPeer(peer) else { return nil }
                    return peer
                }
                peers = Array(peers.prefix(12))
                avatars = peers.map { peer in
                    let avatar = AvatarNode(font: avatarPlaceholderFont(size: 24))
                    avatar.frame = CGRect(x: 0, y: 0, width: 56, height: 56)
                    avatar.setPeer(context: self.context, theme: data.theme, peer: peer, clipStyle: .none, synchronousLoad: false)
                    return avatar
                }
                content.setPeers(Array(zip(peers, avatars)).map { peer, avatar in (title: peer.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder), avatar: avatar.view) })
                sheet.updateItem(groupIndex: 0, itemIndex: 0) { $0 }
            }))
        }
    }

    func openWegramTaxi() {
        guard self.canOpenWegramOptions, self.view.window != nil, self.wegramTaxiSheet == nil, let location = getLocation(from: self.subject) else { return }
        let identifiers: Set<String> = ["yandexGo", "yango", "rizogo"]
        let options = availableOpenInOptions(context: self.context, item: .location(location: location, directions: nil)).filter { identifiers.contains($0.identifier) }
        guard !options.isEmpty else {
            self.wegramLocationUnavailable(chinese: "未检测到支持的打车应用。", english: "No supported taxi app is installed.")
            return
        }
        let messageId = self.subject.id
        let sheet = ActionSheetController(theme: ActionSheetControllerTheme(wegramTheme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize))
        var active = true
        sheet.willDismiss = { active = false }
        let items: [ActionSheetItem] = options.compactMap { option in
            guard case let .other(title, _, _, _) = option.application else { return nil }
            return ActionSheetButtonItem(title: title, action: { [weak self, weak sheet] in
                guard active else { return }
                active = false
                sheet?.dismissAnimated()
                guard let self, self.canOpenWegramOptions, self.view.window != nil, self.subject.id == messageId, let location = getLocation(from: self.subject),
                      let current = availableOpenInOptions(context: self.context, item: .location(location: location, directions: nil)).first(where: { $0.identifier == option.identifier }),
                      case let .openUrl(url) = current.action() else { return }
                self.wegramOpenUrl(url)
            })
        }
        sheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { [weak sheet] in active = false; sheet?.dismissAnimated() })])])
        self.wegramTaxiSheet = sheet
        self.present(sheet, in: .window(.root))
    }

    private func wegramLocationUnavailable(chinese: String, english: String) {
        let text = self.presentationData.strings.baseLanguageCode.hasPrefix("zh") ? chinese : english
        self.present(textAlertController(context: self.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
    }

    private var wegramDidRequestDismiss = false
    var canOpenWegramOptions: Bool { return !self.isPreview && !self.isBeingDismissed && !self.wegramDidRequestDismiss }
    private var didDismiss = false
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !self.didDismiss {
            self.didDismiss = true
            self.dismissed()
        }
    }
    
    public override func dismiss(completion: (() -> Void)? = nil) {
        self.wegramDidRequestDismiss = true
        super.dismiss(completion: completion)
    }
}
