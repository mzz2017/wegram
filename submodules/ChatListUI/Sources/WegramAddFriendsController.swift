import Foundation
import UIKit
import CoreImage
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ContactListUI
import QrCodeUI

/// WeChat 8's 添加朋友 (dark references IMG_2461-2466, 402x874pt at 3x), backed by
/// Telegram's username/phone lookup, QR scanner, new-contact form and channel and app search. WeChat's
/// rows with no Telegram counterpart (雷达, 企业微信联系人, 面对面建群) are left out rather than shown dead.
final class WegramAddFriendsController: ViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    private enum Row: CaseIterable {
        case scan
        case phoneContacts
        case officialAccounts
        case serviceAccounts
    }

    private struct Colors {
        let background: UIColor
        let field: UIColor
        let searchBackground: UIColor
        let searchField: UIColor
        let separator: UIColor
        let primary: UIColor
        let secondary: UIColor
        let placeholder: UIColor
        let notFound: UIColor
        let link: UIColor
        let hud: UIColor
        let hudText: UIColor
        let indigo: UIColor

        init(dark: Bool) {
            // Dark values are read off IMG_2461-2466 (P3 converted to sRGB); the light ones are WeUI's light
            // counterparts and have no reference screenshot yet.
            self.background = UIColor(rgb: dark ? 0x191919 : 0xffffff)
            self.field = UIColor(rgb: dark ? 0x313131 : 0xf3f3f3)
            self.searchBackground = UIColor(rgb: dark ? 0x111111 : 0xededed)
            self.searchField = UIColor(rgb: dark ? 0x191919 : 0xffffff)
            self.separator = UIColor(white: dark ? 1.0 : 0.0, alpha: 0.1)
            self.primary = UIColor(white: dark ? 1.0 : 0.0, alpha: dark ? 0.8 : 0.9)
            self.secondary = UIColor(white: dark ? 1.0 : 0.0, alpha: 0.3)
            self.placeholder = UIColor(white: dark ? 1.0 : 0.0, alpha: 0.3)
            self.notFound = UIColor(white: dark ? 1.0 : 0.0, alpha: 0.5)
            self.link = UIColor(rgb: dark ? 0x7d90a9 : 0x576b95)
            self.hud = UIColor(rgb: dark ? 0x292929 : 0x4c4c4c)
            self.hudText = dark ? UIColor(white: 1.0, alpha: 0.36) : UIColor(white: 1.0, alpha: 0.9)
            self.indigo = UIColor(rgb: dark ? 0x1196ff : 0x1485ee)
        }
    }

    private static let green = UIColor(rgb: 0x07c160)
    // IMG_2461: rows of 220px, the search box 10pt under the bar, the first row 17.67pt under the box.
    private static let rowHeight: CGFloat = 220.0 / 3.0
    private static let headerHeight: CGFloat = 10.0 + 36.0 + 53.0 / 3.0

    private let context: AccountContext
    private let openSearch: (ChatListSearchFilter) -> Void
    private var presentationData: PresentationData
    private var presentationDisposable: Disposable?
    private var peerDisposable: Disposable?
    private let resolveDisposable = MetaDisposable()
    private var accountPeer: EnginePeer?

    private let titleLabel = UILabel()
    private let backButton = ASButtonNode()
    private let moreButton = WegramOffsetButtonNode(imageOffset: 29.0 / 3.0)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let header = UIView()
    private let fieldButton = UIButton(type: .custom)
    private let fieldGlyph = UIImageView()
    private let fieldPlaceholder = UILabel()
    private let footer = UIView()
    private let codeCard = UIButton(type: .custom)
    private let codeImageView = UIImageView()
    private let codeCaption = UILabel()
    private var codeLink: String?

    private let searchView = UIView()
    private let searchField = UIView()
    private let searchGlyph = UIImageView()
    private let textField = UITextField()
    private let cancelButton = UIButton(type: .custom)
    private let suggestionRow = UIButton(type: .custom)
    private let suggestionIcon = UIImageView()
    private let suggestionLabel = UILabel()
    private let suggestionSeparator = UIView()
    private let suggestionBorder = UIView()
    private let clearButton = UIButton(type: .custom)
    private let notFoundView = UIView()
    private let notFoundLabel = UILabel()
    private let hud = UIView()
    private let hudSpinner = WegramRingSpinnerView(frame: CGRect(x: 0.0, y: 0.0, width: 37.0, height: 37.0))
    private let hudLabel = UILabel()
    private var isSearching = false
    private var validLayout: ContainerViewLayout?

    private var chinese: Bool {
        return self.presentationData.strings.baseLanguageCode.hasPrefix("zh")
    }

    private func text(_ zh: String, _ en: String) -> String {
        return self.chinese ? zh : en
    }

    init(context: AccountContext, openSearch: @escaping (ChatListSearchFilter) -> Void) {
        self.context = context
        self.openSearch = openSearch
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: WegramAddFriendsController.navigationBarData(self.presentationData))

        self.titleLabel.font = wegramNavigationTitleFont
        self.titleLabel.textAlignment = .center
        self.titleLabel.accessibilityTraits = .header
        self.navigationItem.titleView = self.titleLabel

        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        if let item = UIBarButtonItem(customDisplayNode: self.backButton) {
            item.target = self
            item.action = #selector(self.backPressed)
            item.accessibilityLabel = self.presentationData.strings.Common_Back
            self.navigationItem.leftBarButtonItem = item
        }
        self.moreButton.addTarget(self, action: #selector(self.morePressed), forControlEvents: .touchUpInside)
        self.moreButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 0)
        self.moreButton.hitTestSlop = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -12)
        if let item = UIBarButtonItem(customDisplayNode: self.moreButton) {
            item.target = self
            item.action = #selector(self.morePressed)
            item.accessibilityLabel = self.text("更多", "More")
            self.navigationItem.rightBarButtonItem = item
        }

        self.presentationDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            self.presentationData = presentationData
            self.updatePresentation()
        })
        self.peerDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
            guard let self else {
                return
            }
            self.accountPeer = peer
            self.updateCode()
        })
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDisposable?.dispose()
        self.peerDisposable?.dispose()
        self.resolveDisposable.dispose()
    }

    private static func navigationBarData(_ presentationData: PresentationData) -> NavigationBarPresentationData {
        // The bar shares the page's own background here, not the grey of WeChat's grouped pages.
        let colors = Colors(dark: presentationData.theme.overallDarkAppearance)
        return NavigationBarPresentationData(theme: NavigationBarTheme(wegramTheme: presentationData.theme).withUpdatedBackgroundColor(colors.background).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: presentationData.strings))
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.separatorStyle = .none
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.alwaysBounceVertical = true
        self.tableView.keyboardDismissMode = .onDrag
        if #available(iOS 15.0, *) {
            self.tableView.sectionHeaderTopPadding = 0.0
        }
        self.displayNode.view.addSubview(self.tableView)

        self.fieldButton.layer.cornerRadius = 6.0
        self.fieldButton.addTarget(self, action: #selector(self.fieldPressed), for: .touchUpInside)
        self.fieldGlyph.isUserInteractionEnabled = false
        self.fieldPlaceholder.isUserInteractionEnabled = false
        self.fieldButton.addSubview(self.fieldGlyph)
        self.fieldButton.addSubview(self.fieldPlaceholder)
        self.header.addSubview(self.fieldButton)

        self.codeCard.backgroundColor = .white
        self.codeCard.layer.cornerRadius = 12.0
        self.codeCard.addTarget(self, action: #selector(self.codePressed), for: .touchUpInside)
        self.codeImageView.isUserInteractionEnabled = false
        self.codeImageView.layer.magnificationFilter = .nearest
        self.codeCard.addSubview(self.codeImageView)
        self.footer.addSubview(self.codeCard)
        self.codeCaption.textAlignment = .center
        self.footer.addSubview(self.codeCaption)

        self.searchView.isHidden = true
        self.searchView.accessibilityViewIsModal = true
        self.searchField.layer.cornerRadius = 4.0
        self.searchView.addSubview(self.searchField)
        self.searchField.addSubview(self.searchGlyph)
        self.textField.returnKeyType = .search
        self.textField.enablesReturnKeyAutomatically = true
        self.textField.autocorrectionType = .no
        self.textField.autocapitalizationType = .none
        self.textField.spellCheckingType = .no
        self.textField.tintColor = WegramAddFriendsController.green
        self.textField.delegate = self
        self.textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
        self.searchField.addSubview(self.textField)
        // UIKit's own clear button is a dark disc here; WeChat's is a light 17pt one (IMG_2464).
        self.clearButton.isHidden = true
        self.clearButton.addTarget(self, action: #selector(self.clearPressed), for: .touchUpInside)
        self.searchField.addSubview(self.clearButton)
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), for: .touchUpInside)
        self.searchView.addSubview(self.cancelButton)

        self.suggestionRow.isHidden = true
        self.suggestionRow.addTarget(self, action: #selector(self.suggestionPressed), for: .touchUpInside)
        self.suggestionIcon.backgroundColor = WegramAddFriendsController.green
        self.suggestionIcon.layer.cornerRadius = 16.0 / 3.0
        self.suggestionIcon.clipsToBounds = true
        self.suggestionIcon.contentMode = .center
        self.suggestionIcon.image = WegramAddFriendsController.magnifierImage(size: 70.0 / 3.0, lineWidth: 2.2, color: .white)
        self.suggestionIcon.isUserInteractionEnabled = false
        self.suggestionLabel.isUserInteractionEnabled = false
        self.suggestionRow.addSubview(self.suggestionIcon)
        self.suggestionRow.addSubview(self.suggestionLabel)
        self.suggestionRow.addSubview(self.suggestionBorder)
        self.suggestionRow.addSubview(self.suggestionSeparator)
        self.searchView.addSubview(self.suggestionRow)

        self.notFoundView.isHidden = true
        self.notFoundLabel.textAlignment = .center
        self.notFoundView.addSubview(self.notFoundLabel)
        self.searchView.addSubview(self.notFoundView)

        self.hud.isHidden = true
        self.hud.layer.cornerRadius = 8.0
        self.hud.addSubview(self.hudSpinner)
        self.hudLabel.textAlignment = .center
        self.hud.addSubview(self.hudLabel)
        self.searchView.addSubview(self.hud)

        self.displayNode.view.addSubview(self.searchView)

        self.updatePresentation()
        self.displayNodeDidLoad()
    }

    private func updatePresentation() {
        let data = self.presentationData
        let dark = data.theme.overallDarkAppearance
        let colors = Colors(dark: dark)
        let control = WegramNavigationColors(isDark: dark).control

        self.navigationBar?.updatePresentationData(WegramAddFriendsController.navigationBarData(data), transition: .immediate)
        self.statusBar.statusBarStyle = data.theme.rootController.statusBarStyle.style
        self.titleLabel.text = self.text("添加朋友", "Add Friends")
        self.titleLabel.textColor = control
        self.titleLabel.sizeToFit()

        let backImage = wegramNavigationBackArrowImage(color: control)
        self.backButton.setImage(backImage, for: .normal)
        let backSize = backImage?.size ?? .zero
        self.backButton.contentEdgeInsets = UIEdgeInsets(top: (44 - backSize.height) / 2, left: 0, bottom: (44 - backSize.height) / 2, right: 44 - backSize.width)
        self.navigationItem.leftBarButtonItem?.accessibilityLabel = data.strings.Common_Back
        self.moreButton.setImage(generateTintedImage(image: WegramIcon.chatMore.image(), color: control), for: .normal)
        self.navigationItem.rightBarButtonItem?.accessibilityLabel = self.text("更多", "More")
        self.moreButton.accessibilityLabel = self.text("更多", "More")

        guard self.isNodeLoaded else {
            return
        }
        let scale = data.listsFontSize.itemListBaseFontSize / 17.0
        self.displayNode.backgroundColor = colors.background
        self.tableView.backgroundColor = colors.background

        self.fieldButton.backgroundColor = colors.field
        self.fieldGlyph.image = WegramAddFriendsController.magnifierImage(size: 16.0, lineWidth: 1.4, color: colors.placeholder)
        self.fieldPlaceholder.font = Font.regular(17.0 * scale)
        self.fieldPlaceholder.textColor = colors.placeholder
        self.fieldPlaceholder.text = self.text("账号/手机号", "Username/Phone")
        self.fieldButton.accessibilityLabel = self.fieldPlaceholder.text
        self.fieldButton.accessibilityTraits = .searchField

        self.codeCaption.font = Font.regular(17.0 * scale)
        self.codeCaption.textColor = colors.primary
        self.codeCard.accessibilityLabel = self.text("我的二维码", "My QR Code")

        self.searchView.backgroundColor = colors.searchBackground
        self.searchField.backgroundColor = colors.searchField
        self.searchGlyph.image = WegramAddFriendsController.magnifierImage(size: 16.0, lineWidth: 1.4, color: colors.placeholder)
        self.textField.font = Font.regular(17.0 * scale)
        self.textField.textColor = colors.primary
        self.textField.keyboardAppearance = dark ? .dark : .light
        self.textField.attributedPlaceholder = NSAttributedString(string: self.text("账号/手机号", "Username/Phone"), attributes: [.font: Font.regular(17.0 * scale), .foregroundColor: colors.placeholder])
        self.cancelButton.setTitle(data.strings.Common_Cancel, for: .normal)
        self.cancelButton.setTitleColor(colors.link, for: .normal)
        self.cancelButton.titleLabel?.font = Font.regular(17.0 * scale)
        self.suggestionRow.backgroundColor = colors.searchField
        // IMG_2464: a #303030 line across the row's foot, brighter (70) from 16pt in.
        self.suggestionBorder.backgroundColor = colors.separator
        self.suggestionSeparator.backgroundColor = UIColor(white: dark ? 1.0 : 0.0, alpha: 0.1)
        self.clearButton.setImage(WegramAddFriendsController.clearImage(color: UIColor(rgb: dark ? 0x9898a0 : 0xb2b2b2)), for: .normal)
        self.clearButton.accessibilityLabel = self.text("清除", "Clear")
        self.notFoundView.backgroundColor = colors.searchField
        self.notFoundLabel.font = Font.regular(16.0 * scale)
        self.notFoundLabel.textColor = colors.notFound
        self.notFoundLabel.text = self.text("该用户不存在", "This user does not exist")
        self.hud.backgroundColor = colors.hud
        self.hudSpinner.color = colors.hudText
        self.hudLabel.font = Font.regular(13.0 * scale)
        self.hudLabel.textColor = colors.hudText
        self.hudLabel.text = self.text("正在加载", "Loading")
        self.updateSuggestion()
        self.updateCode()
        self.tableView.reloadData()
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: .immediate)
        }
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.validLayout = layout
        let scale = self.presentationData.listsFontSize.itemListBaseFontSize / 17.0

        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let width = layout.size.width - layout.safeInsets.left - layout.safeInsets.right
        transition.updateFrame(view: self.tableView, frame: CGRect(x: layout.safeInsets.left, y: top, width: width, height: max(0.0, layout.size.height - top)))
        self.tableView.contentInset.bottom = layout.intrinsicInsets.bottom
        self.tableView.rowHeight = floorToScreenPixels(WegramAddFriendsController.rowHeight * max(1.0, scale))

        self.header.frame = CGRect(x: 0.0, y: 0.0, width: width, height: WegramAddFriendsController.headerHeight)
        self.fieldButton.frame = CGRect(x: 20.0, y: 10.0, width: width - 40.0, height: 36.0)
        // The glyph and placeholder are centred as one group: ink 141.33-259.67pt in IMG_2461.
        let placeholderSize = self.fieldPlaceholder.sizeThatFits(CGSize(width: width, height: 36.0))
        let groupWidth = 16.0 + 10.0 + placeholderSize.width
        let groupX = floorToScreenPixels((self.fieldButton.bounds.width - groupWidth) / 2.0)
        self.fieldGlyph.frame = CGRect(x: groupX, y: 10.0, width: 16.0, height: 16.0)
        self.fieldPlaceholder.frame = CGRect(x: groupX + 26.0, y: floorToScreenPixels((36.0 - placeholderSize.height) / 2.0), width: placeholderSize.width, height: placeholderSize.height)
        if self.tableView.tableHeaderView !== self.header {
            self.tableView.tableHeaderView = self.header
        }

        // IMG_2462: a 192pt card 56.33pt below the last row, its caption's ink 19pt below the card.
        let captionHeight = ceil(self.codeCaption.font.lineHeight)
        let cardTop: CGFloat = 169.0 / 3.0
        self.codeCard.frame = CGRect(x: floorToScreenPixels((width - 192.0) / 2.0), y: cardTop, width: 192.0, height: 192.0)
        self.codeImageView.frame = CGRect(x: 16.0, y: 16.0, width: 160.0, height: 160.0)
        self.codeCaption.frame = CGRect(x: 16.0, y: cardTop + 192.0 + 16.0, width: width - 32.0, height: captionHeight)
        self.footer.frame = CGRect(x: 0.0, y: 0.0, width: width, height: self.codeCaption.frame.maxY + 64.0)
        if self.tableView.tableFooterView !== self.footer {
            self.tableView.tableFooterView = self.footer
        } else {
            self.tableView.tableFooterView = self.footer
        }

        // Search mode (IMG_2463-2466): the box rides up over the bar, 8pt in from the left, with 取消 beside it.
        self.searchView.frame = CGRect(origin: .zero, size: layout.size)
        let statusTop = layout.statusBarHeight ?? layout.safeInsets.top
        let fieldTop = statusTop + 4.0
        let fieldRight = layout.size.width - layout.safeInsets.right - 53.0
        self.searchField.frame = CGRect(x: layout.safeInsets.left + 8.0, y: fieldTop, width: fieldRight - layout.safeInsets.left - 8.0, height: 36.0)
        self.searchGlyph.frame = CGRect(x: 11.0, y: 10.0, width: 16.0, height: 16.0)
        // The clear disc's ink sits 7pt in from the box's right edge (IMG_2464); the button is 44pt wide around it.
        self.clearButton.frame = CGRect(x: self.searchField.bounds.width - 7.0 - 17.0 - 13.5, y: 0.0, width: 44.0, height: 36.0)
        self.textField.frame = CGRect(x: 37.0, y: 0.0, width: self.clearButton.frame.minX - 37.0, height: 36.0)
        let cancelSize = self.cancelButton.sizeThatFits(CGSize(width: 100.0, height: 36.0))
        self.cancelButton.frame = CGRect(x: layout.size.width - layout.safeInsets.right - 8.0 - cancelSize.width, y: fieldTop - 1.0, width: cancelSize.width, height: 36.0)

        let resultsTop = fieldTop + 36.0 + 15.0
        let resultsWidth = layout.size.width
        self.suggestionRow.frame = CGRect(x: 0.0, y: resultsTop, width: resultsWidth, height: 64.0)
        self.suggestionIcon.frame = CGRect(x: layout.safeInsets.left + 15.0, y: 8.0, width: 48.0, height: 48.0)
        self.suggestionLabel.frame = CGRect(x: layout.safeInsets.left + 73.0, y: 0.0, width: resultsWidth - layout.safeInsets.left - 73.0 - 16.0, height: 64.0 - UIScreenPixel)
        self.suggestionBorder.frame = CGRect(x: 0.0, y: 64.0 - UIScreenPixel, width: resultsWidth, height: UIScreenPixel)
        self.suggestionSeparator.frame = CGRect(x: layout.safeInsets.left + 16.0, y: 64.0 - UIScreenPixel, width: resultsWidth - layout.safeInsets.left - 16.0, height: UIScreenPixel)
        self.notFoundView.frame = CGRect(x: 0.0, y: resultsTop, width: resultsWidth, height: 96.0)
        self.notFoundLabel.frame = self.notFoundView.bounds
        // IMG_2466: a 124x121pt toast in the middle of the screen, spinner above a 13pt label.
        self.hud.frame = CGRect(x: floorToScreenPixels((layout.size.width - 124.0) / 2.0), y: floorToScreenPixels((layout.size.height - 121.0) / 2.0), width: 124.0, height: 121.0)
        self.hudSpinner.center = CGPoint(x: 62.0, y: 134.0 / 3.0)
        self.hudLabel.frame = CGRect(x: 0.0, y: 236.0 / 3.0, width: 124.0, height: ceil(self.hudLabel.font.lineHeight))
        self.displayNode.view.bringSubviewToFront(self.searchView)
    }

    private static func clearImage(color: UIColor) -> UIImage? {
        return generateImage(CGSize(width: 17.0, height: 17.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(origin: .zero, size: size))
            // The cross is cut out of the disc.
            context.setBlendMode(.clear)
            context.setLineWidth(1.5)
            context.setLineCap(.round)
            let inset: CGFloat = 5.5
            context.move(to: CGPoint(x: inset, y: inset))
            context.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
            context.move(to: CGPoint(x: size.width - inset, y: inset))
            context.addLine(to: CGPoint(x: inset, y: size.height - inset))
            context.strokePath()
        })
    }

    private static func magnifierImage(size: CGFloat, lineWidth: CGFloat, color: UIColor) -> UIImage? {
        return generateImage(CGSize(width: size, height: size), rotatedContext: { canvas, context in
            context.clear(CGRect(origin: .zero, size: canvas))
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            let radius = canvas.width * 0.36
            let center = CGPoint(x: lineWidth / 2.0 + radius, y: lineWidth / 2.0 + radius)
            // One path, so a translucent colour does not darken where the handle meets the ring.
            context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0))
            let start = center.x + radius * 0.7071
            context.move(to: CGPoint(x: start, y: start))
            context.addLine(to: CGPoint(x: canvas.width - lineWidth / 2.0, y: canvas.height - lineWidth / 2.0))
            context.strokePath()
        })
    }

    // MARK: - Rows

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: "row") as? WegramAddFriendsCell) ?? WegramAddFriendsCell()
        let data = self.presentationData
        let colors = Colors(dark: data.theme.overallDarkAppearance)
        let scale = data.listsFontSize.itemListBaseFontSize / 17.0
        let row = Row.allCases[indexPath.row]
        let title: String
        let subtitle: String
        let icon: WegramIcon
        let tint: UIColor
        switch row {
        case .scan:
            title = self.text("扫一扫", "Scan")
            subtitle = self.text("扫描二维码名片", "Scan a QR code")
            icon = .scan
            tint = colors.indigo
        case .phoneContacts:
            title = self.text("手机联系人", "Phone Contacts")
            subtitle = self.text("添加通讯录中的朋友", "Add friends from your contacts")
            icon = .phoneContacts
            tint = WegramAddFriendsController.green
        case .officialAccounts:
            title = self.text("公众号", "Channels")
            subtitle = self.text("获取更多资讯", "Get more news")
            icon = .officialAccounts
            tint = colors.indigo
        case .serviceAccounts:
            title = self.text("服务号", "Bots and Apps")
            subtitle = self.text("获取更多购物信息和服务", "Get more shopping and services")
            icon = .serviceAccounts
            tint = UIColor(rgb: 0xff6146)
        }
        cell.backgroundColor = colors.background
        cell.selectedBackgroundView?.backgroundColor = data.theme.list.itemHighlightedBackgroundColor
        cell.icon.image = icon.image()
        cell.icon.tintColor = tint
        cell.title.text = title
        cell.title.font = Font.regular(17.0 * scale)
        cell.title.textColor = colors.primary
        cell.subtitle.text = subtitle
        cell.subtitle.font = Font.regular(14.0 * scale)
        cell.subtitle.textColor = colors.secondary
        cell.arrow.tintColor = data.theme.list.disclosureArrowColor
        cell.separator.backgroundColor = colors.separator
        // The last row's line runs under the icon as well (IMG_2461).
        cell.separatorLeftInset = indexPath.row == Row.allCases.count - 1 ? 24.0 : 64.0
        cell.accessibilityLabel = title
        cell.accessibilityHint = subtitle
        cell.accessibilityTraits = .button
        cell.setNeedsLayout()
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Row.allCases[indexPath.row] {
        case .scan:
            self.push(QrCodeScanScreen(context: self.context, subject: .peer, usesWegramAppearance: true))
        case .phoneContacts:
            openNewContact(context: self.context, from: self)
        case .officialAccounts:
            self.openSearch(.channels)
        case .serviceAccounts:
            self.openSearch(.apps)
        }
    }

    // MARK: - My code

    private func updateCode() {
        guard self.isNodeLoaded, let peer = self.accountPeer else {
            return
        }
        let link: String
        if let username = peer.addressName, !username.isEmpty {
            link = "https://t.me/\(username)"
            self.codeCaption.text = self.text("我的账号：", "My username: ") + username
        } else if case let .user(user) = peer, let phone = user.phone, !phone.isEmpty {
            // The same link the profile's 我的二维码 page encodes when there is no username.
            link = "https://t.me/+\(phone)"
            self.codeCaption.text = self.text("我的二维码", "My QR Code")
        } else {
            self.codeLink = nil
            self.codeImageView.image = nil
            self.codeCaption.text = nil
            return
        }
        if link != self.codeLink {
            self.codeLink = link
            self.codeImageView.image = WegramAddFriendsController.codeImage(link: link)
        }
    }

    /// WeChat's code: square modules and plain finder squares, and a black tile with the logo in the middle.
    private static func codeImage(link: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        filter.setValue(Data(link.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage, let full = CIContext().createCGImage(output, from: output.extent) else {
            return nil
        }
        // The generator adds a one-module quiet zone; the card's own 16pt margin replaces it.
        let modules = full.width - 2
        guard modules > 0, let code = full.cropping(to: CGRect(x: 1, y: 1, width: modules, height: modules)) else {
            return nil
        }
        let side: CGFloat = 160.0
        let logo = WegramIcon.chats.image(selected: true).flatMap { generateTintedImage(image: $0, color: .white) }
        return generateImage(CGSize(width: side, height: side), contextGenerator: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.interpolationQuality = .none
            context.draw(code, in: CGRect(origin: .zero, size: size))
            let tile: CGFloat = 39.0
            let tileRect = CGRect(x: (side - tile) / 2.0, y: (side - tile) / 2.0, width: tile, height: tile)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(tileRect.insetBy(dx: -3.0, dy: -3.0))
            context.setFillColor(UIColor.black.cgColor)
            context.addPath(UIBezierPath(roundedRect: tileRect, cornerRadius: 8.0).cgPath)
            context.fillPath()
            if let logo = logo?.cgImage {
                let logoRect = CGRect(x: (side - 26.0) / 2.0, y: (side - 26.0) / 2.0, width: 26.0, height: 26.0)
                context.interpolationQuality = .high
                context.draw(logo, in: logoRect)
            }
        }, opaque: false)
    }

    @objc private func codePressed() {
        guard let peer = self.accountPeer else {
            return
        }
        self.push(self.context.sharedContext.makeChatQrCodeScreen(context: self.context, peer: peer, threadId: nil, temporary: false))
    }

    @objc private func morePressed() {
        guard let peer = self.accountPeer else {
            return
        }
        let data = self.presentationData
        let sheet = ActionSheetController(presentationData: data)
        var items: [ActionSheetItem] = [
            ActionSheetButtonItem(title: self.text("我的二维码", "My QR Code"), color: .accent, action: { [weak self, weak sheet] in
                sheet?.dismissAnimated()
                self?.codePressed()
            })
        ]
        if let username = peer.addressName, !username.isEmpty {
            items.append(ActionSheetButtonItem(title: self.text("复制我的链接", "Copy My Link"), color: .accent, action: { [weak sheet] in
                sheet?.dismissAnimated()
                UIPasteboard.general.string = "https://t.me/\(username)"
            }))
        }
        sheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: data.strings.Common_Cancel, color: .accent, action: { [weak sheet] in
                sheet?.dismissAnimated()
            })])
        ])
        self.present(sheet, in: .window(.root))
    }

    @objc private func backPressed() {
        self.dismiss()
    }

    // MARK: - Search

    @objc private func fieldPressed() {
        guard !self.isSearching else {
            return
        }
        self.isSearching = true
        self.searchView.isHidden = false
        self.searchView.alpha = 0.0
        self.displayNode.view.bringSubviewToFront(self.searchView)
        UIView.animate(withDuration: 0.2, animations: {
            self.searchView.alpha = 1.0
        })
        self.textField.becomeFirstResponder()
        UIAccessibility.post(notification: .screenChanged, argument: self.textField)
    }

    @objc private func cancelPressed() {
        self.resolveDisposable.set(nil)
        self.isSearching = false
        self.textField.resignFirstResponder()
        self.textField.text = nil
        self.clearButton.isHidden = true
        self.hud.isHidden = true
        self.hudSpinner.stopAnimating()
        self.notFoundView.isHidden = true
        self.updateSuggestion()
        UIView.animate(withDuration: 0.2, animations: {
            self.searchView.alpha = 0.0
        }, completion: { [weak self] _ in
            guard let self, !self.isSearching else {
                return
            }
            self.searchView.isHidden = true
        })
        UIAccessibility.post(notification: .screenChanged, argument: self.fieldButton)
    }

    @objc private func clearPressed() {
        self.textField.text = nil
        self.textChanged()
        self.textField.becomeFirstResponder()
    }

    @objc private func textChanged() {
        self.clearButton.isHidden = (self.textField.text ?? "").isEmpty
        self.resolveDisposable.set(nil)
        self.hud.isHidden = true
        self.hudSpinner.stopAnimating()
        self.notFoundView.isHidden = true
        self.updateSuggestion()
    }

    private func updateSuggestion() {
        let query = self.currentQuery
        guard !query.isEmpty, self.notFoundView.isHidden else {
            self.suggestionRow.isHidden = true
            return
        }
        let scale = self.presentationData.listsFontSize.itemListBaseFontSize / 17.0
        let colors = Colors(dark: self.presentationData.theme.overallDarkAppearance)
        let string = NSMutableAttributedString(string: self.text("搜索:", "Search: "), attributes: [.font: Font.regular(17.0 * scale), .foregroundColor: colors.primary])
        string.append(NSAttributedString(string: query, attributes: [.font: Font.regular(17.0 * scale), .foregroundColor: WegramAddFriendsController.green]))
        self.suggestionLabel.attributedText = string
        self.suggestionLabel.lineBreakMode = .byTruncatingTail
        self.suggestionRow.accessibilityLabel = string.string
        self.suggestionRow.isHidden = false
    }

    private var currentQuery: String {
        return (self.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.performSearch()
        return false
    }

    @objc private func suggestionPressed() {
        self.performSearch()
    }

    private func performSearch() {
        let query = self.currentQuery
        guard !query.isEmpty else {
            return
        }
        let digits = query.filter { $0.isASCII && $0.isNumber }
        let looksLikePhone = digits.count >= 5 && query.allSatisfy { "+0123456789 -()".contains($0) }
        var name = query
        if let range = name.range(of: "t.me/", options: .caseInsensitive) {
            name = String(name[range.upperBound...])
        }
        if name.hasPrefix("@") {
            name.removeFirst()
        }
        let lookup: Signal<EnginePeer?, NoError>
        if looksLikePhone {
            lookup = self.context.engine.peers.resolvePeerByPhone(phone: digits)
        } else if name.count >= 4, name.count <= 32, name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }) {
            lookup = self.context.engine.peers.resolvePeerByName(name: name, referrer: nil)
            |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                guard case let .result(peer) = result else {
                    return .complete()
                }
                return .single(peer)
            }
        } else {
            // Not a username Telegram can hold, so there is nothing to ask the server.
            self.showNotFound()
            return
        }

        self.textField.resignFirstResponder()
        self.suggestionRow.isHidden = true
        self.hud.isHidden = false
        self.hudSpinner.startAnimating()
        self.searchView.bringSubviewToFront(self.hud)
        self.resolveDisposable.set((lookup
        |> take(1)
        |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
            guard let self, self.isSearching else {
                return
            }
            self.hud.isHidden = true
            self.hudSpinner.stopAnimating()
            guard let peer, let controller = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: nil, peer: peer, mode: peer.id == self.context.account.peerId ? .myProfile : .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) else {
                self.showNotFound()
                return
            }
            self.push(controller)
        }))
    }

    private func showNotFound() {
        self.textField.resignFirstResponder()
        self.suggestionRow.isHidden = true
        self.notFoundView.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: self.notFoundLabel.text)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.textField.resignFirstResponder()
    }
}

/// WeChat's loading ring (IMG_2466): a 37pt circle whose 2.67pt stroke fades from a bright head to nothing.
private final class WegramRingSpinnerView: UIView {
    private let gradient = CAGradientLayer()
    private let ring = CAShapeLayer()

    var color: UIColor = .white {
        didSet {
            self.gradient.colors = [self.color.withAlphaComponent(0.0).cgColor, self.color.cgColor]
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.gradient.type = .conic
        self.gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.gradient.endPoint = CGPoint(x: 0.5, y: 0.0)
        self.gradient.frame = self.bounds
        let lineWidth: CGFloat = 8.0 / 3.0
        self.ring.path = UIBezierPath(ovalIn: self.bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0)).cgPath
        self.ring.lineWidth = lineWidth
        self.ring.fillColor = nil
        self.ring.strokeColor = UIColor.black.cgColor
        self.ring.frame = self.bounds
        self.gradient.mask = self.ring
        self.layer.addSublayer(self.gradient)
        self.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startAnimating() {
        self.isHidden = false
        guard self.gradient.animation(forKey: "spin") == nil else {
            return
        }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0.0
        animation.toValue = 2.0 * CGFloat.pi
        animation.duration = 0.9
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        self.gradient.add(animation, forKey: "spin")
    }

    func stopAnimating() {
        self.isHidden = true
        self.gradient.removeAnimation(forKey: "spin")
    }
}

/// The bar keeps its right item 24pt from the screen edge, but WeChat's "⋯" ends 19pt from it (IMG_2461),
/// so the glyph is drawn past the node's trailing edge.
private final class WegramOffsetButtonNode: ASButtonNode {
    private let imageOffset: CGFloat

    init(imageOffset: CGFloat) {
        self.imageOffset = imageOffset
        super.init()
    }

    override func layout() {
        super.layout()
        self.imageNode.frame = self.imageNode.frame.offsetBy(dx: self.imageOffset, dy: 0.0)
    }
}

private final class WegramAddFriendsCell: UITableViewCell {
    let icon = UIImageView()
    let title = UILabel()
    let subtitle = UILabel()
    let arrow = UIImageView(image: wegramDisclosureArrowImage)
    let separator = UIView()
    var separatorLeftInset: CGFloat = 64.0

    init() {
        super.init(style: .default, reuseIdentifier: "row")
        self.selectedBackgroundView = UIView()
        self.icon.contentMode = .scaleAspectFit
        self.contentView.addSubview(self.icon)
        self.contentView.addSubview(self.title)
        self.contentView.addSubview(self.subtitle)
        self.contentView.addSubview(self.arrow)
        self.addSubview(self.separator)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.contentView.bounds.width
        let height = self.contentView.bounds.height
        // IMG_2461 at 3x: glyphs on a 24pt grid centred 36pt in, titles from 64pt, the chevron and the lines
        // stopping 24pt short of the right edge. Title and subtitle ink centres sit 26.67pt and 49.17pt into
        // the 73.33pt row.
        self.icon.frame = CGRect(x: 24.0, y: floorToScreenPixels(height / 2.0 - 12.0), width: 24.0, height: 24.0)
        let textWidth = max(0.0, width - 64.0 - 40.0)
        let titleHeight = ceil(self.title.font.lineHeight)
        let subtitleHeight = ceil(self.subtitle.font.lineHeight)
        let titleCenter = height * 80.0 / 220.0
        let subtitleCenter = height * 147.5 / 220.0
        self.title.frame = CGRect(x: 64.0, y: floorToScreenPixels(titleCenter - titleHeight / 2.0), width: textWidth, height: titleHeight)
        self.subtitle.frame = CGRect(x: 64.0, y: floorToScreenPixels(subtitleCenter - subtitleHeight / 2.0), width: textWidth, height: subtitleHeight)
        self.arrow.frame = wegramDisclosureArrowFrame(trailingEdge: width - 8.0, centerY: height / 2.0)
        self.separator.frame = CGRect(x: self.separatorLeftInset, y: self.bounds.height - UIScreenPixel, width: max(0.0, self.bounds.width - self.separatorLeftInset - 24.0), height: UIScreenPixel)
    }
}
