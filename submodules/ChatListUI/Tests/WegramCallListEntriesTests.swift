import XCTest
import Postbox
import TelegramPresentationData
import ItemListUI
@testable import TelegramCore
@testable import CallListUI

extension ChatListRichTextPreviewTests {
    private func callGroup(_ id: Int64, title: String) -> EnginePeer {
        EnginePeer(TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: ._internalFromInt64Value(id)), title: title, photo: [], participantCount: 3, role: .member, membership: .Member, flags: [.hasActiveVoiceChat], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0))
    }
    private func callEntries(groups: [EnginePeer], recent: Bool = true, later: Bool = false, showTab: Bool = false, current: EnginePeer.Id? = nil) -> [CallListNodeEntry] {
        let data = defaultPresentationData()
        let state = CallListNodeState(presentationData: ItemListPresentationData(data), dateTimeFormat: data.dateTimeFormat, disableAnimations: true, editing: false, messageIdWithRevealedOptions: nil)
        return callListNodeEntriesForView(view: EngineCallList(items: [], hasEarlier: true, hasLater: later), displayOpenNewCall: recent, groupCalls: groups, state: state, showSettings: false, showCallsTab: showTab, isRecentCalls: recent, currentGroupCallPeerId: current)
    }
    func testCallsShortcutShowsOriginalOngoingGroupsWithoutTheInertTabSwitch() {
        let first = self.callGroup(1, title: "Alpha")
        let second = self.callGroup(2, title: "Beta")
        for storedShowTab in [false, true] {
            let entries = self.callEntries(groups: [second, first], showTab: storedShowTab, current: second.id)
            XCTAssertFalse(entries.contains { $0.stableId == .setting(0) || $0.stableId == .setting(1) })
            XCTAssertTrue(entries.contains { $0.stableId == .setting(2) })
            let groups = entries.compactMap { entry -> (EnginePeer.Id, Bool)? in
                if case let .groupCall(peer, _, active) = entry { return (peer.id, active) }
                return nil
            }
            XCTAssertEqual(Set(groups.map { $0.0 }), Set([first.id, second.id]))
            XCTAssertEqual(groups.first { $0.0 == second.id }?.1, true)
            XCTAssertEqual(groups.first { $0.0 == first.id }?.1, false)
            XCTAssertEqual(countMeaningfulCallListEntries(entries), 2)
        }
    }
    func testMissedAndOlderPagesKeepOriginalScopeAndNewestPageGates() {
        let group = self.callGroup(1, title: "Call")
        XCTAssertTrue(self.callEntries(groups: [group], recent: false).isEmpty)
        XCTAssertTrue(self.callEntries(groups: [group], later: true).isEmpty)
        let empty = self.callEntries(groups: [])
        XCTAssertEqual(empty.map(\.stableId), [.setting(2)])
        XCTAssertEqual(countMeaningfulCallListEntries(empty), 0)
    }
}
