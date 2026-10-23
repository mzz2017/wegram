import XCTest
import UIKit
import Display
import TelegramCore
import AvatarNode
import TelegramPresentationData

final class WegramMeViewTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }
    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }

    private func data(_ language: String, dark: Bool = false) -> PresentationData {
        let data = defaultPresentationData().withUpdated(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme)
        let strings = PresentationStrings(primaryComponent: PresentationStrings.Component(languageCode: language, localizedName: language, pluralizationRulesCode: nil, dict: [:]), secondaryComponent: nil, groupingSeparator: ",")
        return PresentationData(strings: strings, theme: data.theme, autoNightModeTriggered: data.autoNightModeTriggered, chatWallpaper: data.chatWallpaper, chatFontSize: data.chatFontSize, chatBubbleCorners: data.chatBubbleCorners, listsFontSize: data.listsFontSize, dateTimeFormat: data.dateTimeFormat, nameDisplayOrder: data.nameDisplayOrder, nameSortOrder: data.nameSortOrder, reduceMotion: data.reduceMotion, largeEmoji: data.largeEmoji)
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(self.descendants)
    }

    private func activate(_ button: UIButton) throws {
        let target = try XCTUnwrap(button.allTargets.first as? NSObject)
        let action = try XCTUnwrap(button.actions(forTarget: target, forControlEvent: .touchUpInside)?.first)
        _ = target.perform(NSSelectorFromString(action))
    }

    func testVisibleRowsAndHeaderControlsRefreshWhenOnlyTheLanguageChanges() throws {
        let view = WegramMeView(action: { _ in }, updateAvatar: { _, _, _ in })
        view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        view.update(presentationData: self.data("zh-hans"), peer: nil, topInset: 62, bottomInset: 83)
        view.layoutIfNeeded()
        let table = try XCTUnwrap(view.subviews.compactMap { $0 as? UITableView }.first)
        let profile = try XCTUnwrap(self.descendants(view).compactMap { $0 as? UIButton }.first { $0.accessibilityLabel == "个人资料" })
        let qr = try XCTUnwrap(self.descendants(view).compactMap { $0 as? UIButton }.first { $0.accessibilityLabel == "我的二维码" })
        let status = try XCTUnwrap(self.descendants(view).compactMap { $0 as? UIButton }.first { $0.currentTitle == "状态" })
        XCTAssertEqual(table.cellForRow(at: IndexPath(row: 0, section: 0))?.textLabel?.text, "服务")
        view.update(presentationData: self.data("en"), peer: nil, topInset: 62, bottomInset: 83)
        view.layoutIfNeeded()
        table.layoutIfNeeded()
        XCTAssertEqual(table.cellForRow(at: IndexPath(row: 0, section: 0))?.textLabel?.text, "Services", "Already visible cells must reload on a language-only update")
        let expected = [["Services"], ["Favorites", "Moments", "Cards", "Stickers"], ["Settings"]]
        for (section, titles) in expected.enumerated() {
            for (row, title) in titles.enumerated() {
                XCTAssertEqual(table.dataSource?.tableView(table, cellForRowAt: IndexPath(row: row, section: section)).textLabel?.text, title)
            }
        }
        XCTAssertEqual(profile.accessibilityLabel, "Profile")
        XCTAssertEqual(qr.accessibilityLabel, "My QR Code")
        XCTAssertEqual(status.currentTitle, "Status")
        view.update(presentationData: self.data("zh-hans"), peer: nil, topInset: 62, bottomInset: 83)
        view.layoutIfNeeded()
        XCTAssertEqual(profile.accessibilityLabel, "个人资料")
        XCTAssertEqual(status.currentTitle, "状态")
    }

    func testStatusLabelFitsAtLargeTypeAndControlsKeepTheirOriginalActions() throws {
        var actions: [WegramMeView.Action] = []
        let view = WegramMeView(action: { actions.append($0) }, updateAvatar: { _, _, _ in })
        for width: CGFloat in [320, 402, 720] {
            view.frame = CGRect(x: 0, y: 0, width: width, height: 874)
            let data = self.data("en").withUpdate(listsFontSize: .extraLargeX2)
            view.update(presentationData: data, peer: nil, topInset: 62, bottomInset: 83)
            view.layoutIfNeeded()
            let status = try XCTUnwrap(self.descendants(view).compactMap { $0 as? UIButton }.first { $0 is WegramStatusPill })
            let font = try XCTUnwrap(status.titleLabel?.font)
            XCTAssertEqual(font.pointSize, 14 * data.listsFontSize.itemListBaseFontSize / 17)
            let measured = status.titleLabel!.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            XCTAssertGreaterThanOrEqual(status.bounds.width, ceil(measured.width) + 16)
            XCTAssertGreaterThanOrEqual(status.bounds.height, ceil(measured.height) + 8)
            XCTAssertLessThanOrEqual(status.frame.maxX, width - 16)
        }
        let table = try XCTUnwrap(view.subviews.compactMap { $0 as? UITableView }.first)
        for (section, count) in [1, 4, 1].enumerated() {
            for row in 0 ..< count { table.delegate?.tableView?(table, didSelectRowAt: IndexPath(row: row, section: section)) }
        }
        let buttons = self.descendants(view).compactMap { $0 as? UIButton }
        try self.activate(XCTUnwrap(buttons.first { $0.accessibilityLabel == "Profile" }))
        try self.activate(XCTUnwrap(buttons.first { $0.accessibilityLabel == "My QR Code" }))
        try self.activate(XCTUnwrap(buttons.first { $0.currentTitle == "＋ Status" }))
        XCTAssertEqual(actions, [.services, .savedMessages, .stories, .cards, .stickers, .settings, .profile, .qrCode, .status])
    }
    func testProfileDataAndAvatarCallbackSurviveTheViewSeparation() throws {
        let peer = EnginePeer.user(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(1)), accessHash: nil, firstName: "Preview", lastName: "User", username: "preview", phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
        var updates = 0
        var avatar: AvatarNode?
        let view = WegramMeView(action: { _ in }, updateAvatar: { node, _, value in
            XCTAssertEqual(value, peer)
            updates += 1
            node.setCustomLetters(["P", "U"])
            avatar = node
        })
        view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        let chinese = self.data("zh-hans")
        view.update(presentationData: chinese, peer: peer, topInset: 62, bottomInset: 83)
        view.layoutIfNeeded()
        XCTAssertEqual(updates, 1)
        XCTAssertTrue(self.descendants(view).compactMap { $0 as? UILabel }.contains { $0.text == "微信号：preview" })
        view.update(presentationData: chinese, peer: peer, topInset: 62, bottomInset: 83)
        XCTAssertEqual(updates, 1, "Unchanged data should keep its avatar load")
        for (language, dark) in [("en", false), ("en", true), ("zh-hans", false), ("zh-hans", true)] {
            let data = self.data(language, dark: dark)
            let isChinese = language.hasPrefix("zh")
            view.update(presentationData: data, peer: peer, topInset: 62, bottomInset: 83)
            view.layoutIfNeeded()
            let profile = try XCTUnwrap(self.descendants(view).compactMap { $0 as? UIButton }.first { $0.accessibilityLabel == (isChinese ? "个人资料" : "Profile") })
            XCTAssertEqual(profile.accessibilityValue, isChinese ? "Preview User，微信号：preview" : "Preview User, Username: preview")
            XCTAssertEqual(avatar?.frame.size, CGSize(width: 64, height: 64))
            XCTAssertTrue(self.descendants(view).compactMap { $0 as? UILabel }.contains { $0.text == (isChinese ? "微信号：preview" : "Username: preview") })
            if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                avatar?.recursivelyEnsureDisplaySynchronously(true)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("me-component-\(language)-\(dark ? "dark" : "light").png"))
            }
        }
    }

}
