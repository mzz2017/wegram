import UIKit
import ObjectiveC
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import LocalMediaResources
import AccountContext
import DeviceAccess
import PresentationDataUtils
import WallpaperGalleryScreen

private var wallpaperCameraDelegateKey: UInt8 = 0
private var wallpaperCameraFlowKey: UInt8 = 0

public func presentChatWallpaperCamera(context: AccountContext, from parent: ViewController) {
    let flow = WallpaperCameraFlow(context: context, parent: parent)
    flow.start()
}

private final class WallpaperCameraFlow: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let context: AccountContext
    private weak var parent: ViewController?
    private var finished = false

    init(context: AccountContext, parent: ViewController) {
        self.context = context
        self.parent = parent
    }

    private var visibleParent: ViewController? {
        guard let parent = self.parent, parent.viewIfLoaded?.window != nil,
              let navigation = parent.navigationController as? NavigationController,
              navigation.topViewController === parent, parent.presentedViewController == nil, parent.view.window?.rootViewController?.presentedViewController == nil else { return nil }
        return parent
    }

    func start() {
        guard let parent = self.visibleParent, objc_getAssociatedObject(parent, &wallpaperCameraFlowKey) == nil else { return }
        let data = self.context.sharedContext.currentPresentationData.with { $0 }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            parent.present(textAlertController(context: self.context, title: nil, text: data.strings.baseLanguageCode.hasPrefix("zh") ? "此设备无法使用相机" : "Camera is unavailable on this device.", actions: [TextAlertAction(type: .defaultAction, title: data.strings.Common_OK, action: {})]), in: .window(.root))
            return
        }
        objc_setAssociatedObject(parent, &wallpaperCameraFlowKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        DeviceAccess.authorizeAccess(to: .camera(.video), presentationData: data, present: { [weak parent] controller, arguments in
            guard let parent, parent.viewIfLoaded?.window != nil,
                  parent.navigationController?.topViewController === parent, parent.view.window?.rootViewController?.presentedViewController == nil else { return }
            parent.present(controller, in: .window(.root), with: arguments)
        }, openSettings: { [context = self.context] in
            context.sharedContext.applicationBindings.openSettings()
        }, { [self] granted in
            guard granted, let parent = self.visibleParent else { self.releaseFlow(); return }
            let picker = UIImagePickerController()
            picker.modalPresentationStyle = .fullScreen
            picker.sourceType = .camera
            picker.mediaTypes = ["public.image"]
            picker.allowsEditing = false
            picker.delegate = self
            objc_setAssociatedObject(picker, &wallpaperCameraDelegateKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            parent.present(picker, animated: true)
        })
    }

    private func releaseFlow() {
        if let parent = self.parent, objc_getAssociatedObject(parent, &wallpaperCameraFlowKey) as? WallpaperCameraFlow === self {
            objc_setAssociatedObject(parent, &wallpaperCameraFlowKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        guard !self.finished else { return }
        self.finished = true
        self.releaseFlow()
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard !self.finished else { return }
        self.finished = true
        guard let image = info[.originalImage] as? UIImage else {
            self.releaseFlow()
            picker.dismiss(animated: true)
            return
        }
        picker.dismiss(animated: true, completion: { [self] in
            defer { self.releaseFlow() }
            guard let parent = self.visibleParent, image.size.width > 0, image.size.height > 0 else { return }
            let crop = WegramWallpaperCropController(image: image, presentationData: self.context.sharedContext.currentPresentationData.with { $0 })
            crop.completion = { [weak parent, weak crop, context = self.context] prepared, data in
                guard let parent, let crop, let navigation = parent.navigationController as? NavigationController,
                      navigation.topViewController === crop, crop.viewIfLoaded?.window != nil else { return }
                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data, synchronous: true)
                context.sharedContext.accountManager.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data, synchronous: true)
                let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: Int32(prepared.size.width), height: Int32(prepared.size.height)), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
                let wallpaper = TelegramWallpaper.image([representation], WallpaperSettings())
                // The original gallery owns confirmation, blur/motion, persistence and dismissal.
                let preview = WallpaperGalleryController(context: context, source: .wallpaper(wallpaper, nil, [], nil, nil, nil), mode: .default)
                navigation.setViewControllers(navigation.viewControllers.map { $0 === crop ? preview : $0 }, animated: true)
            }
            parent.push(crop)
        })
    }
}
