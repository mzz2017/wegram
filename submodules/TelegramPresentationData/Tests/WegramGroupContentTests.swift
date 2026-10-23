import XCTest
import UIKit
import Display

final class WegramGroupContentTests: XCTestCase {
    private func content(count: Int = 4, canAdd: Bool = true, muted: Bool = false, about: String? = nil, canShowQRCode: Bool = true) -> WegramGroupContent {
        return WegramGroupContent(name: "测试群聊", about: about, members: (0..<count).map { .init(id: Int64($0), name: "Member \($0)") }, memberCount: count, canAddMembers: canAdd, hasMoreMembers: false, canShowQRCode: canShowQRCode, isPinned: false, pinIsBusy: false, isMuted: muted)
    }
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(self.descendants) }

    func testDescriptionEntryRemainsReachableWhileLoadingEmptyAndAfterClearing() throws {
        for qr in [false, true] {
            for chinese in [false, true] {
                let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
                var actions: [WegramGroupContentView.Action] = []
                view.open = { actions.append($0) }
                for about: String? in [nil, "", "A group description", ""] {
                    let content = self.content(count: 1, canAdd: false, about: about, canShowQRCode: qr)
                    view.update(content, dark: false, fontSize: 17, chinese: chinese, statusHeight: 59, bottomInset: 34)
                    view.layoutIfNeeded(); view.table.layoutIfNeeded()
                    XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: 0), qr ? 3 : 2)
                    let path = IndexPath(row: qr ? 2 : 1, section: 0)
                    actions.removeAll()
                    view.tableView(view.table, didSelectRowAt: path)
                    XCTAssertEqual(actions, [.about], "Loading or empty descriptions must still open the actual group-description destination")
                    guard let cell = view.table.cellForRow(at: path) else { continue }
                    XCTAssertEqual(cell.accessibilityIdentifier, "Wegram.Group.About")
                    XCTAssertEqual(cell.textLabel?.text, chinese ? "群介绍" : "Group Description")
                    let detail = about.map { $0.isEmpty ? (chinese ? "未设置" : "Not Set") : $0 }
                    XCTAssertEqual(cell.detailTextLabel?.text, detail)
                    XCTAssertEqual(cell.accessibilityValue, detail ?? (chinese ? "正在加载" : "Loading"))
                    XCTAssertNotNil(cell.accessoryView)
                    if chinese && !qr && about?.isEmpty == true, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1
                        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("group-empty-description-entry.png"))
                    }
                }
                view.isHidden = true
                actions.removeAll()
                view.tableView(view.table, didSelectRowAt: IndexPath(row: qr ? 2 : 1, section: 0))
                XCTAssertTrue(actions.isEmpty)
            }
        }
    }

    func testBottomHistoryAndLeaveRowsKeepWeChatLayoutAndPermissionProjection() throws {
        for dark in [false, true] {
            for font: CGFloat in [17, 34] {
              for width: CGFloat in [320, 402] {
               for chinese in [false, true] {
                let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: width, height: 600))
                var content = self.content(count: 4, canAdd: false)
                content.canClearHistory = true
                var actions: [WegramGroupContentView.Action] = []
                view.open = { actions.append($0) }
                func update() {
                    view.update(content, dark: dark, fontSize: font, chinese: chinese, statusHeight: 59, bottomInset: 34)
                    view.layoutIfNeeded(); view.table.layoutIfNeeded()
                }
                update()
                let section = view.numberOfSections(in: view.table) - 1
                let clearPath = IndexPath(row: 0, section: section)
                let leavePath = IndexPath(row: 1, section: section)
                XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: section), 2)
                view.table.scrollToRow(at: leavePath, at: .bottom, animated: false)
                view.table.layoutIfNeeded()
                let clear = try XCTUnwrap(view.table.cellForRow(at: clearPath))
                let leave = try XCTUnwrap(view.table.cellForRow(at: leavePath))
                XCTAssertEqual(clear.textLabel?.text, chinese ? "清空聊天记录" : "Clear Chat History")
                XCTAssertEqual(leave.textLabel?.text, chinese ? "退出群聊" : "Leave Group")
                for cell in [clear, leave] {
                    XCTAssertEqual(cell.textLabel?.textAlignment, .center)
                    XCTAssertEqual(cell.textLabel?.textColor, UIColor(rgb: 0xfa5151))
                    let label = try XCTUnwrap(cell.textLabel)
                    XCTAssertEqual(label.frame.midX, cell.contentView.bounds.midX, accuracy: 0.5, "Destructive text must be centered in the actual row, not just in its intrinsic label")
                    let needed = (label.text! as NSString).boundingRect(with: CGSize(width: width - 32, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: label.font!], context: nil)
                    XCTAssertGreaterThanOrEqual(label.frame.height, ceil(needed.height) - 1, "The full action must fit at large type")
                    XCTAssertNil(cell.accessoryView)
                    XCTAssertGreaterThanOrEqual(cell.bounds.height, 56)
                }
                XCTAssertEqual(clear.accessibilityIdentifier, "Wegram.Group.ClearHistory")
                XCTAssertEqual(leave.accessibilityIdentifier, "Wegram.Group.Leave")
                view.tableView(view.table, didSelectRowAt: clearPath)
                view.tableView(view.table, didSelectRowAt: leavePath)
                XCTAssertEqual(actions, [.clearHistory, .leave])
                if font == 17 && width == 402 && chinese, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("group-info-bottom-\(dark ? "dark" : "light").png"))
                }
                content.canClearHistory = false
                update()
                XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: section), 1)
                view.tableView(view.table, didSelectRowAt: leavePath)
                XCTAssertEqual(actions.count, 2)
                view.isHidden = true
                view.tableView(view.table, didSelectRowAt: clearPath)
                XCTAssertEqual(actions.count, 2)
               }
              }
            }
        }
    }

    func testGroupGridUsesRealIdsKeepsTargetsReachableAndRejectsRemovedMembers() {
        let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        var actions: [WegramGroupContentView.Action] = []
        view.open = { actions.append($0) }
        func update(_ content: WegramGroupContent) {
            view.update(content, dark: false, fontSize: 17, chinese: true, statusHeight: 59, bottomInset: 34)
            view.layoutIfNeeded(); view.table.layoutIfNeeded()
        }
        update(self.content())
        XCTAssertTrue(view.accessibilityViewIsModal)
        XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: 0), 3)
        XCTAssertEqual(view.avatarHosts.count, 4)
        let first = self.descendants(view).compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "Wegram.Group.Member.0" }!
        first.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.member(0)])
        let add = self.descendants(view).compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "Wegram.Group.AddMember" }!
        add.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.last, .addMember)
        let cell = view.table.cellForRow(at: IndexPath(row: 0, section: 2))!
        let control = cell.accessoryView as! WegramAppearanceSwitch
        control.isOn = true
        control.sendActions(for: .valueChanged)
        XCTAssertEqual(actions.last, .mute(true))
        let changed = WegramGroupContent(name: "Updated", about: nil, members: [.init(id: 10, name: "New Member")], memberCount: 1, canAddMembers: false, hasMoreMembers: false, canShowQRCode: false, isPinned: nil, pinIsBusy: false, isMuted: true)
        update(changed)
        XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: 0), 2)
        let count = actions.count
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 2, section: 0))
        first.sendActions(for: .touchUpInside)
        add.sendActions(for: .touchUpInside)
        control.sendActions(for: .valueChanged)
        XCTAssertEqual(actions.count, count)
        XCTAssertNil(view.avatarHosts[0])
        XCTAssertEqual(view.avatarHosts.count, 1)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertEqual(actions.last, .search)
        view.isHidden = true
        let current = self.descendants(view).compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "Wegram.Group.Member.10" }!
        current.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.last, .search)
    }

    func testAllMembersRemainsReachableWhenOnlyAPageIsLoadedAndHidesWhenNoLongerNeeded() throws {
        let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        var actions: [WegramGroupContentView.Action] = []
        view.open = { actions.append($0) }
        let partial = WegramGroupContent(name: "Large Group", about: nil, members: [.init(id: 1, name: "Visible Member")], memberCount: 1, canAddMembers: false, hasMoreMembers: true, canShowQRCode: false, isPinned: nil, pinIsBusy: false, isMuted: false)
        view.update(partial, dark: false, fontSize: 17, chinese: true, statusHeight: 59, bottomInset: 34)
        view.layoutIfNeeded(); view.table.layoutIfNeeded()
        let button = try XCTUnwrap(self.descendants(view).compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "Wegram.Group.AllMembers" })
        XCTAssertFalse(button.isHidden)
        XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
        XCTAssertTrue(view.table.tableHeaderView!.bounds.contains(button.frame))
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.allMembers])
        let complete = WegramGroupContent(name: "Small Group", about: nil, members: partial.members, memberCount: 1, canAddMembers: false, hasMoreMembers: false, canShowQRCode: false, isPinned: nil, pinIsBusy: false, isMuted: false)
        view.update(complete, dark: true, fontSize: 26, chinese: false, statusHeight: 59, bottomInset: 34)
        view.layoutIfNeeded(); view.table.layoutIfNeeded()
        XCTAssertTrue(button.isHidden)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.allMembers])
        view.update(self.content(count: 100), dark: false, fontSize: 17, chinese: true, statusHeight: 59, bottomInset: 34)
        view.layoutIfNeeded(); view.table.layoutIfNeeded()
        XCTAssertFalse(button.isHidden)
        XCTAssertEqual(view.avatarHosts.count, 17)
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("wegram-group-info-members.png"))
        }
    }

    func testExpandedMembersStayInlineAndReuseRowsForLargeGroups() throws {
        let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        var actions: [WegramGroupContentView.Action] = []
        var hosts: Set<ObjectIdentifier> = []
        view.open = { actions.append($0) }
        view.configureAvatar = { _, host in hosts.insert(ObjectIdentifier(host)) }
        view.releaseAvatar = { _, host in hosts.remove(ObjectIdentifier(host)) }
        view.setMembersExpanded(true)
        view.update(self.content(count: 2000), dark: false, fontSize: 17, chinese: true, statusHeight: 59, bottomInset: 34)
        view.layoutIfNeeded(); view.table.layoutIfNeeded()
        XCTAssertNil(view.table.tableHeaderView)
        XCTAssertEqual(view.numberOfSections(in: view.table), 6)
        XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: 0), 335)
        XCTAssertTrue(view.avatarHosts.isEmpty)
        XCTAssertGreaterThan(hosts.count, 0)
        XCTAssertLessThan(hosts.count, 100)
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("wegram-group-inline-members.png"))
        }
        let first = try XCTUnwrap(self.descendants(view.table).compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "Wegram.Group.Member.0" })
        first.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.member(0)])
        view.table.scrollToRow(at: IndexPath(row: 333, section: 0), at: .bottom, animated: false)
        view.table.layoutIfNeeded()
        first.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, [.member(0)])
        XCTAssertLessThan(hosts.count, 100)
        let add = try XCTUnwrap(self.descendants(view.table).compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "Wegram.Group.AddMember" })
        add.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.last, .addMember)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 2))
        XCTAssertEqual(actions.last, .search)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 334, section: 0))
        XCTAssertEqual(actions.last, .allMembers)
        view.setMembersExpanded(false)
        view.update(self.content(count: 2000), dark: false, fontSize: 17, chinese: true, statusHeight: 59, bottomInset: 34)
        view.layoutIfNeeded(); view.table.layoutIfNeeded()
        XCTAssertNotNil(view.table.tableHeaderView)
        XCTAssertEqual(view.avatarHosts.count, 17)
        XCTAssertEqual(hosts.count, 0)
        let count = actions.count
        add.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.count, count)
    }

    func testInlinePaginationRejectsHiddenLoadingAndRepeatedRequestsAndAllowsRetry() {
        let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let partial = WegramGroupContent(name: "Group", about: nil, members: [.init(id: 1, name: "Member")], memberCount: 100, canAddMembers: false, hasMoreMembers: true, canShowQRCode: false, isPinned: nil, pinIsBusy: false, isMuted: false)
        var requests = 0
        view.loadMore = { requests += 1; return true }
        func update(loading: Bool = false) {
            view.update(partial, dark: false, fontSize: 17, chinese: true, statusHeight: 59, bottomInset: 34, membersLoading: loading)
            view.layoutIfNeeded(); view.table.layoutIfNeeded()
        }
        update()
        view.requestExpandedMembersIfNeeded()
        XCTAssertEqual(requests, 0)
        view.setMembersExpanded(true)
        update(loading: true)
        view.requestExpandedMembersIfNeeded()
        XCTAssertEqual(requests, 0)
        update()
        view.requestExpandedMembersIfNeeded()
        view.requestExpandedMembersIfNeeded()
        XCTAssertEqual(requests, 1)
        view.scrollViewWillBeginDragging(view.table)
        view.requestExpandedMembersIfNeeded()
        XCTAssertEqual(requests, 2)
        view.isHidden = true
        view.scrollViewWillBeginDragging(view.table)
        view.requestExpandedMembersIfNeeded()
        XCTAssertEqual(requests, 2)
    }

    func testExpandedOwnerOrderingKeepsEveryLoadedMemberAndOriginalOrder() {
        let members = Array(0..<200)
        XCTAssertEqual(wegramGroupPreviewMembers(members, canAddMembers: true, expanded: true, isOwner: { $0 == 199 }), [199] + Array(0..<199))
        XCTAssertEqual(wegramGroupPreviewMembers(members, canAddMembers: false, expanded: true, isOwner: { _ in false }), members)
    }

    func testExpandedRowsFitLargeTextAndNarrowWidthsAndKeepMemberIdentityOnReload() throws {
        for width: CGFloat in [320, 402, 874] {
            let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: width, height: 874))
            var actions: [WegramGroupContentView.Action] = []
            view.open = { actions.append($0) }
            view.setMembersExpanded(true)
            view.update(self.content(count: 40, canAdd: false), dark: true, fontSize: 34, chinese: true, statusHeight: 59, bottomInset: 34)
            view.layoutIfNeeded(); view.table.layoutIfNeeded()
            let button = try XCTUnwrap(self.descendants(view.table).compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "Wegram.Group.Member.0" })
            for cell in view.table.visibleCells {
                cell.layoutIfNeeded()
                for label in cell.contentView.subviews.compactMap({ $0 as? UILabel }) where label.text?.hasPrefix("Member") == true {
                    XCTAssertLessThanOrEqual(label.frame.maxY, cell.contentView.bounds.height)
                }
            }
            view.update(self.content(count: 0, canAdd: false), dark: true, fontSize: 34, chinese: true, statusHeight: 59, bottomInset: 34)
            view.layoutIfNeeded(); view.table.layoutIfNeeded()
            button.sendActions(for: .touchUpInside)
            XCTAssertTrue(actions.isEmpty)
        }
    }

    func testOwnerPrecedesPreviewWithoutReorderingOtherMembersOrInventingMissingOwner() {
        let members = Array(0..<100)
        for canAdd in [true, false] {
            let limit = canAdd ? 17 : 18
            for owner in [0, 5, 80] {
                let preview = wegramGroupPreviewMembers(members, canAddMembers: canAdd, isOwner: { $0 == owner })
                XCTAssertEqual(preview, [owner] + Array(members.filter { $0 != owner }.prefix(limit - 1)))
            }
            XCTAssertEqual(wegramGroupPreviewMembers(members, canAddMembers: canAdd, isOwner: { _ in false }), Array(members.prefix(limit)))
        }
        XCTAssertEqual(members, Array(0..<100))
        XCTAssertEqual(wegramGroupPreviewMembers([Int](), canAddMembers: false, isOwner: { _ in false }), [])
        XCTAssertEqual(wegramGroupPreviewMembers([5, 2, 1], canAddMembers: true, isOwner: { $0 == 1 }), [1, 5, 2])
    }

    func testMemberSearchIsSeparateFromChatHistoryAndMoreRemainsReachable() throws {
        let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        var actions: [WegramGroupContentView.Action] = []
        view.open = { actions.append($0) }
        view.update(self.content(), dark: false, fontSize: 17, chinese: true, statusHeight: 59, bottomInset: 34)
        view.layoutIfNeeded(); view.table.layoutIfNeeded()
        let search = try XCTUnwrap(self.descendants(view).compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "Wegram.Group.SearchMembers" })
        XCTAssertEqual(search.accessibilityLabel, "搜索群成员")
        XCTAssertGreaterThanOrEqual(search.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(search.bounds.height, 44)
        search.sendActions(for: .touchUpInside)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 1))
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 3))
        XCTAssertEqual(actions, [.searchMembers, .search, .more])
        view.isHidden = true
        search.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.count, 3)
    }

    func testPinSwitchUsesObservedStateAndBlocksBusyOrRemovedControls() throws {
        let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        var actions: [WegramGroupContentView.Action] = []
        view.open = { actions.append($0) }
        func update(pinned: Bool?, busy: Bool) {
            let content = WegramGroupContent(name: "Group", about: nil, members: [.init(id: 1, name: "Member")], memberCount: 1, canAddMembers: false, hasMoreMembers: false, canShowQRCode: false, isPinned: pinned, pinIsBusy: busy, isMuted: false)
            view.update(content, dark: true, fontSize: 17, chinese: true, statusHeight: 59, bottomInset: 34)
            view.layoutIfNeeded(); view.table.layoutIfNeeded()
        }
        update(pinned: nil, busy: false)
        XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: 2), 1)
        update(pinned: false, busy: false)
        XCTAssertEqual(view.tableView(view.table, numberOfRowsInSection: 2), 2)
        let control = try XCTUnwrap(view.table.cellForRow(at: IndexPath(row: 1, section: 2))?.accessoryView as? WegramAppearanceSwitch)
        XCTAssertFalse(control.isOn)
        XCTAssertEqual(control.accessibilityIdentifier, "Wegram.Group.Pin")
        control.isOn = true
        control.sendActions(for: .valueChanged)
        XCTAssertEqual(actions, [.pin(true)])
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 1, section: 2))
        XCTAssertEqual(actions.count, 1)
        update(pinned: false, busy: true)
        let busyControl = try XCTUnwrap(view.table.cellForRow(at: IndexPath(row: 1, section: 2))?.accessoryView as? WegramAppearanceSwitch)
        XCTAssertFalse(busyControl.isEnabled)
        busyControl.sendActions(for: .valueChanged)
        control.sendActions(for: .valueChanged)
        XCTAssertEqual(actions.count, 1)
        update(pinned: true, busy: false)
        XCTAssertTrue((view.table.cellForRow(at: IndexPath(row: 1, section: 2))?.accessoryView as? WegramAppearanceSwitch)?.isOn == true)
        update(pinned: nil, busy: false)
        busyControl.sendActions(for: .valueChanged)
        XCTAssertEqual(actions.count, 1)
    }

    func testGroupGridFitsThemesWidthsAndLargeNamesWithoutCreatingUnboundedAvatars() throws {
        for dark in [false, true] {
            for width: CGFloat in [320, 402, 874] {
                for fontSize: CGFloat in [17, 26] {
                    let view = WegramGroupContentView(frame: CGRect(x: 0, y: 0, width: width, height: 874))
                    view.update(self.content(count: 100), dark: dark, fontSize: fontSize, chinese: !dark, statusHeight: 59, bottomInset: 34)
                    view.layoutIfNeeded(); view.table.layoutIfNeeded()
                    XCTAssertEqual(view.avatarHosts.count, width == 320 ? 14 : 17)
                    for host in view.avatarHosts.values {
                        XCTAssertEqual(host.bounds.size, CGSize(width: 48, height: 48))
                        let grid = try XCTUnwrap(host.superview?.superview)
                        XCTAssertTrue(grid.bounds.contains(host.convert(host.bounds, to: grid)))
                    }
                    XCTAssertEqual(view.table.frame.minY, 103)
                    XCTAssertEqual(view.table.contentInset.bottom, 34)
                    let buttons = self.descendants(view).compactMap { $0 as? UIButton }
                    for button in buttons { XCTAssertGreaterThanOrEqual(button.bounds.height, 44) }
                    if width == 402 && fontSize == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        view.update(self.content(), dark: dark, fontSize: fontSize, chinese: true, statusHeight: 59, bottomInset: 34)
                        view.layoutIfNeeded(); view.table.layoutIfNeeded()
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1
                        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "wegram-group-info-dark.png" : "wegram-group-info-light.png"))
                    }
                }
            }
        }
    }
}
