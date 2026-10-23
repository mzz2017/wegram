import XCTest
import UIKit

final class WegramBioContentTests: XCTestCase {
    private func content(limit: Int = 70) -> WegramBioContentView {
        let view = WegramBioContentView()
        view.frame = CGRect(x: 0, y: 0, width: 402, height: 400)
        view.update(isDark: false, fontSize: 17, maximumLength: limit, title: "设置个性签名", doneTitle: "完成")
        return view
    }

    func testLoadingClearAndSubmissionPreserveTheDraft() {
        let view = self.content()
        XCTAssertFalse(view.textView.isEditable)
        XCTAssertFalse(view.canSave)
        view.setBio("Original bio")
        XCTAssertTrue(view.textView.isEditable)
        XCTAssertFalse(view.canSave)
        view.textView.text = ""
        view.textViewDidChange(view.textView)
        XCTAssertTrue(view.canSave, "Clearing a previously set bio must be allowed")
        var submissions = 0
        view.save = { submissions += 1 }
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(submissions, 1)
        view.submitting = true
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(submissions, 1)
        XCTAssertFalse(view.textView.isEditable)
        view.submitting = false
        XCTAssertTrue(view.textView.isEditable)
        XCTAssertTrue(view.canSave)
        view.textView.text = "Draft 🦆\nSecond line"
        view.textViewDidChange(view.textView)
        view.setBio("Remote update")
        XCTAssertEqual(view.text, "Draft 🦆\nSecond line")
        view.update(isDark: true, fontSize: 34, maximumLength: 140, title: "Set Bio", doneTitle: "Done", remainingTitle: "剩余字数")
        XCTAssertEqual(view.text, "Draft 🦆\nSecond line")
        XCTAssertEqual(view.textView.keyboardAppearance, .dark)
        XCTAssertEqual(view.counterLabel.accessibilityLabel, "剩余字数")
    }

    func testLoadedEmptyGroupDescriptionCanCreateItsFirstValueWithoutSavingAnUnchangedEmptyValue() {
        let view = self.content(limit: 255)
        view.allowsEditing = false
        XCTAssertFalse(view.textView.isEditable)
        view.setBio("")
        XCTAssertFalse(view.canSave)
        view.allowsEditing = true
        XCTAssertTrue(view.textView.isEditable)
        XCTAssertFalse(view.canSave)
        var saves = 0
        view.save = { saves += 1 }
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saves, 0)
        view.textView.text = "First group description 🦆"
        view.textViewDidChange(view.textView)
        XCTAssertTrue(view.canSave)
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saves, 1)
        view.allowsEditing = false
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(view.text, "First group description 🦆")
    }

    func testPermissionRevocationDisablesEditingAndSavingWithoutDiscardingDraft() {
        let view = self.content(limit: 255)
        view.setBio("Original group description")
        view.textView.text = "Local draft"
        view.textViewDidChange(view.textView)
        var saves = 0
        view.save = { saves += 1 }
        XCTAssertTrue(view.canSave)
        view.allowsEditing = false
        XCTAssertFalse(view.textView.isEditable)
        XCTAssertFalse(view.canSave)
        XCTAssertFalse(view.makeSaveItem()?.isEnabled ?? true)
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saves, 0)
        view.update(isDark: true, fontSize: 34, maximumLength: 255, title: "Group Description", doneTitle: "Done")
        view.setBio("Remote update")
        XCTAssertEqual(view.text, "Local draft")
        XCTAssertFalse(view.textView.isEditable)
        view.allowsEditing = true
        XCTAssertTrue(view.textView.isEditable)
        XCTAssertTrue(view.canSave)
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saves, 1)
    }

    func testActualCharacterLimitAllowsEmojiWithoutTruncatingOverLimitPastes() {
        let view = self.content(limit: 3)
        view.setBio("")
        let emoji = "👨‍👩‍👧‍👦"
        view.textView.text = "中" + emoji + "e\u{301}"
        view.textViewDidChange(view.textView)
        XCTAssertEqual(view.text.count, 3)
        XCTAssertEqual(view.counterLabel.text, "0")
        XCTAssertTrue(view.canSave)
        view.textView.text += "四"
        view.textViewDidChange(view.textView)
        XCTAssertEqual(view.text, "中" + emoji + "e\u{301}四")
        XCTAssertEqual(view.counterLabel.text, "-1")
        XCTAssertEqual(view.counterLabel.accessibilityLabel, "Characters remaining")
        XCTAssertEqual(view.counterLabel.accessibilityValue, "-1")
        XCTAssertFalse(view.canSave)
        XCTAssertFalse(view.saveButton.isEnabled)
        view.update(isDark: false, fontSize: 17, maximumLength: 4, title: "Bio", doneTitle: "Done")
        XCTAssertTrue(view.canSave, "Account limit changes must be applied without resetting the draft")
        XCTAssertEqual(view.counterLabel.text, "0")
    }

    func testMultilineEditorAndCounterStayInsideSmallAndLargeLayouts() throws {
        for width: CGFloat in [320, 402, 720] {
            for font: CGFloat in [17, 34] {
                let view = self.content(limit: 140)
                view.frame = CGRect(x: 0, y: 0, width: width, height: 120)
                view.update(isDark: true, fontSize: font, maximumLength: 140, title: "个性签名", doneTitle: "完成")
                view.setBio(String(repeating: "一行很长的签名 🦆\n", count: 12))
                view.layoutIfNeeded()
                XCTAssertEqual(view.textView.frame.minX, 16)
                XCTAssertEqual(view.textView.frame.maxX, width - 16)
                XCTAssertLessThanOrEqual(view.textView.frame.maxY, view.counterLabel.frame.minY - 8)
                XCTAssertLessThanOrEqual(view.counterLabel.frame.maxY + 16, view.contentSize.height)
                XCTAssertGreaterThan(view.contentSize.height, view.bounds.height)
                XCTAssertGreaterThanOrEqual(view.saveButton.bounds.height, 44)
                XCTAssertEqual(view.textView.accessibilityLabel, "个性签名")
                if width == 402 && font == 17, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                    let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
                    try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("bio-dark-long-component.png"))
                }
            }
        }
    }
}
