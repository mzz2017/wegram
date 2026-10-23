import XCTest
import UIKit
import AsyncDisplayKit
import Display
import ContextUI
import ContextControllerImpl
import TelegramPresentationData
import SwiftSignalKit

private final class MenuControllerRecorder: ViewController, ContextControllerProtocol {
    var useComplexItemsTransitionAnimation = false
    var immediateItemsTransitionAnimation = false
    var getOverlayViews: (() -> [UIView])?
    var latest: ContextController.Items?
    var dismissResults: [ContextMenuActionResult] = []
    var disposable: Disposable?
    init() { super.init(navigationBarPresentationData: nil) }
    deinit { self.disposable?.dispose() }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func dismiss(completion: (() -> Void)?) { completion?() }
    func dismiss(result: ContextMenuActionResult, completion: (() -> Void)?) { self.dismissResults.append(result); completion?() }
    func getActionsMinHeight() -> ContextController.ActionsHeight? { return nil }
    func setItems(_ items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?, animated: Bool) {
        self.disposable?.dispose()
        self.disposable = items.start(next: { [weak self] items in self?.latest = items })
    }
    func setItems(_ items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?, previousActionsTransition: ContextController.PreviousActionsTransition) { self.setItems(items, minHeight: minHeight, animated: false) }
    func pushItems(items: Signal<ContextController.Items, NoError>) { XCTFail("Asynchronous metadata must replace, not push, the More menu") }
    func popItems() { XCTFail("Back must restore the root signal") }
}

private final class MenuLocationSource: ContextLocationContentSource {
    func transitionInfo() -> ContextControllerLocationViewInfo? {
        return ContextControllerLocationViewInfo(location: CGPoint(x: 160, y: 20), contentAreaInScreenSpace: CGRect(x: 0, y: 0, width: 402, height: 300))
    }
}

final class WegramMessageMenuTests: XCTestCase {
    override class func setUp() { super.setUp(); WegramSearchFieldTests.exchangeResourceLookups() }
    override class func tearDown() { WegramSearchFieldTests.exchangeResourceLookups(); super.tearDown() }

    private func data(dark: Bool = false) -> PresentationData {
        let data = defaultPresentationData().withUpdated(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme)
        let strings = PresentationStrings(primaryComponent: .init(languageCode: "zh-hans", localizedName: "简体中文", pluralizationRulesCode: nil, dict: [:]), secondaryComponent: nil, groupingSeparator: ",")
        return PresentationData(strings: strings, theme: data.theme, autoNightModeTriggered: data.autoNightModeTriggered, chatWallpaper: data.chatWallpaper, chatFontSize: data.chatFontSize, chatBubbleCorners: data.chatBubbleCorners, listsFontSize: data.listsFontSize, dateTimeFormat: data.dateTimeFormat, nameDisplayOrder: data.nameDisplayOrder, nameSortOrder: data.nameSortOrder, reduceMotion: data.reduceMotion, largeEmoji: data.largeEmoji)
    }
    private func buttons(_ node: ASDisplayNode) -> [UIButton] { return node.view.subviews.compactMap { $0 as? UIButton } }
    private func node(_ content: ContextControllerItemsContent, data: PresentationData, width: CGFloat = 320, height: CGFloat = 500) -> ContextControllerItemsNode {
        let node = content.node(requestUpdate: { _ in }, requestUpdateApparentHeight: { _ in })
        let size = node.update(presentationData: data, constrainedWidth: width, maxHeight: height, bottomInset: 0, transition: .immediate).cleanSize
        node.frame = CGRect(origin: .zero, size: size)
        node.view.layoutIfNeeded()
        return node
    }
    private func node(_ menu: WegramMessageMenu) throws -> ContextControllerItemsNode {
        guard case let .custom(content) = menu.items.content else { throw NSError(domain: "Expected grid", code: 0) }
        return self.node(content, data: self.data())
    }
    private func action(_ kind: WegramMessageMenuAction, title: String? = nil, perform: @escaping (ContextMenuActionItem.Action) -> Void = { _ in }) -> ContextMenuActionItem {
        return ContextMenuActionItem(id: kind.identifier, text: title ?? kind.rawValue, icon: { _ in nil }, action: perform)
    }

    func testFiveColumnGridUsesRealButtonsAndAdaptsToLargeTextAndLimitedHeight() throws {
        let titles = ["转发", "收藏", "编辑", "删除", "多选", "引用", "提醒", "更多"]
        for dark in [false, true] {
            let content = WegramMessageMenuContent(items: titles.map { .init(title: $0, symbol: "star") }, isActive: { true }, action: { _ in })
            let node = self.node(content, data: self.data(dark: dark))
            let buttons = self.buttons(node)
            XCTAssertEqual(buttons.map { $0.accessibilityLabel }, titles)
            XCTAssertEqual(node.bounds.size, CGSize(width: 320, height: 136))
            XCTAssertEqual(buttons[4].frame.minY, buttons[0].frame.minY)
            XCTAssertGreaterThan(buttons[5].frame.minY, buttons[4].frame.minY)
            XCTAssertTrue(buttons.allSatisfy { $0.frame.width >= 44 && $0.frame.height >= 44 && $0.image(for: .normal) != nil })
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                let labels = ["复制", "转发", "编辑", "删除", "多选", "引用"]
                let actions = zip(WegramMessageMenuAction.allCases, labels).map { ContextMenuItem.action(self.action($0.0, title: $0.1)) }
                let original = ContextController.Items(content: .list(actions))
                let menu = try XCTUnwrap(WegramMessageMenu(items: original, itemsSignal: .single(original), presentationData: self.data(dark: dark), save: {}))
                let preview = try self.node(menu)
                XCTAssertEqual(self.buttons(preview).map { $0.accessibilityLabel }, ["复制", "转发", "收藏", "编辑", "删除", "多选", "引用", "更多"])
                let format = UIGraphicsImageRendererFormat(); format.scale = 2
                let image = UIGraphicsImageRenderer(size: preview.bounds.size, format: format).image { preview.view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("message-menu-\(dark ? "dark" : "light").png"))
            }
        }
        let content = WegramMessageMenuContent(items: ["A very long localized menu label", "删除", "引用", "更多"].map { .init(title: $0, symbol: "star") }, isActive: { true }, action: { _ in })
        let node = self.node(content, data: self.data().withUpdate(listsFontSize: .extraLargeX2), width: 240, height: 80)
        let scroll = try XCTUnwrap(node.view as? UIScrollView)
        XCTAssertEqual(node.bounds.height, 80)
        XCTAssertTrue(scroll.isScrollEnabled)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        XCTAssertTrue(self.buttons(node).allSatisfy { $0.frame.maxX <= 240 && $0.frame.height >= 64 })
    }

    func testDragCancelOutsideAndKeyboardSelectionInvokeOnlyTheChosenEntry() throws {
        var calls: [Int] = []
        var active = true
        let content = WegramMessageMenuContent(items: (0 ..< 8).map { .init(title: "Action \($0)", symbol: "star") }, isActive: { active }, action: { calls.append($0) })
        let node = self.node(content, data: self.data())
        let buttons = self.buttons(node)
        XCTAssertTrue(node.highlightGestureShouldBegin(location: CGPoint(x: 10, y: 10)))
        node.highlightGestureMoved(location: buttons[6].frame.center)
        node.highlightGestureFinished(performAction: false)
        XCTAssertEqual(calls, [])
        node.highlightGestureMoved(location: buttons[2].frame.center)
        node.highlightGestureMoved(location: CGPoint(x: -1, y: 20))
        node.highlightGestureFinished(performAction: true)
        XCTAssertEqual(calls, [])
        node.highlightGestureMoved(location: buttons[6].frame.center)
        node.highlightGestureFinished(performAction: true)
        node.highlightGestureFinished(performAction: true)
        XCTAssertEqual(calls, [6])
        node.increaseHighlightedIndex(); node.increaseHighlightedIndex(); node.decreaseHighlightedIndex()
        node.highlightGestureFinished(performAction: true)
        XCTAssertEqual(calls, [6, 0])
        _ = buttons[3].accessibilityActivate()
        XCTAssertEqual(calls, [6, 0, 3])
        active = false
        _ = buttons[3].accessibilityActivate()
        node.increaseHighlightedIndex(); node.highlightGestureFinished(performAction: true)
        XCTAssertFalse(node.highlightGestureShouldBegin(location: .zero))
        XCTAssertEqual(calls, [6, 0, 3])
    }

    func testRealCustomWrapperKeepsScrolledTopRowSelectable() throws {
        var selected: [Int] = []
        let content = WegramMessageMenuContent(items: (0 ..< 40).map { .init(title: "Item \($0)", symbol: "star") }, isActive: { true }, action: { selected.append($0) })
        let controller = ContextControllerImpl(presentationData: self.data(), configuration: .init(sources: [.init(id: 0, title: "", source: .location(MenuLocationSource()), items: .single(.init(content: .custom(content))))], initialId: 0))
        let root = controller.displayNode
        _ = root.view
        root.frame = CGRect(x: 0, y: 0, width: 402, height: 300)
        let ready = self.expectation(description: "Real menu items loaded")
        let readiness = (controller.ready.get() |> filter { $0 } |> take(1)).start(next: { _ in ready.fulfill() })
        defer { readiness.dispose() }
        self.wait(for: [ready], timeout: 3)
        controller.containerLayoutUpdated(ContainerViewLayout(size: root.bounds.size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: .zero, safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 0, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false), transition: .immediate)
        func descendants(_ node: ASDisplayNode) -> [ASDisplayNode] { return [node] + (node.subnodes ?? []).flatMap(descendants) }
        func views(_ view: UIView) -> [UIView] { return [view] + view.subviews.flatMap(views) }
        // The production stack mounts ItemContainer.view directly in its glass content UIView.
        let candidates = views(root.view).compactMap { $0.asyncdisplaykit_node as? ContextControllerActionsStackItemNode }
        let wrapper = try XCTUnwrap(candidates.first { candidate in
            descendants(candidate).contains { ($0.view as? UIScrollView)?.subviews.compactMap { $0 as? UIButton }.count == 40 }
        })
        let grid = try XCTUnwrap(descendants(wrapper).first { ($0.view as? UIScrollView)?.subviews.compactMap { $0 as? UIButton }.count == 40 })
        let scroll = try XCTUnwrap(grid.view as? UIScrollView)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        scroll.contentOffset = CGPoint(x: 0, y: 64)
        let button = try XCTUnwrap(self.buttons(grid).dropFirst(5).first)
        let viewportPoint = CGPoint(x: button.frame.midX, y: button.frame.midY - scroll.contentOffset.y)
        XCTAssertGreaterThan(viewportPoint.y, 0)
        XCTAssertLessThan(viewportPoint.y, scroll.bounds.height)
        XCTAssertTrue(wrapper.highlightGestureShouldBegin(location: viewportPoint), "The wrapper passes viewport coordinates even after scrolling")
        wrapper.highlightGestureMoved(location: viewportPoint)
        wrapper.highlightGestureFinished(performAction: true)
        XCTAssertEqual(selected, [5], "Dragging to the visible top row must select its actual item")
        wrapper.increaseHighlightedIndex()
        wrapper.highlightGestureFinished(performAction: true)
        XCTAssertEqual(selected, [5, 0], "Keyboard navigation must also pass through the real custom wrapper")
    }

    func testOriginalActionReceivesControllerAndDismissalAndCannotBeRepeated() throws {
        let recorder = MenuControllerRecorder()
        var copies = 0
        let copy = self.action(.copy) { action in
            XCTAssertTrue(action.controller === recorder)
            copies += 1
            action.dismissWithResult(.dismissWithoutContent)
        }
        let original = ContextController.Items(content: .list([.action(copy)]))
        let menu = try XCTUnwrap(WegramMessageMenu(items: original, itemsSignal: .single(original), presentationData: self.data(), save: { XCTFail("Save is forbidden without Forward") }))
        menu.controller = recorder
        let grid = try self.node(menu)
        let buttons = self.buttons(grid)
        XCTAssertEqual(buttons.map { $0.accessibilityLabel }, ["copy", "更多"])
        _ = buttons[0].accessibilityActivate(); _ = buttons[0].accessibilityActivate()
        XCTAssertEqual(copies, 1)
        XCTAssertEqual(recorder.dismissResults.count, 1)
        guard case .dismissWithoutContent? = recorder.dismissResults.first else { return XCTFail("Original dismissal changed") }
    }

    func testVoiceTranscriptionIsInTheFirstRowAndKeepsItsCurrentActionAndTitle() throws {
        for title in ["转文字", "收起文字"] {
            let recorder = MenuControllerRecorder()
            var calls = 0
            let transcription = self.action(.transcribe, title: title) { action in
                XCTAssertTrue(action.controller === recorder)
                calls += 1
                action.dismissWithResult(.dismissWithoutContent)
            }
            let original = ContextController.Items(content: .list([.action(self.action(.reply)), .action(self.action(.forward)), .action(transcription)]))
            let menu = try XCTUnwrap(WegramMessageMenu(items: original, itemsSignal: .single(original), presentationData: self.data(), save: {}))
            menu.controller = recorder
            let grid = try self.node(menu)
            let buttons = self.buttons(grid)
            XCTAssertEqual(buttons.map { $0.accessibilityLabel }, [title, "forward", "收藏", "引用", "更多"])
            XCTAssertTrue(buttons.allSatisfy { $0.frame.minY == buttons[0].frame.minY })
            XCTAssertNotNil(buttons[0].image(for: .normal))
            _ = buttons[0].accessibilityActivate()
            _ = buttons[0].accessibilityActivate()
            XCTAssertEqual(calls, 1)
            XCTAssertEqual(recorder.dismissResults.count, 1)
        }
        let unavailable = ContextMenuActionItem(id: WegramMessageMenuAction.transcribe.identifier, text: "转文字", icon: { _ in nil }, action: nil as ((ContextMenuActionItem.Action) -> Void)?)
        let original = ContextController.Items(content: .list([.action(unavailable), .action(self.action(.reply))]))
        let menu = try XCTUnwrap(WegramMessageMenu(items: original, itemsSignal: .single(original), presentationData: self.data(), save: nil))
        XCTAssertEqual(self.buttons(try self.node(menu)).map { $0.accessibilityLabel }, ["引用", "更多"])
    }

    func testVoicePlaybackProgressIsDiscoverableBesideTranscriptionAndInvokesTheOriginalActionOnce() throws {
        for title in ["播放进度", "收起进度"] {
            var calls = 0
            let recorder = MenuControllerRecorder()
            let progress = self.action(.playbackProgress, title: title) { _ in calls += 1 }
            let original = ContextController.Items(content: .list([.action(self.action(.reply)), .action(self.action(.forward)), .action(progress), .action(self.action(.transcribe, title: "转文字"))]))
            let menu = try XCTUnwrap(WegramMessageMenu(items: original, itemsSignal: .single(original), presentationData: self.data(), save: {}))
            menu.controller = recorder
            let grid = try self.node(menu)
            let buttons = self.buttons(grid)
            XCTAssertEqual(buttons.map { $0.accessibilityLabel }, ["转文字", title, "forward", "收藏", "引用", "更多"])
            XCTAssertEqual(buttons[0].frame.minY, buttons[1].frame.minY)
            _ = buttons[1].accessibilityActivate()
            _ = buttons[1].accessibilityActivate()
            XCTAssertEqual(calls, 1)
        }
    }

    func testMoreKeepsOriginalItemsAndLiveMetadataAndBackRejectsStaleActions() throws {
        let recorder = MenuControllerRecorder()
        let forward = self.action(.forward)
        let report = ContextMenuActionItem(text: "Report", icon: { _ in nil }, action: { _, _ in })
        let original = ContextController.Items(content: .list([.action(report), .separator, .action(forward)]), tip: .textSelection)
        let updates = Promise<ContextController.Items>(original)
        var saves = 0
        let menu = try XCTUnwrap(WegramMessageMenu(items: original, itemsSignal: updates.get(), presentationData: self.data(), save: { saves += 1 }))
        menu.controller = recorder
        let oldGrid = try self.node(menu)
        let oldButtons = self.buttons(oldGrid)
        XCTAssertEqual(oldButtons.map { $0.accessibilityLabel }, ["forward", "收藏", "更多"])
        _ = oldButtons[2].accessibilityActivate()
        _ = oldButtons[1].accessibilityActivate()
        XCTAssertEqual(saves, 0, "A hidden grid must not run Save")
        guard case let .list(items)? = recorder.latest?.content, case let .action(back) = items.first else { return XCTFail("More has no Back") }
        XCTAssertEqual(items.count, 5)
        guard case let .action(retainedReport) = items[2] else { return XCTFail("Original item missing") }
        XCTAssertTrue(retainedReport === report)
        var updated = original
        updated.tip = .quoteSelection
        updates.set(.single(updated))
        XCTAssertEqual(recorder.latest?.tip, .quoteSelection)
        back.action?(.init(controller: recorder, dismissWithResult: { _ in }, updateAction: { _, _ in }))
        guard case .custom? = recorder.latest?.content else { return XCTFail("Back did not restore the grid") }
        back.action?(.init(controller: recorder, dismissWithResult: { _ in }, updateAction: { _, _ in }))
        let newGrid = try self.node(menu)
        let newButtons = self.buttons(newGrid)
        _ = newButtons[1].accessibilityActivate(); _ = newButtons[1].accessibilityActivate()
        XCTAssertEqual(saves, 1)
        menu.invalidate()
        _ = newButtons[2].accessibilityActivate()
        XCTAssertEqual(recorder.dismissResults.count, 1)
        XCTAssertNil(WegramMessageMenu(items: .init(content: .list([.action(report)])), itemsSignal: .never(), presentationData: self.data(), save: nil))
    }
}
