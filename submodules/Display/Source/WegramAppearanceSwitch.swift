import UIKit

// Fixed legacy geometry avoids the iOS 26+ UISwitch resizing and glass material.
public final class WegramAppearanceSwitch: UIControl {
    private let track = UIView()
    private let thumb = UIView()
    private var initialValue = false
    private var startX: CGFloat = 0
    private var dragged = false
    public var onTintColor = UIColor.green { didSet { self.updateAppearance() } }
    public var offTintColor = UIColor(white: 0.9, alpha: 1) { didSet { self.updateAppearance() } }
    public var onTitle = "On" { didSet { self.updateAppearance() } }
    public var offTitle = "Off" { didSet { self.updateAppearance() } }
    public var isOn = false { didSet { self.updateAppearance() } }
    public override var isEnabled: Bool { didSet { self.updateAppearance() } }

    public init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 51, height: 44))
        self.addSubview(self.track)
        self.track.addSubview(self.thumb)
        self.track.isUserInteractionEnabled = false
        self.track.layer.cornerRadius = 15.5
        self.thumb.layer.cornerRadius = 13.5
        self.thumb.backgroundColor = .white
        self.thumb.layer.shadowColor = UIColor.black.cgColor
        self.thumb.layer.shadowOpacity = 0.15
        self.thumb.layer.shadowRadius = 1
        self.thumb.layer.shadowOffset = CGSize(width: 0, height: 1)
        self.isAccessibilityElement = true
        self.updateAppearance()
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    public override var intrinsicContentSize: CGSize { CGSize(width: 51, height: 44) }
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.track.frame = CGRect(x: (self.bounds.width - 51) / 2, y: (self.bounds.height - 31) / 2, width: 51, height: 31)
        self.thumb.frame = CGRect(x: self.isOn ? 22 : 2, y: 2, width: 27, height: 27)
    }
    private func updateAppearance() {
        self.track.backgroundColor = self.isOn ? self.onTintColor : self.offTintColor
        self.alpha = self.isEnabled ? 1 : 0.45
        self.accessibilityValue = self.isOn ? self.onTitle : self.offTitle
        self.accessibilityTraits = self.isEnabled ? .button : [.button, .notEnabled]
        self.setNeedsLayout()
    }
    private func finish(value: Bool, notify: Bool) {
        self.isOn = value
        if !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.16, animations: { self.layoutIfNeeded() })
        } else { self.layoutIfNeeded() }
        if notify { self.sendActions(for: .valueChanged) }
    }
    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard self.isEnabled else { return false }
        self.initialValue = self.isOn
        self.startX = touch.location(in: self).x
        self.dragged = false
        return true
    }
    public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let x = touch.location(in: self).x
        if abs(x - self.startX) > 4 { self.dragged = true }
        if self.dragged { self.isOn = x >= self.bounds.midX }
        return true
    }
    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        guard self.isEnabled, let touch, self.bounds.insetBy(dx: -20, dy: -10).contains(touch.location(in: self)) else {
            self.finish(value: self.initialValue, notify: false)
            return
        }
        let value = self.dragged ? self.isOn : !self.initialValue
        self.finish(value: value, notify: value != self.initialValue)
    }
    public override func cancelTracking(with event: UIEvent?) { self.finish(value: self.initialValue, notify: false) }
    public override func accessibilityActivate() -> Bool {
        guard self.isEnabled else { return false }
        self.finish(value: !self.isOn, notify: true)
        return true
    }
}

