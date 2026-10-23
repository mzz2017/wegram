import XCTest
import UIKit

final class WegramAutoSaveContentTests: XCTestCase {
    private func rules(video: Bool) -> [WegramDownloadToggle] {
        [WegramDownloadToggle(field: .photo, title: "照片", value: true, enabled: true), WegramDownloadToggle(field: .video, title: "视频", value: video, enabled: true)]
    }
    private let size = WegramDownloadSize(heading: "视频大小上限", text: "最多 100 MB", bytes: 100 * 1024 * 1024, minimum: "512 KB", maximum: "1.5 GB")
    func testPhotosVideosAndExceptionsRejectLoadingAndHiddenOldIntents() throws {
        let view = WegramDownloadCategoryContentView()
        var toggles: [WegramMediaRuleField] = []
        var sizes: [Int64] = []
        var opens = 0
        view.toggle = { toggles.append($0) }
        view.adjustSize = { sizes.append($0) }
        view.openAction = { opens += 1 }
        XCTAssertTrue(view.actionButton.isHidden)
        XCTAssertFalse(view.actionButton.isEnabled)
        XCTAssertTrue(view.actionButton.accessibilityTraits.contains(.notEnabled))
        view.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 0)
        view.load(heading: "保存到系统相册", rules: self.rules(video: true), size: self.size, footer: "视频说明", sectionInfo: "保存收到的照片和视频。", action: WegramMediaRuleAction(title: "例外", value: "3"))
        let photos = try XCTUnwrap(view.rowViews[.photo]).toggle
        let videos = try XCTUnwrap(view.rowViews[.video]).toggle
        XCTAssertTrue(photos.isOn)
        XCTAssertTrue(videos.isOn)
        photos.sendActions(for: .valueChanged)
        videos.sendActions(for: .valueChanged)
        XCTAssertEqual(toggles, [.photo, .video])
        view.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(opens, 1)
        XCTAssertEqual(view.actionButton.accessibilityValue, "3")
        XCTAssertFalse(view.actionButton.accessibilityTraits.contains(.notEnabled))
        for field in [WegramMediaRuleField.contact, .otherPrivate, .group, .channel, .preload] {
            XCTAssertTrue(view.rowViews[field]?.isHidden == true, "Download-specific controls must not leak into album saving")
        }
        view.load(heading: "保存到系统相册", rules: self.rules(video: false), size: nil, footer: "", sectionInfo: "保存说明", action: WegramMediaRuleAction(title: "例外", value: "0"))
        XCTAssertFalse(videos.isOn)
        XCTAssertTrue(view.sizeBlock.isHidden)
        XCTAssertFalse(view.slider.isEnabled)
        view.slider.sendActions(for: .valueChanged)
        view.slider.accessibilityIncrement()
        XCTAssertTrue(sizes.isEmpty)
        XCTAssertEqual(view.actionButton.accessibilityValue, "0", "A loaded zero count is distinct from loading")
        view.load(heading: "", rules: [], size: nil, footer: "")
        view.actionButton.sendActions(for: .touchUpInside)
        photos.sendActions(for: .valueChanged)
        XCTAssertEqual(opens, 1)
        XCTAssertEqual(toggles.count, 2)
    }
    func testAlbumExplanationSliderAndExceptionActionReflowAndKeepTheirHitArea() throws {
        for dark in [false, true] {
            for font: CGFloat in [17, 34] {
                let view = WegramDownloadCategoryContentView(frame: .zero)
                view.update(dark: dark, fontSize: font, chinese: true)
                view.load(heading: "保存到系统相册", rules: self.rules(video: true), size: self.size, footer: "测试说明：仅保存已下载且低于所选大小上限的视频。", sectionInfo: "测试说明：自动保存此类聊天中收到的新照片和视频。", action: WegramMediaRuleAction(title: "例外", value: "3"))
                for width: CGFloat in [402, 320, 720, 402] {
                    view.frame = CGRect(x: 0, y: 0, width: width, height: 600)
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    let video = try XCTUnwrap(view.rowViews[.video])
                    XCTAssertGreaterThanOrEqual(view.sectionInfo.frame.minY, video.frame.maxY + 8)
                    XCTAssertGreaterThanOrEqual(view.sizeHeading.frame.minY, view.sectionInfo.frame.maxY + 16)
                    XCTAssertGreaterThanOrEqual(view.footer.frame.minY, view.sizeBlock.frame.maxY + 8)
                    XCTAssertGreaterThanOrEqual(view.actionButton.frame.minY, view.footer.frame.maxY + 16)
                    XCTAssertEqual(view.actionButton.frame.width, width)
                    XCTAssertGreaterThanOrEqual(view.actionButton.frame.height, 56)
                    view.actionButton.layoutIfNeeded()
                    XCTAssertLessThan(view.actionButton.caption.frame.maxX, view.actionButton.detail.frame.minX)
                    XCTAssertLessThan(view.actionButton.detail.frame.maxX, view.actionButton.arrow.frame.minX)
                    for y: CGFloat in [0.1, view.actionButton.bounds.height - 0.1] {
                        XCTAssertTrue(view.actionButton.hitTest(CGPoint(x: width / 2, y: y), with: nil) === view.actionButton)
                    }
                    XCTAssertGreaterThan(view.contentSize.height, view.actionButton.frame.maxY)
                    for label in [view.sectionInfo, view.footer] {
                        XCTAssertLessThanOrEqual(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height, label.bounds.height + 1)
                    }
                    if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "autosave-dark.png" : "autosave-light.png"))
                    }
                }
                view.actionButton.caption.text = "Exceptions for selected conversations"
                view.actionButton.detail.text = "123456789012345"
                view.actionButton.accessibilityValue = view.actionButton.detail.text
                view.frame.size.width = 320
                view.setNeedsLayout()
                view.layoutIfNeeded()
                view.actionButton.layoutIfNeeded()
                XCTAssertLessThanOrEqual(view.actionButton.caption.sizeThatFits(CGSize(width: view.actionButton.caption.bounds.width, height: .greatestFiniteMagnitude)).height, view.actionButton.caption.bounds.height + 1)
                XCTAssertEqual(view.actionButton.accessibilityValue, "123456789012345")
            }
        }
    }
    func testPeerHeaderScrollsBeforeRulesAndReflowsWithoutLeakingIntoDownloadPages() throws {
        let name = "仅用于组件测试的长聊天名称：验证窄屏、大字以及完整无障碍名称"
        for dark in [false, true] {
            for font: CGFloat in [17, 34] {
                let view = WegramDownloadCategoryContentView(frame: .zero)
                view.update(dark: dark, fontSize: font, chinese: true)
                XCTAssertTrue(view.peerHeader.isHidden)
                view.load(heading: "保存到系统相册", rules: self.rules(video: true), size: self.size, footer: "测试说明：视频只在原大小限制内保存。", peerName: name)
                for width: CGFloat in [402, 320, 720, 402] {
                    view.frame = CGRect(x: 0, y: 0, width: width, height: 600)
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    view.peerHeader.layoutIfNeeded()
                    let header = view.peerHeader
                    XCTAssertFalse(header.isHidden)
                    XCTAssertEqual(header.frame.minY, 8)
                    XCTAssertEqual(header.frame.width, width)
                    XCTAssertGreaterThanOrEqual(header.bounds.height, 56)
                    XCTAssertEqual(header.avatarHost.frame.size, CGSize(width: 40, height: 40))
                    XCTAssertEqual(header.avatarHost.frame.minX, 16)
                    XCTAssertEqual(header.avatarHost.layer.cornerRadius, 4)
                    XCTAssertEqual(header.name.frame.minX, 68)
                    XCTAssertLessThanOrEqual(header.name.sizeThatFits(CGSize(width: header.name.bounds.width, height: .greatestFiniteMagnitude)).height, header.name.bounds.height + 1)
                    XCTAssertEqual(view.heading.frame.minY, header.frame.maxY + 16)
                    XCTAssertGreaterThan(view.rowViews[.photo]!.frame.minY, header.frame.maxY)
                    XCTAssertEqual(header.accessibilityLabel, name)
                    XCTAssertFalse(header.name.isAccessibilityElement)
                    XCTAssertTrue(header.avatarHost.accessibilityElementsHidden)
                    XCTAssertTrue(header.superview === view, "The name and avatar must scroll with the settings")
                    if font == 17 && width == 402, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "autosave-peer-dark.png" : "autosave-peer-light.png"))
                    }
                }
                view.load(heading: "下载范围", rules: [], size: nil, footer: "")
                view.layoutIfNeeded()
                XCTAssertTrue(view.peerHeader.isHidden)
                XCTAssertNil(view.peerHeader.name.text)
                XCTAssertNil(view.peerHeader.accessibilityLabel)
                XCTAssertEqual(view.peerHeader.frame, .zero)
            }
        }
    }

}
