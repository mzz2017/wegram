import Foundation
import UIKit
import AsyncDisplayKit

public final class NavigationBarBadgeNode: ASDisplayNode {
    private var fillColor: UIColor
    private var strokeColor: UIColor
    private var textColor: UIColor
    
    private let textNode: ImmediateTextNode
    private let backgroundNode: ASImageNode
    
    public var usesWegramAppearance = false {
        didSet {
            if self.usesWegramAppearance != oldValue {
                self.updateTheme(fillColor: self.fillColor, strokeColor: self.strokeColor, textColor: self.textColor)
                self.invalidateCalculatedLayout()
            }
        }
    }
    private var font: UIFont { return Font.regular(self.usesWegramAppearance ? 17 : 13) }
    private var badgeDiameter: CGFloat { return self.usesWegramAppearance ? 24 : 18 }
    
    public var text: String = "" {
        didSet {
            self.textNode.attributedText = NSAttributedString(string: self.text, font: self.font, textColor: self.textColor)
            self.invalidateCalculatedLayout()
        }
    }
    
    public init(fillColor: UIColor, strokeColor: UIColor, textColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.textColor = textColor
        
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = generateStretchableFilledCircleImage(radius: 9, color: fillColor, backgroundColor: nil)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
    }
    
    public func updateTheme(fillColor: UIColor, strokeColor: UIColor, textColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.textColor = textColor
        self.backgroundNode.image = generateStretchableFilledCircleImage(radius: self.badgeDiameter * 0.5, color: fillColor, backgroundColor: nil)
        self.textNode.attributedText = NSAttributedString(string: self.text, font: self.font, textColor: self.textColor)
        self.textNode.redrawIfPossible()
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let badgeSize = self.textNode.updateLayout(constrainedSize)
        let backgroundSize: CGSize
        if self.text.count < 2 {
            backgroundSize = CGSize(width: self.badgeDiameter, height: self.badgeDiameter)
        } else {
            backgroundSize = CGSize(width: max(self.badgeDiameter, badgeSize.width + 11), height: self.badgeDiameter)
        }
        let backgroundFrame = CGRect(origin: CGPoint(), size: backgroundSize)
        self.backgroundNode.frame = backgroundFrame
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeSize.width / 2.0), y: floorToScreenPixels((backgroundFrame.size.height - badgeSize.height) / 2.0)), size: badgeSize)
        
        return backgroundSize
    }
}
