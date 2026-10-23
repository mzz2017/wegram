import UIKit
import AccountContext
import TelegramCore
import TelegramPresentationData

enum WegramSelectionExtra: Equatable {
    case share, report, tag, history
}

func wegramSelectionExtras(_ actions: ChatAvailableMessageActions?, hasSelection: Bool, isSecret: Bool, hasHistoryAction: Bool = false) -> [WegramSelectionExtra] {
    var result: [WegramSelectionExtra] = []
    if hasSelection, let actions {
        if !isSecret && actions.options.contains(.forward) && actions.options.contains(.externalShare) { result.append(.share) }
        if actions.options.contains(.report) { result.append(.report) }
        if actions.setTag { result.append(.tag) }
    }
    if hasHistoryAction { result.append(.history) }
    return result
}

final class WegramMessageSelectionBar: UIView {
    enum Action: Int, CaseIterable { case forward, save, delete, more }
    let buttons: [UIButton]
    var selected: ((Action) -> Void)?

    override init(frame: CGRect) {
        self.buttons = Action.allCases.map { _ in UIButton(type: .custom) }
        super.init(frame: frame)
        let symbols = ["arrowshape.turn.up.right", "shippingbox", "trash", "ellipsis"]
        for action in Action.allCases {
            let button = self.buttons[action.rawValue]
            button.setImage(UIImage(systemName: symbols[action.rawValue], withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)), for: .normal)
            button.accessibilityIdentifier = "Wegram.Selection.\(action)"
            button.isAccessibilityElement = true
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button, !self.isHidden, button.isEnabled else { return }
                self.selected?(action)
            }, for: .touchUpInside)
            self.addSubview(button)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(isDark: Bool, titles: [String], enabled: [Bool]) {
        let color = WegramNavigationColors(isDark: isDark).control
        for action in Action.allCases {
            let button = self.buttons[action.rawValue]
            button.accessibilityLabel = titles[action.rawValue]
            button.isEnabled = enabled[action.rawValue]
            button.tintColor = color
            button.alpha = button.isEnabled ? 1 : 0.3
            button.accessibilityTraits = button.isEnabled ? [.button] : [.button, .notEnabled]
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for action in Action.allCases {
            self.buttons[action.rawValue].frame = CGRect(x: floor(self.bounds.width * CGFloat(action.rawValue + 1) / 5) - 22, y: floor((self.bounds.height - 44) / 2), width: 44, height: 44)
        }
    }
}
