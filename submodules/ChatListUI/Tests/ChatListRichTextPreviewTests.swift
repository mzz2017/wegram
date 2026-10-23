import XCTest
import UIKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import TextFormat
import AppBundle
import ObjectiveC
import ItemListUI
import Display
import MergeLists
import ChatListSearchItemHeader
@testable import ChatListUI

final class ChatListRichTextPreviewTests: XCTestCase {
    // An unhosted XCTest runner has no app localization resources. Redirect only
    // these resource lookups to the test bundle; leave production bundle code intact.
    override class func setUp() {
        super.setUp()
        exchangeResourceLookups()
    }

    override class func tearDown() {
        exchangeResourceLookups()
        super.tearDown()
    }

    class func exchangeResourceLookups() {
        for (original, replacement) in [
            (#selector(Bundle.path(forResource:ofType:)), #selector(Bundle.previewResourcePath(_:ofType:))),
            (#selector(Bundle.path(forResource:ofType:inDirectory:forLocalization:)), #selector(Bundle.previewLocalizedResourcePath(_:ofType:inDirectory:forLocalization:)))
        ] {
            method_exchangeImplementations(class_getInstanceMethod(Bundle.self, original)!, class_getInstanceMethod(Bundle.self, replacement)!)
        }
    }

    private let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(123))
    private let dateFormat = PresentationDateTimeFormat(timeFormat: .military, dateFormat: .dayFirst, dateSeparator: ".", dateSuffix: "", requiresFullYear: false, decimalSeparator: ".", groupingSeparator: "")

    private func message(_ text: String = "", blocks: [InstantPageBlock]? = nil, media: [EngineMedia] = [], extraAttributes: [MessageAttribute] = []) -> EngineMessage {
        let attributes: [MessageAttribute] = blocks.map { [RichTextMessageAttribute(instantPage: InstantPage(blocks: $0, media: [:], isComplete: true, rtl: false, url: "", views: nil), fullInstantPage: nil)] } ?? []
        return EngineMessage(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: text, attributes: attributes + extraAttributes, media: media, peers: [:], associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
    }

    private func selected(_ messages: [EngineMessage]) -> (String, NSAttributedString?) {
        let value = chatListItemStrings(strings: defaultPresentationStrings, nameDisplayOrder: .firstLast, dateTimeFormat: dateFormat, contentSettings: .default, messages: messages, chatPeer: EngineRenderedPeer(peerId: peerId, peers: [:], associatedMedia: [:]), accountPeerId: peerId)
        return (value.messageText, value.richTextPreview)
    }

    func testLocalizationResourcesAvailable() {
        XCTAssertNotNil(getAppBundle().path(forResource: "PresentationStrings", ofType: "data"))
        XCTAssertNotNil(getAppBundle().path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en"))
    }

    func testFirstNonemptyCandidateWins() {
        let rich = message(blocks: [.paragraph(.textSpoiler(text: .plain("first")))])
        for second in [message("second"), message(blocks: [.paragraph(.plain("second"))])] {
            let value = selected([rich, second])
            XCTAssertEqual(value.0, "first")
            XCTAssertEqual(value.1?.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 0, effectiveRange: nil) as? Bool, true)
        }
        let plain = selected([message("plain"), rich])
        XCTAssertEqual(plain.0, "plain")
        XCTAssertNil(plain.1)
    }

    func testEmptyRichFallsBackToMessageText() {
        XCTAssertEqual(selected([message("fallback", blocks: [])]).0, "fallback")
        XCTAssertEqual(selected([message(blocks: []), message("later")]).0, "later")
    }

    func testOverrideDiscardsPreviewEvenWhenTextMatches() {
        let media = EngineMedia(TelegramMediaAction(action: .customText(text: "same", entities: [], additionalAttributes: nil)))
        let result = selected([message(blocks: [.paragraph(.textSpoiler(text: .plain("same")))], media: [media])])
        XCTAssertEqual(result.0, "same")
        XCTAssertNil(result.1)
    }

    func testSameTextDifferentAttributesAndSpoilerOverlay() {
        let plain = NSAttributedString(string: "code 12345")
        let rich = NSMutableAttributedString(attributedString: plain)
        rich.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), value: true, range: NSRange(location: 0, length: 4))
        func compose(_ text: NSAttributedString) -> NSAttributedString {
            return chatListRichTextPreview(text, font: .systemFont(ofSize: 15), italicFont: .italicSystemFont(ofSize: 15), textColor: .black, additionalSpoilers: [NSRange(location: 5, length: 5), NSRange(location: Int.max, length: Int.max)])
        }
        let a = compose(plain)
        let b = compose(rich)
        XCTAssertNil(a.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 0, effectiveRange: nil))
        XCTAssertEqual(b.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 0, effectiveRange: nil) as? Bool, true)
        XCTAssertEqual(b.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 5, effectiveRange: nil) as? Bool, true)
    }

    func testAccessibilityIconProjection() {
        let result = selected([message(blocks: [.formula(latex: "x")])])
        XCTAssertEqual(result.0, "\u{fffc}")
        XCTAssertEqual(result.1.map(instantPagePreviewPlainText), "[formula]")
        XCTAssertEqual(result.1?.string, "\u{fffc}")
    }

    func testSharedDescriptionPrefersRichContentOverFallbackText() {
        let message = message("fallback", blocks: [.paragraph(.textSpoiler(text: .plain("rich")))])
        let (text, _, isPlainText) = descriptionStringForMessage(contentSettings: .default, message: message, strings: defaultPresentationStrings, nameDisplayOrder: .firstLast, dateTimeFormat: dateFormat, accountPeerId: peerId)
        XCTAssertEqual(text.string, "rich")
        XCTAssertFalse(isPlainText)
        XCTAssertEqual(text.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 0, effectiveRange: nil) as? Bool, true)
    }

    func testRestrictionOverridesRichContent() {
        let restricted = message("fallback", blocks: [.paragraph(.plain("rich"))], extraAttributes: [RestrictedContentMessageAttribute(rules: [RestrictionRule(platform: "ios", reason: "copyright", text: "Restricted")])])
        let result = selected([restricted])
        XCTAssertEqual(result.0, "Restricted")
        XCTAssertNil(result.1)
        let description = descriptionStringForMessage(contentSettings: .default, message: restricted, strings: defaultPresentationStrings, nameDisplayOrder: .firstLast, dateTimeFormat: dateFormat, accountPeerId: peerId)
        XCTAssertEqual(description.0.string, "Restricted")
    }
}

private extension Bundle {
    @objc func previewResourcePath(_ name: String?, ofType type: String?) -> String? {
        if name == "PresentationStrings", type == "data", self == getAppBundle() {
            return Bundle(for: ChatListRichTextPreviewTests.self).previewResourcePath(name, ofType: type)
        }
        return self.previewResourcePath(name, ofType: type)
    }

    @objc func previewLocalizedResourcePath(_ name: String?, ofType type: String?, inDirectory directory: String?, forLocalization localization: String?) -> String? {
        if name == "Localizable", type == "strings", self == getAppBundle() {
            return Bundle(for: ChatListRichTextPreviewTests.self).previewLocalizedResourcePath(name, ofType: type, inDirectory: directory, forLocalization: localization)
        }
        return self.previewLocalizedResourcePath(name, ofType: type, inDirectory: directory, forLocalization: localization)
    }
}


extension ChatListRichTextPreviewTests {
    private func searchPeer(_ id: Int64, bot: Bool = false) -> EnginePeer {
        return EnginePeer(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(id)), accessHash: nil, firstName: "Peer \(id)", lastName: nil, username: nil, phone: nil, photo: [], botInfo: bot ? BotUserInfo(flags: [], inlinePlaceholder: nil) : nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
    }

    private func localSearchEntry(_ id: Int64, index: Int, expand: ChatListSearchSectionExpandType) -> ChatListSearchEntry {
        return .localPeer(self.searchPeer(id), nil, nil, index, defaultPresentationTheme, defaultPresentationStrings, .firstLast, .firstLast, expand, nil, false, false)
    }

    func testSearchFootersFollowTheirActualSectionsAndHaveStableIdentities() {
        let data = defaultPresentationData()
        let locals = (1...4).map { self.localSearchEntry(Int64($0), index: $0, expand: .none) }
        let global = ChatListSearchEntry.globalPeer(FoundPeer(peer: self.searchPeer(5), subscribers: nil), nil, 0, data.theme, data.strings, .firstLast, .firstLast, .collapse, nil, false, "peer")
        let add = ChatListSearchEntry.addContact("123", data.theme, data.strings)
        let entries = locals + [global, add]
        let results = wegramSearchEntriesWithPeerSections(entries, presentationData: data, contactIds: [], expandedSections: [])
        XCTAssertEqual(results.map(\.stableId), Array(locals.prefix(3)).map(\.stableId) + [.peerSectionFooter(.chats), global.stableId, .peerSectionFooter(.global), add.stableId])
        XCTAssertEqual(results.sorted().map(\.stableId), results.map(\.stableId))
        guard case .peerSectionFooter(.chats, false, _, _, _) = results[3], case .peerSectionFooter(.global, true, _, _, _) = results[5] else {
            return XCTFail("Footer must reflect each section's expand state")
        }
        let expanded = wegramSearchEntriesWithPeerSections(entries, presentationData: data, contactIds: [], expandedSections: [.chats])
        XCTAssertEqual(expanded[4].stableId, results[3].stableId)
        XCTAssertNotEqual(expanded[4], results[3])
        let (deletions, insertions, updates) = mergeListsStableWithUpdates(leftList: results, rightList: expanded)
        XCTAssertTrue(deletions.isEmpty)
        XCTAssertEqual(insertions.count, 1)
        XCTAssertEqual(insertions.first?.1.stableId, locals[3].stableId)
        XCTAssertTrue(updates.contains { $0.1.stableId == results[3].stableId })
        XCTAssertEqual(wegramSearchEntriesWithPeerSections(entries, presentationData: data, contactIds: [], expandedSections: []), results)
    }

    func testSearchFootersDisappearWithFilteredOrUnexpandablePeers() {
        let data = defaultPresentationData()
        XCTAssertTrue(wegramSearchEntriesWithPeerSections([], presentationData: data, contactIds: [], expandedSections: []).isEmpty)
        let local = self.localSearchEntry(1, index: 0, expand: .none)
        let add = ChatListSearchEntry.addContact("123", data.theme, data.strings)
        XCTAssertEqual(wegramSearchEntriesWithPeerSections([local, add], presentationData: data, contactIds: [], expandedSections: []).map(\.stableId), [local.stableId, add.stableId])
        XCTAssertEqual(wegramSearchEntriesWithPeerSections([add], presentationData: data, contactIds: [], expandedSections: [.chats]), [add])
    }

    func testSearchFooterLayoutKeepsLegacyGeometryAndGrowsForLargerText() {
        let data = ItemListPresentationData(defaultPresentationData())
        func item(wegram: Bool) -> ItemListDisclosureItem {
            return ItemListDisclosureItem(presentationData: data, icon: UIImage(systemName: "magnifyingglass"), title: "Show More", label: "", sectionId: 0, style: .plain, noInsets: true, usesWegramSearchFooterLayout: wegram, action: nil)
        }
        let node = ItemListDisclosureItemNode()
        let params = ListViewItemLayoutParams(width: 320, leftInset: 16, rightInset: 8, availableHeight: 640)
        let neighbors = ItemListNeighbors(top: .none, bottom: .none)
        let legacy = node.asyncLayout()(item(wegram: false), params, neighbors).0
        let row = item(wegram: true)
        let (layout, apply) = node.asyncLayout()(row, params, neighbors)
        node.contentSize = layout.contentSize
        node.insets = layout.insets
        node.frame = CGRect(origin: .zero, size: layout.contentSize)
        _ = node.view
        apply()
        XCTAssertGreaterThanOrEqual(layout.contentSize.height, 44)
        XCTAssertEqual(layout.contentSize.height, max(44, legacy.contentSize.height))
        XCTAssertEqual(layout.insets, .zero)
        XCTAssertEqual(node.subnodes?.first(where: { $0 is TextNode })?.frame.minX, 64, "Footer title must be 48pt from the safe content edge")
        node.recursivelyEnsureDisplaySynchronously(true)
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let rendered = UIGraphicsImageRenderer(size: node.bounds.size).image { context in
                UIColor.white.setFill()
                context.fill(node.bounds)
                node.view.layer.render(in: context.cgContext)
            }
            try? rendered.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("wegram-search-footer-light.png"))
        }
        XCTAssertNotEqual(item(wegram: false), row)
        let (_, restore) = node.asyncLayout()(item(wegram: false), params, neighbors)
        restore()
        XCTAssertEqual(node.subnodes?.first(where: { $0 is TextNode })?.frame.minX, 81, "Reusing the node must restore the original inset")
        let largeData = ItemListPresentationData(defaultPresentationData().withFontSizes(chatFontSize: .extraLargeX2, listsFontSize: .extraLargeX2))
        let largeRow = ItemListDisclosureItem(presentationData: largeData, title: "Show More", label: "", sectionId: 0, style: .plain, usesWegramSearchFooterLayout: true, action: nil)
        let (larger, _) = node.asyncLayout()(largeRow, params, neighbors)
        XCTAssertGreaterThanOrEqual(larger.contentSize.height, layout.contentSize.height)
    }

    private func searchChannel(_ id: Int64, group: Bool) -> EnginePeer {
        return EnginePeer(TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: ._internalFromInt64Value(id)), accessHash: nil, title: "Channel \(id)", username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: group ? .group(TelegramChannelGroupInfo(flags: [])) : .broadcast(TelegramChannelBroadcastInfo(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil))
    }

    private func localSearchEntry(peer: EnginePeer, index: Int) -> ChatListSearchEntry {
        return .localPeer(peer, nil, (2, true), index, defaultPresentationTheme, defaultPresentationStrings, .firstLast, .firstLast, .none, nil, true, false)
    }

    func testPeerSectionsUseRealContactMembershipAndPreserveTheOriginalPayloads() {
        let data = defaultPresentationData()
        let contact = self.searchPeer(1)
        let stranger = self.searchPeer(2)
        let bot = self.searchPeer(3, bot: true)
        let group = self.searchChannel(4, group: true)
        let broadcast = self.searchChannel(5, group: false)
        let legacy = EnginePeer(TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: ._internalFromInt64Value(6)), title: "Group", photo: [], participantCount: 2, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0))
        let peers = [broadcast, stranger, bot, group, contact, legacy]
        let entries = peers.enumerated().map { self.localSearchEntry(peer: $0.element, index: $0.offset) }
        let result = wegramSearchEntriesWithPeerSections(entries, presentationData: data, contactIds: [contact.id, bot.id], expandedSections: [])
        var sections: [WegramSearchPeerSection] = []
        for entry in result {
            guard case let .wegramPeer(section, original) = entry else { return XCTFail("Missing section wrapper") }
            sections.append(section)
            XCTAssertEqual(original, entries.first { $0.stableId == entry.stableId })
        }
        XCTAssertEqual(sections, [.contacts, .groups, .groups, .chats, .channels, .bots])
        XCTAssertEqual(Set(result.map(\.stableId)), Set(entries.map(\.stableId)))
        let changed = wegramSearchEntriesWithPeerSections([entries[1]], presentationData: data, contactIds: [stranger.id], expandedSections: [])
        guard case .wegramPeer(.contacts, _) = changed.first else { return XCTFail("New contact relationship must update the section") }
        XCTAssertEqual(changed.first?.stableId, entries[1].stableId)
    }

    func testEachPeerSectionExpandsIndependentlyIncludingMatchingRecentPeers() {
        let data = defaultPresentationData()
        let contacts = (1...4).map { self.localSearchEntry(Int64($0), index: $0, expand: .none) }
        let groups = (5...8).map { self.localSearchEntry(peer: self.searchChannel(Int64($0), group: true), index: $0) }
        let recentPeer = self.searchPeer(9)
        let recent = ChatListSearchEntry.recentlySearchedPeer(recentPeer, nil, nil, 0, data.theme, data.strings, .firstLast, .firstLast, nil, false)
        let ids = Set((1...4).map { self.searchPeer(Int64($0)).id } + [recentPeer.id])
        let entries = [recent] + contacts + groups
        func results(_ expanded: Set<WegramSearchPeerSection>) -> [ChatListSearchEntry] {
            return wegramSearchEntriesWithPeerSections(entries, presentationData: data, contactIds: ids, expandedSections: expanded)
        }
        func count(_ section: WegramSearchPeerSection, in entries: [ChatListSearchEntry]) -> Int {
            return entries.filter { if case let .wegramPeer(value, _) = $0 { return value == section }; return false }.count
        }
        let collapsed = results([])
        XCTAssertEqual(count(.contacts, in: collapsed), 3)
        XCTAssertEqual(count(.groups, in: collapsed), 3)
        XCTAssertEqual(collapsed.first?.stableId, recent.stableId)
        let expanded = results([.groups])
        XCTAssertEqual(count(.contacts, in: expanded), 3)
        XCTAssertEqual(count(.groups, in: expanded), 4)
        let (removed, inserted, _) = mergeListsStableWithUpdates(leftList: collapsed, rightList: expanded)
        XCTAssertTrue(removed.isEmpty)
        XCTAssertEqual(inserted.count, 1)
        XCTAssertEqual(results([]), collapsed)
        XCTAssertEqual(count(.contacts, in: results([.contacts, .groups])), 5)
        XCTAssertEqual(WegramSearchPeerSection.contacts.actionTitle(expanded: false, strings: data.strings), "More Contacts")
        XCTAssertEqual(WegramSearchPeerSection.groups.actionTitle(expanded: true, strings: data.strings), "Fewer Groups")
    }


    func testSectionTitlesUseChineseLabelsAndRegularEnglishCasingInTheActualHeader() {
        let chinese = PresentationStrings(primaryComponent: PresentationStrings.Component(languageCode: "zh-Hans", localizedName: "简体中文", pluralizationRulesCode: nil, dict: [:]), secondaryComponent: defaultPresentationStrings.primaryComponent, groupingSeparator: "")
        let expected: [(WegramSearchPeerSection, String, String)] = [(.contacts, "Contacts", "联系人"), (.groups, "Groups", "群聊"), (.chats, "Chats", "聊天"), (.channels, "Channels", "频道"), (.bots, "Bots", "机器人")]
        func labels(in view: UIView) -> [UILabel] {
            return (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
        }
        for (section, english, zh) in expected {
            for (strings, title) in [(defaultPresentationStrings, english), (chinese, zh)] {
                let header = ChatListSearchItemHeader(type: section.headerType(strings: strings), theme: defaultPresentationTheme, strings: strings, usesWegramAppearance: true)
                let node = header.node(synchronousLoad: true)
                node.frame = CGRect(x: 0, y: 0, width: 402, height: header.height)
                node.updateLayout(size: node.bounds.size, leftInset: 0, rightInset: 0, transition: .immediate)
                let label = labels(in: node.view).first { $0.text == title }
                XCTAssertNotNil(label)
                XCTAssertEqual(label?.font.pointSize, 14)
                XCTAssertEqual(label?.frame.minX, 16)
                XCTAssertEqual(header.height, 40)
            }
        }
        XCTAssertEqual(WegramSearchPeerSection.contacts.actionTitle(expanded: false, strings: chinese), "更多联系人")
        XCTAssertEqual(WegramSearchPeerSection.groups.actionTitle(expanded: true, strings: chinese), "收起群聊")
    }


    private func historyEntry(peer: EnginePeer, id: Int32, text: String = "match", selected: Bool? = nil, section: ChatListSearchEntry.MessageSection = .generic, customHeader: Bool = false) -> ChatListSearchEntry {
        let data = defaultPresentationData()
        let presentation = ChatListPresentationData(theme: data.theme, fontSize: data.listsFontSize, strings: data.strings, dateTimeFormat: data.dateTimeFormat, nameSortOrder: data.nameSortOrder, nameDisplayOrder: data.nameDisplayOrder, disableAnimations: true)
        let message = EngineMessage(stableId: UInt32(id), stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: id), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: id, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: text, attributes: [], media: [], peers: [peer.id: peer], associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
        return .message(message, EngineRenderedPeer(peer: peer), nil, nil, presentation, 200, selected, customHeader, .index(message.index), nil, section, false, nil, false, .everywhere)
    }

    func testMessageOverviewGroupsLoadedResultsWithoutInventingCountsOrLosingTheRepresentative() {
        let peers = (1...4).map { self.searchPeer(Int64($0)) }
        let newest = self.historyEntry(peer: peers[0], id: 10, text: "latest match")
        let older = self.historyEntry(peer: peers[0], id: 9)
        let entries = [newest, older] + peers.dropFirst().enumerated().map { self.historyEntry(peer: $0.element, id: Int32(8 - $0.offset)) }
        let result = wegramSearchMessageOverview(entries.sorted(), presentationData: defaultPresentationData())
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result.prefix(3).map(\.stableId), peers.prefix(3).map { .messageGroup($0.id) })
        XCTAssertEqual(result.last?.stableId, .messageOverviewFooter)
        XCTAssertEqual(result.first?.representativeMessageEntry, newest)
        XCTAssertEqual(Set(result.map(\.stableId)).count, result.count)
        guard case let .wegramMessageGroup(_, original) = result[0] else { return XCTFail("Not a real grouped message") }
        XCTAssertEqual(original, newest)
    }

    func testMessageOverviewLeavesPublicPostsSelectionAndCustomHeadersOnTheirOriginalPaths() {
        let peer = self.searchPeer(1)
        let publicPost = self.historyEntry(peer: peer, id: 1, section: .publicPosts)
        let selected = self.historyEntry(peer: peer, id: 2, selected: false)
        let custom = self.historyEntry(peer: peer, id: 3, customHeader: true)
        let entries = [publicPost, selected, custom].sorted()
        XCTAssertEqual(wegramSearchMessageOverview(entries, presentationData: defaultPresentationData()), entries)
        XCTAssertTrue(wegramSearchMessageOverview([], presentationData: defaultPresentationData()).isEmpty)
    }

    func testNewRepresentativeUpdatesTheSameConversationIdentity() {
        let peer = self.searchPeer(1)
        let data = defaultPresentationData()
        let old = wegramSearchMessageOverview([self.historyEntry(peer: peer, id: 1)], presentationData: data)
        let updated = wegramSearchMessageOverview([self.historyEntry(peer: peer, id: 2), self.historyEntry(peer: peer, id: 1)], presentationData: data)
        XCTAssertEqual(old.first?.stableId, updated.first?.stableId)
        let (removed, inserted, updates) = mergeListsStableWithUpdates(leftList: old, rightList: updated)
        XCTAssertTrue(removed.isEmpty)
        XCTAssertTrue(inserted.isEmpty)
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.1.stableId, .messageGroup(peer.id))
    }

    func testHistoryFilterPreservesOtherOptionsAndCanBeRemovedWithoutClearingThem() {
        let peer = self.searchPeer(1)
        let initial = ChatListSearchOptions(peer: nil, date: nil, folder: nil)
        XCTAssertTrue(initial.isEmpty)
        let history = initial.withUpdatedWegramMessagesOnly(true)
        XCTAssertFalse(history.isEmpty)
        let scoped = history.withUpdatedPeer((peer.id, false, "Peer")).withUpdatedDate((nil, 100, "Date")).withUpdatedFolder((1, "Folder"))
        XCTAssertTrue(scoped.wegramMessagesOnly)
        let restored = scoped.withUpdatedWegramMessagesOnly(false)
        XCTAssertEqual(restored.peer?.0, peer.id)
        XCTAssertEqual(restored.date?.1, 100)
        XCTAssertEqual(restored.folder?.0, 1)
        XCTAssertFalse(restored.wegramMessagesOnly)
        XCTAssertTrue(history.withUpdatedWegramMessagesOnly(false).isEmpty)
    }


    func testFullHistoryUsesOnlyMatchingMessagesAndRetainsLoadingAndEmptyRows() {
        let data = defaultPresentationData()
        let presentation = ChatListPresentationData(theme: data.theme, fontSize: data.listsFontSize, strings: data.strings, dateTimeFormat: data.dateTimeFormat, nameSortOrder: data.nameSortOrder, nameDisplayOrder: data.nameDisplayOrder, disableAnimations: true)
        let peer = self.searchPeer(1)
        let actual = self.historyEntry(peer: peer, id: 3)
        let publicPost = self.historyEntry(peer: peer, id: 2, section: .publicPosts)
        let loading = ChatListSearchEntry.messagePlaceholder(0, presentation, .everywhere)
        let empty = ChatListSearchEntry.emptyMessagesFooter(presentation, .everywhere, "match")
        let original = [self.localSearchEntry(2, index: 0, expand: .none), actual, publicPost, loading, empty]
        XCTAssertEqual(wegramSearchMessageResultsOnly(original), [actual, loading, empty])
        XCTAssertEqual(wegramSearchMessageResultsOnly([publicPost]), [])
    }

}
