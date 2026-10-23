import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData

struct WegramRemarkDraft: Equatable {
    var name: String
    var note: String
}

/// WeChat's 编辑备注 page (IMG_2445) over Telegram's contact edit: 备注名 is the contact name, 备忘 the private
/// note. Telegram's phone number is shown read-only; birthday/photo suggestions, the personal photo and deleting
/// the contact stay in Telegram's editor (profile ••• → full profile → Edit).
final class WegramRemarkEditorController: ViewController {
    struct Initial {
        let name: String
        let phone: String?
        let note: String
        /// A note with formatting cannot be edited as plain text without losing it, so it opens Telegram's editor.
        let noteIsFormatted: Bool
        let noteLimit: Int
    }

    private let initial: Initial
    private var presentationData: PresentationData
    private let save: (WegramRemarkDraft, @escaping (Bool) -> Void) -> Void
    private let openFullEditor: () -> Void
    private var content: WegramRemarkEditorView?
    private var isSaving = false

    init(presentationData: PresentationData, initial: Initial, save: @escaping (WegramRemarkDraft, @escaping (Bool) -> Void) -> Void, openFullEditor: @escaping () -> Void) {
        self.presentationData = presentationData
        self.initial = initial
        self.save = save
        self.openFullEditor = openFullEditor
        super.init(navigationBarPresentationData: nil)
        self.navigationPresentation = .flatModal
        self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        let chinese = self.presentationData.strings.baseLanguageCode.hasPrefix("zh")
        let content = WegramRemarkEditorView(initial: self.initial, dark: self.presentationData.theme.overallDarkAppearance, chinese: chinese)
        content.cancel.addAction(UIAction(handler: { [weak self] _ in
            self?.view.endEditing(true)
            self?.dismiss()
        }), for: .touchUpInside)
        content.done.addAction(UIAction(handler: { [weak self] _ in self?.commit() }), for: .touchUpInside)
        content.openFormattedNote = { [weak self] in
            guard let self else { return }
            self.dismiss()
            self.openFullEditor()
        }
        self.content = content
        self.displayNode.view.addSubview(content)
        self.displayNode.backgroundColor = content.backgroundColor
        self.displayNodeDidLoad()
    }

    private func commit() {
        guard let content = self.content, !self.isSaving, content.canSave else { return }
        self.view.endEditing(true)
        self.isSaving = true
        content.setSaving(true)
        self.save(content.draft, { [weak self] success in
            guard let self else { return }
            self.isSaving = false
            self.content?.setSaving(false)
            if success { self.dismiss() }
        })
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        guard let content = self.content else { return }
        content.statusHeight = layout.statusBarHeight ?? 0
        content.bottomInset = max(layout.intrinsicInsets.bottom, layout.inputHeight ?? 0)
        transition.updateFrame(view: content, frame: CGRect(x: layout.safeInsets.left, y: 0, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: layout.size.height))
        content.setNeedsLayout()
    }
}

final class WegramRemarkEditorView: UIView, UITextFieldDelegate, UITextViewDelegate {
    // IMG_2445 at 3x, in points: fields inset 24 with 16pt text padding and an 8pt radius; each grey label's
    // centre sits 12.6pt above its field and 32.4pt below the previous field. Colours are WeChat's.
    private static let fieldInset: CGFloat = 24
    private static let textInset: CGFloat = 16
    private static let nameLimit = 64

    let cancel = UIButton(type: .custom)
    let done = UIButton(type: .custom)
    private let bar = UIView()
    private let scroll = UIScrollView()
    private let title = UILabel()
    private let nameLabel = UILabel()
    private let nameBox = UIView()
    private let nameField = UITextField()
    private let phoneLabel = UILabel()
    private let phoneBox = UIView()
    private let phoneText = UILabel()
    private let memoLabel = UILabel()
    private let memoBox = UIView()
    private let memoView = UITextView()
    private let memoPlaceholder = UILabel()
    private let initial: WegramRemarkEditorController.Initial
    private let dark: Bool
    private var saving = false
    var openFormattedNote: (() -> Void)?
    var statusHeight: CGFloat = 0
    var bottomInset: CGFloat = 0

    init(initial: WegramRemarkEditorController.Initial, dark: Bool, chinese: Bool) {
        self.initial = initial
        self.dark = dark
        super.init(frame: .zero)
        let primary = UIColor(white: dark ? 1 : 0, alpha: dark ? 0.8 : 0.9)          // FG_0
        let secondary = UIColor(white: dark ? 1 : 0, alpha: dark ? 0.5 : 0.55)       // FG_1
        let placeholder = UIColor(white: dark ? 1 : 0, alpha: 0.3)                   // FG_2
        let field = dark ? UIColor(white: 0x20 / 255, alpha: 1) : UIColor(white: 0xF7 / 255, alpha: 1) // BG_3
        self.backgroundColor = dark ? UIColor(white: 0x19 / 255, alpha: 1) : .white   // BG_2

        self.addSubview(self.scroll)
        self.addSubview(self.bar)
        self.bar.addSubview(self.cancel)
        self.bar.addSubview(self.done)
        self.bar.backgroundColor = self.backgroundColor
        self.scroll.alwaysBounceVertical = true
        self.scroll.keyboardDismissMode = .interactive
        self.scroll.contentInsetAdjustmentBehavior = .never

        self.cancel.setTitle(chinese ? "取消" : "Cancel", for: .normal)
        self.cancel.setTitleColor(primary, for: .normal)
        self.cancel.titleLabel?.font = .systemFont(ofSize: 17)
        self.done.setTitle(chinese ? "完成" : "Done", for: .normal)
        // IMG_2445 at 3x: a 52x32 box with a 6pt radius, its title Medium 14pt (glyph pitch and ink weight).
        self.done.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        self.done.layer.cornerRadius = 6
        self.done.clipsToBounds = true

        self.title.text = chinese ? "编辑备注" : "Edit Remark"
        self.title.font = .systemFont(ofSize: 22, weight: .medium)
        self.title.textColor = primary
        self.title.textAlignment = .center
        self.title.accessibilityTraits = .header

        for (label, text) in [(self.nameLabel, chinese ? "备注名" : "Remark"), (self.phoneLabel, chinese ? "电话" : "Phone"), (self.memoLabel, chinese ? "备忘" : "Notes")] {
            label.text = text
            label.font = .systemFont(ofSize: 14)
            label.textColor = secondary
        }
        for box in [self.nameBox, self.phoneBox, self.memoBox] {
            box.backgroundColor = field
            box.layer.cornerRadius = 8
        }
        for view in [self.title, self.nameLabel, self.nameBox, self.phoneLabel, self.phoneBox, self.memoLabel, self.memoBox] {
            self.scroll.addSubview(view)
        }
        let hasPhone = initial.phone != nil
        self.phoneLabel.isHidden = !hasPhone
        self.phoneBox.isHidden = !hasPhone

        self.nameField.text = initial.name
        self.nameField.font = .systemFont(ofSize: 17)
        self.nameField.textColor = primary
        self.nameField.tintColor = UIColor(rgb: 0x07c160)
        self.nameField.clearButtonMode = .whileEditing
        self.nameField.returnKeyType = .done
        self.nameField.accessibilityLabel = self.nameLabel.text
        self.nameField.attributedPlaceholder = NSAttributedString(string: chinese ? "添加备注名" : "Add Remark", attributes: [.foregroundColor: placeholder])
        self.nameField.delegate = self
        self.nameField.addAction(UIAction(handler: { [weak self] _ in self?.updateDone() }), for: .editingChanged)
        self.nameBox.addSubview(self.nameField)

        self.phoneText.text = initial.phone
        self.phoneText.font = .systemFont(ofSize: 17)
        self.phoneText.textColor = primary
        self.phoneBox.addSubview(self.phoneText)

        self.memoView.text = initial.note
        self.memoView.font = .systemFont(ofSize: 17)
        self.memoView.textColor = primary
        self.memoView.tintColor = UIColor(rgb: 0x07c160)
        self.memoView.backgroundColor = .clear
        self.memoView.isScrollEnabled = false
        self.memoView.textContainer.lineFragmentPadding = 0
        self.memoView.textContainerInset = UIEdgeInsets(top: 18, left: WegramRemarkEditorView.textInset, bottom: 18, right: WegramRemarkEditorView.textInset)
        self.memoView.accessibilityLabel = self.memoLabel.text
        self.memoView.delegate = self
        self.memoView.isEditable = !initial.noteIsFormatted
        if initial.noteIsFormatted {
            self.memoView.isSelectable = false
            self.memoView.accessibilityHint = chinese ? "带格式的备忘在完整编辑页修改" : "Formatted notes are edited on the full edit page"
            self.memoBox.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.formattedNoteTapped)))
        }
        self.memoPlaceholder.text = chinese ? "添加文字" : "Add Text"
        self.memoPlaceholder.font = .systemFont(ofSize: 17)
        self.memoPlaceholder.textColor = placeholder
        self.memoPlaceholder.isAccessibilityElement = false
        self.memoBox.addSubview(self.memoView)
        self.memoBox.addSubview(self.memoPlaceholder)
        self.updateDone()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var draft: WegramRemarkDraft {
        WegramRemarkDraft(name: (self.nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines), note: self.memoView.text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    private var initialDraft: WegramRemarkDraft { WegramRemarkDraft(name: self.initial.name, note: self.initial.note) }
    /// Telegram rejects a contact without a name, so an empty 备注名 cannot be saved.
    var canSave: Bool { !self.draft.name.isEmpty && self.draft != self.initialDraft }

    func setSaving(_ saving: Bool) {
        self.saving = saving
        self.updateDone()
    }

    private func updateDone() {
        let enabled = self.canSave && !self.saving
        self.done.isEnabled = enabled
        // Button_Primary_* when enabled, Button_Disabled_* otherwise.
        self.done.backgroundColor = enabled ? UIColor(rgb: 0x07c160) : UIColor(white: self.dark ? 1 : 0, alpha: self.dark ? 0.1 : 0.05)
        self.done.setTitleColor(enabled ? .white : UIColor(white: self.dark ? 1 : 0, alpha: 0.15), for: .normal)
        self.done.setTitleColor(enabled ? .white : UIColor(white: self.dark ? 1 : 0, alpha: 0.15), for: .disabled)
        self.memoPlaceholder.isHidden = !self.memoView.text.isEmpty
    }

    @objc private func formattedNoteTapped() { self.openFormattedNote?() }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let text = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        return text.count <= WegramRemarkEditorView.nameLimit
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        (textView.text as NSString).replacingCharacters(in: range, with: text).count <= self.initial.noteLimit
    }
    func textViewDidChange(_ textView: UITextView) {
        self.updateDone()
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let barHeight: CGFloat = 50
        self.bar.frame = CGRect(x: 0, y: 0, width: width, height: self.statusHeight + barHeight)
        let barCenter = self.statusHeight + barHeight / 2
        let cancelWidth = ceil(self.cancel.sizeThatFits(CGSize(width: 200, height: 44)).width)
        // IMG_2445 sits 取消 and 完成 2px above the bar's centre line (at 3x).
        self.cancel.frame = CGRect(x: 16, y: barCenter - 22 - 2 / 3, width: cancelWidth, height: 44)
        self.done.frame = CGRect(x: width - 16 - 52, y: barCenter - 16 - 2 / 3, width: 52, height: 32)

        self.scroll.frame = CGRect(x: 0, y: self.bar.frame.maxY, width: width, height: max(0, self.bounds.height - self.bar.frame.maxY))
        self.scroll.contentInset.bottom = self.bottomInset
        self.scroll.verticalScrollIndicatorInsets.bottom = self.bottomInset
        // Offsets below are from the bar's bottom: the title's centre is 108pt below the status bar.
        let titleHeight = ceil(self.title.font.lineHeight)
        self.title.frame = CGRect(x: 16, y: 58 - titleHeight / 2, width: width - 32, height: titleHeight)

        let inset = WegramRemarkEditorView.fieldInset
        let boxWidth = max(1, width - 2 * inset)
        func place(_ label: UILabel, _ box: UIView, labelCenter: CGFloat, height: CGFloat) -> CGFloat {
            let labelHeight = ceil(label.font.lineHeight)
            label.frame = CGRect(x: inset + WegramRemarkEditorView.textInset, y: labelCenter - labelHeight / 2, width: boxWidth - WegramRemarkEditorView.textInset, height: labelHeight)
            box.frame = CGRect(x: inset, y: labelCenter + 12.6, width: boxWidth, height: height)
            return box.frame.maxY
        }
        let textWidth = boxWidth - 2 * WegramRemarkEditorView.textInset
        var bottom = place(self.nameLabel, self.nameBox, labelCenter: 143.7, height: 57)
        self.nameField.frame = CGRect(x: WegramRemarkEditorView.textInset, y: 0, width: boxWidth - WegramRemarkEditorView.textInset - 8, height: 57)
        if !self.phoneBox.isHidden {
            bottom = place(self.phoneLabel, self.phoneBox, labelCenter: bottom + 32.4, height: 56)
            self.phoneText.frame = CGRect(x: WegramRemarkEditorView.textInset, y: 0, width: textWidth, height: 56)
        }
        let memoText = ceil(self.memoView.sizeThatFits(CGSize(width: boxWidth, height: .greatestFiniteMagnitude)).height)
        let memoHeight = max(57, memoText)
        bottom = place(self.memoLabel, self.memoBox, labelCenter: bottom + 32.4, height: memoHeight)
        self.memoView.frame = self.memoBox.bounds
        self.memoPlaceholder.frame = CGRect(x: WegramRemarkEditorView.textInset, y: 0, width: textWidth, height: 57)
        self.scroll.contentSize = CGSize(width: width, height: bottom + 32)
    }
}
