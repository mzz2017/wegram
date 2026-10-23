import XCTest
import UIKit
import TelegramCore

final class WegramStorageTests: XCTestCase {
    private func stats(_ sizes: [StorageUsageStats.CategoryKey: Int64], capacity: Int64 = 1000, free: Int64 = 400) -> AllStorageUsageStats {
        AllStorageUsageStats(deviceAvailableSpace: capacity, deviceFreeSpace: free, totalStats: StorageUsageStats(categories: sizes.mapValues { StorageUsageStats.CategoryData(size: $0, messages: [:]) }), peers: [:])
    }
    func testCacheScopeBreakdownDeviceCapacityAndUnavailableStats() throws {
        let value = WegramStorageSummary(stats: self.stats([.photos: 30, .videos: 20, .files: 10, .music: 10, .avatars: 5, .stickers: 5, .misc: 10, .stories: 10]))
        XCTAssertEqual(value.cacheBytes, 100)
        XCTAssertEqual(value.mediaBytes, 70)
        XCTAssertEqual(value.otherBytes, 30)
        XCTAssertEqual(Set(value.clearCategories), Set([.photos, .videos, .files, .music, .avatars, .stickers, .misc, .stories]))
        let fractions = try XCTUnwrap(value.fractions)
        XCTAssertEqual(fractions[0], 0.1, accuracy: 0.0001)
        XCTAssertEqual(fractions[1], 0.5, accuracy: 0.0001)
        XCTAssertEqual(fractions[2], 0.4, accuracy: 0.0001)
        XCTAssertEqual(fractions.reduce(0, +), 1, accuracy: 0.0001)
        XCTAssertNil(WegramStorageSummary(stats: self.stats([.photos: 100], capacity: 0, free: 0)).fractions)
        XCTAssertNil(WegramStorageSummary(stats: self.stats([.photos: 100], capacity: 1000, free: 999)).fractions, "Logical cache size exceeding physical used space cannot be drawn as a reliable capacity share")
        let invalid = WegramStorageSummary(stats: self.stats([.photos: -100, .videos: Int64.max, .misc: Int64.max]))
        XCTAssertEqual(invalid.cacheBytes, Int64.max)
        XCTAssertGreaterThanOrEqual(invalid.otherBytes, 0)
        XCTAssertFalse(invalid.clearCategories.contains(.photos))
        XCTAssertNil(invalid.fractions)
    }
    func testLoadingZeroAndBusyDoNotClearOrInventACompletedCleanup() {
        let view = WegramStorageContentView()
        var clears = 0
        var manages = 0
        view.clear = { clears += 1 }
        view.manage = { manages += 1 }
        view.blocks[0].button.sendActions(for: .touchUpInside)
        view.blocks[1].button.sendActions(for: .touchUpInside)
        XCTAssertEqual(clears + manages, 0)
        XCTAssertEqual(view.total.text, "—")
        XCTAssertTrue(view.activity.isAnimating)
        view.load(summary: WegramStorageSummary(stats: self.stats([:])))
        view.blocks[0].button.sendActions(for: .touchUpInside)
        view.blocks[1].button.sendActions(for: .touchUpInside)
        XCTAssertEqual(clears, 0)
        XCTAssertEqual(manages, 1)
        view.load(summary: WegramStorageSummary(stats: self.stats([.photos: 100])))
        view.blocks[0].button.sendActions(for: .touchUpInside)
        XCTAssertEqual(clears, 1)
        XCTAssertEqual(view.summary?.cacheBytes, 100, "A clear intent must not replace actual cache stats with zero")
        view.busy = true
        view.blocks[0].button.sendActions(for: .touchUpInside)
        view.blocks[1].button.sendActions(for: .touchUpInside)
        XCTAssertEqual(clears, 1)
        XCTAssertEqual(manages, 1)
        XCTAssertFalse(view.blocks[0].button.isEnabled)
        XCTAssertTrue(view.blocks[0].button.accessibilityTraits.contains(.notEnabled))
        view.setProgress(Float.nan)
        XCTAssertTrue(view.progress.isHidden)
        view.setProgress(2)
        XCTAssertEqual(view.progress.progress, 1)
        view.setProgress(-1)
        XCTAssertEqual(view.progress.progress, 0)
        view.busy = false
        XCTAssertTrue(view.progress.isHidden)
    }
    func testReferenceChartBlocksButtonsAndLongTextFitLargeType() throws {
        for size in [CGSize(width: 320, height: 450), CGSize(width: 402, height: 771), CGSize(width: 720, height: 200)] {
            for font: CGFloat in [17, 34] {
                let view = WegramStorageContentView()
                view.frame = CGRect(origin: .zero, size: size)
                view.update(dark: false, fontSize: font, chinese: true)
                view.load(summary: WegramStorageSummary(stats: self.stats([.photos: 70, .misc: 30])))
                view.layoutIfNeeded()
                XCTAssertEqual(view.chart.frame.minX, 24)
                XCTAssertEqual(view.chart.frame.maxX, size.width - 24)
                XCTAssertEqual(view.segments.last!.frame.maxX, view.chart.bounds.width, accuracy: 0.01)
                for pair in zip(view.legends, view.legends.dropFirst()) { XCTAssertFalse(pair.0.frame.intersects(pair.1.frame)) }
                XCTAssertGreaterThan(view.legends[2].frame.minY, view.legends[1].frame.minY)
                var lastY = view.proportion.frame.maxY
                for block in view.blocks {
                    XCTAssertGreaterThan(block.frame.minY, lastY)
                    XCTAssertGreaterThan(block.explanation.frame.minY, block.size.frame.maxY)
                    XCTAssertLessThanOrEqual(block.explanation.frame.maxY, block.bounds.height - 12)
                    if !block.button.isHidden {
                        XCTAssertGreaterThanOrEqual(block.button.bounds.height, 44)
                        XCTAssertEqual(block.button.titleLabel?.textAlignment, .center, "Storage action text must be centered in the reference button")
                        XCTAssertLessThan(block.title.frame.maxX, block.button.frame.minX)
                        XCTAssertLessThan(block.size.frame.maxX, block.button.frame.minX)
                    }
                    lastY = block.frame.maxY
                }
                XCTAssertGreaterThan(view.contentSize.height, view.blocks.last!.frame.maxY)
                if size.width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let image = UIGraphicsImageRenderer(size: size).image { view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("storage-component.png"))
                }
            }
        }
    }
}
