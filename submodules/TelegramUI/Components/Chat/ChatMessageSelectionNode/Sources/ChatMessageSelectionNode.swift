import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import CheckNode
import TelegramCore

private func selectionCheckTheme(wallpaper: TelegramWallpaper, theme: PresentationTheme, usesWegramAppearance: Bool) -> CheckNodeTheme {
    if usesWegramAppearance {
        // WeChat's checkbox colours. The earlier 57be6a was 07c160 read from a Display P3 screenshot.
        return CheckNodeTheme(backgroundColor: UIColor(rgb: 0x07c160), strokeColor: .white, borderColor: UIColor(white: theme.overallDarkAppearance ? 1.0 : 0.0, alpha: 0.3), overlayBorder: false, hasInset: false, hasShadow: false, borderWidth: 1, checkmarkLineWidth: 1.5)
    }
    let style: CheckNodeTheme.Style
    if wallpaper == theme.chat.defaultWallpaper, case .color = wallpaper {
        style = .plain
    } else {
        style = .overlay
    }
    return CheckNodeTheme(theme: theme, style: style, hasInset: true)
}

public final class ChatMessageSelectionNode: ASDisplayNode {
    private let toggle: (Bool) -> Void
    
    public private(set) var selected = false
    private let checkNode: CheckNode
    private var usesWegramAppearance: Bool
    
    public init(wallpaper: TelegramWallpaper, theme: PresentationTheme, usesWegramAppearance: Bool = false, toggle: @escaping (Bool) -> Void) {
        self.toggle = toggle
        self.usesWegramAppearance = usesWegramAppearance
        
        self.checkNode = CheckNode(theme: selectionCheckTheme(wallpaper: wallpaper, theme: theme, usesWegramAppearance: usesWegramAppearance))
        self.checkNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.checkNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func updateSelected(_ selected: Bool, animated: Bool) {
        if self.selected != selected {
            self.selected = selected
            self.checkNode.setSelected(selected, animated: animated)
        }
    }

    public func updateAppearance(wallpaper: TelegramWallpaper, theme: PresentationTheme, usesWegramAppearance: Bool) {
        self.usesWegramAppearance = usesWegramAppearance
        let checkTheme = selectionCheckTheme(wallpaper: wallpaper, theme: theme, usesWegramAppearance: usesWegramAppearance)
        if self.checkNode.theme != checkTheme { self.checkNode.theme = checkTheme }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.toggle(!self.selected)
        }
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat) {
        let side: CGFloat = self.usesWegramAppearance ? 22 : 28
        let y = self.usesWegramAppearance ? max(0, floor((min(size.height, 40) - side) / 2)) : floor((size.height - side) / 2)
        self.checkNode.frame = CGRect(x: (self.usesWegramAppearance ? 9 : 6) + leftInset, y: y, width: side, height: side)
    }
}
