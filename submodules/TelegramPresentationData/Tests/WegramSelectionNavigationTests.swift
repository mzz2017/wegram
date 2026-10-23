import XCTest
import UIKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ChatPresentationInterfaceState
import AccountContext
import ChatNavigationButton

final class WegramSelectionNavigationTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }

    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }

    private func state(selected: Int) -> ChatPresentationInterfaceState {
        let peer = PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(42))
        return ChatPresentationInterfaceState(chatWallpaper: .color(0xededed), theme: defaultPresentationTheme, preferredGlassType: .default, strings: defaultPresentationStrings, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, limitsConfiguration: .defaultValue, fontSize: .regular, bubbleCorners: .wegram, accountPeerId: peer, mode: .standard(.default), chatLocation: .peer(id: peer), subject: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, threadData: nil, isGeneralThreadClosed: nil, replyMessage: nil, accountPeerColor: nil, businessIntro: nil).updatedInterfaceState { state in
            state.withUpdatedSelectedMessages((0 ..< selected).map { MessageId(peerId: peer, namespace: Namespaces.Message.Cloud, id: Int32($0 + 1)) })
        }
    }

    private func user(_ id: Int64) -> TelegramUser {
        return TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(id)), accessHash: nil, firstName: "Fixture", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
    }

    private func pinnedState(peer: Peer) -> ChatPresentationInterfaceState {
        let id = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1)
        let message = EngineMessage(stableId: 1, stableVersion: 0, id: id, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "Pinned fixture", attributes: [], media: [], peers: [:], associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])._asMessage()
        return self.state(selected: 0).updatedInterfaceState { $0.withoutSelectionState() }
            .updatedChatLocation(.peer(id: peer.id)).updatedPeer { _ in RenderedPeer(peer: peer) }
            .updatedPinnedMessage(ChatPinnedMessage(message: message, index: 0, totalCount: 3, topMessageId: id))
    }

    func testHiddenPinnedEntryUsesCurrentPrivateOrSavedMessageWithoutChangingPinState() throws {
        for id: Int64 in [42, 43] {
            let state = self.pinnedState(peer: self.user(id))
            XCTAssertTrue(state.wegramHiddenPinnedMessage === state.pinnedMessage)
            XCTAssertEqual(state.wegramHiddenPinnedMessage?.totalCount, 3)
            let closed = state.updatedInterfaceState { $0.withUpdatedMessageActionsState { actions in
                var actions = actions
                actions.closedPinnedMessageId = state.pinnedMessage?.topMessageId
                return actions
            } }
            XCTAssertTrue(closed.wegramHiddenPinnedMessage === state.pinnedMessage, "Closing the old banner must not remove access to the list")
            XCTAssertEqual(closed.interfaceState.messageActionsState.closedPinnedMessageId, state.pinnedMessage?.topMessageId)
            XCTAssertNil(state.updatedPinnedMessage(nil).wegramHiddenPinnedMessage, "Removing the final pin must remove the menu entry")
            let pin = try XCTUnwrap(state.pinnedMessage)
            let latest = ChatPinnedMessage(message: pin.message, index: 0, totalCount: 1, topMessageId: pin.topMessageId)
            XCTAssertTrue(state.updatedPinnedMessage(latest).wegramHiddenPinnedMessage === latest)
        }
    }

    func testHiddenPinnedEntryKeepsGroupsAndSpecialChatPresentationsUnchanged() {
        let state = self.pinnedState(peer: self.user(43))
        XCTAssertNil(self.state(selected: 0).wegramHiddenPinnedMessage)
        XCTAssertTrue(state.updatedBubbleCorners(.init(mainRadius: 16, auxiliaryRadius: 8, mergeBubbleCorners: true)).wegramHiddenPinnedMessage === state.pinnedMessage, "Chat state keeps upstream corners; WeGram corners are applied inside message renderers")
        XCTAssertNil(state.updatedSubject(.scheduledMessages).wegramHiddenPinnedMessage)
        XCTAssertNil(state.updatedSubject(.pinnedMessages(id: nil)).wegramHiddenPinnedMessage)
        XCTAssertNil(state.updatedMode(.standard(.previewing)).wegramHiddenPinnedMessage)
        XCTAssertNil(state.updatedMode(.standard(.embedded(invertDirection: false))).wegramHiddenPinnedMessage)
        XCTAssertNil(state.updatedMode(.overlay(nil)).wegramHiddenPinnedMessage)
        XCTAssertNil(state.updatedMode(.inline(nil)).wegramHiddenPinnedMessage)
        XCTAssertNil(state.updatedChatLocation(.customChatContents).wegramHiddenPinnedMessage)
        XCTAssertNil(state.updatedChatLocation(.peer(id: PeerId(namespace: Namespaces.Peer.SecretChat, id: ._internalFromInt64Value(1)))).wegramHiddenPinnedMessage)
        XCTAssertNil(state.updatedPendingUnpinnedAllMessages(true).wegramHiddenPinnedMessage)
        XCTAssertNil(state.updatedIsNotAccessible(true).wegramHiddenPinnedMessage)
        let group = TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: ._internalFromInt64Value(7)), title: "Fixture", photo: [], participantCount: 2, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        XCTAssertNil(self.pinnedState(peer: group).wegramHiddenPinnedMessage)
        for broadcast in [false, true] {
            let channel = TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: ._internalFromInt64Value(9)), accessHash: nil, title: "Fixture", username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: broadcast ? .broadcast(.init(flags: [])) : .group(.init(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil)
            let state = self.pinnedState(peer: channel)
            XCTAssertEqual(state.wegramHiddenPinnedMessage != nil, broadcast)
        }
    }

    func testSelectionExposesCancelOnTheLeftEvenWhenNothingIsSelectedOrPeerIsLoading() {
        for count in [0, 3] {
            let state = self.state(selected: count)
            let button = leftNavigationButtonForChatInterfaceState(state, subject: nil, strings: defaultPresentationStrings, currentButton: nil, target: nil, selector: nil, usesWegramAppearance: true)
            XCTAssertEqual(button?.action, .cancelMessageSelection)
            XCTAssertEqual(button?.buttonItem.title, defaultPresentationStrings.Common_Cancel)
            XCTAssertEqual(button?.buttonItem.accessibilityLabel, defaultPresentationStrings.Common_Cancel)
            XCTAssertNil(leftNavigationButtonForChatInterfaceState(state, subject: nil, strings: defaultPresentationStrings, currentButton: nil, target: nil, selector: nil), "The original peer-loading branch must remain unchanged")
        }
    }

    func testHistoryEntrySurvivesAnEmptySelectionWithoutEnablingMessageActions() {
        XCTAssertEqual(wegramSelectionExtras(nil, hasSelection: false, isSecret: false, hasHistoryAction: true), [.history])
        XCTAssertEqual(wegramSelectionExtras(nil, hasSelection: false, isSecret: true, hasHistoryAction: true), [.history])
        XCTAssertEqual(wegramSelectionExtras(nil, hasSelection: false, isSecret: false, hasHistoryAction: false), [])
    }

    func testSelectionNavigationRestoresOrdinaryStateAndKeepsReportAndPreviewBranches() {
        let state = self.state(selected: 0)
        XCTAssertTrue(wegramUsesSelectionNavigation(state))
        let ordinary = state.updatedInterfaceState { $0.withoutSelectionState() }
        XCTAssertFalse(wegramUsesSelectionNavigation(ordinary))
        XCTAssertNil(leftNavigationButtonForChatInterfaceState(ordinary, subject: nil, strings: defaultPresentationStrings, currentButton: nil, target: nil, selector: nil, usesWegramAppearance: true))
        let report = state.updatedReportReason(.init(title: "Report", option: Data(), message: nil))
        XCTAssertFalse(wegramUsesSelectionNavigation(report))
        XCTAssertEqual(leftNavigationButtonForChatInterfaceState(report, subject: nil, strings: defaultPresentationStrings, currentButton: nil, target: nil, selector: nil, usesWegramAppearance: true)?.action, .spacer)
        XCTAssertFalse(wegramUsesSelectionNavigation(state.updatedMode(.standard(.previewing))))
        let old = ChatNavigationButton(action: .cancelMessageSelection, buttonItem: UIBarButtonItem(title: "Old language", style: .plain, target: nil, action: nil))
        let current = leftNavigationButtonForChatInterfaceState(state, subject: nil, strings: defaultPresentationStrings, currentButton: old, target: nil, selector: nil, usesWegramAppearance: true)
        XCTAssertEqual(current?.buttonItem.title, defaultPresentationStrings.Common_Cancel)
        XCTAssertFalse(current?.buttonItem === old.buttonItem)
    }

    func testHistoryMenuKeepsTheExactChatSubjectAndSelectionBeforeRecheckingOriginalPermissions() {
        let groupId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: ._internalFromInt64Value(7))
        let group = TelegramGroup(id: groupId, title: "Component", photo: [], participantCount: 2, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        let state = self.state(selected: 0).updatedChatLocation(.peer(id: groupId)).updatedPeer { _ in RenderedPeer(peer: group) }
        let target = (location: state.chatLocation, subject: state.subject, selectedIds: Set<EngineMessage.Id>())
        XCTAssertEqual(wegramSelectionHistoryButton(state, matching: target)?.action, .clearHistory)
        let scheduled = state.updatedSubject(.scheduledMessages)
        XCTAssertEqual(wegramSelectionHistoryButton(scheduled)?.action, .clearHistory)
        XCTAssertNil(wegramSelectionHistoryButton(scheduled, matching: target), "An old history menu must not clear the scheduled queue")
        let otherPeer = state.updatedChatLocation(.peer(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: ._internalFromInt64Value(8))))
        XCTAssertNil(wegramSelectionHistoryButton(otherPeer, matching: target), "Empty selections cannot identify the conversation")
        let selected = state.updatedInterfaceState { $0.withUpdatedSelectedMessages([MessageId(peerId: groupId, namespace: Namespaces.Message.Cloud, id: 1)]) }
        XCTAssertNil(wegramSelectionHistoryButton(selected, matching: target))
        XCTAssertNil(wegramSelectionHistoryButton(state.updatedInterfaceState { $0.withoutSelectionState() }, matching: target))
    }
}
