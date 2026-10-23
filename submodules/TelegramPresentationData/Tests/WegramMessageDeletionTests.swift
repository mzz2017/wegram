import XCTest
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit

final class WegramMessageDeletionTests: XCTestCase {
    override class func setUp() { super.setUp(); WegramSearchFieldTests.exchangeResourceLookups() }
    override class func tearDown() { WegramSearchFieldTests.exchangeResourceLookups(); super.tearDown() }
    private func nodes(_ node: ASDisplayNode) -> [ASDisplayNode] { return [node] + (node.subnodes ?? []).flatMap(self.nodes) }
    private func layout(_ controller: ViewController) -> ASDisplayNode {
        let root = controller.displayNode
        _ = root.view
        root.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.containerLayoutUpdated(ContainerViewLayout(size: root.bounds.size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), transition: .immediate)
        return root
    }
    private func save(_ root: ASDisplayNode, name: String) throws {
        guard let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] else { return }
        root.recursivelyEnsureDisplaySynchronously(true)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: root.bounds.size, format: format).image { root.layer.render(in: $0.cgContext) }
        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(name + ".png"))
    }

    func testSingleDeletionKeepsWarningCancelAndDestructiveActionAndRejectsOldActions() throws {
        for dark in [false, true] {
            for choice in 0 ..< 3 {
                var commits = 0
                let data = defaultPresentationData().withUpdated(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme)
                let controller = wegramMessageDeletionConfirmationController(updatedPresentationData: (initial: data, signal: .never()), title: "Delete paid message?", text: "Refund **10 stars** to the author.", actions: [.init(type: .destructiveAction, title: "Delete for Everyone", action: { commits += 1 })], parseMarkdown: true)
                let alert = try XCTUnwrap(controller as? AlertController)
                let root = self.layout(alert)
                let buttons = self.nodes(alert.contentNode).compactMap { $0 as? TextAlertContentActionNode }
                XCTAssertEqual(buttons.map { $0.action.title }, [data.strings.Common_Cancel, "Delete for Everyone"])
                let texts = self.nodes(alert.contentNode).compactMap { ($0 as? ImmediateTextNode)?.attributedText?.string }
                XCTAssertTrue(texts.contains("Delete paid message?"))
                XCTAssertTrue(texts.contains("Refund 10 stars to the author."))
                XCTAssertEqual(alert.theme.destructiveColor, UIColor(rgb: 0xfa5151))
                XCTAssertGreaterThanOrEqual(buttons[0].frame.height, 44)
                if choice == 0 { buttons[0].performAction() }
                else if choice == 1 { buttons[1].performAction() }
                else { alert.dismissAnimated() }
                buttons[0].performAction(); buttons[1].performAction()
                XCTAssertEqual(commits, choice == 1 ? 1 : 0)
                if choice == 0 { try self.save(root, name: "message-delete-single-\(dark ? "dark" : "light")") }
            }
        }
    }

    func testLocalAndGlobalChoicesRemainSeparateAndOnlyChosenHandlerRuns() throws {
        for dark in [false, true] {
            for choice in 0 ..< 4 {
                var calls = [0, 0]
                let data = defaultPresentationData().withUpdated(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme)
                let controller = wegramMessageDeletionConfirmationController(updatedPresentationData: (initial: data, signal: .never()), title: "Delete 2 messages?", text: "", actions: [
                    .init(type: .destructiveAction, title: "Delete for Everyone", action: { calls[0] += 1 }),
                    .init(type: .destructiveAction, title: "Delete for Me", action: { calls[1] += 1 })
                ])
                let sheet = try XCTUnwrap(controller as? ActionSheetController)
                let root = self.layout(sheet)
                XCTAssertTrue(sheet.theme.usesWegramLayout)
                let buttons = self.nodes(root).compactMap { $0 as? ActionSheetButtonNode }
                let areas = try buttons.map { try XCTUnwrap(self.nodes($0).compactMap { $0 as? AccessibilityAreaNode }.first) }
                XCTAssertEqual(areas.map { $0.accessibilityLabel }, ["Delete for Everyone", "Delete for Me", data.strings.Common_Cancel])
                let explanation = try XCTUnwrap(self.nodes(root).compactMap { $0 as? ActionSheetTextNode }.first)
                XCTAssertEqual(self.nodes(explanation).compactMap { ($0 as? ImmediateTextNode)?.attributedText?.string }, ["Delete 2 messages?"])
                XCTAssertEqual(self.nodes(root).filter { String(describing: type(of: $0)) == "ActionSheetItemGroupNode" }.count, 2)
                if choice == 0 { try self.save(root, name: "message-delete-choices-\(dark ? "dark" : "light")") }
                if choice < 3 { _ = areas[choice].accessibilityActivate() }
                else { sheet.dismissAnimated() }
                for area in areas { _ = area.accessibilityActivate() }
                XCTAssertEqual(calls, choice == 0 ? [1, 0] : choice == 1 ? [0, 1] : [0, 0])
            }
        }
    }

    func testEmptyExplanationAddsNoBlankHeader() {
        let data = defaultPresentationData()
        let controller = wegramConfirmationController(updatedPresentationData: (initial: data, signal: .never()), title: "", text: "", cancelTitle: "Cancel", actions: [(title: "Delete", action: {})])
        XCTAssertTrue(self.nodes(self.layout(controller)).compactMap { $0 as? ActionSheetTextNode }.isEmpty)
    }

    func testWegramUnsendSwitchWrapsLargeLabelsAndUpdatesVoiceOverState() throws {
        var values: [Bool] = []
        let data = defaultPresentationData().withUpdate(listsFontSize: .extraLargeX2)
        let theme = ActionSheetControllerTheme(wegramTheme: data.theme, fontSize: data.listsFontSize)
        let item = ActionSheetSwitchItem(title: "Also delete all of my messages for the other participant", isOn: false, action: { values.append($0) })
        let node = item.node(theme: theme)
        _ = node.view
        let size = node.updateLayout(constrainedSize: CGSize(width: 240, height: 1000), transition: .immediate)
        node.frame = CGRect(origin: .zero, size: size)
        let label = try XCTUnwrap(self.nodes(node).compactMap { $0 as? ImmediateTextNode }.first)
        let area = try XCTUnwrap(self.nodes(node).compactMap { $0 as? AccessibilityAreaNode }.first)
        func views(_ view: UIView) -> [UIView] { return [view] + view.subviews.flatMap(views) }
        let toggle = try XCTUnwrap(views(node.view).compactMap { $0 as? UISwitch }.first)
        let toggleFrame = toggle.convert(toggle.bounds, to: node.view)
        XCTAssertEqual(label.maximumNumberOfLines, 0)
        XCTAssertGreaterThan(size.height, 56)
        XCTAssertLessThanOrEqual(label.frame.maxX, toggleFrame.minX - 12)
        XCTAssertLessThanOrEqual(label.frame.maxY, size.height - 12)
        XCTAssertFalse(area.accessibilityTraits.contains(.selected))
        _ = area.accessibilityActivate()
        XCTAssertTrue(area.accessibilityTraits.contains(.selected))
        _ = area.accessibilityActivate()
        XCTAssertFalse(area.accessibilityTraits.contains(.selected))
        toggle.setOn(true, animated: false)
        let target = try XCTUnwrap(toggle.allTargets.first as? NSObject)
        let selector = try XCTUnwrap(toggle.actions(forTarget: target, forControlEvent: .valueChanged)?.first)
        _ = target.perform(NSSelectorFromString(selector), with: toggle)
        XCTAssertTrue(area.accessibilityTraits.contains(.selected))
        XCTAssertEqual(values, [true, false, true])
        let original = item.node(theme: ActionSheetControllerTheme(presentationData: data))
        let originalSize = original.updateLayout(constrainedSize: CGSize(width: 240, height: 1000), transition: .immediate)
        XCTAssertEqual(originalSize.height, 57)
        XCTAssertEqual(self.nodes(original).compactMap { $0 as? ImmediateTextNode }.first?.maximumNumberOfLines, 1)
    }
}
