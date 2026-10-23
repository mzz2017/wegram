import XCTest
import UIKit
import Display
import TelegramPresentationData
import TelegramCore

final class WegramAttachmentPagingTests: XCTestCase {
    private func layout(width: CGFloat = 402, maximumHeight: CGFloat = 600, count: Int) -> WegramAttachmentLayout {
        return WegramAttachmentLayout(width: width, left: 0, right: 0, bottom: 34, maximumHeight: maximumHeight, count: count)
    }

    func testSystemPageControlSelectsRealScrollPageWithoutInvokingAnItem() throws {
        var selectedItems: [Int] = []
        let node = WegramAttachmentInputNode(items: (0..<20).map { index in
            .init(title: "Item \(index)", symbol: "photo", action: { selectedItems.append(index) })
        })
        defer { withExtendedLifetime(node) {} }
        node.updatePagingLayout(self.layout(count: 20), transition: .immediate)
        let control = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIPageControl }.first)
        let scroll = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIScrollView }.first)
        XCTAssertTrue(control.isUserInteractionEnabled)
        XCTAssertEqual(control.numberOfPages, 3)
        control.currentPage = 2
        control.sendActions(for: .valueChanged)
        let arrived = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in abs(scroll.contentOffset.x - 804) < 0.5 }, object: nil)
        wait(for: [arrived], timeout: 2)
        XCTAssertEqual(control.currentPage, 2)
        XCTAssertTrue(selectedItems.isEmpty)
        let button = try XCTUnwrap(scroll.subviews.compactMap { $0 as? UIButton }.first { $0.tag == 16 })
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(selectedItems, [16])
    }

    func testSwipeStateAndRotationKeepTheFirstVisibleItemReachable() throws {
        let node = WegramAttachmentInputNode(items: (0..<20).map { _ in .init(title: "Item", symbol: "photo", action: {}) })
        defer { withExtendedLifetime(node) {} }
        node.updatePagingLayout(self.layout(count: 20), transition: .immediate)
        let control = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIPageControl }.first)
        let scroll = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIScrollView }.first)
        scroll.contentOffset = CGPoint(x: 402, y: 0)
        node.scrollViewDidScroll(scroll)
        XCTAssertEqual(control.currentPage, 1)
        node.updatePagingLayout(self.layout(width: 874, maximumHeight: 180, count: 20), transition: .immediate)
        XCTAssertEqual(control.numberOfPages, 5)
        XCTAssertEqual(control.currentPage, 2)
        XCTAssertEqual(scroll.contentOffset.x, 1748)
        node.updatePagingLayout(self.layout(count: 20), transition: .immediate)
        XCTAssertEqual(control.currentPage, 1)
        XCTAssertEqual(scroll.contentOffset.x, 402)
    }

    func testSinglePageKeepsIndicatorsHiddenAndUnlaidOutEventsAreHarmless() throws {
        let node = WegramAttachmentInputNode(items: [.init(title: "Photo", symbol: "photo", action: {})])
        defer { withExtendedLifetime(node) {} }
        let control = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIPageControl }.first)
        let scroll = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIScrollView }.first)
        control.sendActions(for: .valueChanged)
        XCTAssertEqual(scroll.contentOffset, .zero)
        node.updatePagingLayout(self.layout(count: 1), transition: .immediate)
        XCTAssertEqual(control.numberOfPages, 1)
        XCTAssertTrue(control.hidesForSinglePage)
        XCTAssertEqual(scroll.contentOffset, .zero)
    }
    func testUserIOSAttachmentReferenceSets274PointPanelAnd96PointRows() {
        let layout = self.layout(count: 8)
        XCTAssertEqual(layout.height, 274)
        XCTAssertEqual(layout.viewport.height, 216)
        XCTAssertEqual(layout.rows, 2)
        let xs: [CGFloat] = [20, 116, 213, 310]
        for index in 0 ..< 8 {
            XCTAssertEqual(layout.frames[index], CGRect(x: xs[index % 4], y: index < 4 ? 16 : 112, width: 72, height: 88))
        }
        XCTAssertEqual(layout.indicators, CGRect(x: 0, y: 216, width: 402, height: 24))
    }

    func testRenderedAttachmentTilesMatchReferenceGeometryAndKeepActions() throws {
        let icons: [WegramIcon] = [.attachmentPhoto, .attachmentCamera, .attachmentLocation, .attachmentContact, .attachmentFile, .attachmentMusic, .attachmentVideo, .chatMore]
        var calls: [Int] = []
        let node = WegramAttachmentInputNode(items: icons.enumerated().map { index, icon in
            .init(title: "Item \(index)", symbol: "photo", artwork: icon, action: { calls.append(index) })
        })
        defer { withExtendedLifetime(node) {} }
        let layout = self.layout(count: icons.count)
        node.frame = CGRect(x: 0, y: 0, width: 402, height: layout.height)
        let scroll = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIScrollView }.first)
        for dark in [false, true] {
            node.updatePagingLayout(layout, dark: dark, transition: .immediate)
            let buttons = scroll.subviews.compactMap { $0 as? UIButton }.sorted { $0.tag < $1.tag }
            for (index, button) in buttons.enumerated() {
                XCTAssertEqual(button.frame, layout.frames[index])
                let tile = try XCTUnwrap(button.subviews.first { !($0 is UILabel) })
                XCTAssertEqual(tile.frame, CGRect(x: 4, y: 0, width: 64, height: 64))
                XCTAssertEqual(tile.layer.cornerRadius, 14)
                let label = try XCTUnwrap(button.subviews.compactMap { $0 as? UILabel }.first)
                XCTAssertEqual(label.frame, CGRect(x: 0, y: 72, width: 72, height: 16))
                XCTAssertEqual(label.textColor, UIColor(rgb: dark ? 0x999999 : 0x666666))
                button.sendActions(for: .touchUpInside)
            }
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                func setScale(_ view: UIView) {
                    view.layer.contentsScale = 3
                    view.contentScaleFactor = 3
                    view.subviews.forEach(setScale)
                }
                setScale(node.view)
                let format = UIGraphicsImageRendererFormat(); format.scale = 3
                let image = UIGraphicsImageRenderer(size: node.bounds.size, format: format).image { node.view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "attachment-user-ios-dark.png" : "attachment-user-ios-light.png"))
            }
        }
        XCTAssertEqual(calls, Array(0 ..< 8) + Array(0 ..< 8))
    }

    func testSavedFavoriteSlotKeepsTelegramExtrasOnLaterPagesAndRotationReachable() throws {
        let slots = [0, 1, 4, 2, 5, 6, 7, 8, 9, 10]
        let layout = WegramAttachmentLayout(width: 402, left: 0, right: 0, bottom: 34, maximumHeight: 600, count: slots.count, slots: slots)
        XCTAssertEqual(layout.pageCount, 2)
        XCTAssertEqual(layout.frames[2], CGRect(x: 20, y: 112, width: 72, height: 88), "Favorites occupies row two column one")
        XCTAssertEqual(layout.frames[3], CGRect(x: 213, y: 16, width: 72, height: 88))
        XCTAssertGreaterThanOrEqual(layout.frames[7].minX, 402, "Telegram extensions do not fill the main voice-input position")
        let node = WegramAttachmentInputNode(items: slots.map { slot in .init(title: "Slot \(slot)", symbol: "photo", slot: slot, action: {}) })
        defer { withExtendedLifetime(node) {} }
        node.updatePagingLayout(layout, transition: .immediate)
        let control = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIPageControl }.first)
        let scroll = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIScrollView }.first)
        scroll.contentOffset = CGPoint(x: 402, y: 0)
        node.scrollViewDidScroll(scroll)
        let landscape = WegramAttachmentLayout(width: 874, left: 59, right: 59, bottom: 21, maximumHeight: 180, count: slots.count, slots: slots)
        node.updatePagingLayout(landscape, transition: .immediate)
        XCTAssertEqual(control.currentPage, 2)
        XCTAssertEqual(control.numberOfPages, 3)
        XCTAssertEqual(scroll.contentOffset.x, landscape.pageWidth * 2)
    }

    func testSavedAttachmentStagesOnlyCloudSavedMessageWithoutReplacingDraftForwards() throws {
        let account = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(123))
        let other = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(456))
        let selected = EngineMessage.Id(peerId: account, namespace: Namespaces.Message.Cloud, id: 7)
        let previous = EngineMessage.Id(peerId: other, namespace: Namespaces.Message.Cloud, id: 9)
        XCTAssertEqual(wegramSavedAttachmentForwardIds(current: [previous], selected: selected, accountPeerId: account), [previous, selected])
        XCTAssertEqual(wegramSavedAttachmentForwardIds(current: [previous, selected], selected: selected, accountPeerId: account), [previous, selected])
        XCTAssertNil(wegramSavedAttachmentForwardIds(current: nil, selected: previous, accountPeerId: account))
        let unsent = EngineMessage.Id(peerId: account, namespace: Namespaces.Message.Local, id: 8)
        XCTAssertNil(wegramSavedAttachmentForwardIds(current: nil, selected: unsent, accountPeerId: account))
    }

    func testSavedHistoryWaitsForLoadingAndForAnOlderPageBeforeDisposing() {
        let peer = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(123))
        let anchor = EngineMessage.Index(id: EngineMessage.Id(peerId: peer, namespace: Namespaces.Message.Cloud, id: 100), timestamp: 100)
        let older = EngineMessage.Index(id: EngineMessage.Id(peerId: peer, namespace: Namespaces.Message.Cloud, id: 50), timestamp: 50)
        func ready(loading: Bool = false, loadingEarlier: Bool = false, holeEarlier: Bool = true, holeLater: Bool = false, hasEarlier: Bool = false, oldest: EngineMessage.Index? = nil, requested: EngineMessage.Index? = nil) -> Bool {
            return wegramSavedAttachmentHistoryIsReady(isLoading: loading, isLoadingEarlier: loadingEarlier, holeEarlier: holeEarlier, holeLater: holeLater, hasEarlier: hasEarlier, oldest: oldest, requested: requested)
        }
        XCTAssertFalse(ready(loading: true, oldest: older, requested: anchor))
        XCTAssertFalse(ready(loadingEarlier: true, oldest: older, requested: anchor))
        XCTAssertFalse(ready(oldest: anchor, requested: anchor), "A navigation event with an unfilled older hole must not terminate the history subscription")
        XCTAssertFalse(ready(holeEarlier: false, hasEarlier: true, oldest: anchor, requested: anchor))
        XCTAssertTrue(ready(oldest: older, requested: anchor))
        XCTAssertTrue(ready(holeEarlier: false, oldest: anchor, requested: anchor), "The real end of history may complete without another older message")
        XCTAssertFalse(ready(holeLater: true, oldest: older))
        XCTAssertFalse(ready())
        XCTAssertTrue(ready(holeEarlier: false))
        XCTAssertTrue(ready(oldest: older))
    }

    func testAttachmentBackdropCoversSafeAreasAndNeverInterceptsTileOrPagingActions() throws {
        var selected = false
        let node = WegramAttachmentInputNode(items: [.init(title: "照片", symbol: "photo", action: { selected = true })])
        defer { withExtendedLifetime(node) {} }
        let background = try XCTUnwrap(node.view.subviews.compactMap { $0 as? BlurredBackgroundView }.first)
        for dark in [false, true] {
            for width: CGFloat in [402, 874] {
                let safe: CGFloat = width == 874 ? 59 : 0
                let layout = WegramAttachmentLayout(width: width, left: safe, right: safe, bottom: 34, maximumHeight: 600, count: 1)
                node.frame = CGRect(x: 0, y: 0, width: width, height: layout.height)
                node.updatePagingLayout(layout, dark: dark, transition: .immediate)
                XCTAssertEqual(background.frame, node.bounds, "Blur must cover both landscape safe areas and the home indicator")
                XCTAssertFalse(background.isUserInteractionEnabled)
                XCTAssertTrue(background.accessibilityElementsHidden)
                XCTAssertEqual(node.backgroundColor, .clear, "An opaque node would hide the wallpaper behind the blur")
                let tint = try XCTUnwrap(background.subviews.last)
                let expected = UIColor(rgb: dark ? 0x202020 : 0xf7f7f7).withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? 1 : 0.9)
                XCTAssertEqual(tint.backgroundColor, expected)
                if UIAccessibility.isReduceTransparencyEnabled {
                    XCTAssertNil(background.effectView)
                } else {
                    XCTAssertNotNil(background.effectView)
                    XCTAssertEqual(background.effectView?.frame, background.bounds)
                }
                let scroll = try XCTUnwrap(node.view.subviews.compactMap { $0 as? UIScrollView }.first)
                let button = try XCTUnwrap(scroll.subviews.compactMap { $0 as? UIButton }.first)
                let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: node.view)
                XCTAssertTrue(node.view.hitTest(point, with: nil) === button)
                selected = false
                button.sendActions(for: .touchUpInside)
                XCTAssertTrue(selected)
                XCTAssertLessThan(try XCTUnwrap(node.view.subviews.firstIndex(of: background)), try XCTUnwrap(node.view.subviews.firstIndex(of: scroll)))
            }
        }
    }

}
