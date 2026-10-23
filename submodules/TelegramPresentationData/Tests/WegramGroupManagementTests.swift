import XCTest
import UIKit
import Postbox
import TelegramCore

final class WegramGroupManagementTests: XCTestCase {
    private func group(role: TelegramGroupRole, membership: TelegramGroupMembership = .Member) -> EnginePeer {
        .legacyGroup(TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: ._internalFromInt64Value(8)), title: "Fixture", photo: [], participantCount: 3, role: role, membership: membership, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0))
    }
    private func channel(flags: TelegramChannelFlags = [], admin: Bool = false, rights: TelegramChatAdminRights? = nil, participation: TelegramChannelParticipationStatus = .member, broadcast: Bool = false) -> EnginePeer {
        .channel(TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: ._internalFromInt64Value(9)), accessHash: nil, title: "Fixture", username: nil, photo: [], creationDate: 0, version: 0, participationStatus: participation, info: broadcast ? .broadcast(.init(flags: [])) : .group(.init(flags: [])), flags: flags, restrictionInfo: nil, adminRights: rights ?? (admin ? TelegramChatAdminRights(rights: []) : nil), bannedRights: nil, defaultBannedRights: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil))
    }
    func testManagementUsesOriginalAdminEligibilityAndKeepsGigagroupPermissionRestriction() {
        let basic: [WegramGroupManagementAction] = [.administrators, .permissions, .more]
        XCTAssertEqual(wegramGroupManagementActions(peer: self.group(role: .creator(rank: nil))), basic)
        XCTAssertEqual(wegramGroupManagementActions(peer: self.group(role: .admin(TelegramChatAdminRights(rights: []), rank: nil))), basic)
        XCTAssertTrue(wegramGroupManagementActions(peer: self.group(role: .member), pendingRequests: 4).isEmpty)
        XCTAssertEqual(wegramGroupManagementActions(peer: self.channel(flags: [.isCreator]), pendingRequests: 5), [.administrators, .permissions, .requests, .more])
        XCTAssertEqual(wegramGroupManagementActions(peer: self.channel(admin: true)), basic)
        XCTAssertTrue(wegramGroupManagementActions(peer: self.channel()).isEmpty)
        XCTAssertEqual(wegramGroupManagementActions(peer: self.channel(flags: [.isCreator, .isGigagroup])), [.administrators, .more])
        for flags: TelegramChannelFlags in [[.isCreator, .isVerified], [.isCreator, .isScam], [.isCreator, .isFake], [.isCreator, .isForum], [.isCreator, .isMonoforum]] {
            XCTAssertTrue(wegramGroupManagementActions(peer: self.channel(flags: flags)).isEmpty)
        }
        XCTAssertTrue(wegramGroupManagementActions(peer: self.channel(flags: [.isCreator], participation: .left)).isEmpty)
        XCTAssertTrue(wegramGroupManagementActions(peer: self.channel(flags: [.isCreator], broadcast: true)).isEmpty)
        XCTAssertTrue(wegramGroupManagementActions(peer: nil).isEmpty)
    }
    func testRequestEntryRequiresInvitePermissionEvenWhenAnOldPendingCountRemains() {
        let basic: [WegramGroupManagementAction] = [.administrators, .permissions, .more]
        let rights = TelegramChatAdminRights(rights: [.canInviteUsers])
        XCTAssertEqual(wegramGroupManagementActions(peer: self.channel(admin: true), pendingRequests: 8), basic)
        XCTAssertEqual(wegramGroupManagementActions(peer: self.group(role: .admin(TelegramChatAdminRights(rights: []), rank: nil)), pendingRequests: 8), basic)
        XCTAssertTrue(wegramGroupManagementActions(peer: self.channel(rights: rights), pendingRequests: 8).contains(.requests))
        XCTAssertTrue(wegramGroupManagementActions(peer: self.group(role: .admin(rights, rank: nil)), pendingRequests: 8).contains(.requests))
        XCTAssertEqual(wegramGroupManagementActions(peer: self.channel(admin: true), pendingRequests: 8), basic, "Revoked invite permission must reject a stale request action")
    }

    func testGroupManagementEntryPreservesPendingCountAndDisappearsAfterPermissionRevocation() throws {
        let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        var data = WegramGroupContent(name: "Fixture", about: "", members: [.init(id: 1, name: "Member")], memberCount: 1, canAddMembers: false, hasMoreMembers: false, canShowQRCode: false, isPinned: nil, pinIsBusy: false, isMuted: false, canManageGroup: true, managementRequestCount: 7)
        var actions: [WegramGroupContentView.Action] = []
        view.open = { actions.append($0) }
        func update() {
            view.update(data, dark: false, fontSize: 17, chinese: true, statusHeight: 59, bottomInset: 34)
            view.layoutIfNeeded(); view.table.layoutIfNeeded()
        }
        update()
        let path = IndexPath(row: 2, section: 0)
        let cell = try XCTUnwrap(view.table.cellForRow(at: path))
        XCTAssertEqual(cell.textLabel?.text, "群管理")
        XCTAssertEqual(cell.accessibilityValue, "7")
        view.tableView(view.table, didSelectRowAt: path)
        XCTAssertEqual(actions, [.management])
        data.canManageGroup = false
        update()
        view.tableView(view.table, didSelectRowAt: path)
        XCTAssertEqual(actions, [.management])
    }
    func testExistingManagementPageReflowsLargeEnglishRowsAfterWidthChanges() throws {
        let view = WegramGroupManagementView(frame: CGRect(x: 0, y: 0, width: 720, height: 400))
        view.update(actions: [.administrators, .permissions, .more], pendingRequests: 0, dark: false, fontSize: 34, chinese: false)
        view.layoutIfNeeded(); view.table.layoutIfNeeded()
        let path = IndexPath(row: 0, section: 0)
        let wideHeight = try XCTUnwrap(view.table.cellForRow(at: path)).bounds.height
        view.frame.size.width = 320
        view.setNeedsLayout(); view.layoutIfNeeded(); view.table.layoutIfNeeded()
        let cell = try XCTUnwrap(view.table.cellForRow(at: path))
        let label = try XCTUnwrap(cell.textLabel)
        let needed = (label.text! as NSString).boundingRect(with: CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: label.font!], context: nil).height
        XCTAssertGreaterThan(cell.bounds.height, wideHeight)
        XCTAssertGreaterThanOrEqual(label.frame.height, ceil(needed) - 1)
    }

    func testManagementRowsKeepActionsCountsAndLargeTextReachable() throws {
        for dark in [false, true] {
            for width: CGFloat in [320, 402, 720] {
                for font: CGFloat in [17, 34] {
                    let view = WegramGroupManagementView(frame: CGRect(x: 0, y: 0, width: width, height: 350))
                    let actions: [WegramGroupManagementAction] = [.administrators, .permissions, .requests, .more]
                    var selected: [WegramGroupManagementAction] = []
                    view.open = { selected.append($0) }
                    view.update(actions: actions, pendingRequests: 7, dark: dark, fontSize: font, chinese: false)
                    view.layoutIfNeeded(); view.table.layoutIfNeeded()
                    let paths = [IndexPath(row: 0, section: 0), IndexPath(row: 1, section: 0), IndexPath(row: 2, section: 0), IndexPath(row: 0, section: 1)]
                    for path in paths {
                        view.table.scrollToRow(at: path, at: .middle, animated: false)
                        view.table.layoutIfNeeded()
                        let cell = try XCTUnwrap(view.table.cellForRow(at: path))
                        let label = try XCTUnwrap(cell.textLabel)
                        let height = (label.text! as NSString).boundingRect(with: CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: label.font!], context: nil).height
                        XCTAssertGreaterThanOrEqual(label.frame.height, ceil(height) - 1)
                        XCTAssertGreaterThanOrEqual(cell.bounds.height, 56)
                        if path == paths[2] { XCTAssertEqual(cell.accessibilityValue, "7") }
                        view.tableView(view.table, didSelectRowAt: path)
                    }
                    XCTAssertEqual(selected, actions)
                    if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        view.table.setContentOffset(.zero, animated: false)
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1
                        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("group-management-\(dark ? "dark" : "light").png"))
                    }
                    view.update(actions: [.administrators, .more], pendingRequests: 0, dark: dark, fontSize: font, chinese: true)
                    view.tableView(view.table, didSelectRowAt: paths[2])
                    XCTAssertEqual(selected, actions)
                    view.isHidden = true
                    view.tableView(view.table, didSelectRowAt: paths[0])
                    XCTAssertEqual(selected, actions)
                }
            }
        }
    }
}
