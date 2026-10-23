import XCTest
import UIKit
import Display
import SearchUI
import SearchBarNode
import TelegramPresentationData
import AsyncDisplayKit
import AppBundle
import ObjectiveC

final class WegramSearchFieldTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        exchangeResourceLookups()
    }

    override class func tearDown() {
        exchangeResourceLookups()
        super.tearDown()
    }

    // Use the existing unhosted-test resource pattern without changing app bundle lookup.
    class func exchangeResourceLookups() {
        for (original, replacement) in [
            (#selector(Bundle.path(forResource:ofType:)), #selector(Bundle.wegramResourcePath(_:ofType:))),
            (#selector(Bundle.path(forResource:ofType:inDirectory:forLocalization:)), #selector(Bundle.wegramLocalizedResourcePath(_:ofType:inDirectory:forLocalization:)))
        ] {
            method_exchangeImplementations(class_getInstanceMethod(Bundle.self, original)!, class_getInstanceMethod(Bundle.self, replacement)!)
        }
    }

    private func activeBar() -> SearchBarNode {
        let bar = SearchBarNode(theme: SearchBarNodeTheme(theme: defaultPresentationTheme), presentationTheme: defaultPresentationTheme, strings: defaultPresentationStrings, fieldStyle: .glass, usesWegramAppearance: true)
        bar.frame = CGRect(x: 0, y: 0, width: 402, height: 52)
        bar.updateLayout(boundingSize: bar.bounds.size, leftInset: 0, rightInset: 0, transition: .immediate)
        return bar
    }

    private func control(_ id: String, in bar: SearchBarNode) throws -> ASControlNode {
        return try XCTUnwrap(bar.subnodes?.first { $0.accessibilityIdentifier == id } as? ASControlNode)
    }

    func testActiveSearchControlsDoNotOverlapAndInvokeTheOriginalCallbacks() throws {
        let bar = self.activeBar()
        let query = try XCTUnwrap(bar.view.subviews.compactMap { $0 as? UITextField }.first)
        let cancel = try self.control("Wegram.Search.Cancel", in: bar)
        let clear = try self.control("Wegram.Search.Clear", in: bar)
        XCTAssertTrue(cancel.accessibilityTraits.contains(.button))
        XCTAssertTrue(clear.accessibilityTraits.contains(.button))
        XCTAssertEqual(query.frame.height, 36)
        XCTAssertEqual(cancel.frame.height, 44)
        XCTAssertGreaterThanOrEqual(cancel.frame.width, 44)
        XCTAssertLessThanOrEqual(query.frame.maxX, clear.frame.minX)
        XCTAssertLessThan(clear.frame.maxX, cancel.frame.minX)
        XCTAssertNotNil(cancel.view.hitTest(cancel.bounds.center, with: nil))
        var queries: [String] = []
        var cancels = 0
        var clearedPrefixes = 0
        bar.textUpdated = { text, _ in queries.append(text) }
        bar.cancel = { cancels += 1 }
        bar.clearPrefix = { clearedPrefixes += 1 }
        bar.text = "test query"
        XCTAssertNotNil(clear.view.hitTest(CGPoint(x: -3, y: 18), with: nil), "The clear control must provide a 44pt touch target around its 36pt field")
        clear.sendActions(forControlEvents: .touchUpInside, with: nil)
        XCTAssertEqual(queries, ["test query", ""])
        bar.prefixString = NSAttributedString(string: "from:")
        clear.sendActions(forControlEvents: .touchUpInside, with: nil)
        XCTAssertEqual(clearedPrefixes, 1)
        cancel.sendActions(forControlEvents: .touchUpInside, with: nil)
        XCTAssertEqual(cancels, 1)
    }

    func testActiveSearchThemeAndSafeInsetsKeepTheQueryAndControls() throws {
        let bar = self.activeBar()
        bar.text = "preserve me"
        bar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: defaultDarkPresentationTheme), presentationTheme: defaultDarkPresentationTheme, strings: defaultPresentationStrings)
        bar.updateLayout(boundingSize: bar.bounds.size, leftInset: 24, rightInset: 8, transition: .immediate)
        let query = try XCTUnwrap(bar.view.subviews.compactMap { $0 as? UITextField }.first)
        let cancel = try self.control("Wegram.Search.Cancel", in: bar)
        XCTAssertEqual(bar.text, "preserve me")
        XCTAssertEqual(bar.backgroundColor, UIColor(rgb: 0x111111))
        XCTAssertEqual(query.tintColor, UIColor(rgb: 0x07c160))
        XCTAssertGreaterThan(query.frame.minX, 24)
        XCTAssertLessThanOrEqual(cancel.frame.maxX, 402 - 8)
        let originalWidth = query.frame.width
        bar.hasCancelButton = false
        XCTAssertTrue(cancel.isHidden)
        XCTAssertGreaterThan(query.frame.width, originalWidth)
    }

    func testEmbeddedSearchKeepsItsOwnPaletteQueryAndOriginalControlsAcrossThemes() throws {
        let bar = SearchBarNode(theme: SearchBarNodeTheme(theme: defaultPresentationTheme), presentationTheme: defaultPresentationTheme, strings: defaultPresentationStrings, usesWegramAppearance: true, wegramContentBackground: true)
        bar.frame = CGRect(x: 0, y: 0, width: 402, height: 56)
        bar.hasCancelButton = false
        bar.updateLayout(boundingSize: bar.bounds.size, leftInset: 24, rightInset: 8, transition: .immediate)
        let query = try XCTUnwrap(bar.view.subviews.compactMap { $0 as? UITextField }.first)
        let field = try XCTUnwrap(bar.subnodes?.first { $0.frame.height == 36 && $0.cornerRadius == 5 })
        let cancel = try self.control("Wegram.Search.Cancel", in: bar)
        let clear = try self.control("Wegram.Search.Clear", in: bar)
        XCTAssertEqual(bar.backgroundColor, UIColor(rgb: 0xffffff))
        XCTAssertEqual(field.backgroundColor, UIColor(rgb: 0xededed))
        XCTAssertTrue(cancel.isHidden)
        XCTAssertGreaterThanOrEqual(field.frame.minX, 24)
        XCTAssertLessThanOrEqual(field.frame.maxX, 402 - 8)
        let idleWidth = field.frame.width
        var queries: [String] = []
        var cancels = 0
        var focus: [Bool] = []
        bar.textUpdated = { text, _ in queries.append(text) }
        bar.cancel = { cancels += 1 }
        bar.focusUpdated = { focus.append($0) }
        bar.text = "巨鹿路🗺️"
        bar.hasCancelButton = true
        XCTAssertLessThan(field.frame.width, idleWidth)
        XCTAssertLessThanOrEqual(query.frame.maxX, clear.frame.minX)
        XCTAssertLessThan(clear.frame.maxX, cancel.frame.minX)
        bar.activity = true
        bar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: defaultDarkPresentationTheme), presentationTheme: defaultDarkPresentationTheme, strings: defaultPresentationStrings)
        XCTAssertEqual(bar.backgroundColor, UIColor(rgb: 0x191919))
        XCTAssertEqual(field.backgroundColor, UIColor(rgb: 0x232323))
        XCTAssertEqual(bar.text, "巨鹿路🗺️")
        XCTAssertTrue(bar.activity)
        bar.textFieldDidBeginEditing(query)
        bar.textFieldDidEndEditing(query)
        XCTAssertEqual(focus, [true, false])
        clear.sendActions(forControlEvents: .touchUpInside, with: nil)
        cancel.sendActions(forControlEvents: .touchUpInside, with: nil)
        XCTAssertEqual(queries, ["巨鹿路🗺️", ""])
        XCTAssertEqual(cancels, 1)
        bar.activity = false
        bar.hasCancelButton = false
        XCTAssertEqual(field.frame.width, idleWidth)
    }

    func testActiveSearchExitRestoresTheSourceAndCompletesWithoutChangingTheQuery() {
        let bar = self.activeBar()
        let source = NavigationBarSearchContentNode(theme: defaultPresentationTheme, placeholder: "Search", usesWegramAppearance: true, activate: {})
        self.layout(source)
        bar.text = "keep draft"
        bar.animateIn(from: source.placeholderNode, duration: 0.2, timingFunction: "easeInEaseOut")
        XCTAssertTrue(source.placeholderNode.isHidden)
        var completions = 0
        bar.transitionOut(to: source.placeholderNode, transition: .immediate, completion: { completions += 1 })
        XCTAssertFalse(source.placeholderNode.isHidden)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(bar.text, "keep draft")
    }

    func testSearchDisplayHandoffPreservesBarContentBoundaryQueryAndCancel() throws {
        for status: CGFloat in [0, 59] {
            let content = WegramSearchContentProbe()
            var cancels = 0
            let controller = SearchDisplayController(presentationData: defaultPresentationData(), contentNode: content, cancel: { cancels += 1 }, fieldStyle: .glass, usesWegramAppearance: true)
            let layout = ContainerViewLayout(size: CGSize(width: 402, height: 874), metrics: LayoutMetrics(), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 8), additionalInsets: .zero, statusBarHeight: status, inputHeight: 285, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
            controller.containerLayoutUpdated(layout, navigationBarHeight: status + 60, transition: .immediate)
            let host = ASDisplayNode()
            var bar: SearchBarNode?
            controller.activate(insertSubnode: { node, isBar in
                host.addSubnode(node)
                if isBar { bar = node as? SearchBarNode }
            }, placeholder: nil, focus: false)
            let active = try XCTUnwrap(bar)
            XCTAssertEqual(active.bounds.height, 52)
            XCTAssertEqual(content.navigationHeight, status + 52)
            controller.containerLayoutUpdated(layout, navigationBarHeight: status + 60, transition: .immediate)
            XCTAssertEqual(content.navigationHeight, status + 52)
            XCTAssertEqual(content.latestLayout?.inputHeight, 285)
            XCTAssertEqual(content.latestLayout?.safeInsets.left, 24)
            active.text = "群成员"
            XCTAssertEqual(content.queries.last, "群成员")
            let cancel = try self.control("Wegram.Search.Cancel", in: active)
            cancel.sendActions(forControlEvents: .touchUpInside, with: nil)
            XCTAssertEqual(cancels, 1)
            controller.deactivate(placeholder: nil, animated: false)
        }
    }

    private func background(in view: UIView) -> UIImageView? {
        if let image = view as? UIImageView, image.bounds.width > 300 { return image }
        for child in view.subviews {
            if let image = self.background(in: child) { return image }
        }
        return nil
    }

    private func layout(_ node: NavigationBarSearchContentNode, left: CGFloat = 0, right: CGFloat = 0) {
        node.frame = CGRect(x: 0, y: 0, width: 402, height: 60)
        _ = node.updateLayout(size: node.bounds.size, leftInset: left, rightInset: right, transition: .immediate)
    }

    func testRootSearchFieldUsesTheReferenceFrameAndSquareCorners() throws {
        let node = NavigationBarSearchContentNode(theme: defaultPresentationTheme, placeholder: "搜索", usesWegramAppearance: true, activate: {})
        self.layout(node)
        XCTAssertEqual(node.placeholderNode.frame, CGRect(x: 8, y: 16, width: 386, height: 36))
        let background = try XCTUnwrap(self.background(in: node.placeholderNode.view))
        XCTAssertEqual(background.layer.cornerRadius, 5)
        XCTAssertEqual(background.backgroundColor, UIColor(rgb: 0xffffff))
        XCTAssertEqual(node.placeholderNode.accessibilityLabel, "搜索")
        XCTAssertTrue(node.placeholderNode.accessibilityTraits.contains(.searchField))
        XCTAssertEqual(node.placeholderNode.fieldStyle, .glass)
    }

    func testSafeInsetsThemeChangesAndCollapsedFieldRestore() throws {
        let node = NavigationBarSearchContentNode(theme: defaultPresentationTheme, placeholder: "搜索", usesWegramAppearance: true, activate: {})
        self.layout(node, left: 24, right: 8)
        XCTAssertEqual(node.placeholderNode.frame, CGRect(x: 32, y: 16, width: 354, height: 36))
        node.updateThemeAndPlaceholder(theme: defaultDarkPresentationTheme, placeholder: "Search")
        let background = try XCTUnwrap(self.background(in: node.placeholderNode.view))
        XCTAssertEqual(background.backgroundColor, UIColor(rgb: 0x191919))
        XCTAssertEqual(node.placeholderNode.accessibilityLabel, "Search")
        node.expansionProgress = 0
        self.layout(node)
        XCTAssertEqual(background.bounds.height, 0)
        node.expansionProgress = 1
        self.layout(node)
        XCTAssertEqual(background.bounds.height, 36)
        XCTAssertEqual(background.layer.cornerRadius, 5)
    }

    func testTransferredPlaceholderKeepsAVisibleActiveSearchBackground() {
        let node = NavigationBarSearchContentNode(theme: defaultPresentationTheme, placeholder: "Search", hasOwnGlassContainer: false, usesWegramAppearance: true, activate: {})
        self.layout(node)
        let content = node.placeholderNode.takeContents()
        content.update(size: CGSize(width: 370, height: 44), isActive: true, additionalPlaceholderInset: 0, transition: .immediate)
        XCTAssertGreaterThan(node.placeholderNode.backgroundView.alpha, 0.9, "The original search handoff must retain its active background and controls")
    }

    func testWegramSearchPlaceholderSupportsVoiceOverAndRejectsDisabledAncestors() {
        var calls = 0
        let node = NavigationBarSearchContentNode(theme: defaultPresentationTheme, placeholder: "搜索", usesWegramAppearance: true, activate: { calls += 1 })
        self.layout(node)
        _ = node.view
        XCTAssertTrue(node.placeholderNode.view.superview === node.view)
        XCTAssertTrue(node.placeholderNode.view.accessibilityActivate())
        XCTAssertEqual(calls, 1)
        node.setIsEnabled(false)
        XCTAssertFalse(node.placeholderNode.view.accessibilityActivate())
        XCTAssertEqual(calls, 1)
        node.setIsEnabled(true)
        node.isUserInteractionEnabled = false
        XCTAssertFalse(node.placeholderNode.view.accessibilityActivate())
        XCTAssertEqual(calls, 1)
        node.isUserInteractionEnabled = true
        XCTAssertTrue(node.placeholderNode.view.accessibilityActivate())
        XCTAssertEqual(calls, 2)
        node.placeholderNode.activate = { calls += 10 }
        XCTAssertTrue(node.placeholderNode.view.accessibilityActivate())
        XCTAssertEqual(calls, 12, "VoiceOver must invoke the current original activation callback")
    }

    func testCollapsedWegramSearchRejectsTouchesAndVoiceOverAndRestoresAvailability() {
        var calls = 0
        let node = NavigationBarSearchContentNode(theme: defaultPresentationTheme, placeholder: "搜索", usesWegramAppearance: true, activate: { calls += 1 })
        self.layout(node)
        _ = node.view
        node.expansionProgress = 0
        self.layout(node)
        XCTAssertFalse(node.placeholderNode.isAccessibilityElement)
        XCTAssertFalse(node.placeholderNode.isUserInteractionEnabled)
        XCTAssertNil(node.placeholderNode.view.hitTest(CGPoint(x: 20, y: 18), with: nil), "The invisible search field must not steal a list touch")
        XCTAssertFalse(node.placeholderNode.view.accessibilityActivate())
        XCTAssertEqual(calls, 0)
        node.setIsEnabled(false)
        node.expansionProgress = 1
        self.layout(node, left: 24, right: 8)
        XCTAssertFalse(node.placeholderNode.isUserInteractionEnabled, "Layout changes must not re-enable a disabled search field")
        XCTAssertTrue(node.placeholderNode.accessibilityTraits.contains(.notEnabled))
        XCTAssertFalse(node.placeholderNode.view.accessibilityActivate())
        node.setIsEnabled(true)
        XCTAssertTrue(node.placeholderNode.isAccessibilityElement)
        XCTAssertTrue(node.placeholderNode.isUserInteractionEnabled)
        XCTAssertFalse(node.placeholderNode.accessibilityTraits.contains(.notEnabled))
        XCTAssertTrue(node.placeholderNode.view.accessibilityActivate())
        XCTAssertEqual(calls, 1)
        node.expansionProgress = 0
        self.layout(node)
        node.setIsEnabled(true)
        XCTAssertFalse(node.placeholderNode.isUserInteractionEnabled, "Enabling the search API must not expose a fully collapsed field")
    }

    func testOtherSearchCallersKeepTheOriginalFieldDimensionsAndGlassStyle() {
        let node = NavigationBarSearchContentNode(theme: defaultPresentationTheme, placeholder: "Search", activate: {})
        self.layout(node)
        XCTAssertEqual(node.placeholderNode.frame, CGRect(x: 16, y: 8, width: 370, height: 44))
        XCTAssertEqual(node.placeholderNode.fieldStyle, .glass)
        XCTAssertTrue(node.hasOwnGlassContainer)
    }
}

private extension Bundle {
    @objc func wegramResourcePath(_ name: String?, ofType type: String?) -> String? {
        if ((name == "PresentationStrings" && type == "data") || (name == "en" && type == "lproj")), self == getAppBundle() {
            return Bundle(for: WegramSearchFieldTests.self).wegramResourcePath(name, ofType: type)
        }
        return self.wegramResourcePath(name, ofType: type)
    }

    @objc func wegramLocalizedResourcePath(_ name: String?, ofType type: String?, inDirectory directory: String?, forLocalization localization: String?) -> String? {
        if name == "Localizable", type == "strings", self == getAppBundle() {
            return Bundle(for: WegramSearchFieldTests.self).wegramLocalizedResourcePath(name, ofType: type, inDirectory: directory, forLocalization: localization)
        }
        return self.wegramLocalizedResourcePath(name, ofType: type, inDirectory: directory, forLocalization: localization)
    }
}

private final class WegramSearchContentProbe: SearchDisplayControllerContentNode {
    var navigationHeight: CGFloat = 0
    var latestLayout: ContainerViewLayout?
    var queries: [String] = []
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.latestLayout = layout
        self.navigationHeight = navigationBarHeight
    }
    override func searchTextUpdated(text: String) { self.queries.append(text) }
}
