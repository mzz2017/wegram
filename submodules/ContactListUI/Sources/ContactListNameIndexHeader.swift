import Foundation
import Display
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import ListSectionHeaderNode

final class ContactListNameIndexHeader: Equatable, ListViewItemHeader {
    let id: ListViewItemNode.HeaderId
    let stackingId: ListViewItemNode.HeaderId? = nil
    let theme: PresentationTheme
    let letter: unichar
    let stickDirection: ListViewItemHeaderStickDirection = .top
    public let stickOverInsets: Bool = true
    public let isSticky: Bool
    
    let height: CGFloat
    let usesWegramLayout: Bool

    init(theme: PresentationTheme, letter: unichar, usesWegramLayout: Bool = false) {
        self.height = usesWegramLayout ? 48.0 : 29.0
        self.isSticky = usesWegramLayout
        self.usesWegramLayout = usesWegramLayout
        self.theme = theme
        self.letter = letter
        self.id = ListViewItemNode.HeaderId(space: 0, id: Int64(letter))
    }

    func combinesWith(other: ListViewItemHeader) -> Bool {
        if let other = other as? ContactListNameIndexHeader, self.id == other.id {
            return true
        } else {
            return false
        }
    }
    
    func node(synchronousLoad: Bool) -> ListViewItemHeaderNode {
        return ContactListNameIndexHeaderNode(theme: self.theme, letter: self.letter, usesWegramLayout: self.usesWegramLayout)
    }
    
    func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {
        
    }
    
    static func ==(lhs: ContactListNameIndexHeader, rhs: ContactListNameIndexHeader) -> Bool {
        return lhs.id == rhs.id
    }
}

final class ContactListNameIndexHeaderNode: ListViewItemHeaderNode {
    private var theme: PresentationTheme
    private let letter: unichar
    private let usesWegramLayout: Bool
    
    private let sectionHeaderNode: ListSectionHeaderNode
    private let wegramTitleNode = ImmediateTextNode()
    // Pinned under the navigation bar the header is a 28pt page-coloured bar with a hairline (WeChat scroll recording).
    private let wegramBandNode = ASDisplayNode()
    private let wegramHairlineNode = ASDisplayNode()
    private var wegramStickDistance: CGFloat = 0.0
    private var wegramLeftInset: CGFloat = 0.0
    private var wegramPushDistance: CGFloat = 0.0
    
    init(theme: PresentationTheme, letter: unichar, usesWegramLayout: Bool = false) {
        self.theme = theme
        self.letter = letter
        self.usesWegramLayout = usesWegramLayout
        
        self.sectionHeaderNode = ListSectionHeaderNode(theme: theme)
        
        super.init()
        
        if let scalar = UnicodeScalar(letter) {
            self.sectionHeaderNode.title = "\(Character(scalar))"
        }
        
        if usesWegramLayout {
            self.wegramBandNode.isLayerBacked = true
            self.wegramHairlineNode.isLayerBacked = true
            self.wegramBandNode.alpha = 0.0
            self.wegramHairlineNode.alpha = 0.0
            self.addSubnode(self.wegramBandNode)
            self.addSubnode(self.wegramHairlineNode)
            self.addSubnode(self.wegramTitleNode)
        } else {
            self.addSubnode(self.sectionHeaderNode)
        }
        self.updateWegramBackground()
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.theme = theme
        self.sectionHeaderNode.updateTheme(theme: theme)
        self.updateWegramBackground()
    }

    // WeChat draws the letter as plain grey text on the page, not on a band (IMG_2470).
    private func updateWegramBackground() {
        guard self.usesWegramLayout else {
            return
        }
        self.wegramBandNode.backgroundColor = self.theme.chatList.backgroundColor
        self.wegramHairlineNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        let letter = UnicodeScalar(self.letter).map { String(Character($0)) } ?? ""
        self.wegramTitleNode.attributedText = NSAttributedString(string: letter, font: Font.regular(14.0), textColor: UIColor(rgb: self.theme.overallDarkAppearance ? 0x8e8e8e : 0x7f7f7f))
    }
    
    override func updateStickDistanceFactor(_ factor: CGFloat, distance: CGFloat, transition: ContainedViewLayoutTransition) {
        guard self.usesWegramLayout else {
            return
        }
        self.wegramStickDistance = max(0.0, distance)
        self.updateWegramStick()
    }
    
    // The pinned bar is 28pt of a 48pt node, so the next letter only starts to push it once it is 28pt away: the node
    // is pushed by the full 48pt, and the first 20pt of that is absorbed by moving the bar down inside the node.
    override func updateStickPushDistance(_ distance: CGFloat) {
        guard self.usesWegramLayout else {
            return
        }
        self.wegramPushDistance = distance
        self.updateWegramStick()
    }
    
    // While the natural header scrolls up under the bar its letter keeps rising until it sits in the 28pt pinned bar.
    private func updateWegramStick() {
        let distance = self.wegramStickDistance
        let titleSize = self.wegramTitleNode.updateLayout(CGSize(width: 100.0, height: 20.0))
        let shift = min(max(0.0, self.wegramPushDistance), 20.0)
        let centerY = max(14.0, 34.0 - distance) + shift
        self.wegramTitleNode.frame = CGRect(origin: CGPoint(x: 16.0 + self.wegramLeftInset, y: floor(centerY - titleSize.height / 2.0)), size: titleSize)
        self.wegramBandNode.alpha = distance > 0.0 ? 1.0 : 0.0
        self.wegramBandNode.frame.origin.y = shift
        self.wegramHairlineNode.frame.origin.y = shift + 28.0 - UIScreenPixel
        self.wegramHairlineNode.alpha = min(1.0, distance / 6.0)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.usesWegramLayout {
            self.wegramLeftInset = leftInset
            self.wegramBandNode.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: 28.0)
            self.wegramHairlineNode.frame = CGRect(x: 0.0, y: 28.0 - UIScreenPixel, width: size.width, height: UIScreenPixel)
            self.updateWegramStick()
            return
        }
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: size)
        self.sectionHeaderNode.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
    }
}
