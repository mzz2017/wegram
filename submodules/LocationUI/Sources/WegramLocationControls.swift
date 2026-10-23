import UIKit
import Display
import TelegramPresentationData

public final class WegramLocationControls: UIView {
    public let locateButton = UIButton(type: .custom)
    public var locate: () -> Void = {}
    public var more: () -> Void = {}

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.locateButton)
        self.locateButton.layer.cornerRadius = 9
        self.locateButton.accessibilityIdentifier = "Wegram.Location.Locate"
        self.locateButton.addAction(UIAction { [weak self] _ in
            guard let self, !self.isHidden, self.isUserInteractionEnabled else { return }
            self.locate()
        }, for: .touchUpInside)
        let press = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
        press.cancelsTouchesInView = true
        self.locateButton.addGestureRecognizer(press)
        self.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(mapSize: CGSize, safeInsets: UIEdgeInsets, navigationHeight: CGFloat, dark: Bool, locateTitle: String, moreTitle: String, round: Bool = false) {
        let side: CGFloat = round ? 44 : 48
        let x = safeInsets.left + (round ? 14 : 12)
        let y = mapSize.height - side - (round ? 30 : 36)
        let visible = x + side <= mapSize.width - safeInsets.right && y >= navigationHeight + 8
        self.isHidden = !visible
        self.isUserInteractionEnabled = visible
        self.frame = CGRect(x: x, y: max(0, y), width: side, height: side)
        self.locateButton.layer.cornerRadius = round ? side / 2 : 9
        self.locateButton.frame = self.bounds
        self.locateButton.isAccessibilityElement = visible
        self.locateButton.accessibilityLabel = locateTitle
        self.locateButton.accessibilityCustomActions = [UIAccessibilityCustomAction(name: moreTitle, actionHandler: { [weak self] _ in
            guard let self, !self.isHidden, self.isUserInteractionEnabled else { return false }
            self.more()
            return true
        })]
        self.locateButton.backgroundColor = UIColor(white: dark ? 0.12 : 1, alpha: 1)
        let color = UIColor(white: dark ? 0.9 : 0.1, alpha: 1)
        let iconSide: CGFloat = round ? 24 : 28
        let image = UIGraphicsImageRenderer(size: CGSize(width: iconSide, height: iconSide)).image { renderer in
            let context = renderer.cgContext
            context.scaleBy(x: iconSide / 28, y: iconSide / 28)
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            context.setLineWidth(1.5)
            context.strokeEllipse(in: CGRect(x: 5, y: 5, width: 18, height: 18))
            context.fillEllipse(in: CGRect(x: 10.5, y: 10.5, width: 7, height: 7))
            for points in [[CGPoint(x: 14, y: 1), CGPoint(x: 14, y: 7)], [CGPoint(x: 14, y: 21), CGPoint(x: 14, y: 27)], [CGPoint(x: 1, y: 14), CGPoint(x: 7, y: 14)], [CGPoint(x: 21, y: 14), CGPoint(x: 27, y: 14)]] {
                context.move(to: points[0])
                context.addLine(to: points[1])
            }
            context.strokePath()
        }
        self.locateButton.setImage(image, for: .normal)
    }

    @objc private func longPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, !self.isHidden, self.isUserInteractionEnabled else { return }
        self.more()
    }
}

public enum WegramLocationMenuAction {
    case map, satellite, hybrid, places, live, share
}

public struct WegramLocationMenu {
    public let controller: ActionSheetController
    public let actions: [ActionSheetButtonItem]
    public let cancel: ActionSheetButtonItem

    public init(theme: ActionSheetControllerTheme, options: [(WegramLocationMenuAction, String)], selected: WegramLocationMenuAction, cancelTitle: String, available: @escaping (WegramLocationMenuAction) -> Bool, perform: @escaping (WegramLocationMenuAction) -> Void) {
        let controller = ActionSheetController(theme: theme)
        var active = true
        controller.willDismiss = { active = false }
        self.controller = controller
        self.actions = options.map { action, title in
            ActionSheetButtonItem(title: (action == selected ? "✓  " : "") + title, enabled: available(action), action: { [weak controller] in
                guard active else { return }
                active = false
                controller?.dismissAnimated()
                guard available(action) else { return }
                perform(action)
            })
        }
        self.cancel = ActionSheetButtonItem(title: cancelTitle, action: { [weak controller] in
            active = false
            controller?.dismissAnimated()
        })
        controller.setItemGroups([ActionSheetItemGroup(items: self.actions), ActionSheetItemGroup(items: [self.cancel])])
    }
}

public enum WegramLocationPinVisual {
    public static let size = CGSize(width: 36, height: 56)
    public static let color = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
    public static let image: UIImage = UIGraphicsImageRenderer(size: size).image { renderer in
        let context = renderer.cgContext
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(4)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: 18, y: 32))
        context.addLine(to: CGPoint(x: 18, y: 54))
        context.strokePath()
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: 0, y: 0, width: 36, height: 36))
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 9, y: 9, width: 18, height: 18))
    }
    public static let dot: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { renderer in
        renderer.cgContext.setFillColor(color.cgColor)
        renderer.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 8, height: 8))
    }

    public static func frame(selected: Bool, raised: Bool) -> CGRect {
        return selected ? CGRect(x: -18, y: -56 - (raised ? 30 : 0), width: 36, height: 56) : CGRect(x: -4, y: -4, width: 8, height: 8)
    }

    public static func hitFrame(selected: Bool, raised: Bool) -> CGRect {
        let frame = self.frame(selected: selected, raised: raised)
        return frame.insetBy(dx: -max(0, (44 - frame.width) / 2), dy: -max(0, (44 - frame.height) / 2))
    }

    public static func pickerCenter(size: CGSize, coordinateOffset: CGPoint) -> CGPoint {
        return CGPoint(x: (size.width + coordinateOffset.x) / 2, y: (size.height + coordinateOffset.y) / 2)
    }
}

public final class WegramLocationTopShade: UIView {
    public override class var layerClass: AnyClass { return CAGradientLayer.self }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.isAccessibilityElement = false
        if let layer = self.layer as? CAGradientLayer {
            layer.colors = [UIColor.black.withAlphaComponent(0.36).cgColor, UIColor.clear.cgColor]
            layer.locations = [0, 1]
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}


public final class WegramLocationNavigation: UIView {
    public let backButton = UIButton(type: .custom)
    public let moreButton = UIButton(type: .custom)
    public let titleLabel = UILabel()
    private var mapOverlay = false
    public var back: () -> Void = {}
    public var more: () -> Void = {}

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.titleLabel)
        self.addSubview(self.backButton)
        self.addSubview(self.moreButton)
        self.titleLabel.numberOfLines = 1
        self.titleLabel.textAlignment = .center
        self.titleLabel.lineBreakMode = .byTruncatingTail
        self.titleLabel.accessibilityTraits = .header
        self.backButton.accessibilityIdentifier = "Wegram.Location.Back"
        self.moreButton.accessibilityIdentifier = "Wegram.Location.More"
        self.backButton.addAction(UIAction { [weak self] _ in
            guard let self, self.canActivate else { return }
            self.back()
        }, for: .touchUpInside)
        self.moreButton.addAction(UIAction { [weak self] _ in
            guard let self, self.canActivate, !self.moreButton.isHidden else { return }
            self.more()
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var canActivate: Bool { return !self.isHidden && self.isUserInteractionEnabled && self.alpha > 0 }

    public func update(size: CGSize, navigationHeight: CGFloat, safeInsets: UIEdgeInsets, dark: Bool, fontSize: CGFloat, title: String, backTitle: String, moreTitle: String, mapOverlay: Bool = false) {
        self.mapOverlay = mapOverlay
        let height = max(0, min(size.height, navigationHeight))
        self.frame = CGRect(x: 0, y: 0, width: max(0, size.width), height: height)
        let left = max(0, safeInsets.left)
        let right = max(0, safeInsets.right)
        let visible = height >= 44 && size.width - left - right >= (mapOverlay ? 56 : 104)
        self.isHidden = !visible
        self.isUserInteractionEnabled = visible
        self.accessibilityElementsHidden = !visible
        let colors = WegramNavigationColors(isDark: dark)
        self.backgroundColor = mapOverlay ? .clear : colors.background
        self.titleLabel.isHidden = mapOverlay
        self.moreButton.isHidden = mapOverlay
        self.titleLabel.text = title
        self.titleLabel.font = Font.semibold(fontSize)
        self.titleLabel.textColor = colors.control
        let top = max(0, height - 44)
        self.backButton.frame = CGRect(x: left + (mapOverlay ? 6 : 0), y: top, width: 44, height: 44)
        self.moreButton.frame = CGRect(x: max(left, size.width - right - 52), y: top, width: 44, height: 44)
        let titleInset = max(left + 52, right + 60)
        self.titleLabel.frame = CGRect(x: titleInset, y: top, width: max(0, size.width - titleInset * 2), height: 44)
        self.backButton.accessibilityLabel = backTitle
        self.moreButton.accessibilityLabel = moreTitle
        self.backButton.tintColor = colors.control
        self.moreButton.tintColor = colors.control
        var backConfiguration = UIButton.Configuration.plain()
        backConfiguration.baseForegroundColor = colors.control
        backConfiguration.background.backgroundColor = .clear
        backConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0)
        backConfiguration.image = generateImage(CGSize(width: 10, height: 18), rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.setStrokeColor(colors.control.cgColor)
            context.setLineWidth(1.5)
            context.setLineCap(.square)
            context.setLineJoin(.miter)
            context.move(to: CGPoint(x: 9, y: 1))
            context.addLine(to: CGPoint(x: 1, y: 9))
            context.addLine(to: CGPoint(x: 9, y: 17))
            context.strokePath()
        })
        self.backButton.configuration = backConfiguration
        self.backButton.contentHorizontalAlignment = .left
        self.moreButton.setImage(WegramIcon.chatMore.image(), for: .normal)
        if mapOverlay {
            backConfiguration.contentInsets = .zero
            backConfiguration.image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { renderer in
                let context = renderer.cgContext
                context.setFillColor(UIColor.white.withAlphaComponent(0.95).cgColor)
                context.fillEllipse(in: CGRect(x: 0, y: 0, width: 20, height: 20))
                context.setStrokeColor(UIColor(white: 0.83, alpha: 1).cgColor)
                context.setLineWidth(1.7)
                context.move(to: CGPoint(x: 12, y: 5))
                context.addLine(to: CGPoint(x: 7, y: 10))
                context.addLine(to: CGPoint(x: 12, y: 15))
                context.strokePath()
            }.withRenderingMode(.alwaysOriginal)
            self.backButton.configuration = backConfiguration
            self.backButton.contentHorizontalAlignment = .center
        }
    }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if self.mapOverlay { return self.canActivate && self.backButton.frame.contains(point) }
        return super.point(inside: point, with: event)
    }
}


public enum WegramLocationDetailAction: CaseIterable {
    case navigate, taxi, save, more, driving, walking, details
}

private final class WegramLocationDetailButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -max(0, (44 - self.bounds.width) / 2), dy: -max(0, (44 - self.bounds.height) / 2)).contains(point)
    }
}

public final class WegramLocationDetailPanel: UIView {
    public let scrollView = UIScrollView()
    public let titleLabel = UILabel()
    public let addressLabel = UILabel()
    public let distanceLabel = UILabel()
    public let handleButton: UIButton = WegramLocationDetailButton(type: .custom)
    public let navigateButton: UIButton = WegramLocationDetailButton(type: .custom)
    public let taxiButton: UIButton = WegramLocationDetailButton(type: .custom)
    public let saveButton: UIButton = WegramLocationDetailButton(type: .custom)
    public let moreButton: UIButton = WegramLocationDetailButton(type: .custom)
    public let drivingButton: UIButton = WegramLocationDetailButton(type: .custom)
    public let walkingButton: UIButton = WegramLocationDetailButton(type: .custom)
    public let detailsButton: UIButton = WegramLocationDetailButton(type: .custom)
    private let handle = UIView()
    public var action: (WegramLocationDetailAction) -> Void = { _ in }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.cornerRadius = 12
        self.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        self.clipsToBounds = true
        self.addSubview(self.scrollView)
        self.addSubview(self.handleButton)
        self.handleButton.addSubview(self.handle)
        self.handle.isUserInteractionEnabled = false
        self.handle.layer.cornerRadius = 2
        self.titleLabel.numberOfLines = 2
        self.addressLabel.numberOfLines = 2
        self.titleLabel.accessibilityTraits = .header
        self.scrollView.addSubview(self.titleLabel)
        self.scrollView.addSubview(self.addressLabel)
        self.scrollView.addSubview(self.distanceLabel)
        self.scrollView.alwaysBounceVertical = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        for (button, action) in [(self.handleButton, WegramLocationDetailAction.details), (self.navigateButton, .navigate), (self.taxiButton, .taxi), (self.saveButton, .save), (self.moreButton, .more), (self.drivingButton, .driving), (self.walkingButton, .walking), (self.detailsButton, .details)] {
            if button !== self.handleButton { self.scrollView.addSubview(button) }
            button.accessibilityIdentifier = "Wegram.Location.Detail.\(action)"
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button, !self.isHidden, self.alpha > 0, self.isUserInteractionEnabled, button.isEnabled else { return }
                self.action(action)
            }, for: .touchUpInside)
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(self.handlePanned(_:)))
        pan.cancelsTouchesInView = true
        self.handleButton.addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handlePanned(_ pan: UIPanGestureRecognizer) {
        guard pan.state == .ended, pan.translation(in: self).y < -24, !self.isHidden, self.isUserInteractionEnabled else { return }
        self.action(.details)
    }

    @discardableResult public func update(width: CGFloat, maxHeight: CGFloat, bottomInset: CGFloat, safeInsets: UIEdgeInsets, dark: Bool, fontSize: CGFloat, chinese: Bool, title: String, address: String, distance: String, driving: String, walking: String, canSave: Bool) -> CGFloat {
        let width = max(0, width)
        let scale = fontSize / 17
        let foreground = UIColor(rgb: dark ? 0xd0d0d0 : 0x181818)
        let secondary = UIColor(rgb: 0x576b95)
        let x = min(width, max(0, safeInsets.left) + 20)
        let available = max(0, width - x - max(0, safeInsets.right) - 20)
        self.backgroundColor = UIColor(rgb: dark ? 0x191919 : 0xffffff)
        self.handle.backgroundColor = UIColor(rgb: dark ? 0x353535 : 0xededed)
        self.handleButton.accessibilityLabel = chinese ? "更多位置详情" : "More location details"
        self.handleButton.frame = CGRect(x: 0, y: 0, width: width, height: 28)
        self.handle.frame = CGRect(x: max(0, (width - 40) / 2), y: 12, width: min(width, 40), height: 4)
        self.titleLabel.text = title
        self.titleLabel.font = Font.semibold(18 * scale)
        self.titleLabel.textColor = foreground
        self.addressLabel.text = address
        self.addressLabel.font = Font.regular(15 * scale)
        self.addressLabel.textColor = foreground
        self.distanceLabel.text = distance
        self.distanceLabel.font = Font.regular(15 * scale)
        self.distanceLabel.textColor = foreground
        let titleHeight = ceil(self.titleLabel.sizeThatFits(CGSize(width: available, height: .greatestFiniteMagnitude)).height)
        self.titleLabel.frame = CGRect(x: x, y: 14, width: available, height: titleHeight)
        let addressHeight = address.isEmpty ? 0 : ceil(self.addressLabel.sizeThatFits(CGSize(width: available, height: .greatestFiniteMagnitude)).height)
        self.addressLabel.frame = CGRect(x: x, y: self.titleLabel.frame.maxY + 10, width: available, height: addressHeight)
        func configure(_ button: UIButton, title: String?, image: UIImage?, color: UIColor, font: CGFloat, background: Bool) {
            var config = UIButton.Configuration.plain()
            config.title = title
            config.image = image
            config.baseForegroundColor = color
            config.imagePadding = 5
            config.titleLineBreakMode = .byTruncatingTail
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var result = attributes
                result.font = background ? Font.semibold(font) : Font.regular(font)
                return result
            }
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: background ? 6 : 0, bottom: 0, trailing: background ? 6 : 0)
            config.background.backgroundColor = background ? UIColor(rgb: dark ? 0x2c2c2c : 0xf2f2f2) : .clear
            config.background.cornerRadius = 8
            button.configuration = config
            button.accessibilityLabel = title
        }
        func symbol(_ name: String, size: CGFloat) -> UIImage? {
            return UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .medium))
        }
        configure(self.drivingButton, title: driving, image: symbol("car.fill", size: 13 * scale), color: secondary, font: 15 * scale, background: false)
        configure(self.walkingButton, title: walking, image: symbol("figure.walk", size: 13 * scale), color: secondary, font: 15 * scale, background: false)
        configure(self.detailsButton, title: chinese ? "更多" : "More", image: nil, color: secondary, font: 15 * scale, background: false)
        self.drivingButton.accessibilityLabel = (chinese ? "驾车 " : "Drive ") + driving
        self.walkingButton.accessibilityLabel = (chinese ? "步行 " : "Walk ") + walking
        let metaHeight = max(44, ceil(20 * scale))
        let metaTop = max(self.titleLabel.frame.maxY, self.addressLabel.frame.maxY - 8)
        var metaX = x
        var metaY = metaTop
        let metaViews: [UIView] = [self.distanceLabel, self.drivingButton, self.walkingButton, self.detailsButton]
        for view in metaViews {
            if view === self.distanceLabel && distance.isEmpty { view.isHidden = true; continue }
            view.isHidden = false
            let natural = ceil(view.sizeThatFits(CGSize(width: available, height: metaHeight)).width)
            let itemWidth = min(available, max(view is UIButton ? 44 : 0, natural))
            if metaX > x && metaX + itemWidth > x + available { metaX = x; metaY += metaHeight }
            view.frame = CGRect(x: metaX, y: metaY, width: itemWidth, height: metaHeight)
            metaX += itemWidth + 12
        }
        configure(self.navigateButton, title: chinese ? "导航" : "Navigate", image: symbol("location.fill", size: 13 * scale), color: foreground, font: 15 * scale, background: true)
        configure(self.taxiButton, title: chinese ? "打车" : "Taxi", image: symbol("car.fill", size: 13 * scale), color: foreground, font: 15 * scale, background: true)
        configure(self.saveButton, title: chinese ? "收藏" : "Save", image: Self.cubeImage, color: foreground, font: 15 * scale, background: true)
        configure(self.moreButton, title: nil, image: WegramIcon.chatMore.image(), color: foreground, font: 15 * scale, background: true)
        self.moreButton.accessibilityLabel = chinese ? "更多" : "More"
        self.saveButton.isEnabled = canSave
        let actionTop = metaY + metaHeight + 14
        let actionHeight = max(40, ceil(24 * scale))
        let moreWidth = min(40, available)
        let regularWidth = max(0, (available - moreWidth - 24) / 3)
        let regularButtons = [self.navigateButton, self.taxiButton, self.saveButton]
        var actionBottom = actionTop
        if regularWidth >= 64 {
            for (index, button) in regularButtons.enumerated() { button.frame = CGRect(x: x + CGFloat(index) * (regularWidth + 8), y: actionTop, width: regularWidth, height: actionHeight) }
            self.moreButton.frame = CGRect(x: x + available - moreWidth, y: actionTop, width: moreWidth, height: actionHeight)
            actionBottom += actionHeight
        } else {
            for (index, button) in (regularButtons + [self.moreButton]).enumerated() { button.frame = CGRect(x: x, y: actionTop + CGFloat(index) * (actionHeight + 8), width: available, height: actionHeight) }
            actionBottom += actionHeight * 4 + 24
        }
        let bodyHeight = actionBottom + 33 + max(0, bottomInset)
        let height = max(0, min(maxHeight, 28 + bodyHeight))
        self.bounds.size = CGSize(width: width, height: height)
        self.scrollView.frame = CGRect(x: 0, y: min(28, height), width: width, height: max(0, height - 28))
        self.scrollView.contentSize = CGSize(width: width, height: bodyHeight)
        self.scrollView.isScrollEnabled = bodyHeight > self.scrollView.bounds.height
        self.isHidden = height < 28 || available < 44
        self.isUserInteractionEnabled = !self.isHidden
        self.accessibilityElementsHidden = self.isHidden
        return height
    }

    private static let cubeImage: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { renderer in
        let context = renderer.cgContext
        context.setFillColor(UIColor.black.cgColor)
        for points in [[CGPoint(x: 1, y: 4), CGPoint(x: 8, y: 0), CGPoint(x: 15, y: 4), CGPoint(x: 8, y: 8)], [CGPoint(x: 1, y: 5), CGPoint(x: 7.5, y: 9), CGPoint(x: 7.5, y: 16), CGPoint(x: 1, y: 12)], [CGPoint(x: 8.5, y: 9), CGPoint(x: 15, y: 5), CGPoint(x: 15, y: 12), CGPoint(x: 8.5, y: 16)]] {
            context.move(to: points[0]); for point in points.dropFirst() { context.addLine(to: point) }; context.closePath(); context.fillPath()
        }
    }.withRenderingMode(.alwaysTemplate)
}

public enum WegramLocationShareAction: Equatable {
    case peer(Int), forward, copy, improve, cancel
}

/// The location share surface uses real peer avatars supplied by the account controller.
public final class WegramLocationShareView: UIView {
    public let recentScrollView = UIScrollView()
    public let actionScrollView = UIScrollView()
    public private(set) var peerButtons: [UIButton] = []
    public let forwardButton = UIButton(type: .custom)
    public let copyButton = UIButton(type: .custom)
    public let improveButton = UIButton(type: .custom)
    public let cancelButton = UIButton(type: .custom)
    public var perform: (WegramLocationShareAction) -> Void = { _ in }
    private let heading = UILabel()
    private let separator = UIView()
    private var tiles: [(UIButton, UIView, UILabel)] = []
    private var peerLabels: [UILabel] = []
    private var peerAvatars: [UIView] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.heading)
        self.heading.isAccessibilityElement = true
        self.heading.accessibilityTraits = .header
        self.addSubview(self.recentScrollView)
        self.addSubview(self.actionScrollView)
        self.actionScrollView.showsHorizontalScrollIndicator = false
        self.addSubview(self.separator)
        self.recentScrollView.showsHorizontalScrollIndicator = false
        self.addSubview(self.cancelButton)
        self.cancelButton.addAction(UIAction { [weak self] _ in
            guard let self, !self.isHidden, self.alpha > 0, self.isUserInteractionEnabled else { return }
            self.perform(.cancel)
        }, for: .touchUpInside)
        for (button, action, symbol) in [(self.forwardButton, WegramLocationShareAction.forward, "arrowshape.turn.up.right.fill"), (self.copyButton, .copy, "rectangle.on.rectangle"), (self.improveButton, .improve, "square.and.pencil")] {
            let tile = UIView()
            tile.isUserInteractionEnabled = false
            tile.layer.cornerRadius = 14
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 30), format: format).image { renderer in
                let context = renderer.cgContext
                UIColor.black.setStroke()
                context.setLineWidth(1.6)
                context.setLineJoin(.miter)
                switch action {
                case .copy:
                    context.stroke(CGRect(x: 10, y: 3, width: 14, height: 20))
                    context.clear(CGRect(x: 5, y: 9, width: 14, height: 20))
                    context.stroke(CGRect(x: 5, y: 9, width: 14, height: 20))
                case .improve:
                    context.move(to: CGPoint(x: 18, y: 4))
                    context.addLine(to: CGPoint(x: 4, y: 4))
                    context.addLine(to: CGPoint(x: 4, y: 26))
                    context.addLine(to: CGPoint(x: 26, y: 26))
                    context.addLine(to: CGPoint(x: 26, y: 12))
                    context.strokePath()
                    UIColor.black.setFill()
                    context.move(to: CGPoint(x: 12, y: 19))
                    context.addLine(to: CGPoint(x: 14, y: 14))
                    context.addLine(to: CGPoint(x: 25, y: 3))
                    context.addLine(to: CGPoint(x: 28, y: 6))
                    context.addLine(to: CGPoint(x: 17, y: 17))
                    context.closePath()
                    context.fillPath()
                default:
                    UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 27, weight: .regular))?.draw(in: CGRect(x: 0, y: 0, width: 30, height: 30))
                }
            }.withRenderingMode(.alwaysTemplate)
            let icon = UIImageView(image: image)
            icon.contentMode = .scaleAspectFit
            icon.frame = CGRect(x: 13, y: 13, width: 30, height: 30)
            icon.tintColor = action == .forward ? UIColor(rgb: 0x07c160) : UIColor(rgb: 0x181818)
            tile.addSubview(icon)
            let label = UILabel()
            label.numberOfLines = 2
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            button.addSubview(tile)
            button.addSubview(label)
            self.actionScrollView.addSubview(button)
            self.tiles.append((button, tile, label))
            button.accessibilityIdentifier = "Wegram.Location.Share.\(action)"
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button, !self.isHidden, self.alpha > 0, self.isUserInteractionEnabled, button.isEnabled else { return }
                self.perform(action)
            }, for: .touchUpInside)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func setPeers(_ peers: [(title: String, avatar: UIView)]) {
        self.peerButtons.forEach { $0.removeFromSuperview() }
        self.peerButtons = []
        self.peerLabels = []
        self.peerAvatars = []
        for (index, peer) in peers.enumerated() {
            let button = UIButton(type: .custom)
            button.accessibilityLabel = peer.title
            button.accessibilityIdentifier = "Wegram.Location.Share.Peer.\(index)"
            peer.avatar.isUserInteractionEnabled = false
            peer.avatar.layer.cornerRadius = 5
            peer.avatar.clipsToBounds = true
            let label = UILabel()
            label.text = peer.title
            label.numberOfLines = 2
            label.textAlignment = .center
            button.addSubview(peer.avatar)
            button.addSubview(label)
            self.recentScrollView.addSubview(button)
            self.peerButtons.append(button)
            self.peerLabels.append(label)
            self.peerAvatars.append(peer.avatar)
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button, !self.isHidden, self.alpha > 0, self.isUserInteractionEnabled, button.isEnabled, self.peerButtons.indices.contains(index), self.peerButtons[index] === button else { return }
                self.perform(.peer(index))
            }, for: .touchUpInside)
        }
    }

    @discardableResult public func update(width: CGFloat, dark: Bool, fontSize: CGFloat, chinese: Bool, canForward: Bool) -> CGFloat {
        let scale = max(1, fontSize / 17)
        let labelFont = UIFont.systemFont(ofSize: 11 * scale)
        let labelHeight = ceil(labelFont.lineHeight * 2)
        let rowHeight = 56 + 8 + labelHeight
        let headingHeight = ceil(UIFont.systemFont(ofSize: 12 * scale).lineHeight)
        let peersY: CGFloat = 24 + headingHeight + 10
        let separatorY = peersY + rowHeight + 16
        let forwardY = separatorY + 16
        let actionLabelHeight = ceil(labelFont.lineHeight * (chinese ? 1 : 2))
        let actionRowHeight = 64 + actionLabelHeight
        let otherY = forwardY + actionRowHeight + 12
        let height = otherY + actionRowHeight + 12
        self.actionScrollView.frame = CGRect(x: 0, y: forwardY, width: width, height: height - forwardY)
        self.actionScrollView.contentSize = CGSize(width: max(width, 12 + 68 * scale + 72 * scale), height: height - forwardY)
        self.backgroundColor = UIColor(rgb: dark ? 0x202020 : 0xededed)
        self.heading.text = chinese ? "转发给" : "Forward to"
        self.heading.font = UIFont.systemFont(ofSize: 12 * scale, weight: .semibold)
        self.heading.textColor = UIColor(rgb: dark ? 0xd0d0d0 : 0x181818)
        self.heading.frame = CGRect(x: 16, y: 24, width: max(0, width - 32), height: headingHeight)
        self.recentScrollView.frame = CGRect(x: 0, y: peersY, width: width, height: rowHeight)
        self.recentScrollView.isHidden = !canForward || self.peerButtons.isEmpty
        let side: CGFloat = 56
        let stride: CGFloat = 68 * scale
        let peerWidth: CGFloat = 66 * scale - 10
        for index in self.peerButtons.indices {
            let button = self.peerButtons[index]
            button.frame = CGRect(x: 12 + CGFloat(index) * stride, y: 0, width: peerWidth, height: rowHeight)
            button.isEnabled = canForward
            self.peerAvatars[index].frame = CGRect(x: (peerWidth - side) / 2, y: 0, width: side, height: side)
            self.peerLabels[index].font = labelFont
            let nameHeight = min(labelHeight, ceil(self.peerLabels[index].sizeThatFits(CGSize(width: 66 * scale, height: .greatestFiniteMagnitude)).height))
            self.peerLabels[index].frame = CGRect(x: -5, y: 64, width: 66 * scale, height: nameHeight)
            self.peerLabels[index].textColor = UIColor(rgb: dark ? 0x999999 : 0x777777)
        }
        self.recentScrollView.contentSize = CGSize(width: 24 + CGFloat(self.peerButtons.count) * stride, height: rowHeight)
        self.separator.backgroundColor = UIColor(rgb: dark ? 0x333333 : 0xdddddd)
        self.separator.frame = CGRect(x: 12, y: separatorY, width: max(0, width - 24), height: 1 / UIScreen.main.scale)
        let titles = chinese ? ["转发给朋友", "复制位置信息", "完善位置信息"] : ["Forward", "Copy location", "Improve location"]
        for (index, item) in self.tiles.enumerated() {
            let (button, tile, label) = item
            let x: CGFloat = index == 2 ? 4 + 68 * scale : 4
            button.frame = CGRect(x: x, y: index == 0 ? 0 : otherY - forwardY, width: 72 * scale, height: actionRowHeight)
            tile.frame = CGRect(x: floor((button.bounds.width - 56) / 2), y: 0, width: 56, height: 56)
            tile.backgroundColor = UIColor(rgb: dark ? 0x303030 : 0xffffff)
            if index != 0 { tile.subviews.first?.tintColor = UIColor(rgb: dark ? 0xd0d0d0 : 0x181818) }
            label.frame = CGRect(x: 0, y: 64, width: button.bounds.width, height: actionLabelHeight)
            label.font = labelFont
            label.text = titles[index]
            label.textColor = UIColor(rgb: dark ? 0x999999 : 0x777777)
            button.accessibilityLabel = titles[index]
            button.isEnabled = index == 2 || canForward
            button.alpha = button.isEnabled ? 1 : 0.4
        }
        self.cancelButton.frame = CGRect(x: 0, y: height, width: width, height: max(56, ceil(fontSize * 1.2) + 24))
        self.cancelButton.setTitle(chinese ? "取消" : "Cancel", for: .normal)
        self.cancelButton.setTitleColor(UIColor(rgb: dark ? 0x8096bd : 0x576b95), for: .normal)
        self.cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: fontSize)
        self.cancelButton.layer.borderColor = self.separator.backgroundColor?.cgColor
        self.cancelButton.layer.borderWidth = 1 / UIScreen.main.scale
        return self.cancelButton.frame.maxY
    }
}

public final class WegramLocationShareItem: ActionSheetItem {
    public let content: WegramLocationShareView
    private let dark: Bool
    private let fontSize: CGFloat
    private let chinese: Bool
    private let canForward: Bool

    public init(content: WegramLocationShareView, dark: Bool, fontSize: CGFloat, chinese: Bool, canForward: Bool) {
        self.content = content
        self.dark = dark
        self.fontSize = fontSize
        self.chinese = chinese
        self.canForward = canForward
    }

    public static func theme(_ base: ActionSheetControllerTheme) -> ActionSheetControllerTheme {
        return ActionSheetControllerTheme(
            dimColor: base.dimColor, backgroundType: base.backgroundType,
            itemBackgroundColor: UIColor(rgb: base.backgroundType == .dark ? 0x202020 : 0xededed),
            itemHighlightedBackgroundColor: base.itemHighlightedBackgroundColor,
            standardActionTextColor: base.standardActionTextColor, destructiveActionTextColor: base.destructiveActionTextColor,
            disabledActionTextColor: base.disabledActionTextColor, primaryTextColor: base.primaryTextColor,
            secondaryTextColor: base.secondaryTextColor, controlAccentColor: base.controlAccentColor,
            controlColor: base.controlColor, switchFrameColor: base.switchFrameColor,
            switchContentColor: base.switchContentColor, switchHandleColor: base.switchHandleColor,
            baseFontSize: base.baseFontSize, usesWegramLayout: base.usesWegramLayout
        )
    }

    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return WegramLocationShareItemNode(theme: theme, item: self)
    }

    public func updateNode(_ node: ActionSheetItemNode) { node.requestLayoutUpdate() }

    fileprivate func update(width: CGFloat) -> CGFloat {
        return self.content.update(width: width, dark: self.dark, fontSize: self.fontSize, chinese: self.chinese, canForward: self.canForward)
    }
}

private final class WegramLocationShareItemNode: ActionSheetItemNode {
    private let item: WegramLocationShareItem

    init(theme: ActionSheetControllerTheme, item: WegramLocationShareItem) {
        self.item = item
        super.init(theme: theme)
        self.hasSeparator = false
        self.view.addSubview(item.content)
    }

    override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: self.item.update(width: constrainedSize.width))
        self.item.content.frame = CGRect(origin: .zero, size: size)
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
