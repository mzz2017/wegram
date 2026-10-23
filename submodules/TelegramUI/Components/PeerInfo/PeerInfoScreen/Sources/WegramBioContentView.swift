import UIKit
import AsyncDisplayKit
import Display

final class WegramBioContentView: UIScrollView, UITextViewDelegate {
    let textView = UITextView()
    let counterLabel = UILabel()
    let saveButton = WegramNameSaveButton()
    private var initialBio: String?
    private var maximumLength = 0
    private var saveItem: UIBarButtonItem?
    private lazy var saveNode: ASDisplayNode = {
        let node = ASDisplayNode(viewBlock: { [button = self.saveButton] in button })
        node.style.preferredSize = CGSize(width: 64, height: 44)
        return node
    }()
    var save: (() -> Void)?
    var allowsEditing = true { didSet { self.updateState() } }
    var submitting = false { didSet { self.updateState() } }
    var text: String { self.textView.text ?? "" }
    var canSave: Bool {
        self.allowsEditing && self.initialBio != nil && self.text != self.initialBio && !self.submitting && self.textView.markedTextRange == nil && self.text.count <= self.maximumLength
    }

    init() {
        super.init(frame: .zero)
        self.contentInsetAdjustmentBehavior = .never
        self.alwaysBounceVertical = true
        self.keyboardDismissMode = .interactive
        self.textView.delegate = self
        self.textView.isScrollEnabled = false
        self.textView.backgroundColor = .clear
        self.textView.textContainerInset = .zero
        self.textView.textContainer.lineFragmentPadding = 0
        self.textView.accessibilityIdentifier = "Wegram.Profile.Bio"
        self.counterLabel.textAlignment = .right
        self.counterLabel.accessibilityIdentifier = "Wegram.Profile.BioRemaining"
        self.saveButton.accessibilityIdentifier = "Wegram.Profile.SaveBio"
        self.saveButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self, self.canSave else { return }
            self.save?()
        }), for: .touchUpInside)
        self.addSubview(self.textView)
        self.addSubview(self.counterLabel)
        self.updateState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setBio(_ text: String) {
        guard self.initialBio == nil else { return }
        self.initialBio = text
        self.textView.text = text
        self.updateState()
    }

    func update(isDark: Bool, fontSize: CGFloat, maximumLength: Int, title: String, doneTitle: String, remainingTitle: String = "Characters remaining") {
        self.maximumLength = max(0, maximumLength)
        self.backgroundColor = isDark ? UIColor(white: 0.1, alpha: 1) : .white
        self.textView.font = .systemFont(ofSize: fontSize)
        self.textView.textColor = isDark ? UIColor(white: 0.82, alpha: 1) : UIColor(white: 0.1, alpha: 1)
        self.textView.tintColor = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
        self.textView.keyboardAppearance = isDark ? .dark : .light
        self.textView.accessibilityLabel = title
        self.counterLabel.accessibilityLabel = remainingTitle
        self.counterLabel.font = .systemFont(ofSize: max(14, fontSize * 14 / 17))
        self.saveButton.setTitle(self.submitting ? "" : doneTitle, for: .normal)
        self.saveButton.accessibilityLabel = doneTitle
        self.updateState()
    }

    func makeSaveItem() -> UIBarButtonItem? {
        let item = UIBarButtonItem(customDisplayNode: self.saveNode)
        self.saveItem = item
        item?.accessibilityLabel = self.saveButton.accessibilityLabel
        item?.isEnabled = self.canSave
        return item
    }

    private func updateState() {
        self.textView.isEditable = self.allowsEditing && self.initialBio != nil && !self.submitting
        self.saveButton.isEnabled = self.canSave
        self.saveItem?.isEnabled = self.canSave
        self.saveItem?.accessibilityLabel = self.saveButton.accessibilityLabel
        let remaining = self.maximumLength - self.text.count
        self.counterLabel.text = String(remaining)
        self.counterLabel.accessibilityValue = String(remaining)
        self.counterLabel.textColor = remaining < 0 ? .systemRed : UIColor(white: 0.6, alpha: 1)
        self.setNeedsLayout()
    }

    func textViewDidChange(_ textView: UITextView) {
        self.updateState()
        self.layoutIfNeeded()
        if let range = textView.selectedTextRange {
            self.scrollRectToVisible(textView.convert(textView.caretRect(for: range.end).insetBy(dx: 0, dy: -12), to: self), animated: false)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = max(0, self.bounds.width - 32)
        let fitting = self.textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        self.textView.frame = CGRect(x: 16, y: 16, width: width, height: max(48, ceil(fitting.height)))
        let counterHeight = ceil(self.counterLabel.font.lineHeight)
        self.counterLabel.frame = CGRect(x: 16, y: self.textView.frame.maxY + 8, width: width, height: counterHeight)
        self.contentSize = CGSize(width: self.bounds.width, height: self.counterLabel.frame.maxY + 16)
    }
}
