import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

public final class WegramMessageMenuContent: ContextControllerItemsContent {
    public struct Item {
        public let title: String
        public let symbol: String

        public init(title: String, symbol: String) {
            self.title = title
            self.symbol = symbol
        }
    }

    private let items: [Item]
    private let action: (Int) -> Void
    private let isActive: () -> Bool

    public init(items: [Item], isActive: @escaping () -> Bool, action: @escaping (Int) -> Void) {
        self.items = items
        self.isActive = isActive
        self.action = action
    }

    public func node(requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void, requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void) -> ContextControllerItemsNode {
        return WegramMessageMenuNode(items: self.items, isActive: self.isActive, action: self.action)
    }
}

private final class MenuButton: UIButton {
    var activate: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.titleLabel?.numberOfLines = 0
        self.titleLabel?.textAlignment = .center
        self.imageView?.contentMode = .scaleAspectFit
        self.layer.cornerRadius = 4
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet { self.backgroundColor = self.isHighlighted ? UIColor(white: 1, alpha: 0.15) : .clear }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.frame = CGRect(x: floor((self.bounds.width - 24) / 2), y: 10, width: 24, height: 24)
        self.titleLabel?.frame = CGRect(x: 3, y: 39, width: max(0, self.bounds.width - 6), height: max(0, self.bounds.height - 43))
    }

    @objc private func pressed() { self.activate?() }
    override func accessibilityActivate() -> Bool { self.activate?(); return true }
}

private final class WegramMessageMenuNode: ASDisplayNode, ContextControllerItemsNode {
    private let items: [WegramMessageMenuContent.Item]
    private let action: (Int) -> Void
    private let isActive: () -> Bool
    private var buttons: [MenuButton] = []
    private var highlightedIndex: Int?
    private var scrollView: UIScrollView { return self.view as! UIScrollView }
    private(set) var apparentHeight: CGFloat = 0

    init(items: [WegramMessageMenuContent.Item], isActive: @escaping () -> Bool, action: @escaping (Int) -> Void) {
        self.items = items
        self.action = action
        self.isActive = isActive
        super.init()
        self.setViewBlock({ UIScrollView() })
    }

    override func didLoad() {
        super.didLoad()
        self.scrollView.backgroundColor = UIColor(rgb: 0x3d3d3d)
        self.scrollView.layer.cornerRadius = 7
        self.scrollView.clipsToBounds = true
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceVertical = false
        for (index, item) in self.items.enumerated() {
            let button = MenuButton(frame: .zero)
            button.setTitle(item.title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.tintColor = .white
            button.accessibilityLabel = item.title
            button.activate = { [weak self] in self?.perform(index) }
            self.scrollView.addSubview(button)
            self.buttons.append(button)
        }
    }

    private func perform(_ index: Int) {
        guard self.isActive(), self.items.indices.contains(index) else { return }
        self.updateHighlight(nil)
        self.action(index)
    }

    func update(presentationData: PresentationData, constrainedWidth: CGFloat, maxHeight: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> (cleanSize: CGSize, apparentHeight: CGFloat) {
        _ = self.view
        let scale = max(1, presentationData.listsFontSize.itemListBaseFontSize / 17)
        let font = UIFont.systemFont(ofSize: 12 * scale)
        let width = max(0, min(320, constrainedWidth))
        let columns = max(1, min(5, self.items.count, Int(width / (60 * scale))))
        let cellWidth = width / CGFloat(columns)
        let titleHeight = self.items.map { item in
            ceil((item.title as NSString).boundingRect(with: CGSize(width: max(1, cellWidth - 6), height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height)
        }.max() ?? 0
        let rowHeight = max(64, 43 + titleHeight)
        let rows = (self.items.count + columns - 1) / columns
        let fullHeight = CGFloat(rows) * rowHeight + 8
        let height = min(fullHeight, max(0, maxHeight - bottomInset))
        for (index, button) in self.buttons.enumerated() {
            button.titleLabel?.font = font
            button.setImage(UIImage(systemName: self.items[index].symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)), for: .normal)
            button.frame = CGRect(x: CGFloat(index % columns) * cellWidth, y: 4 + CGFloat(index / columns) * rowHeight, width: cellWidth, height: rowHeight)
            button.setNeedsLayout()
        }
        self.scrollView.contentSize = CGSize(width: width, height: fullHeight)
        self.scrollView.isScrollEnabled = fullHeight > height
        self.apparentHeight = height
        return (CGSize(width: width, height: height), height)
    }

    private func updateHighlight(_ index: Int?) {
        guard self.highlightedIndex != index else { return }
        self.highlightedIndex = index
        for (i, button) in self.buttons.enumerated() { button.isHighlighted = i == index }
    }

    func highlightGestureShouldBegin(location: CGPoint) -> Bool {
        return self.isActive() && CGRect(origin: .zero, size: self.bounds.size).contains(location)
    }

    func highlightGestureMoved(location: CGPoint) {
        guard self.isActive(), CGRect(origin: .zero, size: self.bounds.size).contains(location) else { self.updateHighlight(nil); return }
        let point = CGPoint(x: location.x + self.scrollView.contentOffset.x, y: location.y + self.scrollView.contentOffset.y)
        self.updateHighlight(self.buttons.firstIndex { $0.frame.contains(point) })
    }

    func highlightGestureFinished(performAction: Bool) {
        let index = self.highlightedIndex
        self.updateHighlight(nil)
        if performAction, let index { self.perform(index) }
    }

    private func moveHighlight(_ delta: Int) {
        guard self.isActive(), !self.buttons.isEmpty else { return }
        let index = self.highlightedIndex.map { min(self.buttons.count - 1, max(0, $0 + delta)) } ?? (delta > 0 ? 0 : self.buttons.count - 1)
        self.updateHighlight(index)
        self.scrollView.scrollRectToVisible(self.buttons[index].frame, animated: false)
    }

    func decreaseHighlightedIndex() { self.moveHighlight(-1) }
    func increaseHighlightedIndex() { self.moveHighlight(1) }
}
