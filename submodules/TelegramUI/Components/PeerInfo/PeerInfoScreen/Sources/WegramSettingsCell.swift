import UIKit
import Display

// WeChat's grouped lists: #EEEEEE/#111111 gaps around #FFFFFF/#191919 rows, measured from the user's
// own dark chat list and the user's 发现/我 screenshots (IMG_2442/2443). Inside a section the divider is
// inset to the title; each section's first and last row carry a full-width line on the row itself. UIKit
// draws its edge lines in the gap, so rows draw their own.
enum WegramGroupedListColors {
    static func background(dark: Bool) -> UIColor { UIColor(rgb: dark ? 0x111111 : 0xeeeeee) }
    static func row(dark: Bool) -> UIColor { UIColor(rgb: dark ? 0x191919 : 0xffffff) }
    // Dark: white at 10%, measured from the user's chat list (49 on #191919 rows, 55 on #202020 pinned rows).
    static func separator(dark: Bool) -> UIColor { dark ? UIColor(rgb: 0xffffff, alpha: 0.1) : UIColor(rgb: 0x000000, alpha: 0.1) }
}

final class WegramSettingsCell: UITableViewCell {
    let arrow = UIImageView(image: wegramDisclosureArrowImage)
    var centered = false
    let valueIcon = UIImageView()
    let separatorLine = UIView()
    let topSeparatorLine = UIView()
    // nil leaves dividers to the table (cells in lists that keep UIKit separators).
    var sectionPosition: (isFirst: Bool, isLast: Bool)? {
        didSet { self.setNeedsLayout() }
    }
    var avatarLayout: ((CGSize) -> Void)?
    var avatarContent: UIView? {
        didSet {
            if oldValue !== self.avatarContent {
                oldValue?.removeFromSuperview()
                if let avatarContent { self.contentView.addSubview(avatarContent) }
            }
            self.setNeedsLayout()
        }
    }

    init() {
        super.init(style: .value1, reuseIdentifier: "setting")
        self.contentView.addSubview(self.arrow)
        self.contentView.addSubview(self.valueIcon)
        self.valueIcon.contentMode = .scaleAspectFit
        self.valueIcon.isAccessibilityElement = false
        self.arrow.contentMode = .center
        self.selectedBackgroundView = UIView()
        self.addSubview(self.separatorLine)
        self.addSubview(self.topSeparatorLine)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.contentView.bounds.width
        let height = self.contentView.bounds.height
        self.arrow.isHidden = self.centered || self.accessoryView != nil
        self.arrow.frame = wegramDisclosureArrowFrame(trailingEdge: width, centerY: height / 2)
        self.textLabel?.textAlignment = self.centered ? .center : .natural
        let avatarSide = max(0, height - 24)
        self.avatarContent?.frame = CGRect(x: max(16, width - 42 - avatarSide), y: 12, width: avatarSide, height: avatarSide)
        if self.avatarContent != nil { self.avatarLayout?(CGSize(width: avatarSide, height: avatarSide)) }
        self.valueIcon.frame = CGRect(x: width - 66, y: (height - 24) / 2, width: 24, height: 24)
        let detailWidth = min(max(0, width * 0.4), self.detailTextLabel?.sizeThatFits(CGSize(width: width * 0.4, height: height)).width ?? 0)
        self.detailTextLabel?.frame = CGRect(x: width - 42 - detailWidth, y: 0, width: detailWidth, height: height)
        let trailingWidth = self.avatarContent != nil ? avatarSide : (self.valueIcon.image != nil ? 24 : detailWidth)
        let trailingSpacing: CGFloat = self.avatarContent != nil || self.valueIcon.image != nil ? 74 : 58
        let titleInset: CGFloat = self.imageView?.image != nil && !self.centered ? 56 : 16
        if self.imageView?.image != nil {
            self.imageView?.contentMode = .scaleAspectFit
            self.imageView?.frame = CGRect(x: 16, y: (height - 24) / 2, width: 24, height: 24)
        }
        self.textLabel?.frame = CGRect(x: titleInset, y: 0, width: max(0, width - (self.centered ? 32 : trailingSpacing + trailingWidth) - (titleInset - 16)), height: height)
        self.separatorLine.isHidden = self.sectionPosition == nil
        self.topSeparatorLine.isHidden = self.sectionPosition?.isFirst != true
        self.topSeparatorLine.backgroundColor = self.separatorLine.backgroundColor
        let hairline = 1.0 / max(1.0, self.traitCollection.displayScale)
        let bottomInset = self.sectionPosition?.isLast == true ? 0 : titleInset
        self.separatorLine.frame = CGRect(x: bottomInset, y: self.bounds.height - hairline, width: max(0, self.bounds.width - bottomInset), height: hairline)
        self.topSeparatorLine.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: hairline)
        self.bringSubviewToFront(self.separatorLine)
        self.bringSubviewToFront(self.topSeparatorLine)
    }
}
