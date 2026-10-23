import UIKit
import AppBundle

final class WegramWelcomeView: UIView {
    let loginButton = UIButton(type: .custom)
    let registerButton = UIButton(type: .custom)
    let languageButton = UIButton(type: .custom)
    private let earthView = UIImageView()
    private let glow = CAGradientLayer()
    private let ground = CAShapeLayer()
    private let person = CAShapeLayer()
    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0
    var proceed: (() -> Void)?
    var languagePressed: (() -> Void)?
    var enabled = true {
        didSet {
            for button in [self.loginButton, self.registerButton, self.languageButton] {
                button.isEnabled = self.enabled
                button.alpha = self.enabled ? 1 : 0.6
            }
        }
    }

    init(chinese: Bool) {
        super.init(frame: .zero)
        self.backgroundColor = .black
        self.isAccessibilityElement = false
        self.glow.type = .radial
        self.glow.colors = [UIColor(red: 0.02, green: 0.28, blue: 0.45, alpha: 1).cgColor, UIColor.black.cgColor]
        self.glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.glow.endPoint = CGPoint(x: 1, y: 1)
        self.layer.addSublayer(self.glow)
        if let path = getAppBundle().path(forResource: "WegramWelcomeEarth", ofType: "gif") {
            self.earthView.image = UIImage(contentsOfFile: path)
        }
        self.earthView.contentMode = .scaleToFill
        // The NASA scan includes a black border around the disc.
        self.earthView.layer.contentsRect = CGRect(x: 100.0 / 720, y: 83.0 / 709, width: 560.0 / 720, height: 560.0 / 709)
        self.earthView.clipsToBounds = true
        self.earthView.isAccessibilityElement = false
        self.earthView.accessibilityIdentifier = "Auth.Welcome.Earth"
        self.addSubview(self.earthView)
        self.ground.fillColor = UIColor(red: 0.02, green: 0.05, blue: 0.07, alpha: 1).cgColor
        self.layer.addSublayer(self.ground)
        self.person.fillColor = UIColor.black.cgColor
        self.layer.addSublayer(self.person)
        self.loginButton.backgroundColor = UIColor(red: 0.027, green: 0.757, blue: 0.376, alpha: 1)
        self.registerButton.backgroundColor = .white
        for (button, title, color, identifier) in [
            (self.loginButton, chinese ? "登录" : "Log In", UIColor.white, "Auth.Welcome.StartButton"),
            (self.registerButton, chinese ? "注册" : "Sign Up", UIColor.black, "Auth.Welcome.RegisterButton"),
            (self.languageButton, chinese ? "语言" : "Language", UIColor.white, "Auth.Welcome.LanguageButton")
        ] {
            button.setTitle(title, for: .normal)
            button.setTitleColor(color, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: button === self.languageButton ? 14 : 17)
            button.layer.cornerRadius = 5
            button.accessibilityIdentifier = identifier
            self.addSubview(button)
        }
        for button in [self.loginButton, self.registerButton] {
            button.addAction(UIAction(handler: { [weak self] _ in
                guard let self, self.enabled else { return }
                self.proceed?()
            }), for: .touchUpInside)
        }
        self.languageButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.enabled else { return }
            self.languagePressed?()
        }), for: .touchUpInside)
        self.languageButton.accessibilityHint = chinese ? "选择界面语言" : "Choose interface language"
        self.accessibilityElements = [self.languageButton, self.loginButton, self.registerButton]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateLanguage(chinese: Bool) {
        self.loginButton.setTitle(chinese ? "登录" : "Log In", for: .normal)
        self.registerButton.setTitle(chinese ? "注册" : "Sign Up", for: .normal)
        self.languageButton.setTitle(chinese ? "语言" : "Language", for: .normal)
        self.languageButton.accessibilityHint = chinese ? "选择界面语言" : "Choose interface language"
    }

    func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat) {
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.frame.size = size
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        let contentWidth = min(430, max(0, size.width - 40))
        let left = (size.width - contentWidth) / 2
        let height = max(44, ceil(max(self.loginButton.titleLabel?.font.lineHeight ?? 0, self.registerButton.titleLabel?.font.lineHeight ?? 0) + 20))
        let buttonY = max(self.topInset + 60, size.height - self.bottomInset - height - 16)
        let buttonWidth = min(120, (contentWidth - 24) / 2)
        self.loginButton.frame = CGRect(x: left, y: buttonY, width: buttonWidth, height: height)
        self.registerButton.frame = CGRect(x: left + contentWidth - buttonWidth, y: buttonY, width: buttonWidth, height: height)
        self.languageButton.frame = CGRect(x: max(0, size.width - 112), y: self.topInset, width: 100, height: 44)
        let diameter = min(390, size.width * 0.9, max(0, buttonY - self.topInset - 64))
        let centerY = min(size.height * 0.52, buttonY - diameter * 0.5 - 28)
        self.glow.frame = CGRect(x: (size.width - diameter * 1.5) / 2, y: centerY - diameter * 0.75, width: diameter * 1.5, height: diameter * 1.5)
        let earthSize = diameter * 0.78
        self.earthView.frame = CGRect(x: (size.width - earthSize) / 2, y: centerY - earthSize / 2, width: earthSize, height: earthSize)
        self.earthView.layer.cornerRadius = earthSize / 2
        let horizon = centerY + diameter * 0.38
        let hill = UIBezierPath()
        hill.move(to: CGPoint(x: 0, y: horizon + 24))
        hill.addQuadCurve(to: CGPoint(x: size.width, y: horizon + 24), controlPoint: CGPoint(x: size.width / 2, y: horizon - 24))
        hill.addLine(to: CGPoint(x: size.width, y: size.height))
        hill.addLine(to: CGPoint(x: 0, y: size.height))
        hill.close()
        self.ground.frame = self.bounds
        self.ground.path = hill.cgPath
        let human = UIBezierPath(ovalIn: CGRect(x: 4, y: 0, width: 5, height: 5))
        human.append(UIBezierPath(roundedRect: CGRect(x: 3, y: 5, width: 7, height: 15), cornerRadius: 2))
        human.append(UIBezierPath(rect: CGRect(x: 3, y: 19, width: 2, height: 12)))
        human.append(UIBezierPath(rect: CGRect(x: 8, y: 19, width: 2, height: 12)))
        self.person.frame = CGRect(x: floor(size.width / 2) - 6, y: horizon - 31, width: 12, height: 31)
        self.person.path = human.cgPath
    }
}
