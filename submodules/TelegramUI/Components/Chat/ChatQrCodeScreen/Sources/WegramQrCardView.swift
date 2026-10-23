import UIKit

final class WegramQrCardView: UIView {
    let nameLabel = UILabel()
    let addressLabel = UILabel()
    let hintLabel = UILabel()
    private(set) var avatarFrame = CGRect.zero
    private(set) var codeFrame = CGRect.zero
    private(set) var countdownFrame = CGRect.zero
    private var temporary = false

    init() {
        super.init(frame: .zero)
        self.backgroundColor = .white
        self.layer.cornerRadius = 8
        self.nameLabel.numberOfLines = 2
        self.nameLabel.textColor = UIColor(white: 0.1, alpha: 1)
        self.addressLabel.textColor = UIColor(white: 0.6, alpha: 1)
        self.hintLabel.textColor = UIColor(white: 0.6, alpha: 1)
        self.hintLabel.textAlignment = .center
        self.hintLabel.numberOfLines = 0
        for label in [self.nameLabel, self.addressLabel, self.hintLabel] { self.addSubview(label) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(name: String, address: String?, chinese: Bool, fontSize: CGFloat, temporary: Bool) {
        self.temporary = temporary
        self.nameLabel.text = name
        self.addressLabel.text = address.flatMap { $0.isEmpty ? nil : "@" + $0 }
        self.addressLabel.isHidden = self.addressLabel.text == nil
        self.nameLabel.font = .systemFont(ofSize: fontSize * 18 / 17)
        self.addressLabel.font = .systemFont(ofSize: fontSize * 14 / 17)
        self.hintLabel.font = .systemFont(ofSize: fontSize * 13 / 17)
        self.hintLabel.text = temporary ? (chinese ? "此二维码会自动更新" : "This QR code updates automatically") : (chinese ? "扫一扫上面的二维码，联系我" : "Scan the QR code to contact me")
        self.setNeedsLayout()
    }

    func layoutCard(width: CGFloat) -> CGFloat {
        let innerWidth = max(0, width - 48)
        let titleX: CGFloat = 24 + 48 + 16
        let titleWidth = max(0, width - titleX - 24)
        let nameSize = self.nameLabel.sizeThatFits(CGSize(width: titleWidth, height: .greatestFiniteMagnitude))
        let addressHeight = self.addressLabel.isHidden ? 0 : ceil(self.addressLabel.font.lineHeight) + 6
        let headerHeight = max(48, ceil(nameSize.height) + addressHeight)
        self.avatarFrame = CGRect(x: 24, y: 24 + floor((headerHeight - 48) / 2), width: 48, height: 48)
        self.nameLabel.frame = CGRect(x: titleX, y: 24 + floor((headerHeight - ceil(nameSize.height) - addressHeight) / 2), width: titleWidth, height: ceil(nameSize.height))
        self.addressLabel.frame = CGRect(x: titleX, y: self.nameLabel.frame.maxY + 6, width: titleWidth, height: max(0, addressHeight - 6))
        let codeSide = min(280, max(0, width - 64))
        self.codeFrame = CGRect(x: floor((width - codeSide) / 2), y: 24 + headerHeight + 24, width: codeSide, height: codeSide)
        self.countdownFrame = CGRect(x: 24, y: self.codeFrame.maxY + 12, width: innerWidth, height: self.temporary ? 28 : 0)
        let hintY = self.temporary ? self.countdownFrame.maxY + 12 : self.codeFrame.maxY + 16
        let hintHeight = ceil(self.hintLabel.sizeThatFits(CGSize(width: innerWidth, height: .greatestFiniteMagnitude)).height)
        self.hintLabel.frame = CGRect(x: 24, y: hintY, width: innerWidth, height: hintHeight)
        return self.hintLabel.frame.maxY + 28
    }

    static func exportFileName(addressName: String?, phone: String?, temporary: Bool) -> String {
        if temporary { return "contact-qr" }
        if let addressName, !addressName.isEmpty { return "t_me-" + addressName }
        if let phone { return "t_me-" + phone }
        return "t_me-" + String(Int32.random(in: 0 ..< Int32.max))
    }

    static func canShare(temporary: Bool, tokenExpires: Int32?, now: Int32) -> Bool {
        if !temporary { return true }
        guard let tokenExpires else { return false }
        return tokenExpires > now
    }
}
