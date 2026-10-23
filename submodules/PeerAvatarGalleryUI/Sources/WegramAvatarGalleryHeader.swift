import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

final class WegramAvatarGalleryHeader: NSObject {
    let titleLabel = UILabel()
    let backButton = ASButtonNode()
    let moreButton = ASButtonNode()
    var back: (() -> Void)?
    var more: (() -> Void)?

    static var theme: NavigationBarTheme {
        NavigationBarTheme(wegramTheme: defaultDarkColorPresentationTheme).withUpdatedBackgroundColor(.black).withUpdatedSeparatorColor(.clear)
    }

    override init() {
        super.init()
        self.titleLabel.font = wegramNavigationTitleFont
        self.titleLabel.textAlignment = .center
        self.titleLabel.textColor = UIColor(white: 0.82, alpha: 1)
        self.titleLabel.accessibilityTraits = .header
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.moreButton.addTarget(self, action: #selector(self.morePressed), forControlEvents: .touchUpInside)
    }

    func apply(to item: UINavigationItem, chinese: Bool, backTitle: String, moreTitle: String) {
        let control = UIColor(white: 0.82, alpha: 1)
        self.titleLabel.text = chinese ? "个人头像" : "Profile Photo"
        item.titleView = self.titleLabel
        let image = wegramNavigationBackArrowImage(color: control)
        self.backButton.setImage(image, for: .normal)
        let size = image?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - size.height) / 2, left: 0, bottom: (44 - size.height) / 2, right: 44 - size.width)
        self.backButton.accessibilityLabel = backTitle
        let back = UIBarButtonItem(customDisplayNode: self.backButton)
        back?.target = self
        back?.action = #selector(self.backPressed)
        back?.accessibilityLabel = backTitle
        item.leftBarButtonItem = back
        self.moreButton.setImage(WegramIcon.chatMore.image()?.withTintColor(control, renderingMode: .alwaysOriginal), for: .normal)
        self.moreButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        self.moreButton.accessibilityLabel = moreTitle
        let more = UIBarButtonItem(customDisplayNode: self.moreButton)
        more?.target = self
        more?.action = #selector(self.morePressed)
        more?.accessibilityLabel = moreTitle
        item.rightBarButtonItems = more.map { [$0] }
    }

    @objc private func backPressed() { self.back?() }
    @objc private func morePressed() { self.more?() }
}
