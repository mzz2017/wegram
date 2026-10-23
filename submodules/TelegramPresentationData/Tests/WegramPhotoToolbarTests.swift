import XCTest
import UIKit
import LegacyComponents
import ComponentFlow
import PlainButtonComponent

final class WegramPhotoToolbarTests: XCTestCase {
    func testGridFooterMatchesReferenceControlCentersAndSendSizeAcrossSelectionChanges() throws {
        let view = WegramPhotoToolbarView()
        for count in [0, 1, 3, 0] {
            view.update(count: count, original: false, originalAvailable: true, dark: false, fontSize: 17, previewTitle: "预览", originalTitle: "原图", sendTitle: "发送", optionsTitle: "选项", mergeSelected: count >= 3 ? false : nil, limitedAccessTitle: "仅可访问部分照片")
            let height = view.updateLayout(width: 402, leftInset: 0, rightInset: 0, bottomInset: 34)
            view.frame = CGRect(x: 0, y: 874 - height, width: 402, height: height)
            view.layoutIfNeeded()
            XCTAssertEqual(view.frame.minY + view.originalButton.frame.midY, 812)
            XCTAssertEqual(view.frame.minY + view.sendButton.frame.midY, 812)
            XCTAssertEqual(view.sendButton.titleLabel?.font.pointSize, 14)
            let background = try XCTUnwrap(view.sendButton.subviews.first)
            XCTAssertEqual(background.bounds.height, 32)
            XCTAssertEqual(view.sendButton.frame.width, count == 0 ? 52 : 74)
            XCTAssertEqual(view.sendButton.frame.maxX, 386)
            XCTAssertGreaterThanOrEqual(view.sendButton.bounds.height, 44)
            if count == 3 {
                XCTAssertEqual(view.frame.minY + view.mergeView.frame.midY, 758)
            }
            if count == 0 || count == 3 { XCTAssertEqual(height, 162) }
        }
    }

    func testPermissionNoticeHidesForSelectionAndReturnsWhenSelectionClears() {
        let view = WegramPhotoToolbarView()
        var calls = 0
        view.manageAccess = { calls += 1 }
        for count in [0, 1, 3, 0] {
            view.update(count: count, original: false, originalAvailable: true, dark: false, fontSize: 17, previewTitle: "预览", originalTitle: "原图", sendTitle: "发送", optionsTitle: "选项", mergeSelected: count >= 3 ? false : nil, limitedAccessTitle: "仅可访问部分照片")
            let height = view.updateLayout(width: 402, leftInset: 0, rightInset: 0, bottomInset: 34)
            view.frame = CGRect(x: 0, y: 0, width: 402, height: height)
            XCTAssertEqual(view.limitedAccessButton.isHidden, count > 0)
            XCTAssertEqual(view.limitedAccessButton.frame.height, count == 0 ? 72 : 0)
            XCTAssertEqual(height, count == 0 ? 162 : (count >= 3 ? 162 : 90))
            let previous = calls
            view.limitedAccessButton.sendActions(for: .touchUpInside)
            XCTAssertEqual(calls - previous, count == 0 ? 1 : 0)
        }
    }

    func testAddAccessiblePhotosTileKeepsItsRealButtonActionAndReadableTwoLineTitle() {
        let tile = WegramPhotoAddAccessButton(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        var calls = 0
        tile.pressed = { calls += 1 }
        tile.update(title: "添加更多\n可访问照片", fontSize: 14, dark: false)
        tile.layoutIfNeeded()
        XCTAssertEqual(tile.accessibilityLabel, "添加更多 可访问照片")
        XCTAssertEqual(tile.titleLabel?.numberOfLines, 0)
        XCTAssertGreaterThanOrEqual(tile.titleLabel!.frame.minY, tile.imageView!.frame.maxY + 8)
        XCTAssertLessThanOrEqual(tile.titleLabel!.frame.maxY, 100)
        XCTAssertGreaterThanOrEqual(tile.titleLabel!.frame.height, tile.titleLabel!.font.lineHeight * 2)
        tile.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 1)
        tile.pressed = { calls += 10 }
        tile.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 11)
        tile.isEnabled = false
        tile.sendActions(for: .touchUpInside)
        tile.isEnabled = true
        tile.isHidden = true
        tile.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls, 11)
    }

    func testLimitedPhotoAccessNoticeReservesSpaceAndUsesOnlyItsCurrentAvailableAction() {
        let view = WegramPhotoToolbarView()
        let title = "你已设置WeGram只能访问相册部分照片，建议设为「允许访问所有照片」"
        var actions = 0
        view.manageAccess = { actions += 1 }
        for width: CGFloat in [250, 402, 756] {
            for font: CGFloat in [17, 34, 56] {
                view.update(count: 0, original: false, originalAvailable: true, dark: false, fontSize: font, previewTitle: "预览", originalTitle: "原图", sendTitle: "发送", optionsTitle: "选项", mergeSelected: false, limitedAccessTitle: title)
                let height = view.updateLayout(width: width, leftInset: 0, rightInset: 0, bottomInset: 34)
                view.frame = CGRect(x: 0, y: 0, width: width, height: height)
                view.layoutIfNeeded()
                view.limitedAccessButton.layoutIfNeeded()
                XCTAssertFalse(view.limitedAccessButton.isHidden)
                XCTAssertEqual(view.limitedAccessButton.currentTitle, title)
                XCTAssertGreaterThanOrEqual(view.limitedAccessButton.frame.height, 72)
                XCTAssertEqual(view.mergeView.frame.minY, view.limitedAccessButton.frame.maxY)
                XCTAssertGreaterThanOrEqual(view.previewButton.frame.minY, view.mergeView.frame.maxY)
                let label = view.limitedAccessButton.titleLabel!
                XCTAssertLessThanOrEqual(label.frame.maxX, width - 28)
                XCTAssertGreaterThanOrEqual(label.frame.minY, 0)
                XCTAssertLessThanOrEqual(label.frame.maxY, view.limitedAccessButton.bounds.height)
            }
        }
        view.limitedAccessButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, 1)
        view.manageAccess = { actions += 10 }
        view.limitedAccessButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, 11)
        view.updateLoadingProgress(0.5)
        view.limitedAccessButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, 11)
        view.updateLoadingProgress(nil)
        view.isHidden = true
        view.limitedAccessButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, 11)
        view.isHidden = false
        self.update(view)
        let height = view.updateLayout(width: 402, leftInset: 0, rightInset: 0, bottomInset: 34)
        XCTAssertTrue(view.limitedAccessButton.isHidden)
        XCTAssertEqual(view.limitedAccessButton.frame.height, 0)
        XCTAssertEqual(height, 90)
        view.limitedAccessButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, 11)
    }

    func testPreviewMergeRowUsesReferenceHeightAndStillFitsLargeText() {
        let row = WegramPhotoMergeView()
        row.update(count: 3, selected: false, dark: true, fontSize: 17, title: "发送后合并展示", minimumHeight: 64)
        XCTAssertEqual(row.sizeThatFits(CGSize(width: 402, height: 200)).height, 64)
        row.update(count: 3, selected: false, dark: true, fontSize: 34, title: "发送后合并展示", minimumHeight: 64)
        XCTAssertGreaterThan(row.sizeThatFits(CGSize(width: 160, height: 200)).height, 64)
        row.update(count: 2, selected: nil, dark: true, fontSize: 17, title: "发送后合并展示", minimumHeight: 64)
        XCTAssertEqual(row.sizeThatFits(CGSize(width: 402, height: 200)).height, 0)
    }

    func testPreviewSendButtonCanSwitchBetweenIconAndTextWithoutReusingAnIncompatibleView() throws {
        let button = ComponentView<Empty>()
        let titles: [String?] = [nil, "发送(3)", "发送(1)", nil, "Send", nil, "发送(3)"]
        for title in titles {
            let size = button.update(transition: .immediate, component: AnyComponent(PlainButtonComponent(
                content: wegramPhotoToolbarDoneContent(iconName: "Navigation/Done", title: title),
                minSize: CGSize(width: 72, height: 44), action: {}, animateScale: false
            )), environment: {}, containerSize: CGSize(width: 200, height: 44))
            let view = try XCTUnwrap(button.view as? PlainButtonComponent.View)
            view.frame = CGRect(origin: .zero, size: size)
            XCTAssertGreaterThanOrEqual(size.width, 72)
            XCTAssertEqual(size.height, 44)
            XCTAssertNotNil(view.contentView)
            XCTAssertTrue(view.hitTest(CGPoint(x: size.width / 2, y: size.height / 2), with: nil) === view)
        }
    }

    private func update(_ view: WegramPhotoToolbarView, count: Int = 3, original: Bool = false, available: Bool = true, dark: Bool = false, font: CGFloat = 17, chinese: Bool = true) {
        view.update(count: count, original: original, originalAvailable: available, dark: dark, fontSize: font, previewTitle: chinese ? "预览" : "Preview", originalTitle: chinese ? "原图" : "Original", sendTitle: chinese ? "发送" : "Send", optionsTitle: "Send Options")
    }
    func testDisabledLoadingAndHiddenControlsCannotDispatchAndCurrentActionsAreUsed() {
        let view = WegramPhotoToolbarView()
        var actions: [String] = []
        view.preview = { actions.append("preview") }
        view.toggleOriginal = { actions.append("original") }
        view.send = { actions.append("send") }
        self.update(view, count: 0)
        view.previewButton.sendActions(for: .touchUpInside)
        view.sendButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(actions.isEmpty)
        view.originalButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, ["original"])
        self.update(view, original: true)
        XCTAssertTrue(view.originalButton.accessibilityTraits.contains(.selected))
        view.updateLoadingProgress(0.5)
        for button in [view.previewButton, view.originalButton, view.sendButton] { button.sendActions(for: .touchUpInside) }
        XCTAssertEqual(actions, ["original"])
        view.updateLoadingProgress(nil)
        view.previewButton.sendActions(for: .touchUpInside)
        view.sendButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, ["original", "preview", "send"])
        view.isHidden = true
        view.sendButton.sendActions(for: .touchUpInside)
        view.isHidden = false
        view.alpha = 0
        view.sendButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.count, 3)
        view.alpha = 1
        self.update(view, available: false)
        view.originalButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.count, 3)
        view.send = { actions.append("current") }
        view.sendButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.last, "current")
    }
    func testToolbarKeepsAllTargetsSeparateAcrossSafeAreasLanguagesAndLargeText() throws {
        let view = WegramPhotoToolbarView()
        for width: CGFloat in [250, 402, 874] {
            for font: CGFloat in [17, 26, 34] {
                for chinese in [true, false] {
                    for dark in [false, true] {
                        self.update(view, count: 99, dark: dark, font: font, chinese: chinese)
                        let safe: CGFloat = width == 874 ? 59 : 0
                        let height = view.updateLayout(width: width, leftInset: safe, rightInset: safe, bottomInset: 34)
                        view.frame = CGRect(x: 0, y: 0, width: width, height: height)
                        view.layoutIfNeeded()
                        let buttons = [view.previewButton, view.originalButton, view.sendButton]
                        for (index, button) in buttons.enumerated() {
                            XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                            XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
                            XCTAssertGreaterThanOrEqual(button.frame.minX, safe + 16)
                            XCTAssertLessThanOrEqual(button.frame.maxX, width - safe - 16)
                            XCTAssertLessThanOrEqual(button.frame.maxY, height - 34)
                            for other in buttons.dropFirst(index + 1) { XCTAssertFalse(button.frame.intersects(other.frame)) }
                        }
                        XCTAssertEqual(view.sendButton.currentTitle, chinese ? "发送(99)" : "Send(99)")
                        if width == 402, font == 17, chinese, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                            let format = UIGraphicsImageRendererFormat(); format.scale = 3
                            let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("photo-toolbar-\(dark ? "dark" : "light").png"))
                        }
                    }
                }
            }
        }
    }
}

final class WegramPhotoAccessTests: XCTestCase {
    func testSettingsUsesCurrentActionAndRejectsHiddenOrDisabledControls() {
        let view = WegramPhotoAccessView()
        var actions: [String] = []
        view.openSettings = { actions.append("old") }
        view.settingsButton.sendActions(for: .touchUpInside)
        view.openSettings = { actions.append("current") }
        view.settingsButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, ["old", "current"])
        view.isHidden = true
        view.settingsButton.sendActions(for: .touchUpInside)
        view.isHidden = false
        view.alpha = 0
        view.settingsButton.sendActions(for: .touchUpInside)
        view.alpha = 1
        view.settingsButton.isEnabled = false
        view.settingsButton.sendActions(for: .touchUpInside)
        view.settingsButton.isEnabled = true
        view.isUserInteractionEnabled = false
        view.settingsButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, ["old", "current"])
    }

    func testPermissionContentRemainsReadableAndScrollableWithLargeTextAndSafeInsets() throws {
        let view = WegramPhotoAccessView()
        for width: CGFloat in [250, 402, 874] {
            for height: CGFloat in [180, 874] {
                for font: CGFloat in [17, 34] {
                    for chinese in [true, false] {
                        for dark in [true, false] {
                            let title = chinese ? "无法访问相册中照片" : "Photo Access Required"
                            let text = chinese ? "请在系统设置中允许访问照片，之后可在这里选择要发送的内容。" : "Allow photo access in system settings to choose photos and videos to send."
                            let settings = chinese ? "前往系统设置" : "Go to System Settings"
                            view.update(dark: dark, fontSize: font, title: title, text: text, settingsTitle: settings)
                            let size = CGSize(width: width, height: height)
                            let side: CGFloat = width == 874 ? 59 : 0
                            view.frame = CGRect(origin: .zero, size: size)
                            view.updateLayout(size: size, insets: UIEdgeInsets(top: 44, left: side, bottom: 34, right: side))
                            view.layoutIfNeeded()
                            XCTAssertEqual(view.titleLabel.text, title)
                            XCTAssertEqual(view.textLabel.text, text)
                            XCTAssertTrue(view.titleLabel.accessibilityTraits.contains(.header))
                            XCTAssertEqual(view.settingsButton.accessibilityLabel, settings)
                            XCTAssertGreaterThanOrEqual(view.settingsButton.bounds.height, 44)
                            XCTAssertGreaterThanOrEqual(view.settingsButton.bounds.width, 44)
                            XCTAssertGreaterThan(view.textLabel.frame.minY, view.titleLabel.frame.maxY)
                            XCTAssertGreaterThan(view.settingsButton.frame.minY, view.textLabel.frame.maxY)
                            for content in [view.titleLabel as UIView, view.textLabel, view.settingsButton] {
                                XCTAssertGreaterThanOrEqual(content.frame.minX, 0)
                                XCTAssertLessThanOrEqual(content.frame.maxX, view.scrollView.bounds.width)
                                XCTAssertLessThanOrEqual(content.frame.maxY, view.scrollView.contentSize.height)
                            }
                            for label in [view.titleLabel, view.textLabel] {
                                XCTAssertGreaterThanOrEqual(label.bounds.height, label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                            }
                            if height == 180 { XCTAssertGreaterThan(view.scrollView.contentSize.height, view.scrollView.bounds.height) }
                            if width == 402, height == 874, font == 17, chinese, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                                let format = UIGraphicsImageRendererFormat(); format.scale = 3
                                let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("photo-access-\(dark ? "dark" : "light").png"))
                            }
                        }
                    }
                }
            }
        }
    }
}

final class WegramPhotoEditorToolbarLayoutTests: XCTestCase {
    func testToolsScrollBetweenActualSideButtonsWithoutCoveringCancelOrSend() {
        for horizontal in [true, false] {
            for length: CGFloat in [250, 320, 402, 874] {
                for count in [0, 1, 3, 8, 14] {
                    let size = horizontal ? CGSize(width: length, height: 44) : CGSize(width: 44, height: length)
                    let cancel = horizontal ? CGRect(x: 26, y: 0, width: 44, height: 44) : CGRect(x: 0, y: length - 44, width: 44, height: 44)
                    let done = horizontal ? CGRect(x: length - 72 - 26, y: 0, width: 72, height: 44) : CGRect(x: 0, y: 0, width: 44, height: 44)
                    let layout = WegramPhotoEditorToolbarLayout(size: size, cancelFrame: cancel, doneFrame: done, count: count)
                    XCTAssertFalse(layout.viewport.intersects(cancel))
                    XCTAssertFalse(layout.viewport.intersects(done))
                    XCTAssertTrue(CGRect(origin: .zero, size: size).contains(layout.viewport))
                    XCTAssertEqual(layout.buttons.count, count)
                    let content = CGRect(origin: .zero, size: layout.contentSize)
                    for (index, button) in layout.buttons.enumerated() {
                        XCTAssertEqual(button.size, CGSize(width: 44, height: 44))
                        XCTAssertTrue(content.contains(button))
                        for other in layout.buttons.dropFirst(index + 1) { XCTAssertFalse(button.intersects(other)) }
                    }
                    let total = CGFloat(count) * 44 + CGFloat(max(0, count - 1)) * 10
                    let viewportLength = horizontal ? layout.viewport.width : layout.viewport.height
                    if total > viewportLength {
                        XCTAssertGreaterThan(horizontal ? layout.contentSize.width : layout.contentSize.height, viewportLength)
                    }
                }
            }
        }
    }
}

final class WegramPhotoViewInteractionTests: XCTestCase {
    func testInactiveAncestorRejectsPhotoActionsAndRestoringItUsesCurrentActions() {
        let ancestor = UIView()
        let container = UIView()
        ancestor.addSubview(container)
        let toolbar = WegramPhotoToolbarView()
        let access = WegramPhotoAccessView()
        container.addSubview(toolbar)
        container.addSubview(access)
        toolbar.update(count: 1, original: false, originalAvailable: true, dark: false, fontSize: 17, previewTitle: "Preview", originalTitle: "Original", sendTitle: "Send", optionsTitle: "Options")
        var actions = 0
        toolbar.send = { actions += 1 }
        access.openSettings = { actions += 1 }
        for mode in 0 ..< 3 {
            ancestor.isHidden = mode == 0
            ancestor.alpha = mode == 1 ? 0 : 1
            ancestor.isUserInteractionEnabled = mode != 2
            XCTAssertFalse(wegramViewAcceptsActions(toolbar))
            XCTAssertFalse(wegramViewAcceptsActions(access))
            toolbar.sendButton.sendActions(for: .touchUpInside)
            access.settingsButton.sendActions(for: .touchUpInside)
        }
        XCTAssertEqual(actions, 0)
        ancestor.isHidden = false
        ancestor.alpha = 1
        ancestor.isUserInteractionEnabled = true
        XCTAssertTrue(wegramViewAcceptsActions(toolbar))
        XCTAssertTrue(wegramViewAcceptsActions(access))
        toolbar.send = { actions += 10 }
        access.openSettings = { actions += 100 }
        toolbar.sendButton.sendActions(for: .touchUpInside)
        access.settingsButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, 110)
    }
}

final class WegramPhotoSendingStateTests: XCTestCase {
    func testOriginalKeepsFileFormatAcrossPreviewAndInvalidationRestoresMediaIntent() {
        let state = WegramPhotoSendingState()
        var options = state.sendOptions(isAvailable: true, asFile: false)
        XCTAssertFalse(options.asFile)
        XCTAssertNil(options.convertToJpeg)
        options = state.sendOptions(isAvailable: true, asFile: true)
        XCTAssertTrue(options.asFile)
        XCTAssertNil(options.convertToJpeg, "The existing explicit file action must retain its HEIC conversion choice")
        state.original = true
        let previewState = state
        options = previewState.sendOptions(isAvailable: true, asFile: false)
        XCTAssertTrue(options.asFile, "A preview send must consume the same Original selection as the grid")
        XCTAssertEqual(options.convertToJpeg, false, "Original must keep HEIC instead of presenting a lossy-conversion prompt after gallery buttons are disabled")
        XCTAssertTrue(state.original)
        options = state.sendOptions(isAvailable: false, asFile: false)
        XCTAssertFalse(state.original, "Spoiler, timer, paid or inaccessible media must clear Original")
        XCTAssertFalse(options.asFile)
        XCTAssertNil(options.convertToJpeg)
        options = previewState.sendOptions(isAvailable: true, asFile: false)
        XCTAssertFalse(options.asFile, "Restoring eligibility must not silently re-enable Original")
        XCTAssertNil(options.convertToJpeg)
    }
}

final class WegramPhotoPreviewControlsTests: XCTestCase {
    func testOriginalSelectionAndMenuStateFollowCurrentSnapshotAndRejectInactiveActions() {
        let parent = UIView()
        let view = WegramPhotoPreviewControlsView()
        parent.addSubview(view)
        var actions = 0
        view.toggleOriginal = { actions += 1 }
        let menu = UIMenu(children: [UIAction(title: "Crop", handler: { _ in }), UIAction(title: "Quality", attributes: .disabled, handler: { _ in })])
        view.update(original: true, available: true, enabled: true, fontSize: 17, editTitle: "编辑", originalTitle: "原图", menu: menu)
        XCTAssertTrue(view.editButton.showsMenuAsPrimaryAction)
        XCTAssertEqual(view.editButton.menu?.children.map(\.title), ["Crop", "Quality"])
        XCTAssertEqual((view.editButton.menu?.children.last as? UIAction)?.attributes, .disabled)
        XCTAssertTrue(view.originalButton.accessibilityTraits.contains(.selected))
        XCTAssertEqual(view.originalButton.accessibilityLabel, "原图")
        view.originalButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, 1)
        parent.isHidden = true
        view.originalButton.sendActions(for: .touchUpInside)
        parent.isHidden = false
        view.update(original: false, available: false, enabled: true, fontSize: 17, editTitle: "Edit", originalTitle: "Original", menu: nil)
        view.originalButton.sendActions(for: .touchUpInside)
        XCTAssertFalse(view.originalButton.accessibilityTraits.contains(.selected))
        XCTAssertFalse(view.editButton.isEnabled)
        view.update(original: false, available: true, enabled: false, fontSize: 17, editTitle: "Edit", originalTitle: "Original", menu: menu)
        view.originalButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, 1)
        view.toggleOriginal = { actions += 10 }
        view.update(original: false, available: true, enabled: true, fontSize: 17, editTitle: "Edit", originalTitle: "Original", menu: menu)
        view.originalButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, 11)
    }

    func testPreviewTargetsStaySeparateAndScrollableInBothToolbarDirections() throws {
        let view = WegramPhotoPreviewControlsView()
        let menu = UIMenu(children: [UIAction(title: "Crop", handler: { _ in })])
        for size in [CGSize(width: 74, height: 44), CGSize(width: 226, height: 44), CGSize(width: 600, height: 44), CGSize(width: 44, height: 80), CGSize(width: 44, height: 300)] {
            for font: CGFloat in [17, 34] {
                for chinese in [true, false] {
                    view.update(original: true, available: true, enabled: true, fontSize: font, editTitle: chinese ? "编辑" : "Edit", originalTitle: chinese ? "原图" : "Original", menu: menu)
                    view.frame = CGRect(origin: .zero, size: size)
                    view.updateLayout(size: size)
                    view.layoutIfNeeded()
                    XCTAssertFalse(view.editButton.frame.intersects(view.originalButton.frame))
                    for button in [view.editButton, view.originalButton] {
                        XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
                        XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                        XCTAssertTrue(CGRect(origin: .zero, size: view.scrollView.contentSize).contains(button.frame))
                        XCTAssertNotNil(button.accessibilityLabel)
                    }
                    if size.width == 74 { XCTAssertGreaterThan(view.scrollView.contentSize.width, size.width) }
                    if size.height == 80 { XCTAssertGreaterThan(view.scrollView.contentSize.height, size.height) }
                    if size.width == 226, font == 17, chinese, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        let format = UIGraphicsImageRendererFormat(); format.scale = 3
                        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                            UIColor.black.setFill(); context.fill(CGRect(origin: .zero, size: size))
                            view.layer.render(in: context.cgContext)
                        }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("photo-preview-controls.png"))
                    }
                }
            }
        }
    }
}

final class WegramPhotoGalleryCheckTests: XCTestCase {
    private func image(_ button: UIView) -> UIImage {
        button.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat(); format.scale = 3
        return UIGraphicsImageRenderer(size: button.bounds.size, format: format).image { context in
            UIColor.black.setFill(); context.fill(button.bounds)
            button.layer.render(in: context.cgContext)
        }
    }
    func testGridCheckUsesReferenceCircleAndTickWithoutShrinkingItsTouchTarget() throws {
        final class ThreeScaleCheckButton: TGCheckButtonView {
            override var traitCollection: UITraitCollection { UITraitCollection(displayScale: 3) }
        }
        let button = ThreeScaleCheckButton(style: TGCheckButtonStyleGallery)!
        button.usesWegramAppearance = true
        button.usesWegramGridAppearance = true
        button.isSelected = true
        let selected = self.image(button)
        let cg = try XCTUnwrap(selected.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        func bounds(white: Bool) -> CGRect {
            var xs: [Int] = [], ys: [Int] = []
            for y in 0..<cg.height { for x in 0..<cg.width {
                let i = (y * cg.width + x) * 4
                if white ? (bytes[i] > 235 && bytes[i+1] > 235 && bytes[i+2] > 235) : (bytes[i] < 40 && bytes[i+1] > 150 && bytes[i+2] > 60 && bytes[i+2] < 140) {
                    xs.append(x); ys.append(y)
                }
            }}
            guard let left = xs.min(), let right = xs.max(), let top = ys.min(), let bottom = ys.max() else { return .zero }
            return CGRect(x: left, y: top, width: right-left+1, height: bottom-top+1)
        }
        let circle = bounds(white: false), tick = bounds(white: true)
        XCTAssertEqual(circle.minX, 36, accuracy: 1)
        XCTAssertEqual(circle.minY, 24, accuracy: 1)
        XCTAssertEqual(circle.width, 72, accuracy: 1)
        XCTAssertEqual(circle.height, 72, accuracy: 1)
        XCTAssertEqual(tick, CGRect(x: 55, y: 49, width: 36, height: 24))
        XCTAssertEqual(button.bounds.size, CGSize(width: 44, height: 44))
        XCTAssertTrue(button.hitTest(CGPoint(x: 1, y: 1), with: nil) === button)
        button.setNumber(27)
        XCTAssertEqual(selected.pngData(), self.image(button).pngData())
        button.usesWegramGridAppearance = false
        XCTAssertNotEqual(selected.pngData(), self.image(button).pngData())
        button.usesWegramGridAppearance = true
        XCTAssertEqual(selected.pngData(), self.image(button).pngData())
        button.isSelected = false
        XCTAssertNotEqual(selected.pngData(), self.image(button).pngData())
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            try selected.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("photo-grid-check-selected.png"))
            try self.image(button).pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("photo-grid-check-empty.png"))
        }
    }

    func testGalleryCheckKeepsSelectionAnd44PointTargetWhileHidingOrdinal() throws {
        let button = TGCheckButtonView(style: TGCheckButtonStyleGallery)!
        let originalSize = button.bounds.size
        button.usesWegramAppearance = true
        XCTAssertEqual(button.bounds.size, CGSize(width: 44, height: 44))
        button.setSelected(true, animated: false)
        button.setNumber(1)
        let first = self.image(button)
        button.setNumber(27)
        XCTAssertEqual(first.pngData(), self.image(button).pngData(), "The actual check must stay a tick, not a changing ordinal")
        XCTAssertTrue(button.isSelected)
        button.setSelected(false, animated: false)
        XCTAssertNotEqual(first.pngData(), self.image(button).pngData())
        button.usesWegramAppearance = false
        XCTAssertEqual(button.bounds.size, originalSize)
        button.usesWegramAppearance = true
        button.isSelected = true
        XCTAssertEqual(first.pngData(), self.image(button).pngData())
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            try first.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("photo-gallery-check-selected.png"))
            button.isSelected = false
            try self.image(button).pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("photo-gallery-check-empty.png"))
        }
    }
}


final class WegramPhotoPreviewPlacementTests: XCTestCase {
    func testPreviewUsesVacatedBackSpaceAndCentersOriginalWithoutCoveringSend() {
        let controls = WegramPhotoPreviewControlsView()
        let menu = UIMenu(children: [UIAction(title: "裁剪", handler: { _ in })])
        for horizontal in [true, false] {
            for length: CGFloat in [250, 320, 402, 874] {
                let size = horizontal ? CGSize(width: length, height: 44) : CGSize(width: 44, height: length)
                let send = horizontal ? CGRect(x: length - 98, y: 0, width: 72, height: 44) : CGRect(x: 0, y: 0, width: 44, height: 44)
                let layout = WegramPhotoEditorToolbarLayout(size: size, cancelFrame: nil, doneFrame: send, count: 0)
                XCTAssertFalse(layout.viewport.intersects(send))
                XCTAssertTrue(CGRect(origin: .zero, size: size).contains(layout.viewport))
                if horizontal {
                    XCTAssertEqual(layout.viewport.minX, 16)
                } else {
                    XCTAssertEqual(layout.viewport.maxY, size.height - 16)
                }
                for font: CGFloat in [17, 34] {
                    controls.update(original: true, available: true, enabled: true, fontSize: font, editTitle: "编辑", originalTitle: "原图", menu: menu)
                    controls.frame = layout.viewport
                    controls.updateLayout(size: layout.viewport.size, originalCenter: size.width / 2 - layout.viewport.minX)
                    XCTAssertFalse(controls.editButton.frame.intersects(controls.originalButton.frame))
                    for button in [controls.editButton, controls.originalButton] {
                        XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
                        XCTAssertTrue(CGRect(origin: .zero, size: controls.scrollView.contentSize).contains(button.frame))
                    }
                    if horizontal && length >= 320 && font == 17 {
                        XCTAssertEqual(layout.viewport.minX + controls.originalButton.frame.midX, size.width / 2, accuracy: 0.5)
                    }
                }
            }
        }
    }
}


final class WegramPhotoCounterVisibilityTests: XCTestCase {
    func testCounterStaysHiddenWhenClosedAndKeepsInterfaceHidingWhenExpanded() throws {
        let buttonClass = try XCTUnwrap(NSClassFromString("TGMediaPickerPhotoCounterButton") as? UIButton.Type)
        let button = buttonClass.init(frame: CGRect(x: 0, y: 0, width: 64, height: 38))
        button.isHidden = false
        XCTAssertFalse(button.isHidden)
        button.setValue(true, forKey: "hidesWhenUnselected")
        XCTAssertTrue(button.isHidden, "Closed selection management must not leave a counter on the preview")
        button.isHidden = false
        XCTAssertTrue(button.isHidden, "An interface show must not restore the closed counter")
        button.isSelected = true
        XCTAssertFalse(button.isHidden, "Expanded management must retain its close control")
        button.isHidden = true
        button.isSelected = false
        button.isSelected = true
        XCTAssertTrue(button.isHidden, "Selection changes must not unhide an interface hidden for editing")
        button.setValue(false, forKey: "hidesWhenUnselected")
        XCTAssertTrue(button.isHidden, "Restoring the default style must retain interface hiding")
        button.isHidden = false
        button.isSelected = false
        XCTAssertFalse(button.isHidden, "The original counter remains visible when unselected")
    }
}


final class WegramPhotoSelectionManagementAvailabilityTests: XCTestCase {
    func testSelectionManagementStaysReachableWhileEditingAndOriginalRemainDisabled() {
        let controls = WegramPhotoPreviewControlsView()
        let menu = UIMenu(children: [UIAction(title: "已选照片(2)", handler: { _ in })])
        controls.update(original: false, available: true, enabled: false, fontSize: 17, editTitle: "编辑", originalTitle: "原图", menu: menu, selectionManagementAvailable: true)
        XCTAssertTrue(controls.editButton.isEnabled)
        XCTAssertFalse(controls.originalButton.isEnabled)
        controls.update(original: false, available: true, enabled: false, fontSize: 17, editTitle: "编辑", originalTitle: "原图", menu: menu)
        XCTAssertFalse(controls.editButton.isEnabled)
        XCTAssertFalse(controls.originalButton.isEnabled)
        controls.update(original: false, available: true, enabled: false, fontSize: 17, editTitle: "编辑", originalTitle: "原图", menu: UIMenu(children: []), selectionManagementAvailable: true)
        XCTAssertFalse(controls.editButton.isEnabled)
    }
}

final class WegramPhotoAlbumListTests: XCTestCase {
    private func makeView(font: CGFloat = 17) -> WegramPhotoAlbumListView {
        let titles = ["可访问的照片", "Favorites", "Videos", "Selfies", "Live Photos", "Portrait", "Screenshots", "Long album name"]
        return WegramPhotoAlbumListView(items: titles.enumerated().map { .init(id: String($0.offset), title: $0.element, count: $0.offset == 0 ? 1575 : $0.offset, selected: $0.offset == 0) }, limitedTitle: "微信只能访问部分照片和相册", dark: false, fontSize: font, cancelTitle: "取消")
    }
    func testAlbumListUsesFullWidthLeftThumbnailsInlineCountsAndSelectedCheck() throws {
        let view = self.makeView()
        view.frame = CGRect(x: 0, y: 0, width: 402, height: 550)
        view.updateLayout(size: view.bounds.size)
        view.tableView.layoutIfNeeded()
        XCTAssertEqual(view.tableView.frame, CGRect(x: 0, y: 0, width: 402, height: 378))
        XCTAssertEqual(view.tableView.rowHeight, 56)
        XCTAssertTrue(view.tableView.isScrollEnabled)
        let first = try XCTUnwrap(view.tableView.cellForRow(at: IndexPath(row: 0, section: 0)))
        first.layoutIfNeeded()
        let label = try XCTUnwrap(first.contentView.subviews.compactMap { $0 as? UILabel }.first)
        XCTAssertEqual(label.attributedText?.string, "可访问的照片(1575)")
        XCTAssertEqual(label.frame.minX, 72)
        XCTAssertTrue(first.accessibilityTraits.contains(.selected))
        XCTAssertEqual(first.accessibilityValue, "1575")
        let images = first.contentView.subviews.compactMap { $0 as? UIImageView }
        XCTAssertTrue(images.contains { $0.frame == CGRect(x: 0, y: 0, width: 56, height: 56) })
        XCTAssertTrue(images.contains { !$0.isHidden && $0.frame == CGRect(x: 362, y: 16, width: 24, height: 24) })
        let second = try XCTUnwrap(view.tableView.cellForRow(at: IndexPath(row: 1, section: 0)))
        XCTAssertFalse(second.accessibilityTraits.contains(.selected))
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let format = UIGraphicsImageRendererFormat(); format.scale = 3
            let snapshot = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
            try snapshot.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("photo-album-list.png"))
        }
    }
    func testAlbumActionsUseIdentifiersRejectInactiveAncestorsAndConsumeOnlyOnce() {
        let parent = UIView()
        let view = self.makeView()
        parent.addSubview(view)
        var ids: [String] = []
        view.select = { ids.append($0) }
        parent.isHidden = true
        view.tableView(view.tableView, didSelectRowAt: IndexPath(row: 3, section: 0))
        XCTAssertTrue(ids.isEmpty)
        parent.isHidden = false
        view.tableView(view.tableView, didSelectRowAt: IndexPath(row: 3, section: 0))
        view.tableView(view.tableView, didSelectRowAt: IndexPath(row: 4, section: 0))
        XCTAssertEqual(ids, ["3"])
        let other = self.makeView()
        var cancelled = 0
        other.dismissed = { cancelled += 1 }
        XCTAssertTrue(other.accessibilityPerformEscape())
        other.dimmingButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(cancelled, 1)
    }
    func testAlbumHeaderAndRowsRemainScrollableWithLargeTextAndNarrowLayouts() {
        for width: CGFloat in [250, 402, 874] {
            for font: CGFloat in [17, 34, 56] {
                let view = self.makeView(font: font)
                view.frame = CGRect(x: 0, y: 0, width: width, height: 400)
                view.updateLayout(size: view.bounds.size)
                view.tableView.layoutIfNeeded()
                XCTAssertEqual(view.tableView.bounds.width, width)
                XCTAssertLessThanOrEqual(view.tableView.bounds.height, 356)
                XCTAssertGreaterThanOrEqual(view.tableView.rowHeight, 44)
                if let label = view.tableView.tableHeaderView as? UILabel {
                    XCTAssertGreaterThanOrEqual(label.bounds.height, label.sizeThatFits(CGSize(width: max(1, width - 32), height: .greatestFiniteMagnitude)).height)
                }
            }
        }
    }
}

final class WegramPhotoAlbumButtonTests: XCTestCase {
    func testAlbumButtonTracksExpansionAndKeepsCurrentOptionsWithInactiveAncestorGuard() throws {
        let parent = UIView()
        let button = WegramPhotoAlbumButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        parent.addSubview(button)
        var toggles = 0, options = 0
        button.toggle = { toggles += 1 }
        button.options = { options += 1 }
        button.update(expanded: false, dark: false, enabled: true, chinese: true, moreTitle: "更多照片选项")
        let closed = try XCTUnwrap(button.currentImage?.pngData())
        XCTAssertEqual(button.intrinsicContentSize, CGSize(width: 44, height: 44))
        XCTAssertEqual(button.accessibilityValue, "已收起")
        button.sendActions(for: .touchUpInside)
        let action = try XCTUnwrap(button.accessibilityCustomActions?.first)
        XCTAssertTrue(action.actionHandler?(action) == true)
        XCTAssertEqual(toggles, 1)
        XCTAssertEqual(options, 1)
        button.update(expanded: true, dark: true, enabled: true, chinese: false, moreTitle: "More Photo Options")
        XCTAssertTrue(button.isSelected)
        XCTAssertEqual(button.accessibilityValue, "Expanded")
        XCTAssertNotEqual(closed, button.currentImage?.pngData())
        parent.isHidden = true
        button.sendActions(for: .touchUpInside)
        XCTAssertFalse(action.actionHandler?(action) ?? true)
        XCTAssertEqual(toggles, 1)
        parent.isHidden = false
        button.isEnabled = false
        XCTAssertFalse(action.actionHandler?(action) ?? true)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(toggles, 1)
        button.isEnabled = true
        button.options = { options += 10 }
        XCTAssertTrue(action.actionHandler?(action) == true)
        XCTAssertEqual(options, 11)
    }

    func testAlbumButtonRendersBothReferenceStackStates() throws {
        let button = WegramPhotoAlbumButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        for expanded in [false, true] {
            button.update(expanded: expanded, dark: false, enabled: true, chinese: true, moreTitle: "更多照片选项")
            button.layoutIfNeeded()
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                let format = UIGraphicsImageRendererFormat(); format.scale = 3
                let image = UIGraphicsImageRenderer(size: button.bounds.size, format: format).image { context in
                    UIColor.white.setFill(); context.fill(button.bounds)
                    button.layer.render(in: context.cgContext)
                }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(expanded ? "photo-album-button-expanded.png" : "photo-album-button-closed.png"))
            }
        }
    }
}

private final class WegramStripTestItem: NSObject, TGMediaSelectableItem {
    let uniqueIdentifier: String
    init(_ id: String) { self.uniqueIdentifier = id }
}

final class WegramPhotoPreviewStripTests: XCTestCase {
    func testPositionUsesActualGalleryOrderAndHidesMissingFocus() {
        let first = NSObject(), second = NSObject(), third = NSObject()
        XCTAssertEqual(TGMediaPickerGalleryPositionText([first, second, third], second), "2/3")
        XCTAssertEqual(TGMediaPickerGalleryPositionText([third, first], first), "2/2")
        XCTAssertEqual(TGMediaPickerGalleryPositionText([first], first), "1/1")
        XCTAssertNil(TGMediaPickerGalleryPositionText([first, second], third))
        XCTAssertNil(TGMediaPickerGalleryPositionText([], first))
        XCTAssertNil(TGMediaPickerGalleryPositionText([first], nil))
    }

    func testFullWidthStripRetainsLeadingInsetFocusAndSelectionOrderThroughInsertAndDelete() throws {
        let viewClass = try XCTUnwrap(NSClassFromString("TGMediaPickerPhotoStripView") as? UIView.Type)
        let view = viewClass.init(frame: CGRect(x: 0, y: 0, width: 402, height: 96))
        let selection = try XCTUnwrap(TGMediaSelectionContext(groupingAllowed: true, selectionLimit: 100))
        let model = try XCTUnwrap(TGMediaPickerGallerySelectedItemsModel(selectionContext: selection))
        view.setValue(selection, forKey: "selectionContext")
        view.setValue(model, forKey: "selectedItemsModel")
        view.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "interfaceOrientation")
        view.setValue(true, forKey: "usesWegramAppearance")
        view.layoutIfNeeded()
        let collection = try XCTUnwrap(view.value(forKey: "collectionView") as? UICollectionView)
        let first = WegramStripTestItem("first"), second = WegramStripTestItem("second")
        selection.setItem(first, selected: true)
        view.setValue("first", forKey: "focusedItemIdentifier")
        typealias IndexAction = @convention(c) (AnyObject, Selector, Int) -> Void
        let insert = NSSelectorFromString("insertItemAtIndex:")
        let invokeInsert = unsafeBitCast(view.method(for: insert), to: IndexAction.self)
        invokeInsert(view, insert, 0)
        collection.layoutIfNeeded()
        view.setValue("first", forKey: "focusedItemIdentifier")
        XCTAssertEqual(collection.contentOffset.x, 0, accuracy: 0.5)
        let firstCell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(firstCell.frame, CGRect(x: 16, y: 16, width: 64, height: 64))
        XCTAssertTrue(firstCell.accessibilityTraits.contains(.selected))
        let border = try XCTUnwrap(firstCell.value(forKey: "focusBorderView") as? UIView)
        XCTAssertFalse(border.isHidden)
        XCTAssertEqual(border.layer.borderWidth, 4)
        selection.setItem(second, selected: true)
        invokeInsert(view, insert, 1)
        view.layoutIfNeeded()
        collection.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, 0, accuracy: 0.5, "A short full-width strip must not inherit the legacy negative trailing offset")
        XCTAssertEqual(collection.cellForItem(at: IndexPath(item: 1, section: 0))?.frame.minX, 92)
        view.setValue("second", forKey: "focusedItemIdentifier")
        XCTAssertFalse(try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 0, section: 0))).accessibilityTraits.contains(.selected))
        XCTAssertTrue(try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 1, section: 0))).accessibilityTraits.contains(.selected))
        XCTAssertEqual(selection.selectedItems().compactMap { ($0 as? WegramStripTestItem)?.uniqueIdentifier }, ["first", "second"])
        selection.setItem(first, selected: false)
        let delete = NSSelectorFromString("deleteItemAtIndex:")
        unsafeBitCast(view.method(for: delete), to: IndexAction.self)(view, delete, 0)
        collection.layoutIfNeeded()
        XCTAssertEqual(collection.numberOfItems(inSection: 0), 1)
        XCTAssertEqual(collection.contentOffset.x, 0, accuracy: 0.5)
        XCTAssertTrue(try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 0, section: 0))).accessibilityTraits.contains(.selected))
        XCTAssertEqual(selection.selectedItems().compactMap { ($0 as? WegramStripTestItem)?.uniqueIdentifier }, ["second"])
        for index in 2 ... 8 {
            selection.setItem(WegramStripTestItem("item-\(index)"), selected: true)
            invokeInsert(view, insert, index - 1)
        }
        view.setValue("item-8", forKey: "focusedItemIdentifier")
        collection.layoutIfNeeded()
        let lastCell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 7, section: 0)))
        XCTAssertTrue(lastCell.accessibilityTraits.contains(.selected))
        XCTAssertTrue(collection.bounds.intersects(lastCell.frame), "Paging must reveal the focused thumbnail beyond the first screen")
        view.setValue("second", forKey: "focusedItemIdentifier")
        collection.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, 0, accuracy: 0.5)
        // Artificial colors expose geometry and focus without copying private reference photos.
        for (index, cell) in collection.visibleCells.enumerated() {
            (cell.value(forKey: "imageView") as? UIView)?.backgroundColor = [UIColor.systemBrown, .systemGray, .systemBlue, .systemOrange, .systemTeal][index % 5]
        }
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let format = UIGraphicsImageRendererFormat(); format.scale = 3
            let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("photo-preview-strip.png"))
        }
        view.setValue(false, forKey: "usesWegramAppearance")
        collection.layoutIfNeeded()
        let restoredCell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 0, section: 0)))
        XCTAssertTrue(try XCTUnwrap(restoredCell.value(forKey: "focusBorderView") as? UIView).isHidden)
        XCTAssertEqual(restoredCell.layer.cornerRadius, 4)
    }
}

final class WegramPhotoMergeTests: XCTestCase {
    private func update(_ view: WegramPhotoMergeView, count: Int = 3, selected: Bool? = false, enabled: Bool = true, dark: Bool = false, font: CGFloat = 17) {
        view.update(count: count, selected: selected, enabled: enabled, dark: dark, fontSize: font, title: "发送后合并展示")
    }

    func testMergeActionUsesNativeGroupingAndRejectsUnavailableDisabledAndHiddenAncestors() throws {
        let selection = try XCTUnwrap(TGMediaSelectionContext(groupingAllowed: false, selectionLimit: 100))
        let state = WegramPhotoSendingState()
        let parent = UIView()
        let row = WegramPhotoMergeView()
        parent.addSubview(row)
        var changes = 0
        row.toggle = {
            selection.toggleGrouping()
            state.mergeDisplay = selection.grouping
            changes += 1
            self.update(row, selected: selection.grouping)
        }
        XCTAssertFalse(state.mergeDisplay)
        self.update(row, count: 2)
        row.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(changes, 0)
        self.update(row)
        row.button.sendActions(for: .touchUpInside)
        XCTAssertTrue(selection.grouping)
        XCTAssertTrue(state.mergeDisplay)
        XCTAssertTrue(row.button.accessibilityTraits.contains(.selected))
        row.button.sendActions(for: .touchUpInside)
        XCTAssertFalse(selection.grouping)
        XCTAssertFalse(state.mergeDisplay)
        parent.isHidden = true
        row.button.sendActions(for: .touchUpInside)
        parent.isHidden = false
        row.setEnabled(false)
        row.button.sendActions(for: .touchUpInside)
        self.update(row, selected: nil)
        row.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(changes, 2)
    }

    func testGridAddsExactlyOneMergeRowAndLoadingRecoversItsCurrentAction() {
        let toolbar = WegramPhotoToolbarView()
        var changes = 0
        toolbar.mergeView.toggle = { changes += 1 }
        func update(merge: Bool?) {
            toolbar.update(count: 3, original: false, originalAvailable: true, dark: false, fontSize: 17, previewTitle: "预览", originalTitle: "原图", sendTitle: "发送", optionsTitle: "更多", mergeSelected: merge)
        }
        update(merge: nil)
        let originalHeight = toolbar.updateLayout(width: 402, leftInset: 0, rightInset: 0, bottomInset: 34)
        update(merge: false)
        let mergedHeight = toolbar.updateLayout(width: 402, leftInset: 0, rightInset: 0, bottomInset: 34)
        toolbar.frame = CGRect(x: 0, y: 0, width: 402, height: mergedHeight)
        toolbar.layoutIfNeeded()
        XCTAssertEqual(mergedHeight - originalHeight, 72)
        XCTAssertEqual(toolbar.mergeView.frame, CGRect(x: 0, y: 20, width: 402, height: 52))
        XCTAssertEqual(toolbar.previewButton.frame.minY, 72)
        XCTAssertEqual(toolbar.previewButton.currentTitle, "预览(3)")
        toolbar.updateLoadingProgress(0.5)
        update(merge: false)
        toolbar.mergeView.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(changes, 0)
        toolbar.updateLoadingProgress(nil)
        toolbar.mergeView.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(changes, 1)
        toolbar.mergeView.toggle = { changes += 10 }
        toolbar.mergeView.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(changes, 11)
    }

    func testMergeRowWrapsLargeTextAndReservesFortyFourPointTarget() {
        let row = WegramPhotoMergeView()
        for width: CGFloat in [250, 402, 756] {
            for font: CGFloat in [17, 34, 56] {
                self.update(row, font: font)
                let size = row.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
                row.frame = CGRect(origin: .zero, size: size)
                row.layoutIfNeeded()
                row.button.layoutIfNeeded()
                XCTAssertGreaterThanOrEqual(row.button.frame.height, 44)
                XCTAssertGreaterThanOrEqual(row.button.titleLabel?.frame.height ?? 0, ceil(row.button.titleLabel?.font.lineHeight ?? 0))
                XCTAssertLessThanOrEqual(row.button.titleLabel?.frame.maxX ?? 0, row.button.bounds.maxX)
                XCTAssertLessThanOrEqual(row.button.titleLabel?.frame.maxY ?? 0, row.button.bounds.maxY)
            }
        }
    }

    func testRenderActualMergeRowAndGridToolbarInBothThemes() throws {
        guard let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] else { return }
        for dark in [false, true] {
            let toolbar = WegramPhotoToolbarView()
            toolbar.update(count: 3, original: false, originalAvailable: true, dark: dark, fontSize: 17, previewTitle: "预览", originalTitle: "原图", sendTitle: "发送", optionsTitle: "更多", mergeSelected: false)
            let height = toolbar.updateLayout(width: 402, leftInset: 0, rightInset: 0, bottomInset: 34)
            toolbar.frame = CGRect(x: 0, y: 0, width: 402, height: height)
            toolbar.layoutIfNeeded()
            toolbar.mergeView.layoutIfNeeded()
            toolbar.mergeView.button.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat(); format.scale = 3
            let image = UIGraphicsImageRenderer(size: toolbar.bounds.size, format: format).image { toolbar.layer.render(in: $0.cgContext) }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "photo-merge-toolbar-dark.png" : "photo-merge-toolbar-light.png"))
        }
    }
}
