import XCTest
import UIKit
import Display

final class WegramDownloadCategoryTests: XCTestCase {
    private func rules(preload: Bool = true) -> [WegramDownloadToggle] {
        [WegramDownloadToggle(field: .contact, title: "联系人", value: true, enabled: true),
         WegramDownloadToggle(field: .otherPrivate, title: "其他私聊及尚未添加为联系人的用户", value: false, enabled: true),
         WegramDownloadToggle(field: .group, title: "群组", value: true, enabled: true),
         WegramDownloadToggle(field: .channel, title: "频道", value: false, enabled: true),
         WegramDownloadToggle(field: .preload, title: "预下载较大的视频", value: preload, enabled: preload)]
    }
    private func size(_ bytes: Int64 = 10 * 1024 * 1024) -> WegramDownloadSize {
        WegramDownloadSize(heading: "视频大小上限", text: "最多 10 MB", bytes: bytes, minimum: "512 KB", maximum: "1.5 GB")
    }
    func testSizeSliderThumbRemainsVisibleOnWhiteRows() throws {
        let view = WegramDownloadCategoryContentView()
        let knob = try XCTUnwrap(view.slider.knobImage)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: CGSize(width: 27, height: 27), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 27, height: 27))
            knob.draw(in: CGRect(x: 0, y: 0, width: 27, height: 27))
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixels = [UInt8](repeating: 0, count: 27 * 27 * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 27, height: 27, bitsPerComponent: 8, bytesPerRow: 27 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 27, height: 27))
        }
        let darkest = pixels.enumerated().filter { $0.offset % 4 != 3 }.map { $0.element }.min() ?? 255
        XCTAssertLessThan(darkest, 245, "A white thumb without an outline disappears on the white settings row")
    }
    func testOriginalNonlinearSizeMappingAndUntouchedUnlimitedValue() {
        let anchors: [(CGFloat, Int64)] = [(0, 512 * 1024), (0.257, 1024 * 1024), (0.520, 10 * 1024 * 1024), (0.763, 100 * 1024 * 1024), (1, 1536 * 1024 * 1024)]
        for (position, bytes) in anchors {
            XCTAssertEqual(autodownloadSizeSliderValue(for: bytes), position, accuracy: 0.00001)
            XCTAssertEqual(autodownloadSizeForSliderValue(for: position), bytes)
        }
        for bytes: Int64 in [600_000, 2_700_000, 15_000_000, 500_000_000] {
            let restored = autodownloadSizeForSliderValue(for: autodownloadSizeSliderValue(for: bytes))
            XCTAssertLessThanOrEqual(abs(restored - bytes), 1)
        }
        let view = WegramDownloadCategoryContentView()
        var changes: [Int64] = []
        view.adjustSize = { changes.append($0) }
        view.load(heading: "测试", rules: self.rules(), size: self.size(Int64.max), footer: "")
        XCTAssertEqual(view.slider.value, 1)
        XCTAssertTrue(changes.isEmpty, "Showing an unlimited source value must not rewrite it to the slider maximum")
    }
    func testLoadingDisabledPreloadAndReusedControlCannotRunOldIntents() throws {
        let view = WegramDownloadCategoryContentView()
        var toggles: [WegramMediaRuleField] = []
        var sizes: [Int64] = []
        view.toggle = { toggles.append($0) }
        view.adjustSize = { sizes.append($0) }
        view.slider.sendActions(for: .valueChanged)
        for row in view.rowViews.values { row.toggle.sendActions(for: .valueChanged) }
        XCTAssertTrue(toggles.isEmpty)
        XCTAssertTrue(sizes.isEmpty)
        view.load(heading: "测试", rules: self.rules(), size: self.size(), footer: "")
        for field in [WegramMediaRuleField.contact, .otherPrivate, .group, .channel, .preload] {
            try XCTUnwrap(view.rowViews[field]).toggle.sendActions(for: .valueChanged)
        }
        XCTAssertEqual(toggles, [.contact, .otherPrivate, .group, .channel, .preload])
        let oldPreload = try XCTUnwrap(view.rowViews[.preload]).toggle
        view.load(heading: "测试", rules: self.rules(preload: false), size: self.size(1024 * 1024), footer: "")
        XCTAssertFalse(oldPreload.isOn)
        XCTAssertFalse(oldPreload.isEnabled)
        XCTAssertTrue(oldPreload.accessibilityTraits.contains(.notEnabled))
        oldPreload.sendActions(for: .valueChanged)
        XCTAssertFalse(oldPreload.accessibilityActivate())
        XCTAssertEqual(toggles.count, 5)
        view.load(heading: "照片", rules: Array(self.rules().prefix(4)), size: nil, footer: "")
        XCTAssertTrue(view.sizeBlock.isHidden)
        XCTAssertTrue(view.rowViews[.preload]?.isHidden == true)
        view.slider.sendActions(for: .valueChanged)
        oldPreload.sendActions(for: .valueChanged)
        XCTAssertTrue(sizes.isEmpty)
        XCTAssertEqual(toggles.count, 5)
    }
    func testSizeSliderAccessibilityUsesTheOriginalMappingAndStopsAtEdges() {
        let view = WegramDownloadCategoryContentView()
        var sizes: [Int64] = []
        view.adjustSize = { sizes.append($0) }
        view.formatSize = { "\($0) bytes" }
        view.slider.accessibilityIncrement()
        XCTAssertTrue(sizes.isEmpty)
        view.load(heading: "测试", rules: self.rules(), size: self.size(), footer: "")
        let before = view.slider.value
        view.slider.accessibilityIncrement()
        XCTAssertEqual(view.slider.value, before + 0.05, accuracy: 0.0001)
        XCTAssertEqual(sizes.last, autodownloadSizeForSliderValue(for: view.slider.value))
        XCTAssertEqual(view.slider.accessibilityValue, "\(sizes.last!) bytes")
        XCTAssertTrue(view.slider.accessibilityTraits.contains(.adjustable))
        view.slider.value = 1
        let count = sizes.count
        view.slider.accessibilityIncrement()
        XCTAssertEqual(sizes.count, count)
        view.slider.value = 0
        view.slider.accessibilityDecrement()
        XCTAssertEqual(sizes.count, count)
        view.load(heading: "照片", rules: Array(self.rules().prefix(4)), size: nil, footer: "")
        view.slider.accessibilityIncrement()
        XCTAssertEqual(sizes.count, count)
    }
    func testRuleRowsSliderAndDescriptionsReflowOnTheSameView() throws {
        for dark in [false, true] {
            for font: CGFloat in [17, 34] {
                let view = WegramDownloadCategoryContentView(frame: .zero)
                view.update(dark: dark, fontSize: font, chinese: true)
                view.load(heading: "自动下载视频", rules: self.rules(), size: self.size(), footer: "测试说明：仅在原有规则允许的范围内预下载视频。")
                for width: CGFloat in [402, 320, 720, 402] {
                    view.frame = CGRect(x: 0, y: 0, width: width, height: 600)
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    for row in view.rowViews.values where !row.isHidden {
                        row.layoutIfNeeded()
                        XCTAssertEqual(row.frame.width, width)
                        XCTAssertEqual(row.title.frame.minX, 16)
                        XCTAssertGreaterThanOrEqual(row.frame.height, 56)
                        XCTAssertEqual(row.toggle.bounds.size, CGSize(width: 51, height: 44))
                        XCTAssertLessThan(row.title.frame.maxX, row.toggle.frame.minX)
                        XCTAssertLessThanOrEqual(row.title.sizeThatFits(CGSize(width: row.title.bounds.width, height: .greatestFiniteMagnitude)).height, row.title.bounds.height + 1)
                    }
                    XCTAssertEqual(view.slider.bounds.height, 44)
                    XCTAssertGreaterThanOrEqual(view.slider.frame.minY, view.sizeLabel.frame.maxY + 8)
                    XCTAssertGreaterThanOrEqual(view.minimum.frame.minY, view.slider.frame.maxY)
                    XCTAssertLessThan(view.minimum.frame.maxX, view.maximum.frame.minX)
                    XCTAssertLessThanOrEqual(view.maximum.frame.maxY, view.sizeBlock.bounds.height - 12)
                    let preload = try XCTUnwrap(view.rowViews[.preload])
                    XCTAssertEqual(preload.frame.minY, view.sizeBlock.frame.maxY)
                    XCTAssertGreaterThanOrEqual(view.footer.frame.minY, preload.frame.maxY + 8)
                    XCTAssertGreaterThan(view.contentSize.height, view.footer.frame.maxY)
                    if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "download-rule-dark.png" : "download-rule-light.png"))
                    }
                }
            }
        }
    }
}
