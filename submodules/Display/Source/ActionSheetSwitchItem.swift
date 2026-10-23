import Foundation
import UIKit
import AsyncDisplayKit

public class ActionSheetSwitchItem: ActionSheetItem {
    public let title: String
    public let isOn: Bool
    public let action: (Bool) -> Void
    
    public init(title: String, isOn: Bool, action: @escaping (Bool) -> Void) {
        self.title = title
        self.isOn = isOn
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = ActionSheetSwitchNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? ActionSheetSwitchNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

public class ActionSheetSwitchNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private var item: ActionSheetSwitchItem?
    
    private let button: HighlightTrackingButton
    private let label: ImmediateTextNode
    private let switchNode: SwitchNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.button = HighlightTrackingButton()
        self.button.isAccessibilityElement = false
        
        self.label = ImmediateTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.maximumNumberOfLines = 1
        self.label.displaysAsynchronously = false
        self.label.truncationType = .end
        self.label.isAccessibilityElement = false
        
        self.switchNode = SwitchNode()
        self.switchNode.frameColor = theme.switchFrameColor
        self.switchNode.contentColor = theme.switchContentColor
        self.switchNode.handleColor = theme.switchHandleColor
        self.switchNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        
        self.label.isUserInteractionEnabled = false
        self.addSubnode(self.label)
        self.addSubnode(self.switchNode)
        
        self.addSubnode(self.accessibilityArea)
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        self.switchNode.valueUpdated = { [weak self] value in
            self?.item?.action(value)
            self?.updateWegramAccessibility()
        }
        
        self.accessibilityArea.activate = { [weak self] in
            self?.buttonPressed()
            return true
        }
    }
    
    func setItem(_ item: ActionSheetSwitchItem) {
        self.item = item
        
        let defaultFont = Font.regular(floor(theme.baseFontSize * (theme.usesWegramLayout ? 17.0 : 20.0) / 17.0))
        self.label.maximumNumberOfLines = theme.usesWegramLayout ? 0 : 1
        
        self.label.attributedText = NSAttributedString(string: item.title, font: defaultFont, textColor: self.theme.primaryTextColor)
        self.label.isAccessibilityElement = false
        
        self.switchNode.isOn = item.isOn
        
        self.accessibilityArea.accessibilityLabel = item.title
        
        var accessibilityTraits: UIAccessibilityTraits = [.button]
        if item.isOn {
            accessibilityTraits.insert(.selected)
        }
        self.accessibilityArea.accessibilityTraits = accessibilityTraits
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var switchSize = CGSize(width: 51.0, height: 31.0)
        if let switchView = self.switchNode.view as? UISwitch {
            if self.switchNode.bounds.size.width.isZero { switchView.sizeToFit() }
            switchSize = switchView.bounds.size
        }
        let labelWidth = self.theme.usesWegramLayout ? constrainedSize.width - switchSize.width - 32 - 12 : constrainedSize.width - 51 - 32
        let labelSize = self.label.updateLayout(CGSize(width: max(1, labelWidth), height: self.theme.usesWegramLayout ? 10000 : 57))
        let height = self.theme.usesWegramLayout ? max(56, labelSize.height + 24, switchSize.height + 24) : 57
        let size = CGSize(width: constrainedSize.width, height: height)
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        self.label.frame = CGRect(origin: CGPoint(x: 16, y: floorToScreenPixels((height - labelSize.height) / 2)), size: labelSize)
        self.switchNode.frame = CGRect(origin: CGPoint(x: size.width - 16 - switchSize.width, y: floor((height - switchSize.height) / 2)), size: switchSize)
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }

    private func updateWegramAccessibility() {
        guard self.theme.usesWegramLayout else { return }
        self.accessibilityArea.accessibilityTraits = self.switchNode.isOn ? [.button, .selected] : [.button]
    }

    @objc func buttonPressed() {
        let value = !self.switchNode.isOn
        self.switchNode.setOn(value, animated: true)
        self.item?.action(value)
        self.updateWegramAccessibility()
    }
}
