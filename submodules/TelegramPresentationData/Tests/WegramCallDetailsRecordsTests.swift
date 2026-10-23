import XCTest
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import Postbox

final class WegramCallDetailsRecordsTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }
    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }
    private func message(_ id: Int32) -> EngineMessage {
        let peer = PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(123))
        return EngineMessage(stableId: UInt32(id), stableVersion: 0, id: MessageId(peerId: peer, namespace: Namespaces.Message.Cloud, id: id), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 1_760_800_000 + id * 60, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [EngineMedia(TelegramMediaAction(action: .phoneCall(callId: Int64(id), discardReason: nil, duration: 60, isVideo: false)))], peers: [:], associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
    }

    func testActualRecordCreationUpdatesItsHostWithoutASecondExternalLayout() throws {
        for dark in [false, true] {
            let data = defaultPresentationData().withUpdated(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme)
            let view = WegramCallDetailsView()
            view.frame = CGRect(x: 0, y: 0, width: 402, height: 786)
            view.update(name: "Local test", username: nil, messageTitle: "Send Message", callTitle: "Call Back", dark: dark, fontSize: 17)
            let records = WegramCallDetailsRecordsNode()
            view.recordsHost.addSubnode(records)
            let ready = self.expectation(description: "Original call record creation")
            records.heightChanged = { height in
                view.updateLayout(recordsHeight: height, bottomInset: 34)
                ready.fulfill()
            }
            records.update(presentationData: data, messages: [self.message(1), self.message(2)], width: 402)
            self.wait(for: [ready], timeout: 3)
            let item = try XCTUnwrap(records.subnodes?.first)
            XCTAssertGreaterThan(item.bounds.height, 0)
            XCTAssertEqual(view.recordsHost.frame.height, item.bounds.height + 16)
            XCTAssertEqual(records.bounds.width, 402)
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                records.recursivelyEnsureDisplaySynchronously(true)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("call-details-records-\(dark ? "dark" : "light").png"))
            }
        }
    }

    func testSequentialRecordUpdatesReuseOneNodeAndApplyCurrentLayout() throws {
        let data = defaultPresentationData()
        let records = WegramCallDetailsRecordsNode()
        let created = self.expectation(description: "Both main-thread layouts")
        created.expectedFulfillmentCount = 2
        var heights: [CGFloat] = []
        records.heightChanged = { heights.append($0); created.fulfill() }
        records.update(presentationData: data, messages: [self.message(1)], width: 320)
        records.update(presentationData: data, messages: [self.message(1), self.message(2)], width: 402)
        self.wait(for: [created], timeout: 3)
        XCTAssertEqual(records.subnodes?.count, 1)
        XCTAssertEqual(records.bounds.width, 402)
        XCTAssertEqual(heights.count, 2)
        let firstHeight = records.bounds.height
        let changed = self.expectation(description: "Both updated layouts")
        changed.expectedFulfillmentCount = 2
        records.heightChanged = { heights.append($0); changed.fulfill() }
        records.update(presentationData: data, messages: [self.message(1)], width: 260)
        records.update(presentationData: data.withUpdate(listsFontSize: .extraLargeX2), messages: [self.message(1), self.message(2), self.message(3)], width: 342)
        self.wait(for: [changed], timeout: 3)
        XCTAssertEqual(records.subnodes?.count, 1)
        XCTAssertEqual(records.bounds.width, 342)
        XCTAssertGreaterThan(records.bounds.height, firstHeight)
        XCTAssertEqual(heights.count, 4)
        XCTAssertEqual(heights.last, records.bounds.height)
    }
}
