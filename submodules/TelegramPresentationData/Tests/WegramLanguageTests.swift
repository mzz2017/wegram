import XCTest
import UIKit
@testable import WegramLanguageUI
import TelegramCore

final class WegramLanguageTests: XCTestCase {
    private func language(_ code: String, title: String? = nil, official: Bool = true) -> LocalizationInfo {
        return LocalizationInfo(languageCode: code, baseLanguageCode: nil, customPluralizationCode: nil, title: code, localizedTitle: title ?? code, isOfficial: official, totalStringCount: 1, translatedStringCount: 1, platformUrl: "")
    }

    func testRealLanguageCodesDeduplicateAndKeepDraftAcrossUpdates() {
        var draft = WegramLanguageDraft()
        draft.select(code: "en")
        XCTAssertNil(draft.selected)
        draft.update(official: [self.language("en"), self.language("de")], saved: [self.language("en", official: false), self.language("custom", official: false)], activeCode: "en")
        XCTAssertEqual(draft.languages.map { $0.languageCode }, ["en", "de", "custom"])
        XCTAssertEqual(draft.selectedCode, "en")
        XCTAssertTrue(draft.languages[0].isOfficial)
        draft.select(code: "custom")
        draft.update(official: [self.language("de"), self.language("en")], saved: [self.language("custom", official: false)], activeCode: "de")
        XCTAssertEqual(draft.activeCode, "de")
        XCTAssertEqual(draft.selectedCode, "custom")
        XCTAssertFalse(draft.selected?.isOfficial ?? true)
        draft.select(code: "not-a-language")
        XCTAssertEqual(draft.selectedCode, "custom")
        draft.update(official: [self.language("en")], saved: [], activeCode: "en")
        XCTAssertNil(draft.selected, "A removed language must not be applied using stale row information")
        draft.select(code: "en")
        XCTAssertEqual(draft.selected?.languageCode, "en")
    }

    func testSelectingDoesNotApplyUntilDoneAndSubmissionIsGated() {
        let view = WegramLanguageContentView()
        view.update(dark: false, fontSize: 17, doneTitle: "完成", loadingTitle: "载入中")
        view.frame = CGRect(x: 0, y: 0, width: 402, height: 700)
        view.layoutIfNeeded()
        let item = view.makeSaveItem()
        XCTAssertFalse(view.canSave)
        XCTAssertFalse(item?.isEnabled ?? true)
        view.load(official: [self.language("en", title: "English"), self.language("de", title: "Deutsch")], saved: [], activeCode: "en")
        XCTAssertTrue(item?.isEnabled ?? false)
        var applied: [String] = []
        view.save = { applied.append($0.languageCode) }
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertTrue(applied.isEmpty)
        XCTAssertEqual(view.draft.selectedCode, "de")
        let selected = view.tableView(view.table, cellForRowAt: IndexPath(row: 1, section: 0)) as! WegramLanguageCell
        XCTAssertFalse(selected.check.isHidden)
        XCTAssertTrue(selected.accessibilityTraits.contains(.selected))
        XCTAssertEqual(selected.accessibilityLabel, "Deutsch")
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(applied, ["de"])
        view.submitting = true
        view.saveButton.sendActions(for: .touchUpInside)
        view.tableView(view.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(view.draft.selectedCode, "de")
        XCTAssertEqual(applied, ["de"])
        XCTAssertFalse(view.table.isUserInteractionEnabled)
        XCTAssertFalse(item?.isEnabled ?? true)
        view.submitting = false
        view.update(dark: true, fontSize: 34, doneTitle: "Done", loadingTitle: "Loading")
        XCTAssertEqual(view.draft.selectedCode, "de")
        XCTAssertTrue(view.canSave)
    }

    func testFlatRowsLongNamesAndLoadingState() throws {
        for size in [CGSize(width: 320, height: 450), CGSize(width: 402, height: 771), CGSize(width: 720, height: 200)] {
            let view = WegramLanguageContentView()
            view.frame = CGRect(origin: .zero, size: size)
            view.update(dark: false, fontSize: 17, doneTitle: "完成", loadingTitle: "载入中")
            view.layoutIfNeeded()
            XCTAssertTrue(view.activity.isAnimating)
            view.load(official: [self.language("zh-hans", title: "简体中文"), self.language("zh-hant", title: "繁體中文"), self.language("en", title: "English")], saved: [], activeCode: "en")
            view.table.layoutIfNeeded()
            XCTAssertFalse(view.activity.isAnimating)
            XCTAssertEqual(view.tableView(view.table, heightForRowAt: IndexPath(row: 0, section: 0)), 56)
            XCTAssertEqual(view.table.frame, view.bounds)
            if size.width == 402, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                let image = UIGraphicsImageRenderer(size: size).image { view.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("languages-component.png"))
            }
            view.load(official: [self.language("long", title: String(repeating: "长语言名称", count: 5))], saved: [], activeCode: "long")
            view.update(dark: true, fontSize: 34, doneTitle: "Done", loadingTitle: "Loading")
            let index = IndexPath(row: 0, section: 0)
            let height = view.tableView(view.table, heightForRowAt: index)
            let cell = view.tableView(view.table, cellForRowAt: index) as! WegramLanguageCell
            cell.frame = CGRect(x: 0, y: 0, width: size.width, height: height)
            cell.layoutIfNeeded()
            XCTAssertGreaterThan(height, 56)
            XCTAssertLessThan(cell.name.frame.maxX, cell.check.frame.minX)
            XCTAssertGreaterThanOrEqual(cell.name.bounds.height, cell.name.sizeThatFits(cell.name.bounds.size).height)
            XCTAssertFalse(cell.check.isHidden)
        }
    }
}
