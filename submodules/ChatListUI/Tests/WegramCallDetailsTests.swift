import XCTest
import UIKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import Display
@testable import PeerInfoUI

extension ChatListRichTextPreviewTests {
    private func detailCall(_ id: Int32, incoming: Bool, reason: PhoneCallDiscardReason?, duration: Int32?, video: Bool) -> EngineMessage {
        let peer = PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(123))
        return EngineMessage(stableId: UInt32(id), stableVersion: 0, id: MessageId(peerId: peer, namespace: Namespaces.Message.Cloud, id: id), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 1_760_800_000 + id * 60, flags: incoming ? [.Incoming] : [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [EngineMedia(TelegramMediaAction(action: .phoneCall(callId: 1, discardReason: reason, duration: duration, isVideo: video)))], peers: [:], associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
    }
    private func layoutDetails(_ node: ItemListCallListItemNode, messages: [EngineMessage], width: CGFloat, safe: CGFloat = 0, large: Bool = false, dark: Bool = false) -> CGSize {
        let data = defaultPresentationData()
        let presentation = ItemListPresentationData(theme: dark ? defaultDarkPresentationTheme : data.theme, fontSize: large ? .extraLargeX2 : .regular, strings: data.strings, nameDisplayOrder: data.nameDisplayOrder, dateTimeFormat: data.dateTimeFormat)
        let item = ItemListCallListItem(presentationData: presentation, dateTimeFormat: data.dateTimeFormat, messages: messages, sectionId: 0, style: .blocks, displayDecorations: false)
        let (layout, apply) = node.asyncLayout()(item, ListViewItemLayoutParams(width: width, leftInset: safe, rightInset: safe, availableHeight: 1000), ItemListNeighbors(top: .none, bottom: .none))
        apply()
        node.contentSize = layout.contentSize
        node.insets = layout.insets
        return layout.contentSize
    }
    func testActualCallDetailNodesFitSafeColumnsAndResizeOnReuse() throws {
        let messages = [self.detailCall(1, incoming: true, reason: .missed, duration: nil, video: true), self.detailCall(2, incoming: false, reason: .hangup, duration: 65, video: false)]
        let node = ItemListCallListItemNode()
        for width: CGFloat in [320, 402, 720] {
            for safe: CGFloat in [0, 16, 59] {
                for large in [false, true] {
                    let size = self.layoutDetails(node, messages: messages, width: width, safe: safe, large: large)
                    XCTAssertEqual(node.callNodes.count, 2)
                    var previousBottom = node.titleNode.frame.maxY
                    for (time, type) in node.callNodes {
                        XCTAssertGreaterThan(time.frame.width, 0)
                        XCTAssertGreaterThan(type.frame.width, 0)
                        XCTAssertGreaterThanOrEqual(time.frame.minX, safe + 16)
                        XCTAssertLessThanOrEqual(time.frame.maxX + 12, type.frame.minX + 0.5)
                        XCTAssertLessThanOrEqual(type.frame.maxX, width - safe - 16 + 0.5)
                        XCTAssertGreaterThanOrEqual(min(time.frame.minY, type.frame.minY), previousBottom + 7)
                        previousBottom = max(time.frame.maxY, type.frame.maxY)
                        XCTAssertFalse(time.isAccessibilityElement)
                        XCTAssertFalse(type.isAccessibilityElement)
                    }
                    XCTAssertGreaterThanOrEqual(size.height, previousBottom + 7)
                }
            }
        }
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            for dark in [false, true] {
                let size = self.layoutDetails(node, messages: messages, width: 402, dark: dark)
                let host = UIView(frame: CGRect(origin: .zero, size: size))
                host.backgroundColor = dark ? defaultDarkPresentationTheme.list.itemBlocksBackgroundColor : defaultPresentationData().theme.list.itemBlocksBackgroundColor
                host.addSubnode(node)
                node.frame = host.bounds
                _ = node.view
                node.recursivelyEnsureDisplaySynchronously(true)
                let image = UIGraphicsImageRenderer(size: size).image { host.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "call-details-dark.png" : "call-details-light.png"))
            }
        }
        _ = self.layoutDetails(node, messages: [], width: 320)
        XCTAssertTrue(node.callNodes.isEmpty)
        XCTAssertEqual(node.contentSize.height, 0)
        _ = self.layoutDetails(node, messages: [messages[0]], width: 320)
        XCTAssertEqual(node.callNodes.count, 1)
    }
    func testCallDetailRenderingPreservesOriginalConnectedAndMissedSemantics() {
        let node = ItemListCallListItemNode()
        let strings = defaultPresentationStrings
        let examples: [(Bool, PhoneCallDiscardReason?, Int32?, Bool, String)] = [
            (true, .missed, nil, true, strings.Notification_VideoCallMissed),
            (false, .busy, nil, false, strings.Notification_CallCanceled),
            (true, .disconnect, 65, false, strings.Notification_CallIncoming),
            (false, .disconnect, nil, true, strings.Notification_VideoCallCanceled),
            (false, .hangup, 65, true, strings.Notification_VideoCallOutgoing)
        ]
        for (index, example) in examples.enumerated() {
            _ = self.layoutDetails(node, messages: [self.detailCall(Int32(index + 1), incoming: example.0, reason: example.1, duration: example.2, video: example.3)], width: 320)
            XCTAssertEqual(node.callNodes.first?.1.cachedLayout?.attributedString?.string, example.4)
        }
    }
}
