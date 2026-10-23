import UIKit

public final class WegramNameSaveButton: UIButton {
    private let fill = UIView()

    public init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 64, height: 44))
        self.fill.isUserInteractionEnabled = false
        self.fill.layer.cornerRadius = 5
        self.insertSubview(self.fill, at: 0)
        self.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        self.titleLabel?.textAlignment = .center
        self.setTitleColor(.white, for: .normal)
        self.setTitleColor(UIColor(white: 0.65, alpha: 1), for: .disabled)
        self.accessibilityIdentifier = "Wegram.Profile.SaveName"
        self.updateFill()
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    public override var isEnabled: Bool { didSet { self.updateFill() } }
    public override var isHighlighted: Bool { didSet { self.alpha = self.isHighlighted ? 0.6 : 1 } }
    private func updateFill() { self.fill.backgroundColor = self.isEnabled ? UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1) : UIColor(white: 0.85, alpha: 1) }
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.fill.frame = CGRect(x: 0, y: (self.bounds.height - 32) / 2, width: self.bounds.width, height: 32)
        self.titleLabel?.frame = self.bounds
    }
}
