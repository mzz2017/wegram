import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AuthorizationUtils

private func timerValueString(days: Int32, hours: Int32, minutes: Int32, color: UIColor, strings: PresentationStrings) -> NSAttributedString {
    var daysString = ""
    if days > 0 {
        daysString = strings.MessageTimer_Days(days) + " "
    }
    
    var hoursString = ""
    if hours > 0 || days > 0 {
        hoursString = strings.MessageTimer_Hours(hours) + " "
    }
    
    let minutesString = strings.MessageTimer_Minutes(minutes)
    
    return NSAttributedString(string: daysString + hoursString + minutesString, font: Font.regular(21.0), textColor: color)
}

final class AuthorizationSequenceAwaitingAccountResetControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let usesWegramAppearance: Bool
    private let contentScrollNode = ASScrollNode()
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    
    private let timerTitleNode: ASTextNode
    private let timerValueNode: ASTextNode
    private let resetNode: HighlightableButtonNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    var reset: (() -> Void)?
    
    private var protectedUntil: Int32 = 0
    
    private var timer: SwiftSignalKit.Timer?
    
    init(strings: PresentationStrings, theme: PresentationTheme, usesWegramAppearance: Bool = false) {
        self.usesWegramAppearance = usesWegramAppearance
        self.strings = strings
        self.theme = theme
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: strings.Login_ResetAccountProtected_Title, font: usesWegramAppearance ? Font.regular(22) : Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
        
        self.noticeNode = ASTextNode()
        self.noticeNode.isUserInteractionEnabled = false
        self.noticeNode.displaysAsynchronously = false
        
        self.timerTitleNode = ASTextNode()
        self.timerTitleNode.isUserInteractionEnabled = false
        self.timerTitleNode.displaysAsynchronously = false
        self.timerTitleNode.attributedText = NSAttributedString(string: strings.Login_ResetAccountProtected_TimerTitle, font: Font.regular(16.0), textColor: self.theme.list.itemPrimaryTextColor)
        
        self.timerValueNode = ASTextNode()
        self.timerValueNode.isUserInteractionEnabled = false
        self.timerValueNode.displaysAsynchronously = false
        
        self.resetNode = HighlightableButtonNode()
        self.resetNode.setAttributedTitle(NSAttributedString(string: strings.Login_ResetAccountProtected_Reset, font: Font.regular(usesWegramAppearance ? 17 : 21), textColor: usesWegramAppearance ? theme.list.itemDestructiveColor : self.theme.list.itemAccentColor), for: [])
        self.resetNode.setAttributedTitle(NSAttributedString(string: strings.Login_ResetAccountProtected_Reset, font: Font.regular(usesWegramAppearance ? 17 : 21), textColor: self.theme.list.itemPlaceholderTextColor), for: [.disabled])
        self.resetNode.displaysAsynchronously = false
        self.resetNode.isEnabled = false
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.theme.list.plainBackgroundColor
        
        let contentNode: ASDisplayNode
        if usesWegramAppearance {
            self.contentScrollNode.accessibilityIdentifier = "Auth.ResetWait.Content"
            self.contentScrollNode.clipsToBounds = true
            self.contentScrollNode.view.contentInsetAdjustmentBehavior = .never
            self.addSubnode(self.contentScrollNode)
            contentNode = self.contentScrollNode
            self.resetNode.setBackgroundImage(generateFilledRoundedRectImage(size: CGSize(width: 10, height: 10), cornerRadius: 5, color: theme.list.itemPrimaryTextColor.withAlphaComponent(0.05))?.stretchableImage(withLeftCapWidth: 5, topCapHeight: 5), for: [])
            for node in [self.titleNode, self.noticeNode, self.timerTitleNode, self.timerValueNode] {
                node.isAccessibilityElement = true
                node.accessibilityTraits = .staticText
            }
            self.resetNode.accessibilityLabel = strings.Login_ResetAccountProtected_Reset
            self.resetNode.accessibilityTraits = [.button, .notEnabled]
        } else {
            contentNode = self
        }
        self.titleNode.accessibilityIdentifier = "Auth.ResetWait.Title"
        self.noticeNode.accessibilityIdentifier = "Auth.ResetWait.Notice"
        self.timerTitleNode.accessibilityIdentifier = "Auth.ResetWait.TimerTitle"
        self.timerValueNode.accessibilityIdentifier = "Auth.ResetWait.TimerValue"
        self.resetNode.accessibilityIdentifier = "Auth.ResetWait.Reset"
        contentNode.addSubnode(self.titleNode)
        contentNode.addSubnode(self.noticeNode)
        contentNode.addSubnode(self.timerTitleNode)
        contentNode.addSubnode(self.timerValueNode)
        contentNode.addSubnode(self.resetNode)
        
        self.resetNode.addTarget(self, action: #selector(self.resetPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func updateData(protectedUntil: Int32, number: String) {
        self.protectedUntil = protectedUntil
        self.updateTimerValue()
        
        self.noticeNode.attributedText = NSAttributedString(string: strings.Login_ResetAccountProtected_Text(number).string, font: Font.regular(16.0), textColor: self.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
        
        if self.timer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                self?.updateTimerValue()
            }, queue: Queue.mainQueue())
            self.timer = timer
            timer.start()
        }
    }
    
    private func updateTimerValue() {
        let timerSeconds = max(0, self.protectedUntil - Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970))
        
        let secondsInAMinute: Int32 = 60
        let secondsInAnHour: Int32 = 60 * secondsInAMinute
        let secondsInADay: Int32 = 24 * secondsInAnHour
        
        let days = timerSeconds / secondsInADay
        
        let hourSeconds = timerSeconds % secondsInADay
        let hours = hourSeconds / secondsInAnHour
        
        let minuteSeconds = hourSeconds % secondsInAnHour
        var minutes = minuteSeconds / secondsInAMinute
        
        if days == 0 && hours == 0 && minutes == 0 && timerSeconds > 0 {
            minutes = 1
        }
        
        self.timerValueNode.attributedText = timerValueString(days: days, hours: hours, minutes: minutes, color: self.theme.list.itemPrimaryTextColor, strings: self.strings)
        
        self.resetNode.isEnabled = timerSeconds <= 0
        if self.usesWegramAppearance {
            self.timerValueNode.accessibilityLabel = self.timerValueNode.attributedText?.string
            self.resetNode.accessibilityTraits = self.resetNode.isEnabled ? [.button] : [.button, .notEnabled]
        }
        
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top = navigationBarHeight
        
        if self.usesWegramAppearance {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_ResetAccountProtected_Title, font: Font.regular(22), textColor: self.theme.list.itemPrimaryTextColor)
        } else if max(layout.size.width, layout.size.height) > 1023.0 {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_ResetAccountProtected_Title, font: Font.light(40.0), textColor: self.theme.list.itemPrimaryTextColor)
        } else {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_ResetAccountProtected_Title, font: Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
        }
        
        let maximumWidth = self.usesWegramAppearance ? min(430, layout.size.width) : layout.size.width
        let sideInset: CGFloat = self.usesWegramAppearance ? 30 : 0
        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth - sideInset * 2, height: CGFloat.greatestFiniteMagnitude))
        
        let noticeSize = self.noticeNode.measure(CGSize(width: maximumWidth - (self.usesWegramAppearance ? 60 : 28), height: CGFloat.greatestFiniteMagnitude))
        
        let timerTitleSize = self.timerTitleNode.measure(CGSize(width: maximumWidth - sideInset * 2, height: CGFloat.greatestFiniteMagnitude))
        let timerValueSize = self.timerValueNode.measure(CGSize(width: maximumWidth - sideInset * 2, height: CGFloat.greatestFiniteMagnitude))
        var resetSize = self.resetNode.measure(CGSize(width: maximumWidth - sideInset * 2, height: CGFloat.greatestFiniteMagnitude))
        
        if self.usesWegramAppearance {
            resetSize = CGSize(width: maximumWidth - 60, height: max(44, resetSize.height + 16))
        }
        var items: [AuthorizationLayoutItem] = []
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.timerTitleNode, size: timerTitleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 100.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.timerValueNode, size: timerValueSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.resetNode, size: resetSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        if self.usesWegramAppearance {
            let gaps: [CGFloat] = [0, 18, 36, 10, 18]
            items = items.enumerated().map { index, item in
                return AuthorizationLayoutItem(node: item.node!, size: item.size, spacingBefore: AuthorizationLayoutItemSpacing(weight: gaps[index], maxValue: gaps[index]), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0, maxValue: 0))
            }
            let visibleHeight = max(0, layout.size.height - insets.top - insets.bottom - 20)
            let contentHeight = max(visibleHeight, items.reduce(CGFloat(0)) { $0 + $1.size.height + $1.spacingBefore.maxValue })
            transition.updateFrame(node: self.contentScrollNode, frame: CGRect(x: 0, y: insets.top, width: layout.size.width, height: visibleHeight))
            self.contentScrollNode.view.contentSize = CGSize(width: layout.size.width, height: contentHeight)
            let _ = layoutAuthorizationItems(bounds: CGRect(x: 0, y: 0, width: layout.size.width, height: contentHeight), items: items, transition: transition, failIfDoesNotFit: false)
            self.titleNode.accessibilityLabel = self.titleNode.attributedText?.string
            self.noticeNode.accessibilityLabel = self.noticeNode.attributedText?.string
            self.timerTitleNode.accessibilityLabel = self.timerTitleNode.attributedText?.string
            self.timerValueNode.accessibilityLabel = self.timerValueNode.attributedText?.string
            self.resetNode.accessibilityTraits = self.resetNode.isEnabled ? [.button] : [.button, .notEnabled]
        } else {
            let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 20.0)), items: items, transition: transition, failIfDoesNotFit: false)
        }
    }
    
    @objc func resetPressed() {
        self.reset?()
    }
}


