import XCTest
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import SwiftSignalKit

final class WegramCleanupSheetTests: XCTestCase {
    func testStyledConfirmationKeepsOptionsNeutralDiscardRedAndCancelSeparate() throws {
        for dark in [false, true] {
            for selection in 0 ..< 4 {
                var calls = [0, 0]
                let data = defaultPresentationData().withUpdated(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme)
                let controller = wegramConfirmationController(
                    updatedPresentationData: (initial: data, signal: .never()),
                    title: "Forward 2 messages", text: "From **Literal Name**", cancelTitle: "Cancel",
                    styledActions: [
                        (title: "Show Options", color: .accent, action: { calls[0] += 1 }),
                        (title: "Cancel Forwarding", color: .destructive, action: { calls[1] += 1 })
                    ]
                )
                let root = controller.displayNode
                _ = root.view
                let size = CGSize(width: 402, height: 874)
                root.frame = CGRect(origin: .zero, size: size)
                controller.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), transition: .immediate)
                let buttons = self.descendants(root).compactMap { $0 as? ActionSheetButtonNode }
                let areas = try buttons.map { try XCTUnwrap(self.descendants($0).compactMap { $0 as? AccessibilityAreaNode }.first) }
                XCTAssertEqual(areas.map { $0.accessibilityLabel }, ["Show Options", "Cancel Forwarding", "Cancel"])
                let labels = buttons.compactMap { self.texts($0).first?.attributedText }
                XCTAssertEqual(labels[0].attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, controller.theme.standardActionTextColor)
                XCTAssertEqual(labels[1].attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, UIColor(rgb: 0xfa5151))
                let warning = try XCTUnwrap(self.descendants(root).compactMap { $0 as? ActionSheetTextNode }.first)
                XCTAssertEqual(self.texts(warning).first?.attributedText?.string, "Forward 2 messages\n\nFrom **Literal Name**")
                XCTAssertEqual(self.descendants(root).filter { String(describing: type(of: $0)) == "ActionSheetItemGroupNode" }.count, 2)
                if selection == 0, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    root.recursivelyEnsureDisplaySynchronously(true)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    let image = UIGraphicsImageRenderer(size: size, format: format).image { root.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("forward-confirmation-\(dark ? "dark" : "light").png"))
                }
                XCTAssertEqual(calls, [0, 0])
                if selection < 3 { _ = areas[selection].accessibilityActivate() }
                else { controller.dismissAnimated() }
                for area in areas { _ = area.accessibilityActivate() }
                XCTAssertEqual(calls, selection == 0 ? [1, 0] : selection == 1 ? [0, 1] : [0, 0])
            }
        }
    }

    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }

    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }

    private func descendants(_ node: ASDisplayNode) -> [ASDisplayNode] {
        return [node] + (node.subnodes ?? []).flatMap(self.descendants)
    }

    func testHistoryConfirmationKeepsWarningAndSeparateCancelWithoutRunningDeletion() throws {
        for confirm in [false, true] {
            for dark in [false, true] {
                var clears = 0
                let data = defaultPresentationData().withUpdated(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme)
                let controller = wegramConfirmationController(
                    updatedPresentationData: (initial: data, signal: .never()),
                    title: "清空**全部**", text: "删除后无法恢复。仅清理已说明的范围。",
                    cancelTitle: "取消", actionTitle: "清空聊天记录", action: { clears += 1 }
                )
                let root = controller.displayNode
                _ = root.view
                let size = CGSize(width: 402, height: 874)
                root.frame = CGRect(origin: .zero, size: size)
                controller.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), transition: .immediate)
                XCTAssertTrue(controller.theme.usesWegramLayout)
                let buttons = self.descendants(root).compactMap { $0 as? ActionSheetButtonNode }
                XCTAssertEqual(buttons.count, 2)
                let areas = try buttons.map { try XCTUnwrap(self.descendants($0).compactMap { $0 as? AccessibilityAreaNode }.first) }
                XCTAssertEqual(areas.map { $0.accessibilityLabel }, ["清空聊天记录", "取消"])
                let labels = buttons.compactMap { self.texts($0).first?.attributedText }
                XCTAssertEqual(labels.first?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, UIColor(rgb: 0xfa5151))
                let warning = try XCTUnwrap(self.descendants(root).compactMap { $0 as? ActionSheetTextNode }.first)
                XCTAssertEqual(self.texts(warning).first?.attributedText?.string, "清空**全部**\n\n删除后无法恢复。仅清理已说明的范围。")
                let groups = self.descendants(root).filter { String(describing: type(of: $0)) == "ActionSheetItemGroupNode" }
                XCTAssertEqual(groups.count, 2)
                let cancel = try XCTUnwrap(buttons.last)
                XCTAssertEqual(cancel.view.convert(cancel.bounds, to: root.view).maxY, 840)
                XCTAssertEqual(clears, 0)
                if !confirm, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    root.recursivelyEnsureDisplaySynchronously(true)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    let image = UIGraphicsImageRenderer(size: size, format: format).image { root.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("cleanup-confirmation-\(dark ? "dark" : "light").png"))
                }
                XCTAssertTrue(areas[confirm ? 0 : 1].accessibilityActivate())
                XCTAssertEqual(clears, confirm ? 1 : 0)
                _ = areas[0].accessibilityActivate()
                _ = areas[1].accessibilityActivate()
                _ = areas[0].accessibilityActivate()
                XCTAssertEqual(clears, confirm ? 1 : 0, "Dismissed or consumed confirmation must reject old and duplicate actions")
            }
        }
    }

    func testMultipleHistoryScopesKeepTheirOrderAndOnlyTheChosenActionRunsOnce() throws {
        for selection in 0..<4 {
            var calls = [0, 0]
            let data = defaultPresentationData()
            let controller = wegramConfirmationController(updatedPresentationData: (initial: data, signal: .never()), title: "Clear", text: "Delete **group** messages", cancelTitle: "Cancel", actions: [
                (title: "Delete for everyone", action: { calls[0] += 1 }),
                (title: "Delete for me", action: { calls[1] += 1 })
            ], parseMarkdown: true)
            let root = controller.displayNode
            _ = root.view
            let buttons = self.descendants(root).compactMap { $0 as? ActionSheetButtonNode }
            let areas = try buttons.map { try XCTUnwrap(self.descendants($0).compactMap { $0 as? AccessibilityAreaNode }.first) }
            XCTAssertEqual(areas.map { $0.accessibilityLabel }, ["Delete for everyone", "Delete for me", "Cancel"])
            let warning = try XCTUnwrap(self.descendants(root).compactMap { $0 as? ActionSheetTextNode }.first)
            XCTAssertEqual(self.texts(warning).first?.attributedText?.string, "Clear\n\nDelete group messages")
            XCTAssertEqual(calls, [0, 0])
            if selection < 3 { _ = areas[selection].accessibilityActivate() }
            else { controller.dismissAnimated() }
            for area in areas { _ = area.accessibilityActivate() }
            XCTAssertEqual(calls, selection == 0 ? [1, 0] : selection == 1 ? [0, 1] : [0, 0])
        }
    }

    func testClosingConfirmationRejectsItsOldActionDuringAnimation() throws {
        for drag in [false, true] {
            var clears = 0
            let data = defaultPresentationData()
            let controller = wegramConfirmationController(
                updatedPresentationData: (initial: data, signal: .never()),
                title: "Clear", text: "Warning", cancelTitle: "Cancel", actionTitle: "Delete", action: { clears += 1 }
            )
            let root = controller.displayNode
            _ = root.view
            let button = try XCTUnwrap(self.descendants(root).compactMap { $0 as? ActionSheetButtonNode }.first)
            let area = try XCTUnwrap(self.descendants(button).compactMap { $0 as? AccessibilityAreaNode }.first)
            if drag {
                let scroll = try XCTUnwrap(self.descendants(root).compactMap { $0 as? ASScrollNode }.first?.view)
                scroll.contentOffset = CGPoint(x: 0, y: -50)
                scroll.delegate?.scrollViewDidEndDragging?(scroll, willDecelerate: false)
            } else {
                controller.dismissAnimated()
            }
            _ = area.accessibilityActivate()
            XCTAssertEqual(clears, 0)
        }
    }

    func testHistoryConfirmationRetainsPresentationUpdates() {
        let initial = defaultPresentationData()
        let controller = wegramConfirmationController(
            updatedPresentationData: (initial: initial, signal: .single(initial.withUpdated(theme: defaultDarkPresentationTheme))),
            title: "Clear", text: "Warning", cancelTitle: "Cancel", actionTitle: "Delete", action: {}
        )
        XCTAssertEqual(controller.theme.itemBackgroundColor, UIColor(rgb: 0x202020))
    }

    private func texts(_ node: ASDisplayNode) -> [ImmediateTextNode] {
        return (node.subnodes ?? []).compactMap { $0 as? ImmediateTextNode }
    }

    func testCacheCategoryUsesFormTypographyAndAccessibleSizeWhileKeepingToggleValues() throws {
        let theme = ActionSheetControllerTheme(wegramTheme: defaultPresentationTheme, fontSize: .regular)
        var values: [Bool] = []
        let item = ActionSheetCheckboxItem(title: "Photos", label: "10.0 MB", value: false, action: { values.append($0) })
        let node = item.node(theme: theme)
        _ = node.view
        let size = node.updateLayout(constrainedSize: CGSize(width: 402, height: 800), transition: .immediate)
        XCTAssertEqual(size.height, 56)
        for text in self.texts(node) {
            XCTAssertEqual((text.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, 17)
        }
        let area = try XCTUnwrap(node.subnodes?.compactMap { $0 as? AccessibilityAreaNode }.first)
        XCTAssertEqual(area.accessibilityLabel, "Photos")
        XCTAssertEqual(area.accessibilityValue, "10.0 MB")
        XCTAssertTrue(area.accessibilityActivate())
        XCTAssertEqual(values, [true])
        ActionSheetCheckboxItem(title: "Photos", label: "10.0 MB", value: true, action: { values.append($0) }).updateNode(node)
        XCTAssertTrue(area.accessibilityTraits.contains(.selected))
        XCTAssertTrue(area.accessibilityActivate())
        XCTAssertEqual(values, [true, false])
    }

    func testOriginalCacheCategoryKeepsItsLegacyFontAndHeight() {
        let theme = ActionSheetControllerTheme(presentationTheme: defaultPresentationTheme, fontSize: .regular)
        let node = ActionSheetCheckboxItem(title: "Photos", label: "10 MB", value: true, action: { _ in }).node(theme: theme)
        XCTAssertEqual(node.updateLayout(constrainedSize: CGSize(width: 402, height: 800), transition: .immediate).height, 57)
        for text in self.texts(node) {
            XCTAssertEqual((text.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, 20)
        }
    }

    func testLongCategoriesAndAmountsFitLargeTypeAndBothCheckPositions() throws {
        for width: CGFloat in [320, 402, 750] {
            for font: PresentationFontSize in [.regular, .extraLargeX2] {
                for style: ActionSheetCheckboxStyle in [.default, .alignRight] {
                    let theme = ActionSheetControllerTheme(wegramTheme: defaultDarkPresentationTheme, fontSize: font)
                    let node = ActionSheetCheckboxItem(title: "缓存类别名称较长的图片和视频文件", label: "123.4 GB", value: true, style: style, action: { _ in }).node(theme: theme)
                    _ = node.view
                    let size = node.updateLayout(constrainedSize: CGSize(width: width, height: 800), transition: .immediate)
                    node.frame = CGRect(origin: .zero, size: size)
                    let texts = self.texts(node)
                    XCTAssertEqual(texts.count, 2)
                    let title = try XCTUnwrap(texts.first)
                    let amount = try XCTUnwrap(texts.last)
                    XCTAssertLessThanOrEqual(title.frame.maxX + 12, amount.frame.minX + 0.01)
                    XCTAssertGreaterThanOrEqual(size.height, 56)
                    for text in texts {
                        XCTAssertGreaterThanOrEqual(text.frame.minX, 16)
                        XCTAssertLessThanOrEqual(text.frame.maxX, width - 16)
                        XCTAssertGreaterThanOrEqual(text.frame.minY, 12)
                        XCTAssertLessThanOrEqual(text.frame.maxY, size.height - 12)
                        XCTAssertEqual((text.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, font.baseDisplaySize)
                    }
                    let check = try XCTUnwrap(node.subnodes?.compactMap { $0 as? ASImageNode }.first)
                    if style == .alignRight {
                        XCTAssertLessThanOrEqual(amount.frame.maxX, check.frame.minX - 8)
                    } else {
                        XCTAssertGreaterThanOrEqual(title.frame.minX, check.frame.maxX + 8)
                    }
                    if width == 402 && style == .default, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        node.recursivelyEnsureDisplaySynchronously(true)
                        let image = UIGraphicsImageRenderer(size: size).image { node.view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("cleanup-category-\(font.baseDisplaySize).png"))
                    }
                }
            }
        }
    }
}
