import XCTest
import UIKit
import TelegramUIPreferences
import TelegramPresentationData

final class WegramTextSizeTests: XCTestCase {
    func testUntouchedDraftPreservesSystemModeAndIndependentSizes() {
        var current = PresentationThemeSettings.defaultSettings
        current.useSystemFont = true
        current.fontSize = .small
        current.listsFontSize = .extraLarge
        var draft = WegramTextSizeDraft()
        draft.select(index: 6)
        XCTAssertNil(draft.selection, "Loading cannot accept input")
        draft.load(previewSize: 19)
        let untouched = draft.applying(to: current)
        XCTAssertTrue(untouched.useSystemFont)
        XCTAssertEqual(untouched.fontSize, .small)
        XCTAssertEqual(untouched.listsFontSize, .extraLarge)
        draft.select(index: 2)
        draft.load(previewSize: 26)
        XCTAssertEqual(draft.previewSize, 16)
        XCTAssertEqual(draft.selection, .medium, "Raw value ordering must not skip the 16pt size")
        current.largeEmoji = !current.largeEmoji
        let updated = draft.applying(to: current)
        XCTAssertFalse(updated.useSystemFont)
        XCTAssertEqual(updated.fontSize, .medium)
        XCTAssertEqual(updated.listsFontSize, .medium)
        XCTAssertEqual(updated.largeEmoji, current.largeEmoji, "Saving must retain concurrent unrelated preferences")
        XCTAssertEqual(WegramTextSizeDraft.sizes.map { $0.baseDisplaySize }, [14, 15, 16, 17, 19, 23, 26])
    }

    func testRealSliderPreviewAndSubmissionGuard() {
        let view = WegramTextSizeContentView()
        view.update(isDark: false, chinese: true, doneTitle: "完成", safeBottom: 34)
        XCTAssertFalse(view.slider.isEnabled)
        XCTAssertFalse(view.saveButton.isEnabled)
        let item = view.makeSaveItem()
        XCTAssertFalse(item?.isEnabled ?? true)
        view.load(previewSize: 17)
        XCTAssertTrue(item?.isEnabled ?? false)
        XCTAssertEqual(view.slider.value, 3)
        var saves = 0
        view.save = { saves += 1 }
        view.slider.value = 5.8
        view.slider.sendActions(for: .valueChanged)
        XCTAssertEqual(view.slider.value, 6)
        XCTAssertEqual(view.draft.selection, .extraLargeX2)
        XCTAssertEqual(view.bubbles[0].attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, .systemFont(ofSize: 26))
        XCTAssertEqual(view.slider.accessibilityValue, "26")
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saves, 1)
        view.submitting = true
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saves, 1)
        XCTAssertFalse(view.slider.isEnabled)
        XCTAssertFalse(item?.isEnabled ?? true)
        view.update(isDark: true, chinese: false, doneTitle: "Done", safeBottom: 0)
        XCTAssertEqual(view.slider.accessibilityLabel, "Text Size")
        XCTAssertEqual(view.draft.selection, .extraLargeX2)
    }

    func testPreviewScrollsWithoutOverlappingSliderOnShortScreens() throws {
        for size in [CGSize(width: 320, height: 450), CGSize(width: 402, height: 771), CGSize(width: 720, height: 200)] {
            let view = WegramTextSizeContentView()
            view.frame = CGRect(origin: .zero, size: size)
            view.update(isDark: false, chinese: true, doneTitle: "完成", safeBottom: 34)
            view.load(previewSize: 26)
            view.layoutIfNeeded()
            XCTAssertEqual(view.preview.frame.maxY, view.panel.frame.minY)
            XCTAssertGreaterThanOrEqual(view.slider.bounds.height, 44)
            XCTAssertTrue(view.panel.bounds.contains(view.slider.frame))
            XCTAssertLessThan(view.bubbles[0].frame.maxY, view.bubbles[1].frame.minY)
            XCTAssertLessThan(view.bubbles[1].frame.maxY, view.bubbles[2].frame.minY)
            for bubble in view.bubbles { XCTAssertLessThanOrEqual(bubble.frame.maxX, view.bounds.width - 12) }
            XCTAssertGreaterThanOrEqual(view.preview.contentSize.height, view.bubbles[2].frame.maxY)
            if size.width == 402, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                let image = UIGraphicsImageRenderer(size: size).image { view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("text-size-large-component.png"))
            }
        }
    }
}
