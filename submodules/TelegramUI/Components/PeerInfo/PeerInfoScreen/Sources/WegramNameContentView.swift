import UIKit
import AsyncDisplayKit
import Display

final class WegramNameContentView: UIScrollView, UITextFieldDelegate {
    let firstNameField = UITextField()
    let lastNameField = UITextField()
    let saveButton = WegramNameSaveButton()
    private let firstRow = UIView()
    private let lastRow = UIView()
    private var initialFirstName: String?
    private var initialLastName = ""
    private var rowHeight: CGFloat = 56
    private lazy var saveButtonNode: ASDisplayNode = {
        let node = ASDisplayNode(viewBlock: { [button = self.saveButton] in button })
        node.style.preferredSize = CGSize(width: 64, height: 44)
        return node
    }()
    private var saveItem: UIBarButtonItem?
    func makeSaveItem() -> UIBarButtonItem? {
        let item = UIBarButtonItem(customDisplayNode: self.saveButtonNode)
        self.saveItem = item
        item?.accessibilityLabel = self.saveButton.accessibilityLabel
        item?.isEnabled = self.canSave
        return item
    }
    var allowsEditing = true { didSet { self.updateSaveState() } }
    var save: (() -> Void)?
    var submitting = false {
        didSet { self.updateSaveState() }
    }

    var firstName: String { self.firstNameField.text ?? "" }
    var lastName: String { self.lastNameField.text ?? "" }
    var canSave: Bool {
        self.allowsEditing && self.initialFirstName != nil && !self.submitting && self.firstNameField.markedTextRange == nil && self.lastNameField.markedTextRange == nil && !self.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (self.firstName != self.initialFirstName || self.lastName != self.initialLastName)
    }

    init() {
        super.init(frame: .zero)
        self.contentInsetAdjustmentBehavior = .never
        self.alwaysBounceVertical = true
        self.keyboardDismissMode = .interactive
        self.addSubview(self.firstRow)
        self.addSubview(self.lastRow)
        self.firstRow.addSubview(self.firstNameField)
        self.lastRow.addSubview(self.lastNameField)
        for field in [self.firstNameField, self.lastNameField] {
            field.delegate = self
            field.clearButtonMode = .whileEditing
            field.autocorrectionType = .no
            field.autocapitalizationType = .words
            field.returnKeyType = .done
            field.addAction(UIAction(handler: { [weak self] _ in self?.updateSaveState() }), for: .editingChanged)
        }
        self.firstNameField.textContentType = .givenName
        self.lastNameField.textContentType = .familyName
        self.firstNameField.accessibilityIdentifier = "Wegram.Profile.FirstName"
        self.lastNameField.accessibilityIdentifier = "Wegram.Profile.LastName"
        self.saveButton.addAction(UIAction(handler: { [weak self] _ in self?.requestSave() }), for: .touchUpInside)
        self.lastRow.isHidden = true
        self.updateSaveState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setName(firstName: String, lastName: String) {
        guard self.initialFirstName == nil else { return }
        self.initialFirstName = firstName
        self.initialLastName = lastName
        self.firstNameField.text = firstName
        self.lastNameField.text = lastName
        // Empty surname editing remains available through the full profile entry.
        self.lastRow.isHidden = lastName.isEmpty
        self.setNeedsLayout()
        self.updateSaveState()
    }

    func update(isDark: Bool, fontSize: CGFloat, doneTitle: String, firstNameTitle: String, lastNameTitle: String) {
        self.backgroundColor = UIColor(white: isDark ? 0.1 : 237 / 255, alpha: 1)
        self.rowHeight = max(56, ceil(fontSize * 56 / 17))
        for (row, field, title) in [(self.firstRow, self.firstNameField, firstNameTitle), (self.lastRow, self.lastNameField, lastNameTitle)] {
            row.backgroundColor = isDark ? UIColor(white: 0.14, alpha: 1) : .white
            field.font = .systemFont(ofSize: fontSize)
            field.textColor = isDark ? UIColor(white: 0.82, alpha: 1) : UIColor(white: 0.1, alpha: 1)
            field.tintColor = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
            field.keyboardAppearance = isDark ? .dark : .light
            field.placeholder = title
            field.accessibilityLabel = title
        }
        self.saveButton.setTitle(self.submitting ? "" : doneTitle, for: .normal)
        self.saveButton.accessibilityLabel = doneTitle
        self.saveItem?.accessibilityLabel = doneTitle
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.firstRow.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.rowHeight)
        self.lastRow.frame = CGRect(x: 0, y: self.rowHeight + 1 / self.traitCollection.displayScale, width: self.bounds.width, height: self.rowHeight)
        for (row, field) in [(self.firstRow, self.firstNameField), (self.lastRow, self.lastNameField)] {
            field.frame = row.bounds.insetBy(dx: 16, dy: 0)
        }
        self.contentSize = CGSize(width: self.bounds.width, height: self.lastRow.isHidden ? self.rowHeight : self.lastRow.frame.maxY)
    }

    private func updateSaveState() {
        self.firstNameField.isEnabled = self.allowsEditing && self.initialFirstName != nil && !self.submitting
        self.lastNameField.isEnabled = self.allowsEditing && self.initialFirstName != nil && !self.submitting
        self.saveButton.isEnabled = self.canSave
        self.saveItem?.isEnabled = self.canSave
    }
    private func requestSave() { if self.canSave { self.save?() } }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.requestSave()
        return false
    }
}

