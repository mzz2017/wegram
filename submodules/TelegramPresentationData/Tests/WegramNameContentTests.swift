import XCTest
import UIKit

final class WegramNameContentTests: XCTestCase {
    func testNameEditsPreserveSurnameAndRejectEmptyOrUnchangedValues() {
        let view = WegramNameContentView()
        XCTAssertFalse(view.canSave)
        XCTAssertFalse(view.firstNameField.isEnabled, "Do not accept a draft that the initial peer read would overwrite")
        XCTAssertFalse(view.lastNameField.isEnabled)
        view.setName(firstName: "小明", lastName: "陈")
        XCTAssertFalse(view.canSave)
        view.firstNameField.text = "新名字"
        view.firstNameField.sendActions(for: .editingChanged)
        XCTAssertTrue(view.canSave)
        XCTAssertTrue(view.saveButton.isEnabled)
        XCTAssertEqual(view.lastName, "陈")
        view.setName(firstName: "Remote", lastName: "Changed")
        XCTAssertEqual(view.firstName, "新名字", "Presentation refresh must not replace an edited draft")
        XCTAssertEqual(view.lastName, "陈")
        view.firstNameField.text = " \n "
        view.firstNameField.sendActions(for: .editingChanged)
        XCTAssertFalse(view.canSave)
        XCTAssertFalse(view.saveButton.isEnabled)
        view.firstNameField.text = "小明"
        view.lastNameField.text = "另一个姓"
        view.lastNameField.sendActions(for: .editingChanged)
        XCTAssertTrue(view.canSave)
    }

    func testSaveAndReturnUseTheSameValidationAndSubmissionCannotRepeat() {
        let view = WegramNameContentView()
        view.setName(firstName: "Alice", lastName: "")
        var saves = 0
        view.save = { saves += 1 }
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saves, 0)
        view.firstNameField.text = "Alice 🦆"
        view.firstNameField.sendActions(for: .editingChanged)
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saves, 1)
        XCTAssertFalse(view.textFieldShouldReturn(view.firstNameField))
        XCTAssertEqual(saves, 2)
        view.submitting = true
        view.saveButton.sendActions(for: .touchUpInside)
        _ = view.textFieldShouldReturn(view.firstNameField)
        XCTAssertEqual(saves, 2)
        XCTAssertFalse(view.firstNameField.isEnabled)
        XCTAssertFalse(view.lastNameField.isEnabled)
        view.submitting = false
        XCTAssertTrue(view.canSave)
        XCTAssertTrue(view.saveButton.isEnabled)
        XCTAssertTrue(view.firstNameField.isEnabled)
    }

    func testPermissionLossDisablesSaveAndReturnWithoutReplacingTheDraft() {
        let view = WegramNameContentView()
        view.setName(firstName: "Initial Group", lastName: "")
        view.firstNameField.text = "New Group 🦆"
        view.firstNameField.sendActions(for: .editingChanged)
        var saves = 0
        view.save = { saves += 1 }
        XCTAssertTrue(view.canSave)
        view.allowsEditing = false
        XCTAssertFalse(view.canSave)
        XCTAssertFalse(view.firstNameField.isEnabled)
        XCTAssertFalse(view.saveButton.isEnabled)
        view.saveButton.sendActions(for: .touchUpInside)
        _ = view.textFieldShouldReturn(view.firstNameField)
        XCTAssertEqual(saves, 0)
        view.setName(firstName: "Remote Title", lastName: "")
        XCTAssertEqual(view.firstName, "New Group 🦆")
        view.allowsEditing = true
        XCTAssertTrue(view.canSave)
        view.submitting = true
        view.allowsEditing = false
        view.allowsEditing = true
        XCTAssertFalse(view.canSave)
        view.submitting = false
        view.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(view.firstName, "New Group 🦆")
    }

    func testFieldsAndSaveTargetFitSmallLargeAndDarkLayouts() {
        for width: CGFloat in [320, 402, 720] {
            for font: CGFloat in [17, 34] {
                let view = WegramNameContentView()
                view.frame = CGRect(x: 0, y: 0, width: width, height: 180)
                view.setName(firstName: "名字", lastName: "姓氏")
                view.update(isDark: true, fontSize: font, doneTitle: "完成", firstNameTitle: "名", lastNameTitle: "姓")
                view.layoutIfNeeded()
                XCTAssertEqual(view.firstNameField.frame.minX, 16)
                XCTAssertEqual(view.firstNameField.frame.maxX, width - 16)
                XCTAssertGreaterThanOrEqual(view.firstNameField.bounds.height, 56)
                let first = view.firstNameField.convert(view.firstNameField.bounds, to: view)
                let last = view.lastNameField.convert(view.lastNameField.bounds, to: view)
                XCTAssertGreaterThanOrEqual(last.minY, first.maxY)
                XCTAssertGreaterThanOrEqual(view.contentSize.height, last.maxY)
                XCTAssertEqual(view.firstNameField.keyboardAppearance, .dark)
                XCTAssertEqual(view.firstNameField.accessibilityLabel, "名")
                XCTAssertEqual(view.lastNameField.accessibilityLabel, "姓")
                XCTAssertEqual(view.saveButton.accessibilityLabel, "完成")
                XCTAssertGreaterThanOrEqual(view.saveButton.bounds.height, 44)
                XCTAssertGreaterThanOrEqual(view.saveButton.bounds.width, 44)
            }
        }
        let view = WegramNameContentView()
        view.frame = CGRect(x: 0, y: 0, width: 402, height: 180)
        view.setName(firstName: "名字", lastName: "")
        view.layoutIfNeeded()
        XCTAssertEqual(view.contentSize.height, 56, "An empty surname must not add a blank row to the one-field screen")
    }
}
