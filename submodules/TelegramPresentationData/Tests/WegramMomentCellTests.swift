import XCTest
import UIKit

final class WegramMomentCellTests: XCTestCase {
    private func content(peer: Int64 = 1, id: Int32? = 1, timestamp: Int32 = 100, expiration: Int32? = 200, expired: Bool = false, protected: Bool = false, caption: String = "组件测试正文", ratio: CGFloat? = 1, video: Bool = false) -> WegramMomentContent {
        WegramMomentContent(peerId: peer, storyId: id, timestamp: timestamp, expiration: expiration, expired: expired, protected: protected, caption: caption, status: "受保护的动态，点按查看", aspectRatio: ratio, video: video)
    }
    func testTimelineExpirationAndStableOrder() {
        XCTAssertTrue(self.content().isVisible(at: 199))
        XCTAssertFalse(self.content().isVisible(at: 200))
        XCTAssertFalse(self.content().isVisible(at: 201))
        XCTAssertFalse(self.content(expired: true).isVisible(at: 100))
        XCTAssertTrue(self.content(id: nil, expiration: nil).isVisible(at: Int64.max))
        let values = [self.content(peer: 2, id: 1), self.content(peer: 1, id: 2), self.content(peer: 1, id: 1), self.content(peer: 2, id: 3, timestamp: 101)]
        let sorted = values.sorted(by: WegramMomentContent.comesBefore)
        XCTAssertEqual(sorted.map { $0.peerId }, [2, 1, 1, 2])
        XCTAssertEqual(sorted.map { $0.storyId }, [3, 2, 1, 1])
    }
    func testProtectedAndReusedCellsNeverExposeCaptionOrMedia() {
        let cell = WegramMomentCell(style: .default, reuseIdentifier: nil)
        cell.load(self.content(video: true), name: "测试用户", date: "1分钟前", dark: false, font: 17)
        XCTAssertFalse(cell.mediaHost.isHidden)
        XCTAssertFalse(cell.play.isHidden)
        XCTAssertEqual(cell.caption.text, "组件测试正文")
        cell.load(self.content(protected: true, caption: "SECRET CAPTION", video: true), name: "测试用户", date: "1分钟前", dark: true, font: 17)
        XCTAssertTrue(cell.mediaHost.isHidden)
        XCTAssertTrue(cell.play.isHidden)
        XCTAssertEqual(cell.caption.text, "受保护的动态，点按查看")
        XCTAssertFalse(cell.accessibilityValue?.contains("SECRET") ?? true)
        XCTAssertTrue(cell.mediaHost.accessibilityElementsHidden)
        XCTAssertFalse(cell.caption.isAccessibilityElement)
        XCTAssertTrue(cell.accessibilityTraits.contains(.button))
        cell.load(self.content(caption: "", ratio: nil), name: "新用户", date: "", dark: false, font: 34)
        XCTAssertEqual(cell.accessibilityLabel, "新用户")
        XCTAssertTrue(cell.mediaHost.isHidden)
        XCTAssertFalse(cell.accessibilityValue?.contains("1分钟前") ?? true)
        cell.load(self.content(ratio: .nan), name: "新用户", date: "", dark: false, font: 17)
        XCTAssertTrue(cell.mediaHost.isHidden)
    }
    func testFullCaptionChangesRowHeightAndKeepsIndependentActions() throws {
        let cell = WegramMomentCell(style: .default, reuseIdentifier: nil)
        let caption = (1...14).map { "第\($0)行用于正文展开检查" }.joined(separator: "\n")
        let content = self.content(caption: caption)
        var requests = 0
        cell.toggleCaption = { requests += 1; return true }
        for font: CGFloat in [17, 34] {
            for width: CGFloat in [320, 402, 720] {
                cell.load(content, name: "布局检查", date: "1分钟前", dark: false, font: font, actionsAvailable: true, moreTitle: "更多互动")
                let collapsedHeight = cell.measuredHeight(width: width)
                cell.frame = CGRect(x: 0, y: 0, width: width, height: collapsedHeight)
                cell.layoutIfNeeded()
                XCTAssertFalse(cell.captionToggle.isHidden)
                XCTAssertEqual(cell.captionToggle.currentTitle, "全文")
                XCTAssertEqual(cell.caption.numberOfLines, 6)
                XCTAssertEqual(cell.accessibilityCustomActions?.map { $0.name }, ["更多互动", "全文"])
                let old = try XCTUnwrap(cell.accessibilityCustomActions?.last)
                let before = requests
                cell.captionToggle.sendActions(for: .touchUpInside)
                XCTAssertEqual(requests, before + 1)
                XCTAssertTrue(cell.captionToggle.point(inside: CGPoint(x: 22, y: cell.captionToggle.bounds.midY - 21), with: nil))
                let hit = cell.convert(CGPoint(x: 22, y: cell.captionToggle.bounds.midY), from: cell.captionToggle)
                XCTAssertTrue(cell.hitTest(hit, with: nil) === cell.captionToggle)
                cell.load(content, name: "布局检查", date: "1分钟前", dark: false, font: font, actionsAvailable: true, moreTitle: "更多互动", captionExpanded: true)
                let expandedHeight = cell.measuredHeight(width: width)
                cell.frame = CGRect(x: 0, y: 0, width: width, height: expandedHeight)
                cell.layoutIfNeeded()
                XCTAssertGreaterThan(expandedHeight, collapsedHeight)
                XCTAssertEqual(cell.caption.numberOfLines, 0)
                XCTAssertEqual(cell.caption.text, caption)
                XCTAssertEqual(cell.captionToggle.currentTitle, "收起")
                XCTAssertGreaterThanOrEqual(cell.captionToggle.frame.minY, cell.caption.frame.maxY)
                XCTAssertGreaterThan(cell.mediaHost.frame.minY, cell.captionToggle.frame.maxY)
                XCTAssertFalse(old.actionHandler?(old) ?? true)
                let action = try XCTUnwrap(cell.accessibilityCustomActions?.last)
                XCTAssertTrue(action.actionHandler?(action) ?? false)
                XCTAssertEqual(requests, before + 2)
                if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let image = UIGraphicsImageRenderer(size: cell.bounds.size).image { cell.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("moments-caption-expanded.png"))
                }
            }
        }
        XCTAssertNotEqual(self.content(peer: 1).id, self.content(peer: 2).id)
        XCTAssertNil(self.content(id: nil).id)
    }
    func testAuthorControlsKeepViewerMediaAndCaptionInteractionsSeparate() throws {
        let cell = WegramMomentCell(style: .default, reuseIdentifier: nil)
        let text = String(repeating: "正文检查\n", count: 12)
        var opens = 0
        cell.openAuthor = { opens += 1; return true }
        for font: CGFloat in [17, 34] {
            for width: CGFloat in [320, 402, 720] {
                cell.load(self.content(caption: text), name: "作者名称", date: "1分钟前", dark: false, font: font, actionsAvailable: true, moreTitle: "更多互动", authorTitle: "查看作者资料")
                cell.frame = CGRect(x: 0, y: 0, width: width, height: cell.measuredHeight(width: width))
                cell.layoutIfNeeded()
                XCTAssertEqual(cell.authorAvatarButton.bounds.size, CGSize(width: 44, height: 44))
                XCTAssertTrue(cell.hitTest(cell.authorAvatarButton.center, with: nil) === cell.authorAvatarButton)
                XCTAssertTrue(cell.hitTest(cell.authorNameButton.center, with: nil) === cell.authorNameButton)
                XCTAssertFalse(cell.hitTest(CGPoint(x: cell.mediaHost.frame.midX, y: cell.mediaHost.frame.midY), with: nil) === cell.authorNameButton)
                XCTAssertLessThanOrEqual(cell.authorNameButton.frame.maxY, cell.caption.frame.minY)
                XCTAssertEqual(cell.accessibilityCustomActions?.map { $0.name }, ["更多互动", "全文", "查看作者资料"])
                let before = opens
                cell.authorAvatarButton.sendActions(for: .touchUpInside)
                cell.authorNameButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(opens, before + 2)
                let action = try XCTUnwrap(cell.accessibilityCustomActions?.last)
                XCTAssertTrue(action.actionHandler?(action) ?? false)
                XCTAssertEqual(opens, before + 3)
            }
        }
    }
    func testOldAuthorActionCannotOpenAnotherReusedPost() throws {
        let cell = WegramMomentCell(style: .default, reuseIdentifier: nil)
        var opens = 0
        cell.load(self.content(), name: "原作者", date: "", dark: false, font: 17)
        cell.openAuthor = { opens += 1; return true }
        let old = try XCTUnwrap(cell.accessibilityCustomActions?.last)
        cell.prepareForReuse()
        cell.authorAvatarButton.sendActions(for: .touchUpInside)
        XCTAssertFalse(old.actionHandler?(old) ?? true)
        cell.load(self.content(peer: 2), name: "新作者", date: "", dark: false, font: 17)
        cell.openAuthor = { opens += 1; return true }
        XCTAssertFalse(old.actionHandler?(old) ?? true)
        XCTAssertEqual(opens, 0)
        XCTAssertFalse(cell.authorNameButton.isHidden)
        cell.authorNameButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 1)
    }

    func testCaptionExpansionDoesNotSurviveProtectedContentOrReuse() throws {
        let cell = WegramMomentCell(style: .default, reuseIdentifier: nil)
        let text = String(repeating: "长正文\n", count: 12)
        cell.load(self.content(caption: text), name: "检查", date: "", dark: true, font: 17)
        cell.frame = CGRect(x: 0, y: 0, width: 402, height: cell.measuredHeight(width: 402))
        cell.layoutIfNeeded()
        let old = try XCTUnwrap(cell.accessibilityCustomActions?.last)
        var requests = 0
        cell.toggleCaption = { requests += 1; return true }
        cell.prepareForReuse()
        cell.captionToggle.sendActions(for: .touchUpInside)
        XCTAssertFalse(old.actionHandler?(old) ?? true)
        XCTAssertEqual(requests, 0)
        cell.load(self.content(protected: true, caption: text), name: "保护内容", date: "", dark: true, font: 17, captionExpanded: true)
        cell.frame.size.height = cell.measuredHeight(width: 402)
        cell.layoutIfNeeded()
        XCTAssertTrue(cell.captionToggle.isHidden)
        XCTAssertEqual(cell.caption.numberOfLines, 6)
        XCTAssertFalse(cell.accessibilityValue?.contains("长正文") ?? true)
        XCTAssertNil(cell.accessibilityCustomActions)
        cell.load(self.content(caption: "短正文"), name: "新内容", date: "", dark: true, font: 17)
        cell.frame.size.height = cell.measuredHeight(width: 402)
        cell.layoutIfNeeded()
        XCTAssertTrue(cell.captionToggle.isHidden)
        XCTAssertFalse(cell.captionToggle.isEnabled)
    }

    func testDynamicNameCaptionMediaAndTimeLayout() throws {
        let cell = WegramMomentCell(style: .default, reuseIdentifier: nil)
        let caption = String(repeating: "用于组件布局验证的长文字，不代表真实动态。", count: 20)
        for dark in [false, true] {
            for font: CGFloat in [17, 34] {
                for ratio: CGFloat in [1, 0.5, 2] {
                    cell.load(self.content(caption: caption, ratio: ratio, video: true), name: "组件测试的长用户名称", date: "测试日期：1分钟前", dark: dark, font: font)
                    for width: CGFloat in [402, 320, 720, 402] {
                        cell.frame = CGRect(x: 0, y: 0, width: width, height: cell.measuredHeight(width: width))
                        cell.setNeedsLayout()
                        cell.layoutIfNeeded()
                        XCTAssertEqual(cell.avatarHost.frame, CGRect(x: 16, y: 16, width: 40, height: 40))
                        XCTAssertEqual(cell.avatarHost.layer.cornerRadius, 4)
                        XCTAssertEqual(cell.name.frame.minX, 68)
                        XCTAssertGreaterThanOrEqual(cell.caption.frame.minY, cell.name.frame.maxY + 6)
                        XCTAssertEqual(cell.mediaHost.frame.minY, (cell.captionToggle.isHidden ? cell.caption.frame.maxY : cell.captionToggle.frame.maxY) + 8)
                        XCTAssertLessThanOrEqual(cell.mediaHost.frame.width, width - 84)
                        XCTAssertLessThanOrEqual(cell.mediaHost.frame.height, 300)
                        XCTAssertEqual(cell.date.frame.minY, cell.mediaHost.frame.maxY + 12)
                        XCTAssertLessThanOrEqual(cell.date.frame.maxY, cell.bounds.height - 15)
                        XCTAssertLessThanOrEqual(cell.caption.bounds.height, ceil(cell.caption.font.lineHeight * 6) + 1)
                        XCTAssertEqual(cell.accessibilityValue, caption + ", 测试日期：1分钟前")
                        XCTAssertEqual(cell.play.frame.midX, cell.mediaHost.frame.midX)
                        XCTAssertEqual(cell.play.frame.midY, cell.mediaHost.frame.midY)
                        if width == 402 && font == 17 && ratio == 1, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                            let image = UIGraphicsImageRenderer(size: cell.bounds.size).image { cell.layer.render(in: $0.cgContext) }
                            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "moments-item-dark.png" : "moments-item-light.png"))
                        }
                    }
                }
            }
        }
    }
}
