import XCTest
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SwiftSignalKit

final class WegramGroupSettingsMenuTests: XCTestCase {
    override class func setUp() { super.setUp(); WegramSearchFieldTests.exchangeResourceLookups() }
    override class func tearDown() { WegramSearchFieldTests.exchangeResourceLookups(); super.tearDown() }
    private func nodes(_ node: ASDisplayNode) -> [ASDisplayNode] { [node] + (node.subnodes ?? []).flatMap(self.nodes) }
    private func layout(_ controller: ActionSheetController) -> [AccessibilityAreaNode] {
        let root = controller.displayNode
        _ = root.view
        root.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.containerLayoutUpdated(ContainerViewLayout(size: root.bounds.size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), transition: .immediate)
        return self.nodes(root).compactMap { $0 as? ActionSheetButtonNode }.flatMap { self.nodes($0).compactMap { $0 as? AccessibilityAreaNode } }
    }

    func testActualMenuOnlyOffersTheAvailableGroupCapabilitiesAndKeepsFullDetails() {
        let data = defaultPresentationData()
        for canCall in [false, true] {
            for appearance in [false, true] {
                let sheet = wegramGroupSettingsMenu(updatedPresentationData: (initial: data, signal: .never()), canCall: canCall, canChangeAppearance: appearance, selected: { _ in XCTFail("Rendering a menu must not invoke a group action") })
                let areas = self.layout(sheet)
                var titles: [String] = []
                if canCall { titles.append("Group Call") }
                if appearance { titles.append("Group Appearance and Wallpaper") }
                titles += ["Full Group Info", data.strings.Common_Cancel]
                XCTAssertEqual(areas.map { $0.accessibilityLabel ?? "" }, titles)
                XCTAssertTrue(sheet.theme.usesWegramLayout)
                XCTAssertEqual(self.nodes(sheet.displayNode).compactMap { $0 as? ActionSheetTextNode }.isEmpty, !appearance, "The shared group-appearance warning only belongs to an available appearance action")
                XCTAssertEqual(self.nodes(sheet.displayNode).filter { String(describing: type(of: $0)) == "ActionSheetItemGroupNode" }.count, 2)
            }
        }
    }

    func testEachActualActionCancelAndOutsideDismissalConsumesTheMenuOnce() throws {
        for dark in [false, true] {
            for choice in 0..<5 {
                var selected: [WegramGroupSettingsAction] = []
                let data = defaultPresentationData().withUpdated(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme)
                let sheet = wegramGroupSettingsMenu(updatedPresentationData: (initial: data, signal: .never()), canCall: true, canChangeAppearance: true, selected: { selected.append($0) })
                let areas = self.layout(sheet)
                XCTAssertEqual(areas.count, 4)
                if choice == 0, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let root = sheet.displayNode
                    root.recursivelyEnsureDisplaySynchronously(true)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    let image = UIGraphicsImageRenderer(size: root.bounds.size, format: format).image { root.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("group-settings-menu-\(dark ? "dark" : "light").png"))
                }
                if choice < areas.count { _ = areas[choice].accessibilityActivate() }
                else { sheet.dismissAnimated() }
                for area in areas { _ = area.accessibilityActivate() }
                let actions: [WegramGroupSettingsAction] = [.call, .appearance, .fullDetails]
                XCTAssertEqual(selected, choice < 3 ? [actions[choice]] : [])
            }
        }
    }
}
