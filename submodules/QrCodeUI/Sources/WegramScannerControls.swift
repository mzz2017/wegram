import UIKit

final class WegramScannerControls: UIView {
    let back = UIButton(type: .custom)
    let myCode = UIButton(type: .custom)
    let torch = UIButton(type: .custom)
    let gallery = UIButton(type: .custom)
    private let myCodeCircle = UIView()
    private let galleryCircle = UIView()
    private let bar = UIView()
    private let mode = UILabel()
    private let dot = UIView()
    private var safe = UIEdgeInsets.zero
    private var top: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.bar.backgroundColor = UIColor(white: 0, alpha: 0.8)
        self.addSubview(self.bar)
        self.mode.textColor = .white
        self.mode.font = .systemFont(ofSize: 17, weight: .medium)
        self.mode.textAlignment = .center
        self.mode.isAccessibilityElement = true
        self.mode.accessibilityTraits = [.staticText, .selected]
        self.addSubview(self.mode)
        self.dot.backgroundColor = .white
        self.dot.layer.cornerRadius = 2
        self.addSubview(self.dot)
        for circle in [self.myCodeCircle, self.galleryCircle] {
            circle.backgroundColor = UIColor(white: 1, alpha: 0.2)
            circle.layer.cornerRadius = 26
            circle.isUserInteractionEnabled = false
            self.addSubview(circle)
        }
        for button in [self.back, self.myCode, self.torch, self.gallery] {
            button.tintColor = .white
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13)
            self.addSubview(button)
        }
        self.back.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 23, weight: .regular)), for: .normal)
        self.setIcon(self.myCode, name: "person.fill")
        self.setIcon(self.gallery, name: "photo")
        self.update(chinese: true, hasTorch: false, torchOn: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setIcon(_ button: UIButton, name: String) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .regular))
        configuration.imagePlacement = .top
        configuration.imagePadding = 8
        configuration.contentInsets = .zero
        configuration.baseForegroundColor = .white
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13))
            return attributes
        }
        button.configuration = configuration
    }

    func update(chinese: Bool, hasTorch: Bool, torchOn: Bool) {
        self.mode.text = chinese ? "扫一扫" : "Scan"
        self.back.accessibilityLabel = chinese ? "返回" : "Back"
        self.myCode.configuration?.title = chinese ? "我的二维码" : "My QR Code"
        self.gallery.configuration?.title = chinese ? "相册" : "Photos"
        self.setIcon(self.torch, name: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
        self.torch.configuration?.title = chinese ? (torchOn ? "轻触关闭" : "轻触照亮") : (torchOn ? "Turn off" : "Light up")
        self.myCode.accessibilityLabel = chinese ? "我的二维码" : "My QR Code"
        self.gallery.accessibilityLabel = chinese ? "相册" : "Photos"
        self.torch.accessibilityLabel = chinese ? "手电筒" : "Flashlight"
        self.torch.accessibilityValue = chinese ? (torchOn ? "已开启" : "已关闭") : (torchOn ? "On" : "Off")
        self.torch.isHidden = !hasTorch
        self.setNeedsLayout()
    }

    func setControlsAlpha(_ alpha: CGFloat) {
        for view in [self.myCode, self.gallery, self.torch, self.myCodeCircle, self.galleryCircle, self.bar, self.mode, self.dot] { view.alpha = alpha }
    }

    func updateLayout(size: CGSize, safe: UIEdgeInsets, top: CGFloat) {
        self.frame.size = size
        self.safe = safe
        self.top = max(top, safe.top)
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let usableWidth = max(0, self.bounds.width - self.safe.left - self.safe.right)
        let barTop = max(self.top + 44, self.bounds.height - self.safe.bottom - 60)
        self.bar.frame = CGRect(x: 0, y: barTop, width: self.bounds.width, height: self.bounds.height - barTop)
        self.mode.frame = CGRect(x: self.safe.left, y: barTop + 12, width: usableWidth, height: 24)
        self.dot.frame = CGRect(x: floor(self.mode.frame.midX - 2), y: barTop + 43, width: 4, height: 4)
        self.back.frame = CGRect(x: self.safe.left + 8, y: self.top, width: 44, height: 44)
        let width = min(96, usableWidth / 3)
        let y = max(self.top + 52, barTop - 104)
        for (button, fraction) in [(self.myCode, CGFloat(1.0 / 6.0)), (self.torch, CGFloat(0.5)), (self.gallery, CGFloat(5.0 / 6.0))] {
            button.frame = CGRect(x: self.safe.left + usableWidth * fraction - width / 2, y: y, width: width, height: 88)
        }
        self.myCodeCircle.frame = CGRect(x: self.myCode.frame.midX - 26, y: y + 6, width: 52, height: 52)
        self.galleryCircle.frame = CGRect(x: self.gallery.frame.midX - 26, y: y + 6, width: 52, height: 52)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self || hit === self.bar || hit === self.mode || hit === self.dot ? nil : hit
    }
}
