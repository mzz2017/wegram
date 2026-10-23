import Foundation
import UIKit
import AttachmentUI
import Display
import SwiftSignalKit
import TelegramCore
import SSignalKit
import TelegramPresentationData
import AccountContext
import LegacyComponents
import LegacyUI
import LegacyMediaPickerUI
import Photos
import MediaAssetsContext

func wegramCanMergeSelectedMedia(selection: TGMediaSelectionContext?, editing: TGMediaEditingContext, asFile: Bool, peer: EnginePeer?) -> Bool {
    if let peer, case .secretChat = peer { return false }
    guard !asFile, let selection, selection.count() >= 3, editing.sendPaidMessageStars == 0 else { return false }
    for selected in selection.selectedItems() {
        guard let item = selected as? (NSObject & TGMediaEditableItem) else { return false }
        if let asset = item as? TGMediaAsset, asset.type == TGMediaAssetGifType { return false }
        let adjustments = editing.adjustments(for: item)
        if editing.spoiler(for: item) || editing.timer(for: item) != nil || editing.price(for: item) != nil || adjustments?.sendAsGif == true || adjustments?.paintingData?.hasAnimation == true { return false }
        if let mode = editing.livePhotoMode(for: item)?.uintValue, mode == TGMediaLivePhotoMode.loop.rawValue || mode == TGMediaLivePhotoMode.bounce.rawValue { return false }
    }
    return true
}

private func galleryFetchResultItems(
    fetchResult: PHFetchResult<PHAsset>,
    index: Int,
    reversed: Bool,
    selectionContext: TGMediaSelectionContext?,
    editingContext: TGMediaEditingContext,
    stickersContext: TGPhotoPaintStickersContext,
    immediateThumbnail: UIImage?,
    asFile: Bool
) -> ([TGModernGalleryItem], TGModernGalleryItem?) {
    var focusItem: TGModernGalleryItem?
    var galleryItems: [TGModernGalleryItem] = []
    
    let legacyFetchResult = TGMediaAssetFetchResult(phFetchResult: fetchResult as? PHFetchResult<AnyObject>, reversed: reversed)
    
    for i in 0 ..< fetchResult.count {
        if let galleryItem = TGMediaPickerGalleryFetchResultItem(fetchResult: legacyFetchResult, index: UInt(i)) {
            galleryItem.selectionContext = selectionContext
            galleryItem.editingContext = editingContext
            galleryItem.stickersContext = stickersContext
            galleryItem.asFile = asFile
            galleryItems.append(galleryItem)
            
            if i == index {
                galleryItem.immediateThumbnailImage = immediateThumbnail
                focusItem = galleryItem
            }
        }
    }
    return (galleryItems, focusItem)
}

private func gallerySelectionItems(item: TGMediaSelectableItem, selectionContext: TGMediaSelectionContext?, editingContext: TGMediaEditingContext, stickersContext: TGPhotoPaintStickersContext, immediateThumbnail: UIImage?) -> ([TGModernGalleryItem], TGModernGalleryItem?) {
    var focusItem: TGModernGalleryItem?
    var galleryItems: [TGModernGalleryItem] = []
    
    if let selectionContext = selectionContext {
        for case let selectedItem as TGMediaSelectableItem in selectionContext.selectedItems() {
            if let asset = selectedItem as? TGMediaAsset {
                let galleryItem: (TGModernGallerySelectableItem & TGModernGalleryEditableItem)
                switch asset.type {
                    case TGMediaAssetVideoType:
                        galleryItem = TGMediaPickerGalleryVideoItem(asset: asset)
                    case TGMediaAssetGifType:
                        let convertedAsset = TGCameraCapturedVideo(asset: asset, livePhoto: false)
                        galleryItem = TGMediaPickerGalleryVideoItem(asset: convertedAsset)
                    default:
                        galleryItem = TGMediaPickerGalleryPhotoItem(asset: asset)
                }
                galleryItem.selectionContext = selectionContext
                galleryItem.editingContext = editingContext
                galleryItem.stickersContext = stickersContext
                galleryItems.append(galleryItem)
                
                if selectedItem.uniqueIdentifier == item.uniqueIdentifier {
                    if let galleryItem = galleryItem as? TGMediaPickerGalleryItem {
                        galleryItem.immediateThumbnailImage = immediateThumbnail
                    }
                    focusItem = galleryItem
                }
            } else if let asset = selectedItem as? UIImage {
                let galleryItem: (TGModernGallerySelectableItem & TGModernGalleryEditableItem) = TGMediaPickerGalleryPhotoItem(asset: asset)
                galleryItem.selectionContext = selectionContext
                galleryItem.editingContext = editingContext
                galleryItem.stickersContext = stickersContext
                galleryItems.append(galleryItem)
                
                if selectedItem.uniqueIdentifier == item.uniqueIdentifier {
                    if let galleryItem = galleryItem as? TGMediaPickerGalleryItem {
                        galleryItem.immediateThumbnailImage = immediateThumbnail
                    }
                    focusItem = galleryItem
                }
            } else if let asset = selectedItem as? TGCameraCapturedVideo {
                let galleryItem: (TGModernGallerySelectableItem & TGModernGalleryEditableItem) = TGMediaPickerGalleryVideoItem(asset: asset)
                galleryItem.selectionContext = selectionContext
                galleryItem.editingContext = editingContext
                galleryItem.stickersContext = stickersContext
                galleryItems.append(galleryItem)
                
                if selectedItem.uniqueIdentifier == item.uniqueIdentifier {
                    if let galleryItem = galleryItem as? TGMediaPickerGalleryItem {
                        galleryItem.immediateThumbnailImage = immediateThumbnail
                    }
                    focusItem = galleryItem
                }
            }
        }
    }
    
    return (galleryItems, focusItem)
}

enum LegacyMediaPickerGallerySource {
    case fetchResult(fetchResult: PHFetchResult<PHAsset>, index: Int, reversed: Bool)
    case selection(item: TGMediaSelectableItem)
}

func presentLegacyMediaPickerGallery(
    context: AccountContext,
    peer: EnginePeer?,
    threadTitle: String?,
    chatLocation: ChatLocation?,
    isScheduledMessages: Bool,
    isActionButtonDone: Bool = false,
    usesWegramAppearance: Bool = false,
    photoSendingState: WegramPhotoSendingState? = nil,
    originalPhotoAvailable: (() -> Bool)? = nil,
    originalPhotoSelectionUpdated: (() -> Void)? = nil,
    presentationData: PresentationData,
    source: LegacyMediaPickerGallerySource,
    immediateThumbnail: UIImage?,
    selectionContext: TGMediaSelectionContext?,
    editingContext: TGMediaEditingContext,
    asFile: Bool,
    hasSilentPosting: Bool,
    hasSchedule: Bool,
    hasTimer: Bool,
    updateHiddenMedia: @escaping (String?) -> Void,
    initialLayout: ContainerViewLayout?,
    transitionHostView: @escaping () -> UIView?,
    transitionView: @escaping (String) -> UIView?,
    completed: @escaping (TGMediaSelectableItem & TGMediaEditableItem, Bool, Int32?, @escaping () -> Void) -> Void,
    presentSchedulePicker: @escaping (Bool, @escaping (Int32, Bool) -> Void) -> Void,
    presentTimerPicker: @escaping (@escaping (Int32) -> Void) -> Void,
    getCaptionPanelView: @escaping () -> TGCaptionPanelView?,
    present: @escaping (ViewController, Any?) -> Void,
    finishedTransitionIn: @escaping () -> Void,
    willTransitionOut: @escaping () -> Void,
    dismissAll: @escaping () -> Void,
    editCover: @escaping (CGSize, @escaping (UIImage) -> Void) -> Void = { _, _ in }
) -> TGModernGalleryController {
    let usesWegramPhotoAppearance = usesWegramAppearance && editingContext.sendPaidMessageStars == 0
    let reminder = peer?.id == context.account.peerId
    let hasSilentPosting = hasSilentPosting && peer?.id != context.account.peerId
    var hasCoverButton = false
    if case let .channel(channel) = peer, case .broadcast = channel.info {
        hasCoverButton = true
    } else if peer?.id == context.account.peerId {
        hasCoverButton = true
    }
    
    let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: nil)
    legacyController.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
    
    let paintStickersContext = LegacyPaintStickersContext(context: context)
    paintStickersContext.presentMediaPickerSendActionMenu = makeLegacyMediaPickerSendActionMenuPresenter(context: context, presentationData: presentationData, presentInGlobalOverlay: { [weak legacyController] controller in
        if let legacyController {
            legacyController.presentInGlobalOverlay(controller)
        } else if let mainWindow = context.sharedContext.mainWindow {
            mainWindow.presentInGlobalOverlay(controller)
        } else {
            context.sharedContext.presentGlobalController(controller, nil)
        }
    })
    paintStickersContext.captionPanelView = {
        return getCaptionPanelView()
    }
    paintStickersContext.livePhotoButton = {
        if case .secretChat = peer {
            return nil
        } else if peer == nil {
            return nil
        }
        let livePhotoButton = LivePhotoButton(context: context)
        livePhotoButton.present = present
        return livePhotoButton
    }
    weak var previewController: TGModernGalleryController?
    let canSelectOriginal: () -> Bool = { [weak editingContext] in
        guard originalPhotoAvailable?() == true, let editingContext else { return false }
        if let item = previewController?.currentItem() as? TGMediaPickerGalleryItem {
            if editingContext.spoiler(for: item.asset) || editingContext.price(for: item.asset) != nil || (editingContext.timer(for: item.asset)?.intValue ?? 0) > 0 { return false }
        }
        return true
    }
    paintStickersContext.photoToolbarView = { [weak selectionContext] backButton, doneButton, solidBackground, hasSendStarsButton in
        let previewState: (() -> (original: Bool, originalAvailable: Bool, count: Int, itemId: String?))?
        if let photoSendingState {
            previewState = {
                let available = canSelectOriginal()
                if !available { photoSendingState.original = false }
                let focusedItem = (previewController?.currentItem() as? TGMediaPickerGalleryItem)?.asset
                let count = Int(selectionContext?.count() ?? 0)
                // The original completion may select the focused item, subject to its permission gate.
                let displayedCount = count == 0 ? 1 : ((focusedItem.map { selectionContext?.isItemSelected($0) == true } ?? false) ? count : 0)
                return (photoSendingState.original, available, displayedCount, focusedItem?.uniqueIdentifier)
            }
        } else {
            previewState = nil
        }
        return makeMediaPickerPhotoToolbarView(context: context, backButton: backButton, doneButton: doneButton, solidBackground: solidBackground, hasSendStarsButton: hasSendStarsButton, usesWegramAppearance: usesWegramPhotoAppearance, previewState: previewState, toggleOriginal: {
            guard let photoSendingState, canSelectOriginal() else { return }
            photoSendingState.original.toggle()
            originalPhotoSelectionUpdated?()
            (previewController?.model as? TGMediaPickerGalleryModel)?.interfaceView.setNeedsLayout()
        }, caption: {
            guard usesWegramPhotoAppearance, !solidBackground, photoSendingState != nil,
                  let model = previewController?.model as? TGMediaPickerGalleryModel, model.interfaceView.canBeginEditingCaption() else { return nil }
            return (presentationData.strings.baseLanguageCode.hasPrefix("zh") ? "说明" : "Caption", {
                guard let controller = previewController, controller.viewIfLoaded?.window != nil,
                      let model = controller.model as? TGMediaPickerGalleryModel else { return }
                model.interfaceView.beginEditingCaption()
            })
        }, selectedPhotos: { [weak selectionContext] in
            guard usesWegramPhotoAppearance, !solidBackground, let selectionContext, selectionContext.count() > 0 else { return nil }
            let chinese = presentationData.strings.baseLanguageCode.hasPrefix("zh")
            let title = (chinese ? "已选照片" : "Selected Photos") + "(\(selectionContext.count()))"
            return (title, {
                guard let model = previewController?.model as? TGMediaPickerGalleryModel else { return }
                model.interfaceView.toggleSelectedPhotosFromMenu()
            })
        })
    }
    paintStickersContext.editCover = { dimensions, completion in
        editCover(dimensions, completion)
    }
    
    let controller = TGModernGalleryController(context: legacyController.context)!
    previewController = controller
    controller.asyncTransitionIn = true
    legacyController.bind(controller: controller)
    
    let (items, focusItem): ([TGModernGalleryItem], TGModernGalleryItem?)
    switch source {
    case let .fetchResult(fetchResult, index, reversed):
        (items, focusItem) = galleryFetchResultItems(fetchResult: fetchResult, index: index, reversed: reversed, selectionContext: selectionContext, editingContext: editingContext, stickersContext: paintStickersContext, immediateThumbnail: immediateThumbnail, asFile: asFile)
    case let .selection(item):
        (items, focusItem) = gallerySelectionItems(item: item, selectionContext: selectionContext, editingContext: editingContext, stickersContext: paintStickersContext, immediateThumbnail: immediateThumbnail)
    }
    
    let recipientName: String?
    if let threadTitle {
        recipientName = threadTitle
    } else {
        if peer?.id == context.account.peerId {
            recipientName = presentationData.strings.DialogList_SavedMessages
        } else {
            recipientName = peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        }
    }
    
    let model = TGMediaPickerGalleryModel(
        context: legacyController.context,
        items: items,
        focus: focusItem,
        selectionContext: selectionContext,
        editingContext: editingContext,
        hasCaptions: true,
        allowCaptionEntities: true,
        hasTimer: hasTimer,
        onlyCrop: false,
        inhibitDocumentCaptions: false,
        hasSelectionPanel: true,
        hasCamera: false,
        recipientName: recipientName,
        isScheduledMessages: isScheduledMessages,
        isActionButtonDone: isActionButtonDone,
        hasCoverButton: hasCoverButton
    )!
    model.stickersContext = paintStickersContext
    model.interfaceView.usesWegramAppearance = usesWegramPhotoAppearance
    model.interfaceView.hidesSelectionCounterWhenClosed = usesWegramPhotoAppearance && photoSendingState != nil
    model.interfaceView.hidesWegramCaptionPanel = usesWegramPhotoAppearance && photoSendingState != nil
    if usesWegramPhotoAppearance, let photoSendingState {
        let mergeView = WegramPhotoMergeView()
        let updateMerge: () -> Void = { [weak mergeView, weak selectionContext] in
            let available = wegramCanMergeSelectedMedia(selection: selectionContext, editing: editingContext, asFile: asFile || photoSendingState.original, peer: peer)
            mergeView?.update(count: Int(selectionContext?.count() ?? 0), selected: available ? (selectionContext?.grouping ?? false) : nil, dark: true, fontSize: presentationData.listsFontSize.baseDisplaySize, title: presentationData.strings.baseLanguageCode.hasPrefix("zh") ? "发送后合并展示" : "Display as an album", minimumHeight: 64)
        }
        mergeView.toggle = { [weak mergeView, weak selectionContext] in
            guard let mergeView, mergeView.window != nil, wegramViewAcceptsActions(mergeView),
                  wegramCanMergeSelectedMedia(selection: selectionContext, editing: editingContext, asFile: asFile || photoSendingState.original, peer: peer),
                  let selectionContext else { return }
            selectionContext.toggleGrouping()
            photoSendingState.mergeDisplay = selectionContext.grouping
            originalPhotoSelectionUpdated?()
            updateMerge()
        }
        model.interfaceView.wegramMergeView = mergeView
        model.interfaceView.updateWegramMergeView = updateMerge
        updateMerge()
    }
    controller.model = model
    model.controller = controller
    model.willFinishEditingItem = { item, adjustments, representation, hasChanges in
        if hasChanges {
            editingContext.setAdjustments(adjustments, for: item)
            editingContext.setTemporaryRep(representation, for: item)
        }
        
        if let selectionContext = selectionContext, adjustments != nil, let item = item as? TGMediaSelectableItem {
            selectionContext.setItem(item, selected: true)
        }
    }
    model.didFinishEditingItem = { item, adjustments, result, thumbnail in
        editingContext.setImage(result, thumbnailImage: thumbnail, for: item, synchronous: false)
    }
    model.saveItemCaption = { item, caption in
        editingContext.setCaption(caption, for: item)
        if let selectionContext = selectionContext, let caption = caption, caption.length > 0, let item = item as? TGMediaSelectableItem {
            selectionContext.setItem(item, selected: true)
        }
    }
    model.didFinishRenderingFullSizeImage = { item, result in
        editingContext.setFullSizeImage(result, for: item)
    }
    model.requestAdjustments = { item in
        return editingContext.adjustments(for: item)
    }
    if let selectionContext = selectionContext {
        model.interfaceView.updateSelectionInterface(selectionContext.count(), counterVisible: selectionContext.count() > 0, animated: false)
    }
    controller.transitionHost = {
        return transitionHostView()
    }
    var transitionedIn = false
    controller.itemFocused = { item in
        if let item = item as? TGMediaPickerGalleryItem, transitionedIn {
            updateHiddenMedia(item.asset.uniqueIdentifier)
        }
    }
    controller.beginTransitionIn = { item, itemView in
        if let item = item as? TGMediaPickerGalleryItem {
            if let itemView = itemView as? TGMediaPickerGalleryVideoItemView {
                itemView.setIsCurrent(true)
            }
            
            return transitionView(item.asset.uniqueIdentifier)
        } else {
            return nil
        }
    }
    
    controller.startedTransitionIn = {
        transitionedIn = true
        if let focusItem = focusItem as? TGModernGallerySelectableItem {
            updateHiddenMedia(focusItem.selectableMediaItem().uniqueIdentifier)
        }
    }
    controller.beginTransitionOut = { item, itemView in
        willTransitionOut()
        
        if let item = item as? TGMediaPickerGalleryItem {
            if let itemView = itemView as? TGMediaPickerGalleryVideoItemView {
                itemView.stop()
            }
            return transitionView(item.asset.uniqueIdentifier)
        } else {
            return nil
        }
    }
    controller.finishedTransitionIn = { [weak model] _, _ in
        model?.interfaceView.setSelectedItemsModel(model?.selectedItemsModel)
        
        finishedTransitionIn()
    }
    controller.completedTransitionOut = { [weak legacyController] in
        updateHiddenMedia(nil)
        legacyController?.dismiss()
    }

    model.interfaceView.donePressed = { [weak controller] item in
        if let item = item as? TGMediaPickerGalleryItem {
            completed(item.asset, false, nil, {
                controller?.dismissWhenReady(animated: true)
                dismissAll()
            })
        }
    }
    if !isScheduledMessages && peer != nil {
        model.interfaceView.doneLongPressed = { [weak selectionContext, weak editingContext, weak legacyController, weak model, weak paintStickersContext] item, sourceView in
            if let legacyController = legacyController, let item = item as? TGMediaPickerGalleryItem, let model = model, let selectionContext = selectionContext {
                var effectiveHasSchedule = hasSchedule
                
                if let editingContext = editingContext {
                    if let timer = editingContext.timer(for: item.asset)?.intValue, timer > 0 {
                        effectiveHasSchedule = false
                    }
                    for item in selectionContext.selectedItems() {
                        if let editableItem = item as? TGMediaEditableItem, let timer = editingContext.timer(for: editableItem)?.intValue, timer > 0 {
                            effectiveHasSchedule = false
                            break
                        }
                    }
                }
                
                let sendWhenOnlineAvailable: Signal<Bool, NoError>
                if let peer {
                    if case .secretChat = peer {
                        effectiveHasSchedule = false
                    }
                    sendWhenOnlineAvailable = context.account.viewTracker.peerView(peer.id)
                    |> take(1)
                    |> map { peerView -> Bool in
                        guard let peer = peerViewMainPeer(peerView) else {
                            return false
                        }
                        var sendWhenOnlineAvailable = false
                        if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence, case let .present(until) = presence.status {
                            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                            if currentTime > until {
                                sendWhenOnlineAvailable = true
                            }
                        }
                        if peer.id.namespace == Namespaces.Peer.CloudUser && peer.id.id._internalGetInt64Value() == 777000 {
                            sendWhenOnlineAvailable = false
                        }
                        return sendWhenOnlineAvailable
                    }
                } else {
                    sendWhenOnlineAvailable = .single(false)
                }
                
                let _ = (sendWhenOnlineAvailable
                |> take(1)
                |> deliverOnMainQueue).start(next: { [model] sendWhenOnlineAvailable in
                    let dismissImpl = { [weak model] in
                        model?.dismiss(true, false)
                        dismissAll()
                    }
                    let send = {
                        completed(item.asset, false, nil, {
                            dismissImpl()
                        })
                    }
                    let sendSilently = { [weak model] in
                        model?.interfaceView.onDismiss()
                        
                        completed(item.asset, true, nil, {
                            dismissImpl()
                        })
                    }
                    let sendWhenOnline = {
                        completed(item.asset, false, scheduleWhenOnlineTimestamp, {
                            dismissImpl()
                        })
                    }
                    let schedule = {
                        presentSchedulePicker(true, { time, silentPosting in
                            completed(item.asset, silentPosting, time, {
                                dismissImpl()
                            })
                        })
                    }
                    let sendWithTimer = {
                        presentTimerPicker { time in
                            var items = selectionContext.selectedItems() ?? []
                            items.append(item.asset as Any)
                            
                            for case let item as TGMediaEditableItem in items {
                                editingContext?.setTimer(time as NSNumber, for: item)
                            }
                            
                            completed(item.asset, false, nil, {
                                dismissImpl()
                            })
                        }
                    }

                    if let sourceView, let paintStickersContext, paintStickersContext.presentMediaPickerSendActionMenu?(sourceView, hasSilentPosting, sendWhenOnlineAvailable && effectiveHasSchedule, effectiveHasSchedule, reminder, hasTimer, sendSilently, sendWhenOnline, schedule, sendWithTimer) == true {
                        let hapticFeedback = HapticFeedback()
                        hapticFeedback.impact()
                        return
                    }

                    let legacySheetController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: nil)
                    let sheetController = TGMediaPickerSendActionSheetController(context: legacyController.context, isDark: true, sendButtonFrame: model.interfaceView.doneButtonFrame, canSendSilently: hasSilentPosting, canSendWhenOnline: sendWhenOnlineAvailable && effectiveHasSchedule, canSchedule: effectiveHasSchedule, reminder: reminder, hasTimer: hasTimer)
                    sheetController.send = send
                    sheetController.sendSilently = sendSilently
                    sheetController.sendWhenOnline = sendWhenOnline
                    sheetController.schedule = schedule
                    sheetController.sendWithTimer = sendWithTimer
                    sheetController.customDismissBlock = { [weak legacySheetController] in
                        legacySheetController?.dismiss()
                    }
                    legacySheetController.bind(controller: sheetController)
                    present(legacySheetController, nil)
                    
                    let hapticFeedback = HapticFeedback()
                    hapticFeedback.impact()
                })
            }
        }
    }
    model.interfaceView.setThumbnailSignalForItem { item in
        let imageSignal = SSignal(generator: { subscriber in
            var asset: PHAsset?
            if let item = item as? TGCameraCapturedVideo, item.originalAsset != nil {
                asset = item.originalAsset.backingAsset
            } else if let item = item as? TGMediaAsset {
                asset = item.backingAsset
            }
            var disposable: Disposable?
            if let asset = asset {
                let scale = min(2.0, UIScreenScale)
                disposable = assetImage(asset: asset, targetSize: CGSize(width: 128.0 * scale, height: 128.0 * scale), exact: false).start(next: { image in
                    subscriber.putNext(image)
                }, completed: {
                    subscriber.putCompletion()
                })
            } else {
                subscriber.putCompletion()
            }
            return SBlockDisposable(block: {
                disposable?.dispose()
            })
        })
        if let item = item as? TGMediaEditableItem {
            return editingContext.thumbnailImageSignal(for: item).map(toSignal: { result in
                if let result = result {
                    return SSignal.single(result)
                } else {
                    return imageSignal
                }
            })
        } else {
            return imageSignal
        }
    }
    if usesWegramPhotoAppearance {
        legacyController.view.accessibilityViewIsModal = true
    }
    present(legacyController, nil)
    
    return controller
}
