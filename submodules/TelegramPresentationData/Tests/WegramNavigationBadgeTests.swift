import XCTest
import UIKit
import Display
import NavigationBarImpl
import TelegramPresentationData
import AsyncDisplayKit
import ComponentFlow
import TabBarComponent

final class WegramNavigationBadgeTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }

    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }

    func testFlatTabsExposeOneAccessibleButtonPerVisibleTabAndRefreshSelectionAndBadge() throws {
        let tabs = ["微信", "通讯录", "发现", "我"].map { UITabBarItem(title: $0, image: WegramIcon.chatInputMore.image(), selectedImage: nil) }
        tabs[0].badgeValue = "7.1K"
        let componentView = ComponentView<Empty>()
        func update(selected: Int, flat: Bool = true, items: [UITabBarItem]? = nil) -> [UIView] {
            let items = items ?? tabs
            let size = componentView.update(transition: .immediate, component: AnyComponent(TabBarComponent(
                theme: defaultPresentationTheme, isFlat: flat, strings: defaultPresentationStrings,
                items: items.map { TabBarComponent.Item(content: .tabBarItem($0), action: { _ in XCTFail("Detached tab must not activate") }, doubleTapAction: nil, contextAction: nil) },
                search: nil, selectedId: AnyHashable(ObjectIdentifier(items[selected])), outerInsets: .zero
            )), environment: {}, containerSize: CGSize(width: 402, height: 83))
            componentView.view?.frame = CGRect(origin: .zero, size: size)
            func accessible(_ view: UIView) -> [UIView] {
                guard !view.isHidden, view.alpha > 0, !view.accessibilityElementsHidden else { return [] }
                return view.isAccessibilityElement ? [view] : view.subviews.flatMap(accessible)
            }
            return componentView.view.map(accessible) ?? []
        }
        let initial = update(selected: 0)
        XCTAssertEqual(initial.map(\.accessibilityLabel), tabs.map(\.title))
        XCTAssertEqual(initial.count, 4)
        guard initial.count == 4 else { return }
        XCTAssertTrue(initial.allSatisfy { $0.accessibilityTraits.contains(.button) })
        XCTAssertEqual(initial.map { $0.accessibilityTraits.contains(.selected) }, [true, false, false, false])
        XCTAssertEqual(initial[0].accessibilityValue, "7.1K")
        XCTAssertFalse(initial[0].accessibilityActivate())
        tabs[0].badgeValue = nil
        let next = update(selected: 1)
        XCTAssertEqual(next.map { $0.accessibilityTraits.contains(.selected) }, [false, true, false, false])
        XCTAssertNil(next.first?.accessibilityValue)
        let removed = try XCTUnwrap(next.last)
        XCTAssertEqual(update(selected: 0, items: Array(tabs.prefix(3))).count, 3)
        XCTAssertFalse(removed.isAccessibilityElement)
        XCTAssertFalse(removed.accessibilityActivate())
        XCTAssertEqual(update(selected: 0).count, 4)
        XCTAssertFalse(removed.isAccessibilityElement, "Re-adding the same tab must not revive the removed view")
        XCTAssertFalse(removed.accessibilityActivate())
        XCTAssertTrue(update(selected: 0, flat: false).isEmpty, "WeGram accessibility must not duplicate the glass renderer")
        XCTAssertFalse(initial[0].accessibilityActivate())
    }

    func testVoiceInputArtworkHasAllThreeInnerWavesFromTheReference() throws {
        let image = try XCTUnwrap(WegramIcon.chatInputVoice.image()?.cgImage)
        let side = 84
        var rgba = [UInt8](repeating: 0, count: side * side * 4)
        let context = try XCTUnwrap(CGContext(data: &rgba, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        var centers: [CGFloat] = []
        var start: Int?
        for x in 15...69 {
            let visible = rgba[(42 * side + x) * 4 + 3] > 127
            if visible && start == nil { start = x }
            if !visible, let first = start {
                centers.append(CGFloat(first + x - 1) / 6.0)
                start = nil
            }
        }
        XCTAssertEqual(centers.count, 3, "Voice artwork must contain the small inner wedge and two larger waves")
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let canvas = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 80))
            for (row, dark) in [false, true].enumerated() {
                let background = UIView(frame: CGRect(x: 0, y: row * 40, width: 320, height: 40))
                background.backgroundColor = UIColor(rgb: dark ? 0x202020 : 0xf7f7f7)
                canvas.addSubview(background)
                for (column, icon) in [WegramIcon.chatInputVoice, .chatInputEmoji, .chatInputMore, .chatInputKeyboard, .attachmentPhoto, .attachmentCamera, .attachmentVideo, .attachmentLocation].enumerated() {
                    let view = UIImageView(image: icon.image())
                    view.tintColor = WegramNavigationColors(isDark: dark).control
                    view.frame = CGRect(x: column * 40 + 6, y: 6, width: 28, height: 28)
                    background.addSubview(view)
                }
            }
            let format = UIGraphicsImageRendererFormat(); format.scale = 3
            let artwork = UIGraphicsImageRenderer(size: canvas.bounds.size, format: format).image { canvas.layer.render(in: $0.cgContext) }
            try artwork.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("wegram-input-icons.png"))
        }
        if centers.count == 3 {
            XCTAssertTrue((8.0...11.0).contains(centers[0]))
            XCTAssertTrue((13.0...15.0).contains(centers[1]))
            XCTAssertTrue((17.0...19.0).contains(centers[2]))
        }
    }

    func testDisabledActionSheetItemCannotRunThroughAccessibilityActivation() {
        let theme = ActionSheetControllerTheme(wegramTheme: defaultPresentationTheme, fontSize: .regular)
        var invoked = 0
        let item = ActionSheetButtonItem(title: "Unavailable", color: .disabled, enabled: false, action: { invoked += 1 })
        let node = item.node(theme: theme)
        let _ = node.view
        let _ = node.updateLayout(constrainedSize: CGSize(width: 320, height: 200), transition: .immediate)
        let area = node.subnodes?.compactMap { $0 as? AccessibilityAreaNode }.first
        XCTAssertNotNil(area)
        XCTAssertTrue(area?.accessibilityTraits.contains(.notEnabled) == true)
        let _ = area?.accessibilityActivate()
        XCTAssertEqual(invoked, 0, "Disabled menu actions must reject activation from every input path")
        item.updateNode(node)
        let enabled = ActionSheetButtonItem(title: "Available", enabled: true, action: { invoked += 1 })
        enabled.updateNode(node)
        let _ = area?.accessibilityActivate()
        XCTAssertEqual(invoked, 1)
    }

    func testWegramActionSheetUsesFlatFullWidthRowsAndKeepsCancelAboveTheHomeArea() {
        func descendants(_ node: ASDisplayNode) -> [ASDisplayNode] { [node] + (node.subnodes ?? []).flatMap(descendants) }
        for dark in [false, true] {
            for size in [CGSize(width: 320, height: 568), CGSize(width: 402, height: 874), CGSize(width: 720, height: 320)] {
                let theme = ActionSheetControllerTheme(wegramTheme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme, fontSize: .regular)
                let sheet = ActionSheetController(theme: theme)
                sheet.setItemGroups([
                    ActionSheetItemGroup(items: ["更换头像", "保存或分享头像", "查看历史头像", "更多编辑选项"].map { ActionSheetButtonItem(title: $0, action: {}) }),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "取消", action: {})])
                ])
                let root = sheet.displayNode
                let _ = root.view
                root.frame = CGRect(origin: .zero, size: size)
                let bottom: CGFloat = 34
                let layout = ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
                sheet.containerLayoutUpdated(layout, transition: .immediate)
                let buttons = descendants(root).compactMap { $0 as? ActionSheetButtonNode }
                XCTAssertEqual(buttons.count, 5)
                for button in buttons {
                    XCTAssertEqual(button.bounds.width, size.width)
                    XCTAssertEqual(button.bounds.height, 56)
                    let text = descendants(button).compactMap { $0 as? ImmediateTextNode }.first?.attributedText
                    XCTAssertEqual((text?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, 17)
                }
                guard let cancel = buttons.last else { continue }
                let cancelFrame = cancel.view.convert(cancel.bounds, to: root.view)
                XCTAssertEqual(cancelFrame.minX, 0)
                XCTAssertEqual(cancelFrame.maxY, size.height - bottom)
                let gaps = descendants(root).filter { String(describing: type(of: $0)) == "ActionSheetItemGroupNode" }
                XCTAssertEqual(gaps.count, 2)
                let first = gaps[0].view.convert(gaps[0].bounds, to: root.view)
                let last = gaps[1].view.convert(gaps[1].bounds, to: root.view)
                XCTAssertEqual(last.minY - first.maxY, 8)
                XCTAssertEqual(theme.standardActionTextColor, UIColor(rgb: dark ? 0xd0d0d0 : 0x181818))
                XCTAssertEqual(theme.itemBackgroundColor, UIColor(rgb: dark ? 0x202020 : 0xffffff))
                if size.width == 402 && !dark {
                    root.recursivelyEnsureDisplaySynchronously(true)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    let image = UIGraphicsImageRenderer(size: size, format: format).image { root.layer.render(in: $0.cgContext) }
                    if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        try? image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("avatar-menu-light-component.png"))
                    }
                    for x in [CGFloat(0), size.width - 1] {
                        guard let pixel = image.cgImage?.cropping(to: CGRect(x: x, y: cancelFrame.maxY - 1, width: 1, height: 1)) else { XCTFail("Missing menu image"); continue }
                        var rgba = [UInt8](repeating: 0, count: 4)
                        let context = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                        context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                        XCTAssertEqual(Array(rgba.prefix(3)), [255, 255, 255], "The cancel row must meet the home area without rounded bottom gaps")
                    }
                }
            }
        }
    }

    func testDefaultActionSheetRetainsItsFontAndRowHeightAndLargeWegramTextHasRoom() {
        let originalTheme = ActionSheetControllerTheme(presentationTheme: defaultPresentationTheme, fontSize: .regular)
        XCTAssertFalse(originalTheme.usesWegramLayout)
        for (theme, expectedFont, expectedHeight) in [
            (originalTheme, CGFloat(20), CGFloat(57)),
            (ActionSheetControllerTheme(wegramTheme: defaultPresentationTheme, fontSize: .extraLargeX2), CGFloat(26), CGFloat(56))
        ] {
            let node = ActionSheetButtonItem(title: "Action", action: {}).node(theme: theme)
            let _ = node.view
            let size = node.updateLayout(constrainedSize: CGSize(width: 320, height: 200), transition: .immediate)
            XCTAssertEqual(size.height, expectedHeight)
            let label = node.subnodes?.compactMap { $0 as? ImmediateTextNode }.first
            XCTAssertEqual((label?.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, expectedFont)
            XCTAssertLessThanOrEqual(label?.frame.maxY ?? 1000, size.height)
        }
    }

    private final class FillingTitle: UIView, NavigationBarTitleView {
        var requestUpdate: ((ContainedViewLayoutTransition) -> Void)?
        func animateLayoutTransition() {}
        func updateLayout(availableSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize { return availableSize }
    }

    private func navigationBar(count: String, nominalHeight: CGFloat = 44) -> NavigationBarImpl {
        let theme = NavigationBarTheme(overallDarkAppearance: true, buttonColor: .white, disabledButtonColor: .gray, primaryTextColor: .white, backgroundColor: .black, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .darkGray, badgeStrokeColor: .clear, badgeTextColor: .white, accentButtonColor: .green, accentDisabledButtonColor: .gray, accentForegroundColor: .white, nominalHeight: nominalHeight)
        let copiedTheme = theme.withUpdatedBackgroundColor(.black).withUpdatedSeparatorColor(.clear)
        let bar = NavigationBarImpl(presentationData: NavigationBarPresentationData(theme: copiedTheme, strings: NavigationBarStrings(back: "返回", close: "关闭")))
        bar.customBackButtonText = ""
        bar.badgeNode.usesWegramAppearance = true
        let item = UINavigationItem(title: "群聊")
        item.titleView = FillingTitle()
        bar.item = item
        bar.previousItem = .item(UINavigationItem(title: "微信"))
        bar.badgeNode.text = count
        bar.badgeNode.isHidden = count.isEmpty
        bar.frame = CGRect(x: 0, y: 0, width: 402, height: 62 + nominalHeight)
        bar.updateLayout(size: bar.bounds.size, defaultHeight: nominalHeight, additionalTopHeight: 62, additionalContentHeight: 0, additionalBackgroundHeight: 0, additionalCutout: nil, leftInset: 0, rightInset: 0, appearsHidden: false, isLandscape: false, transition: .immediate)
        return bar
    }

    func testNameSaveIsVisibleAccessibleAndTracksValidityInsideTheActualNavigationBar() {
        let content = WegramNameContentView()
        content.update(isDark: false, fontSize: 17, doneTitle: "完成", firstNameTitle: "名", lastNameTitle: "姓")
        content.setName(firstName: "Name", lastName: "Surname")
        let bar = self.navigationBar(count: "")
        bar.item!.rightBarButtonItem = content.makeSaveItem()
        func updateBar() {
            bar.updateLayout(size: bar.bounds.size, defaultHeight: 44, additionalTopHeight: 62, additionalContentHeight: 0, additionalBackgroundHeight: 0, additionalCutout: nil, leftInset: 0, rightInset: 0, appearsHidden: false, isLandscape: false, transition: .immediate)
        }
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        updateBar()
        let accessible = descendants(bar.view).filter { $0.isAccessibilityElement && $0.accessibilityTraits.contains(.button) && $0.accessibilityLabel == "完成" }
        XCTAssertFalse(accessible.isEmpty, "The outer navigation wrapper must announce the save action")
        XCTAssertEqual(bar.item!.rightBarButtonItem?.isEnabled, false)
        content.firstNameField.text = "Changed"
        content.firstNameField.sendActions(for: .editingChanged)
        updateBar()
        XCTAssertEqual(bar.item!.rightBarButtonItem?.isEnabled, true)
        XCTAssertTrue(content.saveButton.isDescendant(of: bar.view))
        XCTAssertEqual(content.saveButton.bounds.size, CGSize(width: 64, height: 44))
        let frame = content.saveButton.convert(content.saveButton.bounds, to: bar.view)
        XCTAssertTrue(bar.bounds.contains(frame))
        XCTAssertEqual(frame.midY, 84)
        let hit = bar.view.hitTest(frame.center, with: nil)
        XCTAssertTrue(hit === content.saveButton || hit?.isDescendant(of: content.saveButton) == true)
        content.submitting = true
        XCTAssertEqual(bar.item!.rightBarButtonItem?.isEnabled, false)
    }

    func testBioSaveWrapperAnnouncesTheCurrentLanguageAndTracksTheRealInput() {
        let content = WegramBioContentView()
        content.update(isDark: false, fontSize: 17, maximumLength: 70, title: "签名", doneTitle: "完成")
        content.setBio("Original")
        let bar = self.navigationBar(count: "")
        bar.item!.rightBarButtonItem = content.makeSaveItem()
        content.textView.text = "Changed"
        content.textViewDidChange(content.textView)
        bar.updateLayout(size: bar.bounds.size, defaultHeight: 44, additionalTopHeight: 62, additionalContentHeight: 0, additionalBackgroundHeight: 0, additionalCutout: nil, leftInset: 0, rightInset: 0, appearsHidden: false, isLandscape: false, transition: .immediate)
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        XCTAssertTrue(descendants(bar.view).contains { $0.isAccessibilityElement && $0.accessibilityLabel == "完成" })
        XCTAssertEqual(bar.item!.rightBarButtonItem?.isEnabled, true)
        XCTAssertEqual(content.saveButton.bounds.size, CGSize(width: 64, height: 44))
        let frame = content.saveButton.convert(content.saveButton.bounds, to: bar.view)
        let hit = bar.view.hitTest(frame.center, with: nil)
        XCTAssertTrue(hit === content.saveButton || hit?.isDescendant(of: content.saveButton) == true)
        content.update(isDark: true, fontSize: 17, maximumLength: 70, title: "Bio", doneTitle: "Done")
        bar.item!.rightBarButtonItem = content.makeSaveItem()
        bar.updateLayout(size: bar.bounds.size, defaultHeight: 44, additionalTopHeight: 62, additionalContentHeight: 0, additionalBackgroundHeight: 0, additionalCutout: nil, leftInset: 0, rightInset: 0, appearsHidden: false, isLandscape: false, transition: .immediate)
        XCTAssertTrue(descendants(bar.view).contains { $0.isAccessibilityElement && $0.accessibilityLabel == "Done" })
        content.submitting = true
        XCTAssertEqual(bar.item!.rightBarButtonItem?.isEnabled, false)
        XCTAssertEqual(content.text, "Changed")
    }

    func testProfilePhotoHeaderKeepsTheReferenceTitleAndHasRealBackAndMoreTargets() {
        for width: CGFloat in [320, 402, 720] {
            let bar = self.navigationBar(count: "")
            let header = WegramAvatarGalleryHeader()
            header.apply(to: bar.item!, chinese: true, backTitle: "返回", moreTitle: "更多")
            bar.updatePresentationData(NavigationBarPresentationData(theme: WegramAvatarGalleryHeader.theme, strings: NavigationBarStrings(back: "返回", close: "关闭")), transition: .immediate)
            bar.frame.size.width = width
            bar.updateLayout(size: bar.bounds.size, defaultHeight: 44, additionalTopHeight: 62, additionalContentHeight: 0, additionalBackgroundHeight: 0, additionalCutout: nil, leftInset: 0, rightInset: 0, appearsHidden: false, isLandscape: false, transition: .immediate)
            XCTAssertEqual(bar.nominalHeight, 44)
            XCTAssertEqual(header.titleLabel.text, "个人头像")
            XCTAssertEqual(header.titleLabel.font.pointSize, 17)
            for button in [header.backButton, header.moreButton] {
                let frame = button.view.convert(button.bounds, to: bar.view)
                XCTAssertGreaterThanOrEqual(frame.width, 44)
                XCTAssertGreaterThanOrEqual(frame.height, 44)
                XCTAssertTrue(bar.bounds.contains(frame))
                XCTAssertNotNil(bar.view.hitTest(frame.center, with: nil))
            }
            let more = header.moreButton.view.convert(header.moreButton.bounds, to: bar.view)
            let title = header.titleLabel.convert(header.titleLabel.bounds, to: bar.view)
            XCTAssertLessThanOrEqual(title.maxX, more.minX)
            XCTAssertEqual(title.midX, bar.bounds.midX, accuracy: 1)
            XCTAssertEqual(bar.item!.rightBarButtonItem?.accessibilityLabel, "更多")
            bar.item!.title = "1 of 12"
            XCTAssertEqual(header.titleLabel.text, "个人头像", "Gallery counters must not replace the profile-photo title")
        }
    }

    func testProfilePhotoHeaderUpdatesAccessibleLanguageAndKeepsItsActions() {
        let header = WegramAvatarGalleryHeader()
        let item = UINavigationItem()
        var backs = 0
        var menus = 0
        header.back = { backs += 1 }
        header.more = { menus += 1 }
        header.apply(to: item, chinese: true, backTitle: "返回", moreTitle: "更多")
        header.apply(to: item, chinese: false, backTitle: "Back", moreTitle: "More")
        XCTAssertEqual(header.titleLabel.text, "Profile Photo")
        XCTAssertEqual(item.leftBarButtonItem?.accessibilityLabel, "Back")
        XCTAssertEqual(item.rightBarButtonItem?.accessibilityLabel, "More")
        for button in [item.leftBarButtonItem!, item.rightBarButtonItem!] {
            if let target = button.target as? NSObject, let action = button.action { _ = target.perform(action) }
        }
        XCTAssertEqual(backs, 1)
        XCTAssertEqual(menus, 1)
    }

    func testArrowAndUnreadBadgeRemainInsideARealBackTouchTarget() {
        for count in ["", "4", "12345"] {
            let bar = self.navigationBar(count: count)
            let arrowPoint = bar.backButtonArrow.frame.center
            XCTAssertEqual(bar.backButtonArrow.frame.minX, 16)
            XCTAssertEqual(bar.backButtonArrow.frame.size, CGSize(width: 10, height: 18))
            XCTAssertEqual(arrowPoint.y, 84, "Back arrow must align with the 44pt row below the 62pt status area")
            let localArrow = bar.view.convert(arrowPoint, to: bar.backButtonNode.view)
            XCTAssertNotNil(bar.backButtonNode.view.hitTest(localArrow, with: nil), "Arrow cannot be tapped with an empty back title")
            if !count.isEmpty {
                let badgePoint = bar.view.convert(bar.badgeNode.bounds.center, from: bar.badgeNode.view)
                let localBadge = bar.view.convert(badgePoint, to: bar.backButtonNode.view)
                XCTAssertNotNil(bar.backButtonNode.view.hitTest(localBadge, with: nil), "Unread badge cannot be tapped")
            }
        }
    }

    func testLongTitlesReserveSpaceForLargeUnreadCounts() {
        let bar = self.navigationBar(count: "12345")
        let title = bar.item!.titleView!
        let titleFrame = bar.view.convert(title.bounds, from: title)
        let badgeFrame = bar.view.convert(bar.badgeNode.bounds, from: bar.badgeNode.view)
        XCTAssertGreaterThanOrEqual(titleFrame.minX, badgeFrame.maxX + 8, "Long title overlaps unread badge")
    }

    func testBarHeightSurvivesThemeCopiesAndKeepsLegacyRowsAt60() {
        let compact = self.navigationBar(count: "4")
        let legacyHeight = self.navigationBar(count: "4", nominalHeight: 60)
        XCTAssertEqual(compact.nominalHeight, 44)
        XCTAssertEqual(compact.backButtonArrow.frame.midY, 84)
        XCTAssertEqual(legacyHeight.nominalHeight, 60)
        XCTAssertEqual(legacyHeight.backButtonArrow.frame.midY, 92)
        let photoHeader = self.navigationBar(count: "4", nominalHeight: 64)
        XCTAssertEqual(photoHeader.backButtonArrow.frame.midY, 94)
        let defaultTheme = NavigationBarTheme(wegramTheme: defaultPresentationTheme)
        let photoTheme = NavigationBarTheme(wegramTheme: defaultPresentationTheme, nominalHeight: 64)
        XCTAssertEqual(defaultTheme.nominalHeight, 44)
        XCTAssertEqual(photoTheme.withUpdatedBackgroundColor(.white).nominalHeight, 64)
        XCTAssertEqual(photoTheme.withUpdatedSeparatorColor(.clear).nominalHeight, 64)
    }

    func testImageButtonLabelReachesTheActualAccessibleUIView() {
        let bar = self.navigationBar(count: "")
        let back = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: nil, action: nil)
        back.accessibilityLabel = "Back"
        bar.item!.leftBarButtonItem = back
        bar.updateLayout(size: bar.bounds.size, defaultHeight: 44, additionalTopHeight: 62, additionalContentHeight: 0, additionalBackgroundHeight: 0, additionalCutout: nil, leftInset: 0, rightInset: 0, appearsHidden: false, isLandscape: false, transition: .immediate)
        func descendants(_ view: UIView) -> [UIView] {
            return [view] + view.subviews.flatMap(descendants)
        }
        let buttons = descendants(bar.view).filter { $0.isAccessibilityElement && $0.accessibilityTraits.contains(.button) }
        XCTAssertTrue(buttons.contains { $0.accessibilityLabel == "Back" }, "The actual accessible UIView must announce the image button label; node-only getters are insufficient")
    }

    func testOnlyOptedInBadgesUseTheReferenceSizeAndCanRestoreTheOriginalSize() {
        let badge = NavigationBarBadgeNode(fillColor: .darkGray, strokeColor: .clear, textColor: .white)
        badge.text = "4"
        let constraint = CGSize(width: 200, height: 100)
        XCTAssertEqual(badge.measure(constraint), CGSize(width: 18, height: 18))
        badge.usesWegramAppearance = true
        XCTAssertEqual(badge.measure(constraint), CGSize(width: 24, height: 24))
        badge.usesWegramAppearance = false
        XCTAssertEqual(badge.measure(constraint), CGSize(width: 18, height: 18))
    }

    func testUnreadCountChangesGrowAndShrinkTheBadgeWithoutClipping() {
        let badge = NavigationBarBadgeNode(fillColor: .darkGray, strokeColor: .clear, textColor: .white)
        badge.usesWegramAppearance = true
        let constraint = CGSize(width: 200, height: 100)
        badge.text = "4"
        let single = badge.measure(constraint)
        badge.text = "1234"
        let multiple = badge.measure(constraint)
        XCTAssertGreaterThan(multiple.width, single.width)
        XCTAssertEqual(multiple.height, 24)
        badge.text = "4"
        XCTAssertEqual(badge.measure(constraint), single)
    }
}
