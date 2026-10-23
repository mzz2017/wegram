import XCTest
import UIKit
import Display
import TelegramPresentationData

final class WegramLocationControlsTests: XCTestCase {
    private func update(_ controls: WegramLocationControls, height: CGFloat = 559, dark: Bool = false) {
        controls.update(mapSize: CGSize(width: 402, height: height), safeInsets: UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 8), navigationHeight: 103, dark: dark, locateTitle: dark ? "Show My Location" : "回到我的位置", moreTitle: dark ? "More" : "更多")
    }

    func testLocateKeepsOneTapAndMoreHasAnAccessibleShortcut() throws {
        let controls = WegramLocationControls()
        self.update(controls)
        XCTAssertEqual(controls.frame, CGRect(x: 36, y: 475, width: 48, height: 48))
        XCTAssertEqual(controls.locateButton.frame, controls.bounds)
        XCTAssertEqual(controls.locateButton.layer.cornerRadius, 9)
        XCTAssertFalse(controls.isHidden)
        XCTAssertTrue(controls.hitTest(CGPoint(x: 24, y: 24), with: nil) === controls.locateButton)
        XCTAssertEqual(controls.locateButton.accessibilityLabel, "回到我的位置")
        var locates = 0
        var menus = 0
        controls.locate = { locates += 1 }
        controls.more = { menus += 1 }
        controls.locateButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(locates, 1)
        XCTAssertEqual(menus, 0)
        let more = try XCTUnwrap(controls.locateButton.accessibilityCustomActions?.first)
        XCTAssertEqual(more.name, "更多")
        XCTAssertTrue(more.actionHandler?(more) == true)
        XCTAssertEqual(menus, 1)
        XCTAssertEqual(locates, 1)
        let press = try XCTUnwrap(controls.locateButton.gestureRecognizers?.compactMap { $0 as? UILongPressGestureRecognizer }.first)
        XCTAssertTrue(press.cancelsTouchesInView, "Showing the menu must cancel the recenter tap")
    }

    func testUnavailableSpaceRejectsTouchAndOldAccessibilityActionsAndCanRestore() throws {
        let controls = WegramLocationControls()
        self.update(controls)
        let oldMore = try XCTUnwrap(controls.locateButton.accessibilityCustomActions?.first)
        var calls = 0
        controls.locate = { calls += 1 }
        controls.more = { calls += 10 }
        self.update(controls, height: 120)
        XCTAssertTrue(controls.isHidden)
        XCTAssertFalse(controls.isUserInteractionEnabled)
        XCTAssertFalse(controls.locateButton.isAccessibilityElement)
        XCTAssertNil(controls.hitTest(CGPoint(x: 24, y: 24), with: nil))
        controls.locateButton.sendActions(for: .touchUpInside)
        XCTAssertFalse(oldMore.actionHandler?(oldMore) ?? true)
        XCTAssertEqual(calls, 0)
        self.update(controls, dark: true)
        XCTAssertEqual(controls.locateButton.accessibilityLabel, "Show My Location")
        XCTAssertEqual(controls.locateButton.accessibilityCustomActions?.first?.name, "More")
        XCTAssertTrue(controls.locateButton.isAccessibilityElement)
        controls.more = { calls += 100 }
        XCTAssertTrue(oldMore.actionHandler?(oldMore) == true)
        controls.locateButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 101, "The restored control and an old accessibility closure must use the current callbacks")
        controls.update(mapSize: CGSize(width: 50, height: 559), safeInsets: .zero, navigationHeight: 103, dark: false, locateTitle: "Locate", moreTitle: "More")
        XCTAssertTrue(controls.isHidden, "A narrow region must not expose a clipped touch target")
    }

    func testCrosshairUsesTransparentEdgesAndVisibleCenterInBothThemes() throws {
        let controls = WegramLocationControls()
        for dark in [false, true] {
            self.update(controls, dark: dark)
            let image = try XCTUnwrap(controls.locateButton.image(for: .normal))
            XCTAssertEqual(image.size, CGSize(width: 28, height: 28))
            var pixels = [UInt8](repeating: 0, count: 28 * 28 * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 28, height: 28, bitsPerComponent: 8, bytesPerRow: 28 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(try XCTUnwrap(image.cgImage), in: CGRect(x: 0, y: 0, width: 28, height: 28))
            }
            XCTAssertEqual(pixels[3], 0)
            let center = (14 * 28 + 14) * 4
            XCTAssertEqual(pixels[center + 3], 255)
            if dark { XCTAssertGreaterThan(pixels[center], 200) } else { XCTAssertLessThan(pixels[center], 64) }
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                controls.layoutIfNeeded()
                let rendered = UIGraphicsImageRenderer(size: controls.bounds.size).image { controls.layer.render(in: $0.cgContext) }
                try rendered.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "location-locate-dark.png" : "location-locate-light.png"))
            }
        }
    }
    func testDetailNavigationKeepsSafeTargetsCenteredTitleAndCurrentActions() throws {
        let navigation = WegramLocationNavigation()
        var backs = 0
        var menus = 0
        navigation.back = { backs += 1 }
        navigation.more = { menus += 1 }
        for dark in [false, true] {
            navigation.update(size: CGSize(width: 402, height: 874), navigationHeight: 103, safeInsets: UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 8), dark: dark, fontSize: 17, title: "位置", backTitle: "返回", moreTitle: "更多")
            XCTAssertEqual(navigation.frame, CGRect(x: 0, y: 0, width: 402, height: 103))
            XCTAssertEqual(navigation.backButton.frame, CGRect(x: 24, y: 59, width: 44, height: 44))
            XCTAssertEqual(navigation.moreButton.frame, CGRect(x: 342, y: 59, width: 44, height: 44))
            XCTAssertEqual(navigation.titleLabel.frame.midX, 201)
            XCTAssertLessThanOrEqual(navigation.backButton.frame.maxX, navigation.titleLabel.frame.minX)
            XCTAssertLessThanOrEqual(navigation.titleLabel.frame.maxX, navigation.moreButton.frame.minX)
            XCTAssertTrue(navigation.hitTest(CGPoint(x: 46, y: 81), with: nil) === navigation.backButton)
            XCTAssertTrue(navigation.hitTest(CGPoint(x: 364, y: 81), with: nil) === navigation.moreButton)
            XCTAssertEqual(navigation.backgroundColor, WegramNavigationColors(isDark: dark).background)
            XCTAssertEqual(navigation.titleLabel.textColor, WegramNavigationColors(isDark: dark).control)
            XCTAssertEqual(navigation.backButton.accessibilityLabel, "返回")
            XCTAssertEqual(navigation.moreButton.accessibilityLabel, "更多")
            XCTAssertTrue(navigation.titleLabel.accessibilityTraits.contains(.header))
            XCTAssertEqual(try XCTUnwrap(navigation.backButton.configuration?.image).size, CGSize(width: 10, height: 18))
            XCTAssertEqual(try XCTUnwrap(navigation.moreButton.image(for: .normal)).size, CGSize(width: 28, height: 28))
            navigation.backButton.sendActions(for: .touchUpInside)
            navigation.moreButton.sendActions(for: .touchUpInside)
        }
        XCTAssertEqual(backs, 2)
        XCTAssertEqual(menus, 2)
        navigation.more = { menus += 10 }
        navigation.moreButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(menus, 12)
    }

    func testDetailNavigationRejectsInvisibleActionsAndRestoresWithNewLanguageAndInsets() {
        let navigation = WegramLocationNavigation()
        var calls = 0
        navigation.back = { calls += 1 }
        navigation.more = { calls += 10 }
        for (size, height) in [(CGSize(width: 402, height: 874), CGFloat(20)), (CGSize(width: 90, height: 300), CGFloat(44)), (.zero, CGFloat(103))] {
            navigation.update(size: size, navigationHeight: height, safeInsets: .zero, dark: false, fontSize: 17, title: "位置", backTitle: "返回", moreTitle: "更多")
            XCTAssertTrue(navigation.isHidden)
            XCTAssertTrue(navigation.accessibilityElementsHidden)
            XCTAssertNil(navigation.hitTest(.zero, with: nil))
            navigation.backButton.sendActions(for: .touchUpInside)
            navigation.moreButton.sendActions(for: .touchUpInside)
        }
        XCTAssertEqual(calls, 0)
        navigation.update(size: CGSize(width: 874, height: 402), navigationHeight: 44, safeInsets: UIEdgeInsets(top: 0, left: 62, bottom: 0, right: 62), dark: true, fontSize: 23, title: "A long location title to truncate within the navigation controls", backTitle: "Back", moreTitle: "More")
        XCTAssertFalse(navigation.isHidden)
        XCTAssertFalse(navigation.accessibilityElementsHidden)
        XCTAssertEqual(navigation.backButton.frame.minX, 62)
        XCTAssertLessThanOrEqual(navigation.moreButton.frame.maxX, 874 - 62)
        XCTAssertEqual(navigation.titleLabel.font.pointSize, 23)
        XCTAssertEqual(navigation.titleLabel.lineBreakMode, .byTruncatingTail)
        XCTAssertEqual(navigation.moreButton.accessibilityLabel, "More")
        navigation.alpha = 0
        navigation.backButton.sendActions(for: .touchUpInside)
        navigation.moreButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 0)
        navigation.alpha = 1
        navigation.moreButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 10)
    }

    func testDetailShareUsesTheSameOneShotMenuAndRechecksDismissal() {
        for dismissed in [false, true] {
            var open = true
            var shares = 0
            let menu = WegramLocationMenu(theme: ActionSheetControllerTheme(wegramTheme: defaultPresentationTheme, fontSize: .regular), options: [(.share, "分享"), (.map, "地图")], selected: .map, cancelTitle: "取消", available: { action in open && (action == .share || action == .map) }, perform: { if $0 == .share { shares += 1 } })
            XCTAssertEqual(menu.actions.map(\.title), ["分享", "✓  地图"])
            open = !dismissed
            menu.actions[0].action()
            menu.actions[0].action()
            XCTAssertEqual(shares, dismissed ? 0 : 1)
        }
    }

    private func detail(_ panel: WegramLocationDetailPanel, width: CGFloat = 402, maxHeight: CGFloat = 727, fontSize: CGFloat = 17, dark: Bool = false, canSave: Bool = true) -> CGFloat {
        return panel.update(width: width, maxHeight: maxHeight, bottomInset: 34, safeInsets: .zero, dark: dark, fontSize: fontSize, chinese: true, title: "抖音集团新江湾城办公园", address: "上海市杨浦区民府路678号", distance: "距你11米", driving: "2分钟", walking: "1分钟", canSave: canSave)
    }

    func testActualDetailPanelMatchesReferenceRowsAndKeepsSeparateFortyFourPointActions() throws {
        let panel = WegramLocationDetailPanel()
        XCTAssertEqual(self.detail(panel), 249)
        XCTAssertEqual(panel.layer.cornerRadius, 12)
        XCTAssertEqual(panel.titleLabel.frame.minX, 20)
        XCTAssertEqual(panel.titleLabel.frame.minY + panel.scrollView.frame.minY, 42)
        XCTAssertEqual(panel.addressLabel.frame.minY + panel.scrollView.frame.minY, 74)
        XCTAssertEqual(panel.navigateButton.frame.minY + panel.scrollView.frame.minY, 142)
        XCTAssertEqual(panel.navigateButton.frame.height, 40)
        XCTAssertEqual(panel.moreButton.frame.width, 40)
        XCTAssertEqual(panel.scrollView.contentSize.height + 28, 249)
        XCTAssertFalse(panel.scrollView.isScrollEnabled)
        let row = [panel.navigateButton, panel.taxiButton, panel.saveButton, panel.moreButton]
        for (left, right) in zip(row, row.dropFirst()) { XCTAssertGreaterThanOrEqual(right.frame.minX - left.frame.maxX, 7.9) }
        XCTAssertTrue(panel.navigateButton.point(inside: CGPoint(x: 20, y: -1), with: nil))
        XCTAssertEqual(panel.drivingButton.accessibilityLabel, "驾车 2分钟")
        XCTAssertEqual(panel.walkingButton.accessibilityLabel, "步行 1分钟")
        XCTAssertEqual(panel.handleButton.accessibilityLabel, "更多位置详情")
        XCTAssertEqual(panel.distanceLabel.font.pointSize, 15)
        XCTAssertEqual(panel.drivingButton.configuration?.baseForegroundColor, UIColor(rgb: 0x576b95))
        var calls: [WegramLocationDetailAction] = []
        panel.action = { calls.append($0) }
        for button in [panel.navigateButton, panel.taxiButton, panel.saveButton, panel.moreButton, panel.drivingButton, panel.walkingButton, panel.detailsButton, panel.handleButton] { button.sendActions(for: .touchUpInside) }
        XCTAssertEqual(calls, [.navigate, .taxi, .save, .more, .driving, .walking, .details, .details])
        XCTAssertTrue(try XCTUnwrap(panel.handleButton.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }.first).cancelsTouchesInView)
        for dark in [false, true] {
            _ = self.detail(panel, dark: dark)
            panel.layoutIfNeeded()
            func displayAtReferenceScale(_ view: UIView) {
                view.contentScaleFactor = 3
                view.layer.contentsScale = 3
                view.setNeedsDisplay()
                view.layer.displayIfNeeded()
                for child in view.subviews { displayAtReferenceScale(child) }
            }
            displayAtReferenceScale(panel)
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                let format = UIGraphicsImageRendererFormat(); format.scale = 3
                let image = UIGraphicsImageRenderer(size: panel.bounds.size, format: format).image { panel.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "location-detail-panel-dark.png" : "location-detail-panel-light.png"))
            }
        }
    }

    func testActualDetailPanelWrapsMetadataAndScrollsLargeTextWithoutOverlappingActions() {
        let panel = WegramLocationDetailPanel()
        for width: CGFloat in [100, 250, 402, 874] {
            for font: CGFloat in [17, 34, 56] {
                let height = self.detail(panel, width: width, maxHeight: 200, fontSize: font)
                XCTAssertLessThanOrEqual(height, 200)
                for button in [panel.navigateButton, panel.taxiButton, panel.saveButton, panel.moreButton, panel.drivingButton, panel.walkingButton, panel.detailsButton] {
                    XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
                    XCTAssertLessThanOrEqual(button.frame.maxX, width)
                    XCTAssertLessThanOrEqual(button.frame.maxY, panel.scrollView.contentSize.height)
                }
                let actions = [panel.navigateButton, panel.taxiButton, panel.saveButton, panel.moreButton]
                for (left, right) in zip(actions, actions.dropFirst()) { XCTAssertFalse(left.frame.intersects(right.frame)) }
                let metadata = [panel.drivingButton, panel.walkingButton, panel.detailsButton]
                for (left, right) in zip(metadata, metadata.dropFirst()) { XCTAssertFalse(left.frame.intersects(right.frame)) }
                XCTAssertGreaterThanOrEqual(panel.navigateButton.frame.minY, metadata.map { $0.frame.maxY }.max() ?? 0)
                XCTAssertEqual(panel.scrollView.isScrollEnabled, panel.scrollView.contentSize.height > panel.scrollView.frame.height)
                XCTAssertEqual(panel.titleLabel.numberOfLines, 2)
                XCTAssertEqual(panel.addressLabel.numberOfLines, 2)
            }
        }
    }

    func testActualDetailPanelRejectsHiddenDisabledAndUnavailableActionsThenUsesCurrentCallback() {
        let panel = WegramLocationDetailPanel()
        var calls = 0
        panel.action = { _ in calls += 1 }
        _ = self.detail(panel, canSave: false)
        panel.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 0)
        _ = self.detail(panel, maxHeight: 10)
        XCTAssertTrue(panel.isHidden)
        panel.moreButton.sendActions(for: .touchUpInside)
        panel.handleButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 0)
        _ = self.detail(panel)
        panel.action = { _ in calls += 10 }
        panel.moreButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 10)
        panel.alpha = 0
        panel.navigateButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 10)
    }

    func testMapOverlayHasOnlyRoundBackAndPassesOtherTouchesToTheMap() throws {
        let navigation = WegramLocationNavigation()
        var backs = 0
        var more = 0
        navigation.back = { backs += 1 }
        navigation.more = { more += 1 }
        navigation.update(size: CGSize(width: 402, height: 874), navigationHeight: 103, safeInsets: .zero, dark: false, fontSize: 17, title: "位置", backTitle: "返回", moreTitle: "更多", mapOverlay: true)
        XCTAssertEqual(navigation.backgroundColor, .clear)
        XCTAssertTrue(navigation.titleLabel.isHidden)
        XCTAssertTrue(navigation.moreButton.isHidden)
        XCTAssertNil(navigation.hitTest(CGPoint(x: 201, y: 81), with: nil))
        XCTAssertTrue(navigation.hitTest(CGPoint(x: 28, y: 81), with: nil) === navigation.backButton)
        XCTAssertEqual(try XCTUnwrap(navigation.backButton.configuration?.image).size, CGSize(width: 20, height: 20))
        navigation.backButton.sendActions(for: .touchUpInside)
        navigation.moreButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(backs, 1)
        XCTAssertEqual(more, 0)
    }

    func testDetailLocateCircleKeepsTheOriginalTrackingAndMoreCallbacks() {
        let controls = WegramLocationControls()
        controls.update(mapSize: CGSize(width: 402, height: 625), safeInsets: .zero, navigationHeight: 103, dark: false, locateTitle: "回到我的位置", moreTitle: "更多", round: true)
        XCTAssertEqual(controls.frame, CGRect(x: 14, y: 551, width: 44, height: 44))
        XCTAssertEqual(controls.locateButton.layer.cornerRadius, 22)
        var tracking = 0
        controls.locate = { tracking += 1 }
        controls.locateButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(tracking, 1)
    }

    func testActualMenuActionsConsumeOnceAndRevalidateVisibilityAndCapability() {
        for exit in 0 ..< 6 {
            var visible = true
            var selection = WegramLocationPickerSelection()
            var coordinateAvailable = true
            var performed: [WegramLocationMenuAction] = []
            let menu = WegramLocationMenu(theme: ActionSheetControllerTheme(wegramTheme: defaultPresentationTheme, fontSize: .regular), options: [(.map, "地图"), (.live, "实时位置")], selected: .map, cancelTitle: "取消", available: { action in
                visible && !selection.isFinished && (action != .live || coordinateAvailable)
            }, perform: { performed.append($0) })
            XCTAssertEqual(menu.actions.map { $0.title }, ["✓  地图", "实时位置"])
            XCTAssertTrue(menu.actions.allSatisfy { $0.enabled })
            switch exit {
            case 0: menu.actions[1].action()
            case 1: menu.cancel.action()
            case 2: menu.controller.willDismiss?()
            case 3: visible = false
            case 4: coordinateAvailable = false
            default: selection.finish()
            }
            menu.actions[1].action()
            menu.actions[0].action()
            XCTAssertEqual(performed, exit == 0 ? [.live] : [])
        }
        let menu = WegramLocationMenu(theme: ActionSheetControllerTheme(wegramTheme: defaultPresentationTheme, fontSize: .regular), options: [(.live, "实时位置")], selected: .map, cancelTitle: "取消", available: { _ in false }, perform: { _ in XCTFail("A disabled live capability must not execute through a retained action") })
        XCTAssertFalse(menu.actions[0].enabled)
        menu.actions[0].action()
    }

    func testGreenPickerImageHasWhiteRingCenterAndStemToCoordinateAnchor() throws {
        let image = WegramLocationPinVisual.image
        XCTAssertEqual(image.size, CGSize(width: 36, height: 56))
        var pixels = [UInt8](repeating: 0, count: 36 * 56 * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 36, height: 56, bitsPerComponent: 8, bytesPerRow: 36 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(try XCTUnwrap(image.cgImage), in: CGRect(x: 0, y: 0, width: 36, height: 56))
        }
        func rgba(_ x: Int, _ y: Int) -> [UInt8] { Array(pixels[(y * 36 + x) * 4 ..< (y * 36 + x + 1) * 4]) }
        XCTAssertEqual(rgba(0, 0)[3], 0)
        XCTAssertEqual(rgba(18, 18), [255, 255, 255, 255])
        for point in [(18, 4), (18, 42), (18, 53)] {
            let pixel = rgba(point.0, point.1)
            XCTAssertEqual(pixel[0], 7, accuracy: 1)
            XCTAssertEqual(pixel[1], 193, accuracy: 1)
            XCTAssertEqual(pixel[2], 96, accuracy: 1)
            XCTAssertEqual(pixel[3], 255)
        }
        XCTAssertEqual(rgba(10, 42)[3], 0)
        XCTAssertEqual(WegramLocationPinVisual.dot.size, CGSize(width: 8, height: 8))
    }

    func testPickerAnchorAndTouchRegionFollowTheVisiblePinRatherThanItsEmptyViewBounds() {
        for raised in [false, true] {
            let selected = WegramLocationPinVisual.frame(selected: true, raised: raised)
            XCTAssertEqual(selected.midX, 0)
            XCTAssertEqual(selected.maxY, raised ? -30 : 0)
            let hit = WegramLocationPinVisual.hitFrame(selected: true, raised: raised)
            XCTAssertGreaterThanOrEqual(hit.width, 44)
            XCTAssertGreaterThanOrEqual(hit.height, 44)
            XCTAssertTrue(hit.contains(CGPoint(x: 0, y: selected.minY + 18)), "The center of the ring must be tappable even though the MKAnnotationView bounds are empty")
        }
        let dotHit = WegramLocationPinVisual.hitFrame(selected: false, raised: true)
        XCTAssertEqual(dotHit, CGRect(x: -22, y: -22, width: 44, height: 44))
        for size in [CGSize(width: 402, height: 402), CGSize(width: 874, height: 874)] {
            let center = WegramLocationPinVisual.pickerCenter(size: size, coordinateOffset: CGPoint(x: 0, y: 33))
            XCTAssertEqual(center.x, size.width / 2)
            XCTAssertEqual(center.y, (size.height + 33) / 2, "The image tip must use the same screen point as the unchanged mapCenterCoordinate conversion")
        }
    }

    func testTopShadeFadesWithoutInterceptingMapTouches() throws {
        let shade = WegramLocationTopShade(frame: CGRect(x: 0, y: 0, width: 40, height: 120))
        XCTAssertFalse(shade.isUserInteractionEnabled)
        XCTAssertFalse(shade.isAccessibilityElement)
        let gradient = try XCTUnwrap(shade.layer as? CAGradientLayer)
        let colors = try XCTUnwrap(gradient.colors as? [CGColor])
        XCTAssertEqual(colors.count, 2)
        XCTAssertEqual(colors[0].alpha, 0.36, accuracy: 0.001)
        XCTAssertEqual(colors[1].alpha, 0)
        XCTAssertNil(shade.hitTest(CGPoint(x: 20, y: 30), with: nil))
    }

}

extension WegramLocationControlsTests {
    func testIOSLocationShareSurfaceUsesRealPeerViewsAndReferenceHierarchy() throws {
        let view = WegramLocationShareView()
        let avatars = (0 ..< 8).map { _ in UIView() }
        view.setPeers(avatars.enumerated().map { (title: $0.offset == 0 ? "较长的会话名称用于换行" : "会话 \($0.offset)", avatar: $0.element) })
        let height = view.update(width: 402, dark: false, fontSize: 17, chinese: true, canForward: true)
        view.frame = CGRect(x: 0, y: 0, width: 402, height: height)
        XCTAssertEqual(height, 408, accuracy: 3)
        XCTAssertEqual(view.peerButtons.count, 8)
        XCTAssertTrue(avatars[0].superview === view.peerButtons[0])
        XCTAssertEqual(avatars[0].frame.size, CGSize(width: 56, height: 56))
        XCTAssertEqual(avatars[0].layer.cornerRadius, 5)
        XCTAssertGreaterThan(view.recentScrollView.contentSize.width, 402)
        XCTAssertEqual(view.forwardButton.superview, view.actionScrollView)
        XCTAssertEqual(view.copyButton.frame.minY, view.improveButton.frame.minY)
        XCTAssertGreaterThan(view.copyButton.frame.minY, view.forwardButton.frame.maxY)
        XCTAssertEqual(view.cancelButton.frame.maxY, height)
        XCTAssertEqual(view.cancelButton.currentTitle, "取消")
        XCTAssertEqual(view.cancelButton.currentTitleColor, UIColor(rgb: 0x576b95))
        var actions: [WegramLocationShareAction] = []
        view.perform = { actions.append($0) }
        view.peerButtons[3].sendActions(for: .touchUpInside)
        view.forwardButton.sendActions(for: .touchUpInside)
        view.copyButton.sendActions(for: .touchUpInside)
        view.improveButton.sendActions(for: .touchUpInside)
        view.cancelButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.peer(3), .forward, .copy, .improve, .cancel])
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            for dark in [false, true] {
                let _ = view.update(width: 402, dark: dark, fontSize: 17, chinese: true, canForward: true)
                func setScale(_ item: UIView) {
                    item.contentScaleFactor = 3
                    item.layer.contentsScale = 3
                    item.subviews.forEach(setScale)
                }
                setScale(view)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 3
                let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "location-share-dark.png" : "location-share-light.png"))
            }
        }
    }

    func testIOSLocationShareRejectsDisabledHiddenAndReplacedPeerActions() {
        let view = WegramLocationShareView()
        view.setPeers([(title: "First", avatar: UIView())])
        let old = view.peerButtons[0]
        var actions: [WegramLocationShareAction] = []
        view.perform = { actions.append($0) }
        let _ = view.update(width: 402, dark: false, fontSize: 17, chinese: true, canForward: false)
        old.sendActions(for: .touchUpInside)
        view.forwardButton.sendActions(for: .touchUpInside)
        view.copyButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(actions.isEmpty)
        XCTAssertTrue(view.recentScrollView.isHidden)
        view.improveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.improve])
        view.setPeers([(title: "Second", avatar: UIView())])
        let _ = view.update(width: 402, dark: true, fontSize: 17, chinese: false, canForward: true)
        old.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.improve])
        view.isHidden = true
        view.peerButtons[0].sendActions(for: .touchUpInside)
        view.cancelButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.improve])
        view.isHidden = false
        view.peerButtons[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.improve, .peer(0)])
        XCTAssertEqual(view.cancelButton.currentTitle, "Cancel")
    }

    func testIOSLocationShareLargeTypeScrollsActionsWithoutOverlappingRows() {
        for width: CGFloat in [250, 402, 874] {
            for font: CGFloat in [17, 34, 56] {
                let view = WegramLocationShareView()
                view.setPeers([(title: "A long recent conversation title", avatar: UIView())])
                let height = view.update(width: width, dark: true, fontSize: font, chinese: false, canForward: true)
                XCTAssertGreaterThan(height, 350)
                XCTAssertEqual(view.actionScrollView.frame.width, width)
                XCTAssertGreaterThanOrEqual(view.actionScrollView.contentSize.width, width)
                XCTAssertLessThanOrEqual(view.forwardButton.frame.maxY, view.copyButton.frame.minY)
                XCTAssertLessThanOrEqual(view.copyButton.frame.maxY, view.actionScrollView.contentSize.height)
                XCTAssertLessThanOrEqual(view.improveButton.frame.maxX, view.actionScrollView.contentSize.width)
                XCTAssertGreaterThanOrEqual(view.cancelButton.frame.height, 44)
                XCTAssertEqual(view.cancelButton.frame.maxY, height)
                let peerButton = view.peerButtons[0]
                for child in peerButton.subviews {
                    let frame = child.convert(child.bounds, to: view.recentScrollView)
                    XCTAssertGreaterThanOrEqual(frame.minX, 0, "The first large-type name must remain reachable by scrolling")
                    XCTAssertLessThanOrEqual(frame.maxX, view.recentScrollView.contentSize.width)
                }
            }
        }
    }
}

extension WegramLocationControlsTests {
    func testIOSLocationShareAsyncPeersRelayoutTheExistingSheetItem() {
        let content = WegramLocationShareView()
        let base = ActionSheetControllerTheme(wegramTheme: defaultPresentationTheme, fontSize: .regular)
        let theme = WegramLocationShareItem.theme(base)
        XCTAssertEqual(theme.itemBackgroundColor, UIColor(rgb: 0xededed))
        XCTAssertEqual(base.itemBackgroundColor, UIColor(rgb: 0xffffff), "The location share surface must not restyle other sheets")
        let item = WegramLocationShareItem(content: content, dark: false, fontSize: 17, chinese: true, canForward: true)
        let node = item.node(theme: theme)
        let originalSize = node.updateLayout(constrainedSize: CGSize(width: 402, height: 700), transition: .immediate)
        content.setPeers([(title: "Recent conversation", avatar: UIView())])
        XCTAssertEqual(content.peerButtons[0].frame, .zero)
        item.updateNode(node)
        XCTAssertEqual(content.frame.size, originalSize)
        XCTAssertEqual(content.peerButtons[0].frame.size.width, 56)
        XCTAssertGreaterThan(content.peerButtons[0].frame.height, 56)
        XCTAssertFalse(content.recentScrollView.isHidden)
    }
}
