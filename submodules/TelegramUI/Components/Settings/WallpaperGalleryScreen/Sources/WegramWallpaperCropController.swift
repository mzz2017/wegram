import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils

public final class WegramWallpaperCropController: ViewController {
    private let image: UIImage
    private let aspectRatio: CGSize?
    private let presentationData: PresentationData
    private let cropNode = WallpaperCropNode()
    private let imageNode = ASImageNode()
    private let cancelButton = ASButtonNode()
    private let doneButton = ASButtonNode()
    private var viewport: CGSize?
    private var processing = false
    public var completion: ((UIImage, Data) -> Void)?

    public init(image: UIImage, presentationData: PresentationData, aspectRatio: CGSize? = nil, title: String? = nil) {
        self.image = image
        if let aspectRatio, aspectRatio.width.isFinite, aspectRatio.height.isFinite, aspectRatio.width > 0, aspectRatio.height > 0 {
            self.aspectRatio = aspectRatio
        } else {
            self.aspectRatio = nil
        }
        self.presentationData = presentationData
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: defaultDarkPresentationTheme), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        self.title = title ?? (presentationData.strings.baseLanguageCode.hasPrefix("zh") ? "调整背景" : "Adjust Background")
        self.cancelButton.setTitle(presentationData.strings.Common_Cancel, with: Font.regular(17), with: .white, for: .normal)
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.cancelButton.style.preferredSize = CGSize(width: max(64, ceil((presentationData.strings.Common_Cancel as NSString).size(withAttributes: [.font: Font.regular(17)]).width) + 16), height: 44)
        self.cancelButton.accessibilityLabel = presentationData.strings.Common_Cancel
        self.doneButton.setTitle(presentationData.strings.Common_Done, with: Font.regular(17), with: UIColor(rgb: 0x07c160), for: .normal)
        self.doneButton.addTarget(self, action: #selector(self.donePressed), forControlEvents: .touchUpInside)
        self.doneButton.style.preferredSize = CGSize(width: max(64, ceil((presentationData.strings.Common_Done as NSString).size(withAttributes: [.font: Font.regular(17)]).width) + 16), height: 44)
        self.doneButton.accessibilityLabel = presentationData.strings.Common_Done
        self.doneButton.accessibilityTraits = .button
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customDisplayNode: self.cancelButton)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: self.doneButton)
        self.statusBar.statusBarStyle = .White
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    public override var navigationEdgeEffectExtension: CGFloat { 0 }

    public override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = .black
        self.cropNode.clipsToBounds = true
        self.imageNode.image = self.image
        self.imageNode.displaysAsynchronously = false
        self.displayNode.addSubnode(self.cropNode)
        self.displayNodeDidLoad()
    }

    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let available = CGSize(width: max(1, layout.size.width - layout.safeInsets.left - layout.safeInsets.right), height: max(1, layout.size.height - top - layout.intrinsicInsets.bottom - 16))
        let ratio = self.aspectRatio ?? layout.size
        let scale = min(available.width / ratio.width, available.height / ratio.height)
        let canvas = CGSize(width: ratio.width * scale, height: ratio.height * scale)
        self.viewport = self.aspectRatio == nil ? layout.size : canvas
        transition.updateFrame(node: self.cropNode, frame: CGRect(x: layout.safeInsets.left + (available.width - canvas.width) / 2, y: top + (available.height - canvas.height) / 2, width: canvas.width, height: canvas.height))
        self.cropNode.containerLayoutUpdated(layout.withUpdatedSize(canvas), transition: transition)
        if self.cropNode.zoomableContent == nil, self.image.size.width > 0, self.image.size.height > 0 {
            self.cropNode.zoomableContent = (self.image.size, self.imageNode)
            let fill = max(canvas.width / self.image.size.width, canvas.height / self.image.size.height)
            let visible = CGSize(width: canvas.width / fill, height: canvas.height / fill)
            self.cropNode.zoom(to: CGRect(x: (self.image.size.width - visible.width) / 2, y: (self.image.size.height - visible.height) / 2, width: visible.width, height: visible.height))
        }
    }

    @objc private func cancelPressed() {
        self.completion = nil
        self.dismiss()
    }

    @objc private func donePressed() {
        let scroll = self.cropNode.scrollNode.view
        guard self.completion != nil, !self.processing, !scroll.isDragging, !scroll.isDecelerating, !scroll.isZooming, let viewport = self.viewport, self.cropNode.zoomableContent != nil else { return }
        self.processing = true
        self.doneButton.isUserInteractionEnabled = false
        self.doneButton.alpha = 0.4
        self.doneButton.accessibilityTraits = [.button, .notEnabled]
        self.cropNode.isUserInteractionEnabled = false
        let rect = self.cropNode.cropRect
        let image = self.image
        Queue.concurrentDefaultQueue().async { [weak self] in
            let prepared = prepareCapturedWallpaperPhoto(image, viewport: viewport, cropRect: rect)
            let data = prepared?.jpegData(compressionQuality: 0.8)
            Queue.mainQueue().async { [weak self] in
                guard let self else { return }
                self.processing = false
                self.doneButton.isUserInteractionEnabled = true
                self.doneButton.alpha = 1
                self.doneButton.accessibilityTraits = .button
                self.cropNode.isUserInteractionEnabled = true
                guard self.isNodeLoaded, self.viewIfLoaded?.window != nil, self.navigationController?.topViewController === self, self.viewport == viewport, let completion = self.completion else { return }
                if let prepared, let data {
                    self.completion = nil
                    completion(prepared, data)
                } else {
                    let data = self.presentationData
                    self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: data), title: nil, text: data.strings.baseLanguageCode.hasPrefix("zh") ? "无法处理这张照片，请重试" : "Unable to process this photo. Please try again.", actions: [TextAlertAction(type: .defaultAction, title: data.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }
        }
    }
}
