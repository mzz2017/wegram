import XCTest
import Postbox
import AccountContext
import TelegramCore
import ChatPresentationInterfaceState
import TelegramPresentationData
import TelegramStringFormatting

final class WegramComposerAccessoriesTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }

    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }

    func testScheduledMessagesDoNotChangeOrdinaryComposerLayout() {
        for mode: ChatTextInputAccessoryItem.InputMode in [.keyboard, .emoji, .stickers, .bot] {
            for enabled in [false, true] {
                let input = ChatTextInputAccessoryItem.input(isEnabled: enabled, inputMode: mode)
                XCTAssertTrue(wegramComposerSupportsAccessoryItems([input]))
                XCTAssertTrue(wegramComposerSupportsAccessoryItems([input, .scheduledMessages]))
                XCTAssertTrue(wegramComposerSupportsAccessoryItems([.scheduledMessages, input]))
                XCTAssertTrue(wegramComposerSupportsAccessoryItems([input, .messageAutoremoveTimeout(nil)]))
                XCTAssertTrue(wegramComposerSupportsAccessoryItems([input, .commands]))
                XCTAssertTrue(wegramComposerSupportsAccessoryItems([.commands, input, .scheduledMessages]))
                XCTAssertTrue(wegramComposerSupportsAccessoryItems([.messageAutoremoveTimeout(60), input, .gift, .scheduledMessages]))
            }
        }
    }

    func testQueueRemainsReachableWhileTypingAndDisappearsWhenItIsEmpty() {
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        XCTAssertEqual(wegramComposerShortcutItems([input, .scheduledMessages], hasScheduledMessages: true, isTextEmpty: true), [.scheduledMessages])
        XCTAssertEqual(wegramComposerShortcutItems([input], hasScheduledMessages: true, isTextEmpty: false), [.scheduledMessages])
        XCTAssertEqual(wegramComposerShortcutItems([input, .scheduledMessages], hasScheduledMessages: false, isTextEmpty: true), [])
        XCTAssertEqual(wegramComposerShortcutItems([.gift, input, .messageAutoremoveTimeout(60)], hasScheduledMessages: true, isTextEmpty: true), [.gift, .messageAutoremoveTimeout(60), .scheduledMessages])
    }

    func testTimerStateAndSelfChatLabelsRemainExplicit() throws {
        let strings = defaultPresentationStrings
        let off = try XCTUnwrap(wegramComposerShortcutTitle(.messageAutoremoveTimeout(nil), strings: strings, isSelfChat: false))
        XCTAssertEqual(off, "Self-destruct Timer Off")
        let thirty = try XCTUnwrap(wegramComposerShortcutTitle(.messageAutoremoveTimeout(30), strings: strings, isSelfChat: false))
        XCTAssertTrue(thirty.contains("30"))
        XCTAssertNotEqual(thirty, off)
        XCTAssertNotEqual(thirty, wegramComposerShortcutTitle(.messageAutoremoveTimeout(60), strings: strings, isSelfChat: false))
        XCTAssertEqual(wegramComposerShortcutTitle(.scheduledMessages, strings: strings, isSelfChat: true), "Reminders")
        XCTAssertEqual(wegramComposerShortcutTitle(.scheduledMessages, strings: strings, isSelfChat: false), "Scheduled Messages")
        XCTAssertEqual(wegramComposerShortcutTitle(.gift, strings: strings, isSelfChat: false), strings.VoiceOver_GiftPremium)
        XCTAssertEqual(wegramComposerShortcutTitle(.commands, strings: strings, isSelfChat: false), strings.VoiceOver_BotCommands)
        XCTAssertEqual(wegramComposerShortcutTitle(.suggestPost, strings: strings, isSelfChat: false), strings.VoiceOver_SuggestPost)
    }

    func testCommandShortcutFollowsActualAccessoryAvailabilityAlongsideOtherShortcuts() {
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        XCTAssertEqual(wegramComposerShortcutItems([.commands, input], hasScheduledMessages: false, isTextEmpty: true), [.commands])
        XCTAssertEqual(wegramComposerShortcutItems([.commands, .messageAutoremoveTimeout(60), input], hasScheduledMessages: true, isTextEmpty: true), [.commands, .messageAutoremoveTimeout(60), .scheduledMessages])
        XCTAssertEqual(wegramComposerShortcutItems([input], hasScheduledMessages: false, isTextEmpty: true), [])
        XCTAssertEqual(wegramComposerShortcutItems([.commands, input], hasScheduledMessages: false, isTextEmpty: false), [])
        XCTAssertEqual(wegramComposerShortcutItems([.commands, input], hasScheduledMessages: true, isTextEmpty: false), [.scheduledMessages])
        XCTAssertTrue(wegramComposerSupportsAccessoryItems([input, .commands, .botInput(isEnabled: true, inputMode: .bot)]))
    }

    func testReplyKeyboardHasAHiddenEntryAndAnExplicitPrimaryReturnControl() {
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        let open = ChatTextInputAccessoryItem.botInput(isEnabled: true, inputMode: .bot)
        let close = ChatTextInputAccessoryItem.botInput(isEnabled: true, inputMode: .keyboard)
        XCTAssertTrue(wegramComposerSupportsAccessoryItems([input, open]))
        XCTAssertEqual(wegramComposerPrimaryInputItem([open, input]), input)
        XCTAssertEqual(wegramComposerShortcutItems([open, input], hasScheduledMessages: false, isTextEmpty: true), [open])
        XCTAssertEqual(wegramComposerShortcutTitle(open, strings: defaultPresentationStrings, isSelfChat: false), defaultPresentationStrings.VoiceOver_BotKeyboard)
        XCTAssertEqual(wegramComposerShortcutItems([open, input], hasScheduledMessages: false, isTextEmpty: false), [])
        XCTAssertEqual(wegramComposerShortcutItems([input], hasScheduledMessages: false, isTextEmpty: true), [])
        XCTAssertTrue(wegramComposerSupportsAccessoryItems([close]))
        XCTAssertEqual(wegramComposerPrimaryInputItem([close]), close)
        XCTAssertEqual(wegramComposerShortcutItems([close], hasScheduledMessages: true, isTextEmpty: true), [.scheduledMessages])
        XCTAssertFalse(wegramComposerSupportsAccessoryItems([open]))
        XCTAssertFalse(wegramComposerSupportsAccessoryItems([input, close]))
        XCTAssertFalse(wegramComposerSupportsAccessoryItems([input, open, open]))
        XCTAssertNil(wegramComposerPrimaryInputItem([]))
    }

    func testBotMenuTracksCommandsStateWebAppConfigurationAndEditing() {
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        let menu = BotMenuButton.webView(text: "Example app", url: "https://example.com/app")
        let open = wegramComposerShortcutActions([input], hasScheduledMessages: false, isTextEmpty: false, hasSendAsPeers: false, botMenuButton: menu)
        XCTAssertEqual(open, [.botMenu(menu, showCommands: false)])
        XCTAssertNotEqual(open, wegramComposerShortcutActions([input], hasScheduledMessages: false, isTextEmpty: false, hasSendAsPeers: false, botMenuButton: .webView(text: "Example app", url: "https://example.com/updated")))
        XCTAssertEqual(wegramComposerShortcutActions([input, .commands], hasScheduledMessages: false, isTextEmpty: true, hasSendAsPeers: false, botMenuButton: .commands, showBotCommands: true), [.accessory(.commands), .botMenu(.commands, showCommands: true)])
        XCTAssertEqual(wegramComposerShortcutActions([input], hasScheduledMessages: false, isTextEmpty: false, hasSendAsPeers: false), [])
        let edit = ChatEditInterfaceMessageState(content: .plaintext, mediaReference: nil)
        XCTAssertEqual(wegramComposerShortcutActions([input], hasScheduledMessages: false, isTextEmpty: true, hasSendAsPeers: false, editMessageState: edit, botMenuButton: menu), [.editMedia])
    }

    func testEditingKeepsMediaReplacementAndActualTimerWithoutUnrelatedSendActions() {
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        let items: [ChatTextInputAccessoryItem] = [input, .messageAutoremoveTimeout(60), .scheduledMessages, .commands]
        for content: ChatEditInterfaceMessageStateContent in [.plaintext, .media(mediaOptions: [.imageOrVideo]), .media(mediaOptions: [.file])] {
            let edit = ChatEditInterfaceMessageState(content: content, mediaReference: nil)
            XCTAssertEqual(wegramComposerShortcutActions(items, hasScheduledMessages: true, isTextEmpty: true, hasSendAsPeers: true, editMessageState: edit), [.accessory(.messageAutoremoveTimeout(60)), .editMedia])
        }
        let restricted = ChatEditInterfaceMessageState(content: .media(mediaOptions: []), mediaReference: nil)
        XCTAssertEqual(wegramComposerShortcutActions([input], hasScheduledMessages: true, isTextEmpty: false, hasSendAsPeers: true, editMessageState: restricted), [])
    }

    func testSendAsEntryRemainsReachableWithDraftAndTracksActualPeerAvailability() {
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        XCTAssertEqual(wegramComposerShortcutActions([input, .silentPost(true)], hasScheduledMessages: true, isTextEmpty: true, hasSendAsPeers: true), [.accessory(.silentPost(true)), .accessory(.scheduledMessages), .sendAs])
        XCTAssertEqual(wegramComposerShortcutActions([input, .silentPost(true)], hasScheduledMessages: false, isTextEmpty: false, hasSendAsPeers: true), [.sendAs])
        XCTAssertEqual(wegramComposerShortcutActions([input], hasScheduledMessages: false, isTextEmpty: false, hasSendAsPeers: false), [])
    }

    func testPublishingShortcutsTrackActualStateAndRejectDuplicates() {
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        for silent in [false, true] {
            let post = ChatTextInputAccessoryItem.silentPost(silent)
            XCTAssertTrue(wegramComposerSupportsAccessoryItems([input, post, .suggestPost]))
            XCTAssertEqual(wegramComposerShortcutItems([input, post, .suggestPost], hasScheduledMessages: true, isTextEmpty: true), [post, .suggestPost, .scheduledMessages])
            XCTAssertEqual(wegramComposerShortcutItems([input, post, .suggestPost], hasScheduledMessages: false, isTextEmpty: false), [.suggestPost])
            XCTAssertEqual(wegramComposerShortcutTitle(post, strings: defaultPresentationStrings, isSelfChat: false), silent ? defaultPresentationStrings.VoiceOver_SilentPostOn : defaultPresentationStrings.VoiceOver_SilentPostOff)
        }
        XCTAssertEqual(wegramComposerShortcutItems([input], hasScheduledMessages: false, isTextEmpty: true), [])
        XCTAssertFalse(wegramComposerSupportsAccessoryItems([input, .silentPost(false), .silentPost(true)]))
        XCTAssertFalse(wegramComposerSupportsAccessoryItems([input, .suggestPost, .suggestPost]))
        XCTAssertFalse(wegramComposerSupportsAccessoryItems([.suggestPost]))
    }

    func testSlowmodeBoostEntryRequiresCurrentRestrictionAndTracksRequiredCount() {
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        let slowmode = ChatSlowmodeState(timeout: 60, variant: .pendingMessages)
        for empty in [false, true] {
            XCTAssertEqual(wegramComposerShortcutActions([input], hasScheduledMessages: true, isTextEmpty: empty, hasSendAsPeers: false, slowmodeState: slowmode, boostsToUnrestrict: 2), [.accessory(.scheduledMessages), .boostToUnrestrict(2)])
        }
        for count: Int32? in [nil, 0, -1] {
            XCTAssertEqual(wegramComposerShortcutActions([input], hasScheduledMessages: false, isTextEmpty: true, hasSendAsPeers: false, slowmodeState: slowmode, boostsToUnrestrict: count), [])
        }
        XCTAssertEqual(wegramComposerShortcutActions([input], hasScheduledMessages: false, isTextEmpty: false, hasSendAsPeers: false, boostsToUnrestrict: 2), [])
        let old = wegramComposerShortcutActions([input], hasScheduledMessages: false, isTextEmpty: false, hasSendAsPeers: false, slowmodeState: slowmode, boostsToUnrestrict: 2)
        let current = wegramComposerShortcutActions([input], hasScheduledMessages: false, isTextEmpty: false, hasSendAsPeers: false, slowmodeState: slowmode, boostsToUnrestrict: 1)
        XCTAssertFalse(current.contains(old[0]))
        let edit = ChatEditInterfaceMessageState(content: .plaintext, mediaReference: nil)
        XCTAssertEqual(wegramComposerShortcutActions([input], hasScheduledMessages: false, isTextEmpty: true, hasSendAsPeers: false, editMessageState: edit, slowmodeState: slowmode, boostsToUnrestrict: 2), [.editMedia])
    }

    func testOnlyEstablishedSecretChatUsesWegramComposerAndKeepsTheCurrentLifetimeAction() {
        let secret = TelegramSecretChat(id: PeerId(namespace: Namespaces.Peer.SecretChat, id: ._internalFromInt64Value(11)), creationDate: 0, regularPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(22)), accessHash: 0, role: .creator, embeddedState: .handshake, messageAutoremoveTimeout: nil)
        XCTAssertFalse(wegramComposerSupportsSecretChat(secret))
        let active = secret.withUpdatedEmbeddedState(.active)
        XCTAssertTrue(wegramComposerSupportsSecretChat(active))
        XCTAssertFalse(wegramComposerSupportsSecretChat(active.withUpdatedEmbeddedState(.terminated)))
        XCTAssertTrue(wegramComposerSupportsSecretChat(nil))
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        for timeout: Int32? in [nil, 1, 30, 60, 3600, 604800] {
            let peer = active.withUpdatedMessageAutoremoveTimeout(timeout)
            let timer = ChatTextInputAccessoryItem.messageAutoremoveTimeout(peer.messageAutoremoveTimeout)
            let items = [input, timer]
            XCTAssertTrue(wegramComposerSupportsAccessoryItems(items))
            for empty in [true, false] {
                let actualItems = empty ? items : [input]
                let actions = wegramComposerShortcutActions(actualItems, hasScheduledMessages: false, isTextEmpty: empty, hasSendAsPeers: false, secretChat: peer)
                XCTAssertEqual(actions, [.accessory(timer)])
                if let timeout {
                    XCTAssertEqual(wegramComposerShortcutTitle(timer, strings: defaultPresentationStrings, isSelfChat: false), defaultPresentationStrings.VoiceOver_SelfDestructTimerOn(timeIntervalString(strings: defaultPresentationStrings, value: timeout)).string)
                } else {
                    XCTAssertEqual(wegramComposerShortcutTitle(timer, strings: defaultPresentationStrings, isSelfChat: false), defaultPresentationStrings.VoiceOver_SelfDestructTimerOff)
                }
            }
        }
        let old = WegramComposerShortcut.accessory(.messageAutoremoveTimeout(30))
        let updated = wegramComposerShortcutActions([input, .messageAutoremoveTimeout(30)], hasScheduledMessages: false, isTextEmpty: false, hasSendAsPeers: false, secretChat: active.withUpdatedMessageAutoremoveTimeout(60))
        XCTAssertEqual(updated, [.accessory(.messageAutoremoveTimeout(60))])
        XCTAssertFalse(updated.contains(old))
    }

    func testScheduledSubjectKeepsComposerWithoutRecursiveQueueOrUnrelatedSlowmodeBoost() {
        XCTAssertTrue(wegramComposerSupportsSubject(nil))
        XCTAssertTrue(wegramComposerSupportsSubject(.scheduledMessages))
        XCTAssertFalse(wegramComposerSupportsSubject(.pinnedMessages(id: nil)))
        XCTAssertTrue(wegramComposerSupportsSubject(.message(id: .timestamp(60), highlight: nil, timecode: nil, setupReply: false)))
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        let items: [ChatTextInputAccessoryItem] = [input, .scheduledMessages, .messageAutoremoveTimeout(60)]
        let slowmode = ChatSlowmodeState(timeout: 60, variant: .pendingMessages)
        for empty in [false, true] {
            XCTAssertEqual(wegramComposerShortcutActions(items, hasScheduledMessages: true, isTextEmpty: empty, hasSendAsPeers: true, slowmodeState: slowmode, boostsToUnrestrict: 2, subject: .scheduledMessages), [.accessory(.messageAutoremoveTimeout(60)), .sendAs])
            let ordinary = wegramComposerShortcutActions(items, hasScheduledMessages: true, isTextEmpty: empty, hasSendAsPeers: true, slowmodeState: slowmode, boostsToUnrestrict: 2)
            XCTAssertTrue(ordinary.contains(.accessory(.scheduledMessages)))
            XCTAssertTrue(ordinary.contains(.boostToUnrestrict(2)))
        }
        let edit = ChatEditInterfaceMessageState(content: .plaintext, mediaReference: nil)
        XCTAssertEqual(wegramComposerShortcutActions(items, hasScheduledMessages: true, isTextEmpty: true, hasSendAsPeers: true, editMessageState: edit, subject: .scheduledMessages), [.accessory(.messageAutoremoveTimeout(60)), .editMedia])
    }

    func testMessageLocatorUsesOrdinaryComposerAndKeepsItsHiddenActions() {
        let id = MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(42)), namespace: Namespaces.Message.Cloud, id: 123)
        let subjects: [ChatControllerSubject] = [
            .message(id: .id(id), highlight: nil, timecode: nil, setupReply: false),
            .message(id: .id(id), highlight: .init(quote: nil), timecode: 63.5, setupReply: true),
            .message(id: .timestamp(60), highlight: nil, timecode: nil, setupReply: false)
        ]
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        let items: [ChatTextInputAccessoryItem] = [input, .messageAutoremoveTimeout(60)]
        for subject in subjects {
            XCTAssertTrue(wegramComposerSupportsSubject(subject), "Opening a message must keep the ordinary chat composer")
            XCTAssertEqual(wegramComposerShortcutActions(items, hasScheduledMessages: true, isTextEmpty: false, hasSendAsPeers: true, subject: subject), [.accessory(.messageAutoremoveTimeout(60)), .accessory(.scheduledMessages), .sendAs])
        }
        XCTAssertFalse(wegramComposerSupportsSubject(.pinnedMessages(id: id)))
    }

    func testStreamingStopRemainsReachableWithTextAndEditingAndDisappearsWhenFinished() {
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        let timer = ChatTextInputAccessoryItem.messageAutoremoveTimeout(60)
        for empty in [false, true] {
            for edit: ChatEditInterfaceMessageState? in [nil, .init(content: .plaintext, mediaReference: nil)] {
                let actions = wegramComposerShortcutActions([input, timer], hasScheduledMessages: true, isTextEmpty: empty, hasSendAsPeers: true, editMessageState: edit, canStopIncomingStreamingMessage: true)
                XCTAssertEqual(actions.first, .stopIncomingStreamingMessage, "Stopping an incoming stream must stay reachable before other extensions")
                XCTAssertTrue(actions.contains(.accessory(timer)))
                if edit == nil {
                    XCTAssertTrue(actions.contains(.accessory(.scheduledMessages)))
                    XCTAssertTrue(actions.contains(.sendAs))
                } else {
                    XCTAssertTrue(actions.contains(.editMedia))
                }
                let finished = wegramComposerShortcutActions([input, timer], hasScheduledMessages: true, isTextEmpty: empty, hasSendAsPeers: true, editMessageState: edit, canStopIncomingStreamingMessage: false)
                XCTAssertFalse(finished.contains(.stopIncomingStreamingMessage), "A stale menu cannot stop after the upstream flag clears")
                XCTAssertEqual(actions.filter { $0 != .stopIncomingStreamingMessage }, finished)
            }
        }
    }

    func testUnsupportedControlsAndIncompleteStatesKeepTheOriginalLayout() {
        let input = ChatTextInputAccessoryItem.input(isEnabled: true, inputMode: .emoji)
        let unsupported: [ChatTextInputAccessoryItem] = [.botInput(isEnabled: true, inputMode: .keyboard), .botInput(isEnabled: true, inputMode: .emoji), .botInput(isEnabled: true, inputMode: .stickers)]
        for item in unsupported {
            XCTAssertFalse(wegramComposerSupportsAccessoryItems([input, item]))
            XCTAssertFalse(wegramComposerSupportsAccessoryItems([input, .scheduledMessages, item]))
        }
        for items: [ChatTextInputAccessoryItem] in [[], [.scheduledMessages], [input, input], [input, .scheduledMessages, .scheduledMessages], [input, .commands, .commands], [input, .gift, .gift], [input, .messageAutoremoveTimeout(nil), .messageAutoremoveTimeout(60)]] {
            XCTAssertFalse(wegramComposerSupportsAccessoryItems(items))
        }
    }
}
