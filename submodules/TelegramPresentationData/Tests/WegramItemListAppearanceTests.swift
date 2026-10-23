import XCTest
import UIKit
import ObjectiveC
import AppBundle
import AsyncDisplayKit
import Display
import ItemListUI
import NavigationBarImpl
import SwiftSignalKit
import TelegramPresentationData

final class WegramItemListAppearanceTests: XCTestCase {
    private struct Entry: ItemListNodeEntry {
        let title: String
        var section: ItemListSectionId { 0 }
        var stableId: Int { 0 }
        static func < (lhs: Entry, rhs: Entry) -> Bool { false }
        func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
            ItemListDisclosureItem(presentationData: presentationData, systemStyle: .legacy, title: self.title, label: "", sectionId: 0, style: .plain, action: arguments as? () -> Void)
        }
    }
    override class func setUp() {
        super.setUp()
        self.exchangeResourceLookups()
    }
    override class func tearDown() {
        self.exchangeResourceLookups()
        super.tearDown()
    }
    private class func exchangeResourceLookups() {
        for (original, replacement) in [
            (#selector(Bundle.path(forResource:ofType:)), #selector(Bundle.wegramItemListResourcePath(_:ofType:))),
            (#selector(Bundle.path(forResource:ofType:inDirectory:forLocalization:)), #selector(Bundle.wegramItemListLocalizedResourcePath(_:ofType:inDirectory:forLocalization:)))
        ] {
            method_exchangeImplementations(class_getInstanceMethod(Bundle.self, original)!, class_getInstanceMethod(Bundle.self, replacement)!)
        }
    }
    func testActualListKeepsFlatNavigationFullWidthAndActionsAcrossThemeAndWidthChanges() throws {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "app.wegram.qrtesthost")
        let previousFactory = defaultNavigationBarImpl
        defaultNavigationBarImpl = { NavigationBarImpl(presentationData: $0) }
        defer { defaultNavigationBarImpl = previousFactory }
        for wegram in [false, true] {
            let data = ItemListPresentationData(defaultPresentationData())
            let state = Promise<(ItemListControllerState, (ItemListNodeState, () -> Void))>()
            var selected = 0
            let action: () -> Void = { selected += 1 }
            func update(dark: Bool, title: String) {
                let data = ItemListPresentationData(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme, fontSize: .regular, strings: defaultPresentationStrings, nameDisplayOrder: .firstLast, dateTimeFormat: PresentationDateTimeFormat())
                state.set(.single((ItemListControllerState(presentationData: data, title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: nil), (ItemListNodeState(presentationData: data, entries: [Entry(title: "Administrator")], style: .plain), action))))
            }
            update(dark: false, title: "群管理员")
            let controller = ItemListController(presentationData: data, updatedPresentationData: .never(), state: state.get(), tabBarItem: nil, usesWegramAppearance: wegram)
            controller.alwaysSynchronous = true
            let node = try XCTUnwrap(controller.displayNode as? ItemListControllerNode)
            _ = node.view
            for (width, dark, title) in [(CGFloat(402), false, "群管理员"), (CGFloat(720), true, "Administrators"), (CGFloat(320), false, "群管理员")] {
                update(dark: dark, title: title)
                let layout = ContainerViewLayout(size: CGSize(width: width, height: 874), metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 44, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
                controller.containerLayoutUpdated(layout, transition: .immediate)
                XCTAssertEqual(node.listNode.insets.left, wegram ? 0 : max(16, floor((width - 674) / 2)))
                XCTAssertEqual(node.listNode.insets.right, node.listNode.insets.left)
                if wegram {
                    let label = try XCTUnwrap(controller.navigationItem.titleView as? UILabel)
                    XCTAssertEqual(label.text, title)
                    XCTAssertEqual(label.font.pointSize, 17)
                    XCTAssertGreaterThan(label.frame.width, 0)
                    XCTAssertEqual(label.font.fontDescriptor.symbolicTraits.contains(.traitBold), false)
                    XCTAssertTrue(label.accessibilityTraits.contains(.header))
                    XCTAssertEqual(label.textColor, WegramNavigationColors(isDark: dark).control)
                    XCTAssertEqual(controller.navigationBar?.nominalHeight, 44)
                    let bar = try XCTUnwrap(controller.navigationBar as? NavigationBarImpl)
                    func nodes(_ node: ASDisplayNode) -> [ASDisplayNode] { [node] + (node.subnodes ?? []).flatMap(nodes) }
                    XCTAssertTrue(nodes(bar).filter { $0.accessibilityLabel == title && $0.alpha > 0 && !$0.isHidden }.isEmpty, "Only the custom 17pt title should be visible")
                    XCTAssertEqual(bar.backgroundNode.alpha, 1, "Flat navigation must be opaque when first loaded")
                    node.listNode.visibleContentOffsetChanged(.known(0), .immediate)
                    XCTAssertEqual(bar.backgroundNode.alpha, 1, "Scrolling to the top must not fade the flat navigation")
                    if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        node.frame = CGRect(origin: .zero, size: layout.size)
                        node.recursivelyEnsureDisplaySynchronously(true)
                        bar.recursivelyEnsureDisplaySynchronously(true)
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1
                        let image = UIGraphicsImageRenderer(size: layout.size, format: format).image { context in
                            node.layer.render(in: context.cgContext)
                            context.cgContext.translateBy(x: bar.frame.minX, y: bar.frame.minY)
                            bar.layer.render(in: context.cgContext)
                        }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("admin-list-foundation-\(Int(width))-\(dark ? "dark" : "light").png"))
                    }
                } else {
                    XCTAssertNil(controller.navigationItem.titleView)
                }
                let item = Entry(title: "Administrator").item(presentationData: data, arguments: action)
                item.selected(listView: node.listNode)
            }
            XCTAssertEqual(selected, 3)
        }
    }
}

private extension Bundle {
    @objc func wegramItemListResourcePath(_ name: String?, ofType type: String?) -> String? {
        if name == "PresentationStrings", type == "data", self == getAppBundle() {
            return Bundle(for: WegramItemListAppearanceTests.self).wegramItemListResourcePath(name, ofType: type)
        }
        return self.wegramItemListResourcePath(name, ofType: type)
    }
    @objc func wegramItemListLocalizedResourcePath(_ name: String?, ofType type: String?, inDirectory directory: String?, forLocalization localization: String?) -> String? {
        if name == "Localizable", type == "strings", self == getAppBundle() {
            return Bundle(for: WegramItemListAppearanceTests.self).wegramItemListLocalizedResourcePath(name, ofType: type, inDirectory: directory, forLocalization: localization)
        }
        return self.wegramItemListLocalizedResourcePath(name, ofType: type, inDirectory: directory, forLocalization: localization)
    }
}
