import UIKit
import AsyncDisplayKit
import Display

final class WegramShortcutMenuController: ViewController {
    private weak var sourceView: UIView?
    private let items: [WegramShortcutMenuItem]
    private let actions: [() -> Void]
    private let fontSize: CGFloat
    private let alignLeft: Bool
    private var isClosing = false
    private weak var obscuredView: UIView?
    private let content = WegramShortcutMenuView()

    init(sourceView: UIView, items: [WegramShortcutMenuItem], actions: [() -> Void], fontSize: CGFloat, alignLeft: Bool) {
        self.sourceView = sourceView
        self.items = items
        self.actions = actions
        self.fontSize = fontSize
        self.alignLeft = alignLeft
        super.init(navigationBarPresentationData: nil)
        self.displayNavigationBar = false
        self.statusBar.statusBarStyle = .Ignore
        self.content.close = { [weak self] in
            guard let self, !self.isClosing else { return }
            let source = self.sourceView
            self.dismiss(completion: {
                if source?.window != nil { UIAccessibility.post(notification: .layoutChanged, argument: source) }
            })
        }
        self.content.select = { [weak self] index in
            guard let self, !self.isClosing, self.actions.indices.contains(index), self.sourceView?.window != nil else { self?.dismiss(); return }
            let action = self.actions[index]
            self.content.invalidate()
            self.dismiss(completion: action)
        }
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.isOpaque = false
        self.displayNode.backgroundColor = .clear
        self.displayNode.view.addSubview(self.content)
        self.content.load(items: self.items, fontSize: self.fontSize)
        if self.isClosing { self.content.invalidate() }
        self.displayNodeDidLoad()
    }
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        transition.updateFrame(view: self.content, frame: CGRect(origin: .zero, size: layout.size))
        guard let source = self.sourceView, source.window != nil else { self.dismiss(); return }
        var insets = layout.safeInsets
        insets.top = max(insets.top, layout.statusBarHeight ?? 0)
        insets.bottom = max(insets.bottom, layout.intrinsicInsets.bottom)
        self.content.position(anchor: source.convert(source.bounds, to: self.content), insets: insets, alignLeft: self.alignLeft)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !self.isClosing else { return }
        self.hideObscuredContentFromAccessibility()
        UIAccessibility.post(notification: .screenChanged, argument: self.content.buttons.first)
    }
    // The menu lives in a global overlay, so its own accessibilityViewIsModal cannot reach the list
    // and tab bar behind it. Hide the highest ancestor of the source that does not contain the menu.
    private func hideObscuredContentFromAccessibility() {
        guard self.obscuredView == nil, var view = self.sourceView, view.window != nil else { return }
        while let superview = view.superview, !self.view.isDescendant(of: superview) {
            view = superview
        }
        guard !self.view.isDescendant(of: view), !view.accessibilityElementsHidden else { return }
        view.accessibilityElementsHidden = true
        self.obscuredView = view
    }
    private func restoreObscuredContentAccessibility() {
        self.obscuredView?.accessibilityElementsHidden = false
        self.obscuredView = nil
    }
    override func accessibilityPerformEscape() -> Bool { self.content.accessibilityPerformEscape() }
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(self.cancelMenu))]
    }
    @objc private func cancelMenu() { _ = self.content.accessibilityPerformEscape() }
    override func dismiss(completion: (() -> Void)? = nil) {
        self.isClosing = true
        self.restoreObscuredContentAccessibility()
        self.content.invalidate()
        super.dismiss(completion: completion)
    }
    override func viewWillDisappear(_ animated: Bool) {
        self.isClosing = true
        self.restoreObscuredContentAccessibility()
        self.content.invalidate()
        super.viewWillDisappear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.restoreObscuredContentAccessibility()
        self.content.invalidate()
    }
}
