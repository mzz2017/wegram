import Foundation
import UIKit
import AsyncDisplayKit

open class AlertContentNode: ASDisplayNode {
    open var containerCornerRadius: CGFloat { return 14.0 }

    open var requestLayout: ((ContainedViewLayoutTransition) -> Void)?
    
    open var dismissOnOutsideTap: Bool {
        return true
    }
    
    open func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        assertionFailure()
        
        return CGSize()
    }
    
    open func updateTheme(_ theme: AlertControllerTheme) {
        
    }
    
    open func performHighlightedAction() {
        
    }
    
    open func decreaseHighlightedIndex() {
        
    }
    
    open func increaseHighlightedIndex() {

    }
}
