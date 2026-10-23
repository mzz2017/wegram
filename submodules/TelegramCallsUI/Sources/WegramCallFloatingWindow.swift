import Foundation
import UIKit
import SwiftSignalKit
import Display
import AccountContext
import CallScreen

// WeChat 8's minimized voice call, measured on a 1206x2622 screenshot and a screen recording of it
// (IMG_2457 and a screen recording).
//
// A 72pt card that floats over every screen. It follows the finger while dragged and on release
// rests 6pt from the nearer side edge. Released past an edge, it tucks into a 16x72pt handle stuck
// to that edge; tapping or dragging the handle brings the card back. Tapping the card reopens the
// call.
//
// It is its own small window, so pushed and presented screens never cover it, and since it never
// spans the status bar it cannot take over the status bar's style. Dragging moves the window.
public final class WegramCallFloatingWindow {
    private enum Edge {
        case left
        case right
    }

    private final class RootController: UIViewController {
        override func loadView() {
            self.view = UIView()
            self.view.backgroundColor = .clear
        }
    }

    private final class TileView: UIView {
        static let cardSize = CGSize(width: 72.0, height: 72.0)
        static let handleSize = CGSize(width: 16.0, height: 72.0)
        private static let green = UIColor(rgb: 0x58bf6b)
        private static let cardCornerRadius: CGFloat = 14.0

        private let cardView = UIView()
        private let iconView = UIImageView()
        private let statusLabel = UILabel()
        private let handleView = UIView()
        private let gripView = UIView()

        var isTucked = false
        var edge: Edge = .right

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.cardView.isUserInteractionEnabled = false
            self.cardView.backgroundColor = UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(rgb: 0x2c2c2c) : .white
            }
            self.cardView.layer.cornerRadius = TileView.cardCornerRadius
            // Measured: a symmetric shadow that darkens the list background by 7.5% at the card's edge
            // and fades out ~22pt away.
            self.cardView.layer.shadowColor = UIColor.black.cgColor
            self.cardView.layer.shadowOpacity = 0.15
            self.cardView.layer.shadowRadius = 20.0
            self.cardView.layer.shadowOffset = CGSize()
            self.cardView.layer.shadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: TileView.cardSize), cornerRadius: TileView.cardCornerRadius).cgPath
            self.addSubview(self.cardView)

            self.iconView.image = generateImage(CGSize(width: 28.0, height: 28.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.translateBy(x: size.width * 0.5, y: size.height * 0.5)
                // The hang-up handset turned upright: earpiece at the top left, mouthpiece at the bottom
                // right (fitted to the reference at IoU 0.91).
                context.rotate(by: -0.75 * .pi)
                context.scaleBy(x: 0.7, y: 0.7)
                drawWegramCallHangUp(context, color: TileView.green.cgColor)
            })
            self.cardView.addSubview(self.iconView)

            // WeChat's digits are proportional: the reference "02:51:06" is 59.7pt wide.
            self.statusLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
            self.statusLabel.textColor = TileView.green
            self.statusLabel.textAlignment = .center
            self.cardView.addSubview(self.statusLabel)

            self.handleView.isUserInteractionEnabled = false
            self.handleView.backgroundColor = UIColor(white: 0.0, alpha: 0.3)
            self.handleView.alpha = 0.0
            self.addSubview(self.handleView)
            self.gripView.backgroundColor = .white
            self.gripView.layer.cornerRadius = 1.0
            self.handleView.addSubview(self.gripView)

            self.isAccessibilityElement = true
            self.accessibilityTraits = .button
        }

        required init?(coder: NSCoder) {
            fatalError()
        }

        func update(status: String, accessibilityTitle: String) {
            self.statusLabel.text = status
            self.accessibilityLabel = accessibilityTitle
            self.accessibilityValue = status
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            // The card keeps its size while the window narrows to the handle, anchored to the screen edge.
            let cardX: CGFloat
            if self.isTucked {
                cardX = self.edge == .right ? 0.0 : self.bounds.width - TileView.cardSize.width
            } else {
                cardX = 0.0
            }
            self.cardView.frame = CGRect(origin: CGPoint(x: cardX, y: 0.0), size: TileView.cardSize)
            self.cardView.alpha = self.isTucked ? 0.0 : 1.0

            self.iconView.frame = CGRect(x: 36.0 - 14.0, y: 24.0 - 14.0, width: 28.0, height: 28.0)
            let font = self.statusLabel.font!
            // Digit ink top 51pt into the card; SF digits are as tall as its cap height.
            self.statusLabel.frame = CGRect(x: 0.0, y: 51.0 - (font.ascender - font.capHeight), width: TileView.cardSize.width, height: ceil(font.lineHeight))

            let handleX: CGFloat = self.edge == .right ? self.bounds.width - TileView.handleSize.width : 0.0
            self.handleView.frame = CGRect(origin: CGPoint(x: handleX, y: 0.0), size: TileView.handleSize)
            self.handleView.layer.cornerRadius = 8.0
            self.handleView.layer.maskedCorners = self.edge == .right ? [.layerMinXMinYCorner, .layerMinXMaxYCorner] : [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            self.handleView.alpha = self.isTucked ? 1.0 : 0.0
            self.gripView.frame = CGRect(x: (TileView.handleSize.width - 2.0) * 0.5, y: (TileView.handleSize.height - 16.0) * 0.5, width: 2.0, height: 16.0)
        }
    }

    private let window: UIWindow
    private weak var hostWindow: UIWindow?
    private let tileView: TileView
    private let call: PresentationCall
    private let isChinese: Bool
    private var stateDisposable: Disposable?
    private var tickTimer: Foundation.Timer?
    private var state: PresentationCallState.State?
    private var panStartOrigin: CGPoint?
    private var isVisible = false

    public var tapAction: (() -> Void)?

    public init?(call: PresentationCall, hostWindow: UIWindow?) {
        guard let hostWindow, let windowScene = hostWindow.windowScene else {
            return nil
        }
        self.call = call
        self.hostWindow = hostWindow
        self.isChinese = call.context.sharedContext.currentPresentationData.with({ $0 }).strings.primaryComponent.languageCode.hasPrefix("zh")

        self.window = UIWindow(windowScene: windowScene)
        self.window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1.0)
        self.window.backgroundColor = .clear
        self.window.rootViewController = RootController()

        self.window.frame = CGRect(origin: CGPoint(), size: TileView.cardSize)
        self.tileView = TileView(frame: CGRect(origin: CGPoint(), size: TileView.cardSize))
        if let rootView = self.window.rootViewController?.view {
            // Size the root view first: it loads at zero size, and autoresizing would add its later growth to the tile.
            rootView.frame = self.window.bounds
            self.tileView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            rootView.addSubview(self.tileView)
        }

        self.tileView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        self.tileView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))

        self.stateDisposable = (call.state
        |> deliverOnMainQueue).startStrict(next: { [weak self] state in
            guard let self else {
                return
            }
            self.state = state.state
            self.updateStatus()
        })
        self.tickTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] _ in
            self?.updateStatus()
        })
    }

    deinit {
        self.stateDisposable?.dispose()
        self.tickTimer?.invalidate()
        self.window.isHidden = true
    }

    private func text(_ zh: String, _ en: String) -> String {
        return self.isChinese ? zh : en
    }

    private func updateStatus() {
        let status: String
        switch self.state {
        case let .active(startTime, _, _), let .reconnecting(startTime, _, _):
            let duration = max(0, Int(CFAbsoluteTimeGetCurrent() - startTime))
            if duration >= 3600 {
                status = String(format: "%02d:%02d:%02d", duration / 3600, duration / 60 % 60, duration % 60)
            } else {
                status = String(format: "%02d:%02d", duration / 60, duration % 60)
            }
        case .connecting:
            status = self.text("连接中", "Connecting")
        case .terminating, .terminated:
            status = self.text("通话结束", "Ended")
        case .waiting, .ringing, .requesting, .none:
            status = self.call.isOutgoing ? self.text("等待接听", "Calling") : self.text("待接听", "Incoming")
        }
        let title = self.text("通话悬浮窗", "Call Floating Window")
        self.tileView.update(status: status, accessibilityTitle: self.tileView.isTucked ? title + self.text("，已收起", ", Collapsed") : title)
    }

    public func show() {
        if self.isVisible {
            return
        }
        self.isVisible = true
        if self.window.isHidden {
            if let hostWindow = self.hostWindow {
                // The reference tile rests at y 273pt on a 402x874 screen, 211pt below its 62pt safe area.
                self.window.frame = self.restingFrame(origin: CGPoint(x: hostWindow.bounds.width, y: hostWindow.safeAreaInsets.top + 211.0), edge: .right)
            }
            self.window.isHidden = false
        }
        self.tileView.alpha = 0.0
        self.tileView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseOut], animations: {
            self.tileView.alpha = 1.0
            self.tileView.transform = .identity
        })
    }

    public func hide(completion: (() -> Void)? = nil) {
        self.isVisible = false
        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            self.tileView.alpha = 0.0
        }, completion: { [weak self] _ in
            if let self, !self.isVisible {
                self.window.isHidden = true
            }
            completion?()
        })
    }

    private func clampedY(_ y: CGFloat, height: CGFloat) -> CGFloat {
        guard let hostWindow = self.hostWindow else {
            return y
        }
        let minY = hostWindow.safeAreaInsets.top
        let maxY = hostWindow.bounds.height - hostWindow.safeAreaInsets.bottom - height
        return min(max(y, minY), max(minY, maxY))
    }

    /// The card resting 6pt in from `edge`.
    private func restingFrame(origin: CGPoint, edge: Edge) -> CGRect {
        let width = self.hostWindow?.bounds.width ?? 0.0
        let size = TileView.cardSize
        let x = edge == .left ? 6.0 : width - 6.0 - size.width
        return CGRect(origin: CGPoint(x: x, y: self.clampedY(origin.y, height: size.height)), size: size)
    }

    private func tuckedFrame(y: CGFloat, edge: Edge) -> CGRect {
        let width = self.hostWindow?.bounds.width ?? 0.0
        let size = TileView.handleSize
        let x = edge == .left ? 0.0 : width - size.width
        return CGRect(origin: CGPoint(x: x, y: self.clampedY(y, height: size.height)), size: size)
    }

    private func setTucked(_ isTucked: Bool, edge: Edge, frame: CGRect, animated: Bool) {
        self.tileView.isTucked = isTucked
        self.tileView.edge = edge
        self.updateStatus()
        let apply = {
            self.window.frame = frame
            self.tileView.setNeedsLayout()
            self.tileView.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.0, options: [.allowUserInteraction, .beginFromCurrentState], animations: apply)
        } else {
            apply()
        }
    }

    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        guard case .ended = recognizer.state else {
            return
        }
        if self.tileView.isTucked {
            let edge = self.tileView.edge
            self.setTucked(false, edge: edge, frame: self.restingFrame(origin: self.window.frame.origin, edge: edge), animated: true)
        } else {
            self.tapAction?()
        }
    }

    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        guard let hostWindow = self.hostWindow else {
            return
        }
        switch recognizer.state {
        case .began:
            if self.tileView.isTucked {
                // Pulling the handle brings the card out under the finger.
                let edge = self.tileView.edge
                let x = edge == .left ? 0.0 : hostWindow.bounds.width - TileView.cardSize.width
                self.setTucked(false, edge: edge, frame: CGRect(origin: CGPoint(x: x, y: self.window.frame.minY), size: TileView.cardSize), animated: false)
            }
            self.panStartOrigin = self.window.frame.origin
        case .changed:
            guard let panStartOrigin = self.panStartOrigin else {
                return
            }
            let translation = recognizer.translation(in: hostWindow)
            self.window.frame.origin = CGPoint(x: panStartOrigin.x + translation.x, y: panStartOrigin.y + translation.y)
        case .ended, .cancelled, .failed:
            self.panStartOrigin = nil
            let velocity = recognizer.velocity(in: hostWindow)
            let frame = self.window.frame
            let width = hostWindow.bounds.width
            // A flick decides the side; otherwise the nearer edge wins.
            let projectedMidX = frame.midX + velocity.x * 0.15
            let edge: Edge = projectedMidX < width * 0.5 ? .left : .right
            let y = frame.minY + velocity.y * 0.1
            // Released with more than half the card past the edge (or flung past it), it tucks away.
            let isPastEdge = edge == .left ? (frame.midX + velocity.x * 0.1 < 0.0) : (frame.midX + velocity.x * 0.1 > width)
            if isPastEdge {
                self.setTucked(true, edge: edge, frame: self.tuckedFrame(y: y, edge: edge), animated: true)
            } else {
                self.setTucked(false, edge: edge, frame: self.restingFrame(origin: CGPoint(x: frame.minX, y: y), edge: edge), animated: true)
            }
        default:
            break
        }
    }
}
