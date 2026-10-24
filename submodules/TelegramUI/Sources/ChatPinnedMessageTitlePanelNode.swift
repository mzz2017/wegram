import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import StickerResources
import PhotoResources
import TelegramStringFormatting
import AnimatedCountLabelNode
import AnimatedNavigationStripeNode
import ContextUI
import RadialStatusNode
import InvisibleInkDustNode
import TextFormat
import ChatPresentationInterfaceState
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import TranslateUI
import ChatControllerInteraction
import LegacyChatHeaderPanelComponent
import UIKitRuntimeUtils

private enum PinnedMessageAnimation {
    case slideToTop
    case slideToBottom
}

/// WeGram card metrics (measured on the 402pt group chat reference: card 45pt tall, 8pt side margins, 10pt corners).
private enum PinnedCardMetrics {
    static let topInset: CGFloat = 4.0
    static let height: CGFloat = 45.0
    static let bottomInset: CGFloat = 8.0
    static let stackPeek: CGFloat = 6.0
    static let cornerRadius: CGFloat = 8.0
    /// The icon's 24pt canvas relative to the card, which `generatePinnedCardIcon` was traced in.
    static let iconFrame = CGRect(x: 16.0, y: 10.0, width: 24.0, height: 24.0)
    static let textLeft: CGFloat = 51.7
    static let trailingInset: CGFloat = 17.0
    static let fontSize: CGFloat = 14.0
    static let removeColor = UIColor(rgb: 0x576B95)
    /// WeChat's primary text (IMG_2486/2488: fully covered glyph pixels read 0x18).
    static let textColor = UIColor(rgb: 0x181818)
}

private func generatePinnedCardIcon() -> UIImage? {
    return generateImage(CGSize(width: 24.0, height: 24.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.translateBy(x: 0.0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        // Traced from IMG_2486's alpha (core #FFBB00 over white): area within 0.4% and centroid within 0.2px at 3x.
        // The rays are tapered, wide at the outer end.
        context.setFillColor(UIColor(rgb: 0xFFBB00).cgColor)
        context.fillEllipse(in: CGRect(x: 9.267 - 8.433, y: 13.767 - 7.2, width: 8.433 * 2.0, height: 7.2 * 2.0))
        context.move(to: CGPoint(x: 3.633, y: 17.667))
        context.addLine(to: CGPoint(x: 3.433, y: 21.533))
        context.addLine(to: CGPoint(x: 3.867, y: 21.833))
        context.addLine(to: CGPoint(x: 7.167, y: 20.167))
        context.closePath()
        context.fillPath()
        func fillTaper(from p1: CGPoint, radius r1: CGFloat, to p2: CGPoint, radius r2: CGFloat) {
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let angle = atan2(dy, dx)
            let spread = acos((r1 - r2) / sqrt(dx * dx + dy * dy))
            context.fillEllipse(in: CGRect(x: p1.x - r1, y: p1.y - r1, width: r1 * 2.0, height: r1 * 2.0))
            context.fillEllipse(in: CGRect(x: p2.x - r2, y: p2.y - r2, width: r2 * 2.0, height: r2 * 2.0))
            context.move(to: CGPoint(x: p1.x + r1 * cos(angle + spread), y: p1.y + r1 * sin(angle + spread)))
            context.addLine(to: CGPoint(x: p2.x + r2 * cos(angle + spread), y: p2.y + r2 * sin(angle + spread)))
            context.addLine(to: CGPoint(x: p2.x + r2 * cos(angle - spread), y: p2.y + r2 * sin(angle - spread)))
            context.addLine(to: CGPoint(x: p1.x + r1 * cos(angle - spread), y: p1.y + r1 * sin(angle - spread)))
            context.closePath()
            context.fillPath()
        }
        fillTaper(from: CGPoint(x: 14.833, y: 2.767), radius: 1.0, to: CGPoint(x: 13.833, y: 5.7), radius: 0.433)
        fillTaper(from: CGPoint(x: 19.967, y: 4.567), radius: 1.1, to: CGPoint(x: 17.0, y: 7.4), radius: 0.467)
        fillTaper(from: CGPoint(x: 21.467, y: 9.2), radius: 1.0, to: CGPoint(x: 18.733, y: 10.3), radius: 0.4)
    })
}

private final class ButtonsContainerNode: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let subnodes = self.subnodes {
            for subnode in subnodes {
                if let result = subnode.view.hitTest(self.view.convert(point, to: subnode.view), with: event) {
                    return result
                }
            }
        }
        return nil
    }
}

final class ChatPinnedMessageTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let context: AccountContext
    private let tapButton: HighlightTrackingButtonNode
    private let buttonsContainer: ButtonsContainerNode
    private let closeButton: HighlightableButtonNode
    private let listButton: HighlightableButtonNode
    private let activityIndicatorContainer: ASDisplayNode
    private let activityIndicator: RadialStatusNode
    
    private let contextContainer: ContextControllerSourceNode
    private let clippingContainer: ASDisplayNode
    private let contentContainer: ASDisplayNode
    private let contentTextContainer: ASDisplayNode
    private let lineNode: AnimatedNavigationStripeNode
    private let titleNode: AnimatedCountLabelNode
    private let textNode: TextNodeWithEntities
    private var spoilerTextNode: TextNodeWithEntities?
    private var dustNode: InvisibleInkDustNode?
    private let actionButton: HighlightableButtonNode
    private let actionButtonTitleNode: ImmediateTextNode
    private let actionButtonBackgroundNode: ASImageNode
    
    private let imageNode: TransformImageNode
    private let imageNodeContainer: ASDisplayNode
    
    private let cardStackNode: ASDisplayNode
    private let cardBackgroundNode: ASDisplayNode
    private let cardIconNode: ASImageNode
    private let removeButton: HighlightableButtonNode
    private var removeButtonWidth: CGFloat = 0.0
    private var lastInterfaceState: ChatPresentationInterfaceState?
    private var listOverlay: PinnedListOverlayView?
    private let listDisposable = MetaDisposable()

    private var currentLayout: (CGFloat, CGFloat, CGFloat)?
    private var currentMessage: ChatPinnedMessage?
    private var previousMediaReference: AnyMediaReference?
    private var currentTranslateToLanguage: (fromLang: String, toLang: String)?
    private let translationDisposable = MetaDisposable()
    
    private var isReplyThread: Bool = false
    
    private let fetchDisposable = MetaDisposable()
    
    private var statusDisposable: Disposable?
    private var progressDisposable: Disposable?
    
    private let animationCache: AnimationCache?
    private let animationRenderer: MultiAnimationRenderer?

    private let queue = Queue()
    
    private var captureProtected: Bool = false {
        didSet {
            if self.captureProtected != oldValue {
                if self.isNodeLoaded {
                    setLayerDisableScreenshots(self.contentContainer.layer, self.captureProtected)
                }
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let buttonResult = self.buttonsContainer.hitTest(point.offsetBy(dx: -self.buttonsContainer.frame.minX, dy: -self.buttonsContainer.frame.minY), with: event) {
            return buttonResult
        }
        let containerResult = self.contentTextContainer.hitTest(point.offsetBy(dx: -self.contentTextContainer.frame.minX, dy: -self.contentTextContainer.frame.minY), with: event)
        if containerResult?.asyncdisplaykit_node === self.dustNode, self.dustNode?.isRevealed == false {
            return containerResult
        }
        let result = super.hitTest(point, with: event)
        return result
    }
    
    init(context: AccountContext, animationCache: AnimationCache?, animationRenderer: MultiAnimationRenderer?) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        
        self.tapButton = HighlightTrackingButtonNode()
        
        self.buttonsContainer = ButtonsContainerNode()
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.actionButton = HighlightableButtonNode()
        self.actionButton.isHidden = true
        self.actionButtonTitleNode = ImmediateTextNode()
        self.actionButtonTitleNode.isHidden = true
        self.actionButtonBackgroundNode = ASImageNode()
        self.actionButtonBackgroundNode.isHidden = true
        self.actionButtonBackgroundNode.displaysAsynchronously = false
        
        self.listButton = HighlightableButtonNode()
        self.listButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.listButton.displaysAsynchronously = false
        
        self.activityIndicatorContainer = ASDisplayNode()
        self.activityIndicatorContainer.isUserInteractionEnabled = false
        self.activityIndicator = RadialStatusNode(backgroundNodeColor: .clear)
        self.activityIndicator.isUserInteractionEnabled = false
        self.activityIndicatorContainer.addSubnode(self.activityIndicator)
        self.activityIndicator.alpha = 0.0
        ContainedViewLayoutTransition.immediate.updateSublayerTransformScale(node: self.activityIndicatorContainer, scale: 0.1)
        
        self.contextContainer = ContextControllerSourceNode()
        
        self.clippingContainer = ASDisplayNode()
        self.clippingContainer.clipsToBounds = true
        
        self.contentContainer = ASDisplayNode()
        self.contentTextContainer = ASDisplayNode()
        
        self.lineNode = AnimatedNavigationStripeNode()
        
        self.titleNode = AnimatedCountLabelNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.reverseAnimationDirection = true
        
        self.textNode = TextNodeWithEntities()
        self.textNode.textNode.displaysAsynchronously = false
        self.textNode.textNode.isUserInteractionEnabled = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        
        self.imageNodeContainer = ASDisplayNode()
        
        self.cardStackNode = ASDisplayNode()
        self.cardStackNode.isUserInteractionEnabled = false
        self.cardStackNode.cornerRadius = PinnedCardMetrics.cornerRadius
        self.cardBackgroundNode = ASDisplayNode()
        self.cardBackgroundNode.isUserInteractionEnabled = false
        self.cardBackgroundNode.cornerRadius = PinnedCardMetrics.cornerRadius
        self.cardIconNode = ASImageNode()
        self.cardIconNode.isUserInteractionEnabled = false
        self.cardIconNode.displaysAsynchronously = false
        self.cardIconNode.image = generatePinnedCardIcon()
        self.removeButton = HighlightableButtonNode()
        self.removeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -10.0, bottom: -8.0, right: -10.0)
        self.removeButton.displaysAsynchronously = false
        
        super.init()
        
        self.tapButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.textNode.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.textNode.alpha = 0.4
                    strongSelf.lineNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.lineNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.textNode.textNode.alpha = 1.0
                    strongSelf.textNode.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.lineNode.alpha = 1.0
                    strongSelf.lineNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.actionButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.actionButton.layer.removeAnimation(forKey: "opacity")
                    strongSelf.actionButton.alpha = 0.4
                } else {
                    strongSelf.actionButton.alpha = 1.0
                    strongSelf.actionButton.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.listButton.addTarget(self, action: #selector(self.listPressed), forControlEvents: [.touchUpInside])
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: [.touchUpInside])
        
        self.addSubnode(self.contextContainer)
        
        self.contextContainer.addSubnode(self.cardStackNode)
        self.contextContainer.addSubnode(self.cardBackgroundNode)
        self.contextContainer.addSubnode(self.clippingContainer)
        self.clippingContainer.addSubnode(self.contentContainer)
        self.contextContainer.addSubnode(self.lineNode)
        self.contentTextContainer.addSubnode(self.titleNode)
        self.contentTextContainer.addSubnode(self.textNode.textNode)
        self.contentContainer.addSubnode(self.contentTextContainer)
        
        self.imageNodeContainer.addSubnode(self.imageNode)
        self.contentContainer.addSubnode(self.imageNodeContainer)
        
        self.actionButton.addSubnode(self.actionButtonBackgroundNode)
        self.actionButton.addSubnode(self.actionButtonTitleNode)
        self.buttonsContainer.addSubnode(self.actionButton)
        self.buttonsContainer.addSubnode(self.closeButton)
        self.buttonsContainer.addSubnode(self.listButton)
        self.contextContainer.addSubnode(self.buttonsContainer)
        self.contextContainer.addSubnode(self.activityIndicatorContainer)
        
        self.tapButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        self.contextContainer.addSubnode(self.tapButton)
        self.contextContainer.addSubnode(self.cardIconNode)
        self.contextContainer.addSubnode(self.removeButton)
        self.removeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.removeButton.highligthedChanged = { [weak self] highlighted in
            self?.removeButton.alpha = highlighted ? 0.4 : 1.0
        }
        
        self.contextContainer.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            if let interfaceInteraction = strongSelf.interfaceInteraction, let _ = strongSelf.currentMessage, !strongSelf.isReplyThread {
                interfaceInteraction.activatePinnedListPreview(strongSelf.contextContainer, gesture)
            }
        }
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.statusDisposable?.dispose()
        self.translationDisposable.dispose()
        self.progressDisposable?.dispose()
    }
    
    private var theme: PresentationTheme?
    
    /// WeGram draws the pinned bar as a white card with a "Remove" action; reply threads keep the upstream bar.
    func usesCardStyle(interfaceState: ChatPresentationInterfaceState) -> Bool {
        if case let .replyThread(message) = interfaceState.chatLocation, !message.isForumPost {
            return false
        }
        return true
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        self.lastInterfaceState = interfaceState
        let usesCard = self.usesCardStyle(interfaceState: interfaceState)
        let isStacked = usesCard && (interfaceState.pinnedMessage?.totalCount ?? 1) > 1
        let cardTop: CGFloat = usesCard ? PinnedCardMetrics.topInset : 0.0
        let cardHeight: CGFloat = usesCard ? PinnedCardMetrics.height : 50.0
        let panelHeight: CGFloat = usesCard ? PinnedCardMetrics.topInset + PinnedCardMetrics.height + PinnedCardMetrics.bottomInset + (isStacked ? PinnedCardMetrics.stackPeek : 0.0) : 50.0
        var themeUpdated = false
        
        self.contextContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        
        if self.theme !== interfaceState.theme {
            themeUpdated = true
            self.theme = interfaceState.theme
            self.cardBackgroundNode.backgroundColor = interfaceState.theme.list.itemBlocksBackgroundColor
            self.cardStackNode.backgroundColor = interfaceState.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.5)
            self.closeButton.setImage(generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setStrokeColor(interfaceState.theme.chat.inputPanel.panelControlColor.cgColor)
                context.setLineWidth(1.33)
                context.setLineCap(.round)
                context.move(to: CGPoint(x: 1.0, y: 1.0))
                context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
                context.strokePath()
                context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
                context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
                context.strokePath()
            }), for: [])
            self.listButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/PinnedList"), color: interfaceState.theme.chat.inputPanel.panelControlColor), for: [])
            
            self.actionButtonBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 14.0 * 2.0, color: interfaceState.theme.list.itemCheckColors.fillColor, strokeColor: nil, strokeWidth: nil, backgroundColor: nil)
        }
        
        if self.statusDisposable == nil, let interfaceInteraction = self.interfaceInteraction, let statuses = interfaceInteraction.statuses {
            self.statusDisposable = (statuses.loadingMessage
            |> map { status -> Bool in
                return status == .pinnedMessage
            }
            |> deliverOnMainQueue).startStrict(next: { [weak self] isLoading in
                guard let self else {
                    return
                }
                self.updateIsLoading(isLoading: isLoading)
            })
        }
        
        let isReplyThread: Bool
        if case let .replyThread(message) = interfaceState.chatLocation, !message.isForumPost {
            isReplyThread = true
        } else {
            isReplyThread = false
        }
        self.isReplyThread = isReplyThread
        
        self.captureProtected = interfaceState.copyProtectionEnabled || interfaceState.myCopyProtectionEnabled
        
        self.contextContainer.isGestureEnabled = !isReplyThread
        
        var actionTitle: String?
        var messageUpdated = false
        var messageUpdatedAnimation: PinnedMessageAnimation?
        if let currentMessage = self.currentMessage, let pinnedMessage = interfaceState.pinnedMessage {
            if currentMessage != pinnedMessage {
                messageUpdated = true
            }
            if currentMessage.message.id != pinnedMessage.message.id {
                if currentMessage.message.id < pinnedMessage.message.id {
                    messageUpdatedAnimation = .slideToTop
                } else {
                    messageUpdatedAnimation = .slideToBottom
                }
            }
        } else if (self.currentMessage != nil) != (interfaceState.pinnedMessage != nil) {
            messageUpdated = true
        }
        
        var isStarsPayment = false
        if let message = interfaceState.pinnedMessage, !message.message.isRestricted(platform: "ios", contentSettings: self.context.currentContentSettings.with { $0 }) {
            for attribute in message.message.attributes {
                if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), attribute.rows.count == 1, attribute.rows[0].buttons.count == 1 {
                    let title = attribute.rows[0].buttons[0].title
                    actionTitle = title
                    if case .payment = attribute.rows[0].buttons[0].action, title.contains("⭐️") {
                        isStarsPayment = true
                    }
                }
            }
            
            if actionTitle == nil {
                for media in message.message.media {
                    if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, content.type == "telegram_call" {
                        actionTitle = interfaceState.strings.Chat_TitleJoinGroupCall
                    }
                }
            }
        } else {
            actionTitle = nil
        }
        
        var displayCloseButton = false
        var displayListButton = false
        
        if usesCard || isReplyThread || actionTitle != nil {
            displayCloseButton = false
            displayListButton = false
        } else if let message = interfaceState.pinnedMessage {
            if message.totalCount > 1 {
                displayCloseButton = false
                displayListButton = true
            } else {
                displayCloseButton = true
                displayListButton = false
            }
        } else {
            displayCloseButton = false
            displayListButton = true
        }
        
        if displayCloseButton != !self.closeButton.isHidden {
            if transition.isAnimated {
                if displayCloseButton {
                    self.closeButton.isHidden = false
                    self.closeButton.layer.removeAllAnimations()
                    
                    self.closeButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.closeButton.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                } else {
                    self.closeButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] completed in
                        guard let strongSelf = self, completed else {
                            return
                        }
                        strongSelf.closeButton.isHidden = true
                        strongSelf.closeButton.layer.removeAllAnimations()
                    })
                    self.closeButton.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                }
            } else {
                self.closeButton.isHidden = !displayCloseButton
                self.closeButton.layer.removeAllAnimations()
            }
        }
        if displayListButton != !self.listButton.isHidden {
            if transition.isAnimated {
                if displayListButton {
                    self.listButton.isHidden = false
                    self.listButton.layer.removeAllAnimations()
                    
                    self.listButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.listButton.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                } else {
                    self.listButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] completed in
                        guard let strongSelf = self, completed else {
                            return
                        }
                        strongSelf.listButton.isHidden = true
                        strongSelf.listButton.layer.removeAllAnimations()
                    })
                    self.listButton.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                }
            } else {
                self.listButton.isHidden = !displayListButton
                self.listButton.layer.removeAllAnimations()
            }
        }
        
        let rightInset: CGFloat = 18.0 + rightInset
        
        var tapButtonRightInset: CGFloat = rightInset
        
        let buttonsContainerSize = CGSize(width: 16.0, height: panelHeight)
        self.buttonsContainer.frame = CGRect(origin: CGPoint(x: width - buttonsContainerSize.width - rightInset - 4.0, y: 0.0), size: buttonsContainerSize)
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        
        if let actionTitle {
            var actionButtonTransition = transition
            var animateButtonIn = false
            if self.actionButton.isHidden {
                actionButtonTransition = .immediate
                animateButtonIn = true
            } else if transition.isAnimated, messageUpdated, actionTitle != self.actionButtonTitleNode.attributedText?.string {
                if let buttonSnapshot = self.actionButton.view.snapshotView(afterScreenUpdates: false) {
                    animateButtonIn = true
                    buttonSnapshot.frame = self.actionButton.frame
                    self.actionButton.view.superview?.insertSubview(buttonSnapshot, belowSubview: self.actionButton.view)
                    
                    buttonSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak buttonSnapshot] _ in
                        buttonSnapshot?.removeFromSuperview()
                    })
                    buttonSnapshot.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                }
            }
            
            self.actionButton.isHidden = false
            self.actionButtonBackgroundNode.isHidden = false
            self.actionButtonTitleNode.isHidden = false
            
            let attributedTitle: NSAttributedString
            if isStarsPayment {
                let updatedTitle = actionTitle.replacingOccurrences(of: "⭐️", with: " # ")
                let buttonAttributedString = NSMutableAttributedString(string: updatedTitle, font: Font.with(size: 15.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor:  interfaceState.theme.list.itemCheckColors.foregroundColor)
                if let range = buttonAttributedString.string.range(of: "#"), let starImage = UIImage(bundleImageName: "Item List/PremiumIcon") {
                    buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.foregroundColor, value: interfaceState.theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: buttonAttributedString.string))
                }
                attributedTitle = buttonAttributedString
            } else {
                attributedTitle = NSAttributedString(string: actionTitle, font: Font.with(size: 15.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor:  interfaceState.theme.list.itemCheckColors.foregroundColor)
            }
            self.actionButtonTitleNode.attributedText = attributedTitle
            
            let actionButtonTitleSize = self.actionButtonTitleNode.updateLayout(CGSize(width: 150.0, height: .greatestFiniteMagnitude))
            let actionButtonSize = CGSize(width: max(actionButtonTitleSize.width + 20.0, 40.0), height: 28.0)
            let actionButtonFrame = CGRect(origin: CGPoint(x: buttonsContainerSize.width + 11.0 - actionButtonSize.width, y: cardTop + floor((cardHeight - actionButtonSize.height) / 2.0)), size: actionButtonSize)
            actionButtonTransition.updateFrame(node: self.actionButton, frame: actionButtonFrame)
            actionButtonTransition.updateFrame(node: self.actionButtonBackgroundNode, frame: CGRect(origin: CGPoint(), size: actionButtonFrame.size))
            actionButtonTransition.updateFrame(node: self.actionButtonTitleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((actionButtonFrame.width - actionButtonTitleSize.width) / 2.0), y: floorToScreenPixels((actionButtonFrame.height - actionButtonTitleSize.height) / 2.0)), size: actionButtonTitleSize))
            
            tapButtonRightInset = 18.0 + actionButtonFrame.width
            
            if animateButtonIn {
                self.actionButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.actionButton.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
            }
        } else if !self.actionButton.isHidden {
            self.actionButton.isHidden = true
            self.actionButtonBackgroundNode.isHidden = true
            self.actionButtonTitleNode.isHidden = true
            
            if transition.isAnimated {
                if let buttonSnapshot = self.actionButton.view.snapshotView(afterScreenUpdates: false) {
                    buttonSnapshot.frame = self.actionButton.frame
                    self.actionButton.view.superview?.insertSubview(buttonSnapshot, belowSubview: self.actionButton.view)
                    
                    buttonSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak buttonSnapshot] _ in
                        buttonSnapshot?.removeFromSuperview()
                    })
                    buttonSnapshot.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                }
            }
        }
        
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: buttonsContainerSize.width - closeButtonSize.width + 1.0, y: 19.0), size: closeButtonSize))
        
        let listButtonSize = self.listButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.listButton, frame: CGRect(origin: CGPoint(x: buttonsContainerSize.width - listButtonSize.width + 4.0, y: 13.0), size: listButtonSize))
        
        let indicatorSize = CGSize(width: 22.0, height: 22.0)
        transition.updateFrame(node: self.activityIndicatorContainer, frame: CGRect(origin: CGPoint(x: width - rightInset - indicatorSize.width + 5.0, y: 15.0), size: indicatorSize))
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(), size: indicatorSize))
        
        // A stack of pins has no Remove on its card (IMG_2487): unpinning happens in the list the card expands into.
        let showsRemove = usesCard && actionTitle == nil && !isStacked
        if usesCard {
            transition.updateFrame(node: self.cardBackgroundNode, frame: CGRect(x: 0.0, y: cardTop, width: width, height: cardHeight))
            transition.updateFrame(node: self.cardStackNode, frame: CGRect(x: 8.0, y: cardTop + PinnedCardMetrics.stackPeek, width: max(0.0, width - 16.0), height: cardHeight))
            self.cardStackNode.isHidden = !isStacked
            self.cardIconNode.frame = PinnedCardMetrics.iconFrame.offsetBy(dx: 0.0, dy: cardTop)
            
            let removeTitle = NSAttributedString(string: interfaceState.strings.DownloadList_RemoveFileAlertRemove, font: Font.regular(PinnedCardMetrics.fontSize), textColor: PinnedCardMetrics.removeColor)
            self.removeButton.setAttributedTitle(removeTitle, for: [])
            self.removeButtonWidth = ceil(removeTitle.size().width)
            let removeHeight: CGFloat = 24.0
            self.removeButton.frame = CGRect(x: width - PinnedCardMetrics.trailingInset - self.removeButtonWidth, y: cardTop + floor((cardHeight - removeHeight) / 2.0) + 0.5, width: self.removeButtonWidth, height: removeHeight)
            if showsRemove {
                tapButtonRightInset = PinnedCardMetrics.trailingInset + self.removeButtonWidth + 10.0
            }
        }
        self.cardBackgroundNode.isHidden = !usesCard
        self.cardIconNode.isHidden = !usesCard
        self.removeButton.isHidden = !showsRemove
        self.lineNode.isHidden = usesCard
        self.titleNode.isHidden = usesCard
        
        self.tapButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: width - tapButtonRightInset, height: panelHeight))
        
        self.clippingContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        self.contentContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        
        var translateToLanguage: (fromLang: String, toLang: String)?
        if let translationState = interfaceState.translationState, translationState.isEnabled {
            translateToLanguage = (normalizeTranslationLanguage(translationState.fromLang), normalizeTranslationLanguage(translationState.toLang))
        }
        
        var currentTranslateToLanguageUpdated = false
        if self.currentTranslateToLanguage?.fromLang != translateToLanguage?.fromLang || self.currentTranslateToLanguage?.toLang != translateToLanguage?.toLang {
            self.currentTranslateToLanguage = translateToLanguage
            currentTranslateToLanguageUpdated = true
        }
        
        if currentTranslateToLanguageUpdated || messageUpdated, let message = interfaceState.pinnedMessage?.message {
            if let translation = message.attributes.first(where: { $0 is TranslationMessageAttribute }) as? TranslationMessageAttribute, translation.toLang == translateToLanguage?.toLang {
            } else if let translateToLanguage {
                self.translationDisposable.set(translateMessageIds(context: self.context, messageIds: [message.id], fromLang: translateToLanguage.fromLang, toLang: translateToLanguage.toLang).startStrict())
            }
        }
        
        if self.currentLayout?.0 != width || self.currentLayout?.1 != leftInset || self.currentLayout?.2 != rightInset || messageUpdated || themeUpdated || currentTranslateToLanguageUpdated {
            self.currentLayout = (width, leftInset, rightInset)
            
            let messageUpdated = self.currentMessage?.message.id != interfaceState.pinnedMessage?.message.id
            let previousMessageWasNil = self.currentMessage == nil
            self.currentMessage = interfaceState.pinnedMessage
            
            if let currentMessage = self.currentMessage, let currentLayout = self.currentLayout {
                self.dustNode?.update(revealed: false, animated: false)
                self.enqueueTransition(width: currentLayout.0, panelHeight: panelHeight, leftInset: currentLayout.1, rightInset: currentLayout.2, transition: messageUpdated ? .immediate : transition, animation: messageUpdatedAnimation, pinnedMessage: currentMessage, theme: interfaceState.theme, strings: interfaceState.strings, nameDisplayOrder: interfaceState.nameDisplayOrder, dateTimeFormat: interfaceState.dateTimeFormat, accountPeerId: self.context.account.peerId, firstTime: previousMessageWasNil, isReplyThread: isReplyThread, translateToLanguage: translateToLanguage?.toLang, usesCard: usesCard, cardTop: cardTop, cardHeight: cardHeight)
            }
        }
        
        self.currentLayout = (width, leftInset, rightInset)
        
        /*if self.currentLayout?.0 != width || self.currentLayout?.1 != leftInset || self.currentLayout?.2 != rightInset || messageUpdated {
            self.currentLayout = (width, leftInset, rightInset)
            
            if let currentMessage = self.currentMessage {
                self.enqueueTransition(width: width, panelHeight: panelHeight, leftInset: leftInset, rightInset: rightInset, transition: .immediate, animation: .none, pinnedMessage: currentMessage, theme: interfaceState.theme, strings: interfaceState.strings, nameDisplayOrder: interfaceState.nameDisplayOrder, dateTimeFormat: interfaceState.dateTimeFormat, accountPeerId: interfaceState.accountPeerId, firstTime: true, isReplyThread: isReplyThread)
            }
        }*/
        
        return LayoutResult(backgroundHeight: panelHeight, insetHeight: panelHeight, hitTestSlop: 0.0)
    }
    
    private func updateIsLoading(isLoading: Bool) {
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
        if isLoading {
            if self.activityIndicator.alpha.isZero {
                transition.updateAlpha(node: self.activityIndicator, alpha: 1.0)
                transition.updateSublayerTransformScale(node: self.activityIndicatorContainer, scale: 1.0)
                
                transition.updateAlpha(node: self.buttonsContainer, alpha: 0.0)
                transition.updateSublayerTransformScale(node: self.buttonsContainer, scale: 0.1)
                
                if let theme = self.theme {
                    self.activityIndicator.transitionToState(.progress(color: theme.chat.inputPanel.panelControlColor, lineWidth: nil, value: nil, cancelEnabled: false, animateRotation: true), animated: false, completion: {
                    })
                }
            }
        } else {
            if !self.activityIndicator.alpha.isZero {
                transition.updateAlpha(node: self.activityIndicator, alpha: 0.0, completion: { [weak self] completed in
                    if completed {
                        self?.activityIndicator.transitionToState(.none, animated: false, completion: {
                        })
                    }
                })
                transition.updateSublayerTransformScale(node: self.activityIndicatorContainer, scale: 0.1)
                
                transition.updateAlpha(node: self.buttonsContainer, alpha: 1.0)
                transition.updateSublayerTransformScale(node: self.buttonsContainer, scale: 1.0)
            }
        }
    }
    
    private func enqueueTransition(width: CGFloat, panelHeight: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, animation: PinnedMessageAnimation?, pinnedMessage: ChatPinnedMessage, theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, accountPeerId: EnginePeer.Id, firstTime: Bool, isReplyThread: Bool, translateToLanguage: String?, usesCard: Bool, cardTop: CGFloat, cardHeight: CGFloat) {
        let message = pinnedMessage.message
        
        var animationTransition: ContainedViewLayoutTransition = .immediate
        
        if let animation = animation {
            animationTransition = .animated(duration: 0.2, curve: .easeInOut)
            
            if let copyView = self.textNode.textNode.view.snapshotView(afterScreenUpdates: false) {
                let offset: CGFloat
                switch animation {
                case .slideToTop:
                    offset = -10.0
                case .slideToBottom:
                    offset = 10.0
                }
                
                copyView.frame = self.textNode.textNode.frame
                self.textNode.textNode.view.superview?.addSubview(copyView)
                copyView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offset), duration: 0.2, removeOnCompletion: false, additive: true)
                copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak copyView] _ in
                    copyView?.removeFromSuperview()
                })
                self.textNode.textNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -offset), to: CGPoint(), duration: 0.2, additive: true)
                self.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        } else {
            animationTransition = transition
        }
        
        let makeTitleLayout = self.titleNode.asyncLayout()
        let makeTextLayout = TextNodeWithEntities.asyncLayout(self.textNode)
        let makeSpoilerTextLayout = TextNodeWithEntities.asyncLayout(self.spoilerTextNode)
        let imageNodeLayout = self.imageNode.asyncLayout()
        
        let previousMediaReference = self.previousMediaReference
        let context = self.context
        
        let contentLeftInset: CGFloat = usesCard ? 0.0 : leftInset + 18.0
        var textLineInset: CGFloat = usesCard ? PinnedCardMetrics.textLeft : 10.0
        var rightInset: CGFloat = 14.0 + rightInset
        if usesCard {
            rightInset = PinnedCardMetrics.trailingInset + (self.actionButton.isHidden ? (self.removeButton.isHidden ? 0.0 : self.removeButtonWidth) : self.actionButton.bounds.width) + 2.0
        }
        
        let textRightInset: CGFloat = 0.0
        
        if !self.actionButton.isHidden && !usesCard {
            rightInset += self.actionButton.bounds.width - 14.0
        }
        
        var updatedMediaReference: AnyMediaReference?
        var imageDimensions: CGSize?
        
        let giveaway = pinnedMessage.message.media.first(where: { $0 is TelegramMediaGiveaway }) as? TelegramMediaGiveaway
        
        var titleStrings: [AnimatedCountLabelNode.Segment] = []
        if let _ = giveaway {
            titleStrings.append(.text(0, NSAttributedString(string: "\(strings.Conversation_PinnedGiveaway) ", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlColor)))
        } else {
            if pinnedMessage.totalCount == 2 {
                if pinnedMessage.index == 0 {
                    titleStrings.append(.text(0, NSAttributedString(string: "\(strings.Conversation_PinnedPreviousMessage) ", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlColor)))
                } else {
                    titleStrings.append(.text(0, NSAttributedString(string: "\(strings.Conversation_PinnedMessage) ", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlColor)))
                }
            } else if pinnedMessage.totalCount > 1 && pinnedMessage.index != pinnedMessage.totalCount - 1 {
                titleStrings.append(.text(0, NSAttributedString(string: "\(strings.Conversation_PinnedMessage)", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlColor)))
                titleStrings.append(.text(1, NSAttributedString(string: " #", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlColor)))
                titleStrings.append(.number(pinnedMessage.index + 1, NSAttributedString(string: "\(pinnedMessage.index + 1)", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlColor)))
            } else {
                titleStrings.append(.text(0, NSAttributedString(string: "\(strings.Conversation_PinnedMessage) ", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlColor)))
            }
        }
        
        if !message.containsSecretMedia {
            for media in message.media {
                if let image = media as? TelegramMediaImage {
                    updatedMediaReference = .message(message: MessageReference(message), media: image)
                    if let representation = largestRepresentationForPhoto(image) {
                        imageDimensions = representation.dimensions.cgSize
                    }
                    break
                } else if let file = media as? TelegramMediaFile {
                    updatedMediaReference = .message(message: MessageReference(message), media: file)
                    if !file.isInstantVideo && !file.isSticker, let representation = largestImageRepresentation(file.previewRepresentations) {
                        imageDimensions = representation.dimensions.cgSize
                    } else if file.isAnimated, let dimensions = file.dimensions {
                        imageDimensions = dimensions.cgSize
                    }
                    break
                } else if let paidContent = media as? TelegramMediaPaidContent, let firstMedia = paidContent.extendedMedia.first {
                    switch firstMedia {
                    case let .preview(dimensions, immediateThumbnailData, _):
                        let thumbnailMedia = TelegramMediaImage(imageId: EngineMedia.Id(namespace: 0, id: 0), representations: [], immediateThumbnailData: immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                        if let dimensions {
                            imageDimensions = dimensions.cgSize
                        }
                        updatedMediaReference = .standalone(media: thumbnailMedia)
                    case let .full(fullMedia):
                        updatedMediaReference = .message(message: MessageReference(message), media: fullMedia)
                        if let image = fullMedia as? TelegramMediaImage {
                            if let representation = largestRepresentationForPhoto(image) {
                                imageDimensions = representation.dimensions.cgSize
                            }
                            break
                        } else if let file = fullMedia as? TelegramMediaFile {
                            if let dimensions = file.dimensions {
                                imageDimensions = dimensions.cgSize
                            }
                            break
                        }
                    }
                }
            }
        }
        
        if isReplyThread {
            let titleString: String
            if let author = message.effectiveAuthor {
                titleString = EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)
            } else {
                titleString = ""
            }
            titleStrings = [.text(0, NSAttributedString(string: titleString, font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlColor))]
        } else {
            for media in message.media {
                if let media = media as? TelegramMediaInvoice {
                    titleStrings = [.text(0, NSAttributedString(string: media.title, font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlColor))]
                    break
                } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, content.type == "telegram_call" {
                    titleStrings = [.text(0, NSAttributedString(string: strings.Chat_PinnedGroupCallTitle, font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlColor))]
                    break
                }
            }
        }
        
        if usesCard {
            imageDimensions = nil
        }
        
        var applyImage: (() -> Void)?
        if let imageDimensions = imageDimensions {
            let boundingSize = CGSize(width: 35.0, height: 35.0)
            applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: 8.0), imageSize: imageDimensions.aspectFilled(boundingSize), boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
            
            textLineInset += 9.0 + 35.0
        }
        
        var mediaUpdated = false
        if let updatedMediaReference = updatedMediaReference, let previousMediaReference = previousMediaReference {
            mediaUpdated = !updatedMediaReference.media.isEqual(to: previousMediaReference.media)
        } else if (updatedMediaReference != nil) != (previousMediaReference != nil) {
            mediaUpdated = true
        }
        
        let hasSpoiler = message.attributes.contains(where: { $0 is MediaSpoilerMessageAttribute })
        
        var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        var updatedFetchMediaSignal: Signal<EngineFetchResourceSourceType, EngineFetchResourceError>?
        if mediaUpdated {
            if let updatedMediaReference = updatedMediaReference, imageDimensions != nil {
                if let imageReference = updatedMediaReference.concrete(TelegramMediaImage.self) {
                    if imageReference.media.representations.isEmpty {
                        updateImageSignal = chatSecretPhoto(account: context.account, userLocation: .peer(message.id.peerId), photoReference: imageReference, ignoreFullSize: true, synchronousLoad: true)
                    } else {
                        updateImageSignal = chatMessagePhotoThumbnail(account: context.account, userLocation: .peer(message.id.peerId), photoReference: imageReference, blurred: hasSpoiler)
                    }
                } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                    if fileReference.media.isAnimatedSticker {
                        let dimensions = fileReference.media.dimensions ?? PixelDimensions(width: 512, height: 512)
                        updateImageSignal = chatMessageAnimatedSticker(postbox: context.account.postbox, userLocation: .peer(message.id.peerId), file: fileReference.media, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0)))
                        updatedFetchMediaSignal = context.engine.resources.fetch(reference: fileReference.resourceReference(fileReference.media.resource), userLocation: .peer(message.id.peerId), userContentType: MediaResourceUserContentType(file: fileReference.media))
                    } else if fileReference.media.isVideo || fileReference.media.isAnimated {
                        updateImageSignal = chatMessageVideoThumbnail(account: context.account, userLocation: .peer(message.id.peerId), fileReference: fileReference, blurred: hasSpoiler)
                    } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                        updateImageSignal = chatWebpageSnippetFile(account: context.account, userLocation: .peer(message.id.peerId), mediaReference: fileReference.abstract, representation: iconImageRepresentation)
                    }
                }
            } else {
                updateImageSignal = .single({ _ in return nil })
            }
        }
        let (titleLayout, titleApply) = makeTitleLayout(CGSize(width: width - textLineInset - contentLeftInset - rightInset - textRightInset, height: CGFloat.greatestFiniteMagnitude), .zero, titleStrings)
        
        let (textString, _, isText) = descriptionStringForMessage(contentSettings: context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, accountPeerId: accountPeerId)
        
        var messageText: NSAttributedString
        let textFont = Font.regular(usesCard ? PinnedCardMetrics.fontSize : 15.0)
        let primaryTextColor = usesCard ? PinnedCardMetrics.textColor : theme.chat.inputPanel.primaryTextColor
        if let giveaway {
            let dateString = stringForDateWithoutYear(date: Date(timeIntervalSince1970: TimeInterval(giveaway.untilDate)), timeZone: .current, strings: strings)
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            let isFinished = currentTime >= giveaway.untilDate
            let text: String
            if isFinished {
                let winnersString = strings.Conversation_PinnedGiveaway_Finished_Winners(giveaway.quantity)
                text = strings.Conversation_PinnedGiveaway_Finished(winnersString, dateString).string
            } else {
                let winnersString = strings.Conversation_PinnedGiveaway_Ongoing_Winners(giveaway.quantity)
                text = strings.Conversation_PinnedGiveaway_Ongoing(winnersString, dateString).string
            }
            messageText = NSAttributedString(string: text, font: textFont, textColor: primaryTextColor)
        } else if isText {
            var text = message.text
            var messageEntities = message.textEntitiesAttribute?.entities ?? []
            
            if let translateToLanguage = translateToLanguage, !text.isEmpty {
                for attribute in message.attributes {
                    if let attribute = attribute as? TranslationMessageAttribute, !attribute.text.isEmpty, attribute.toLang == translateToLanguage {
                        text = attribute.text
                        messageEntities = attribute.entities
                        break
                    }
                }
            }
            
            let entities = messageEntities.filter { entity in
                switch entity.type {
                case .Spoiler, .CustomEmoji:
                    return true
                default:
                    return false
                }
            }
            let textColor = primaryTextColor
            if entities.count > 0 {
                messageText = stringWithAppliedEntities(trimToLineCount(text, lineCount: 1), entities: entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: message)
            } else {
                messageText = NSAttributedString(string: foldLineBreaks(text), font: textFont, textColor: textColor)
            }
        } else {
            let textColor = message.media.isEmpty || message.media.first is TelegramMediaWebpage ? primaryTextColor : theme.chat.inputPanel.secondaryTextColor
            let mutableTextString = styleInstantPagePreview(foldLineBreaks(textString), font: textFont, italicFont: Font.italic(textFont.pointSize), textColor: textColor)
            messageText = renderInstantPagePreviewIcons(mutableTextString, font: textFont, textColor: textColor)
        }
        
        if usesCard, giveaway == nil, let author = message.effectiveAuthor {
            let prefix = NSMutableAttributedString(string: "\(EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)): ", font: textFont, textColor: primaryTextColor)
            prefix.append(messageText)
            messageText = prefix
        }
        
        let textConstrainedSize = CGSize(width: width - textLineInset - contentLeftInset - rightInset - textRightInset - 10.0, height: CGFloat.greatestFiniteMagnitude)
        let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: messageText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0)))
        
        let spoilerTextLayoutAndApply: (TextNodeLayout, (TextNodeWithEntities.Arguments?) -> TextNodeWithEntities)?
        if !textLayout.spoilers.isEmpty {
            spoilerTextLayoutAndApply = makeSpoilerTextLayout(TextNodeLayoutArguments(attributedString: messageText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0), displaySpoilers: true, displayEmbeddedItemsUnderSpoilers: true))
        } else {
            spoilerTextLayoutAndApply = nil
        }
        
        let strongSelf = self
        let _ = titleApply(animation != nil)
        
        var textArguments: TextNodeWithEntities.Arguments?
        if let cache = strongSelf.animationCache, let renderer = strongSelf.animationRenderer {
            textArguments = TextNodeWithEntities.Arguments(
                context: strongSelf.context,
                cache: cache,
                renderer: renderer,
                placeholderColor: theme.list.mediaPlaceholderColor,
                attemptSynchronous: false
            )
        }
        let _ = textApply(textArguments)
        
        strongSelf.previousMediaReference = updatedMediaReference
        
        animationTransition.updateFrameAdditive(node: strongSelf.contentTextContainer, frame: CGRect(origin: CGPoint(x: contentLeftInset + textLineInset, y: 0.0), size: CGSize(width: width, height: panelHeight)))
        
        strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 6.0), size: titleLayout.size)
        
        let textFrame = CGRect(origin: CGPoint(x: 0.0, y: usesCard ? cardTop + floor((cardHeight - textLayout.size.height) / 2.0) + 0.5 : 23.0), size: textLayout.size)
        strongSelf.textNode.textNode.frame = textFrame
        
        if let (_, spoilerTextApply) = spoilerTextLayoutAndApply {
            let spoilerTextNode = spoilerTextApply(textArguments)
            if strongSelf.spoilerTextNode == nil {
                spoilerTextNode.textNode.alpha = 0.0
                spoilerTextNode.textNode.isUserInteractionEnabled = false
                spoilerTextNode.textNode.contentMode = .topLeft
                spoilerTextNode.textNode.contentsScale = UIScreenScale
                spoilerTextNode.textNode.displaysAsynchronously = false
                strongSelf.contentTextContainer.insertSubnode(spoilerTextNode.textNode, aboveSubnode: strongSelf.textNode.textNode)
                
                strongSelf.spoilerTextNode = spoilerTextNode
            }
            
            strongSelf.spoilerTextNode?.textNode.frame = textFrame
            
            let dustNode: InvisibleInkDustNode
            if let current = strongSelf.dustNode {
                dustNode = current
            } else {
                dustNode = InvisibleInkDustNode(textNode: spoilerTextNode.textNode, enableAnimations: strongSelf.context.sharedContext.energyUsageSettings.fullTranslucency)
                strongSelf.dustNode = dustNode
                strongSelf.contentTextContainer.insertSubnode(dustNode, aboveSubnode: spoilerTextNode.textNode)
            }
            dustNode.frame = textFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 3.0)
            dustNode.update(size: dustNode.frame.size, color: theme.chat.inputPanel.secondaryTextColor, textColor: theme.chat.inputPanel.primaryTextColor, rects: textLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: textLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
        } else if let spoilerTextNode = strongSelf.spoilerTextNode {
            strongSelf.spoilerTextNode = nil
            spoilerTextNode.textNode.removeFromSupernode()
            
            if let dustNode = strongSelf.dustNode {
                strongSelf.dustNode = nil
                dustNode.removeFromSupernode()
            }
        }
        
        strongSelf.textNode.visibilityRect = CGRect.infinite
        strongSelf.spoilerTextNode?.visibilityRect = CGRect.infinite
        
        let lineFrame = CGRect(origin: CGPoint(x: contentLeftInset, y: 0.0), size: CGSize(width: 2.0, height: panelHeight))
        animationTransition.updateFrame(node: strongSelf.lineNode, frame: lineFrame)
        strongSelf.lineNode.update(
            colors: AnimatedNavigationStripeNode.Colors(
                foreground: theme.chat.inputPanel.panelControlColor,
                background: theme.chat.inputPanel.panelControlColor.withAlphaComponent(0.5),
                clearBackground: theme.chat.inputPanel.panelBackgroundColor
            ),
            configuration: AnimatedNavigationStripeNode.Configuration(
                height: panelHeight,
                index: pinnedMessage.index,
                count: pinnedMessage.totalCount
            ),
            transition: animationTransition
        )
        
        strongSelf.imageNodeContainer.frame = CGRect(origin: CGPoint(x: contentLeftInset + 9.0, y: 7.0), size: CGSize(width: 36.0, height: 36.0))
        strongSelf.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 36.0, height: 36.0))
        
        if let applyImage = applyImage {
            applyImage()
            
            animationTransition.updateSublayerTransformScale(node: strongSelf.imageNodeContainer, scale: 1.0)
            animationTransition.updateAlpha(node: strongSelf.imageNodeContainer, alpha: 1.0, beginWithCurrentState: true)
        } else {
            animationTransition.updateSublayerTransformScale(node: strongSelf.imageNodeContainer, scale: 0.1)
            animationTransition.updateAlpha(node: strongSelf.imageNodeContainer, alpha: 0.0, beginWithCurrentState: true)
        }
        
        if let updateImageSignal = updateImageSignal {
            strongSelf.imageNode.setSignal(updateImageSignal)
        }
        if let updatedFetchMediaSignal = updatedFetchMediaSignal {
            strongSelf.fetchDisposable.set(updatedFetchMediaSignal.startStrict())
        }
    }
    
    @objc func tapped() {
        if let interfaceInteraction = self.interfaceInteraction, let message = self.currentMessage {
            if self.isReplyThread {
                interfaceInteraction.scrollToTop()
            } else if message.totalCount > 1, self.lastInterfaceState != nil, self.presentPinnedList() {
                return
            } else if message.totalCount > 1 {
                interfaceInteraction.openPinnedList(message.message.id)
            } else {
                interfaceInteraction.navigateToMessage(message.message.id, false, true, .pinnedMessage)
            }
        }
    }
    
    private func presentPinnedList() -> Bool {
        guard let interfaceState = self.lastInterfaceState, let interfaceInteraction = self.interfaceInteraction, self.listOverlay == nil else {
            return self.listOverlay != nil
        }
        var hostNode: ChatControllerNode?
        var current: UIView? = self.view
        while let view = current {
            if let node = view.asyncdisplaykit_node as? ChatControllerNode {
                hostNode = node
                break
            }
            current = view.superview
        }
        let dimColor = UIColor(white: 0.0, alpha: 0.5)
        guard let hostNode, let barBottom = hostNode.updatePinnedListBackdrop(dimColor: dimColor) else {
            return false
        }
        let host = hostNode.view
        let panelTop = host.convert(CGPoint(), from: self.view).y + PinnedCardMetrics.topInset
        let strings = interfaceState.strings
        let nameDisplayOrder = interfaceState.nameDisplayOrder
        let dateTimeFormat = interfaceState.dateTimeFormat
        let accountPeerId = interfaceState.accountPeerId
        let context = self.context
        // WeChat's armed confirm reads 移除置顶 (IMG_2489), where the language pack's Unpin is 取消置顶.
        let languageCode = strings.primaryComponent.languageCode
        let unpinTitle = languageCode.hasPrefix("zh") ? (languageCode.hasSuffix("hant") ? "移除置頂" : "移除置顶") : strings.Conversation_Unpin
        let overlay = PinnedListOverlayView(theme: interfaceState.theme, unpinTitle: unpinTitle, removeTitle: strings.DownloadList_RemoveFileAlertRemove, dimColor: dimColor, barBottom: barBottom, panelTop: panelTop)
        overlay.frame = host.bounds
        overlay.onDismiss = { [weak self, weak overlay, weak hostNode] in
            self?.listDisposable.set(nil)
            overlay?.dismiss()
            let _ = hostNode?.updatePinnedListBackdrop(dimColor: nil)
            self?.listOverlay = nil
        }
        overlay.onSelect = { [weak self] id in
            self?.listOverlay?.onDismiss?()
            interfaceInteraction.navigateToMessage(id, false, true, .pinnedMessage)
        }
        overlay.onUnpin = { id in
            interfaceInteraction.unpinMessage(id, false, nil)
        }
        host.addSubview(overlay)
        self.listOverlay = overlay
        
        let location: ChatLocation
        if case let .replyThread(message) = interfaceState.chatLocation {
            location = .replyThread(message: message)
        } else {
            location = interfaceState.chatLocation
        }
        let signal = chatHistoryViewForLocation(ChatHistoryLocationInput(content: .Initial(count: 100), id: 0), ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), context: context, chatLocation: location, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), scheduled: false, fixedCombinedReadStates: nil, tag: .tag(EngineMessage.Tags.pinned), appendMessagesFromTheSameGroup: false, additionalData: [], orderStatistics: [])
        self.listDisposable.set((signal
        |> deliverOnMainQueue).startStrict(next: { [weak overlay] update in
            guard case let .HistoryView(view, _, _, _, _, _, _) = update else {
                return
            }
            var items: [PinnedListOverlayView.Item] = []
            for entry in view.entries.reversed() {
                let message = entry.message
                let (textString, _, _) = descriptionStringForMessage(contentSettings: context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, accountPeerId: accountPeerId)
                var text = foldLineBreaks(textString).string
                if let author = message.author {
                    text = "\(EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)): \(text)"
                }
                items.append(PinnedListOverlayView.Item(id: message.id, text: text))
            }
            overlay?.setItems(items, animated: true)
        }))
        return true
    }
    
    @objc func closePressed() {
        if let interfaceInteraction = self.interfaceInteraction, let message = self.currentMessage {
            interfaceInteraction.unpinMessage(message.message.id, true, nil)
        }
    }
    
    @objc func listPressed() {
        if let interfaceInteraction = self.interfaceInteraction, let message = self.currentMessage {
            interfaceInteraction.openPinnedList(message.message.id)
        }
    }
    
    @objc private func actionButtonPressed() {
        if let interfaceInteraction = self.interfaceInteraction, let controller = interfaceInteraction.chatController() as? ChatControllerImpl, let controllerInteraction = controller.controllerInteraction, let message = self.currentMessage?.message {
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), attribute.rows.count == 1, attribute.rows[0].buttons.count == 1 {
                    let button = attribute.rows[0].buttons[0]
                    switch button.action {
                    case .text:
                        controllerInteraction.sendMessage(button.title, message.id)
                        return
                    case let .url(url):
                        var isConcealed = true
                        if url.hasPrefix("tg://") {
                            isConcealed = false
                        }
                        controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: url, concealed: isConcealed, progress: Promise()))
                        return
                    case .requestMap:
                        controllerInteraction.shareCurrentLocation(message.id)
                        return
                    case .requestPhone:
                        controllerInteraction.shareAccountContact(message.id)
                        return
                    case .openWebApp:
                        let progressPromise = Promise<Bool>()
                        controllerInteraction.requestMessageActionCallback(message, nil, true, false, progressPromise)
                        self.progressDisposable?.dispose()
                        self.progressDisposable = (progressPromise.get()
                        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                            guard let self else {
                                return
                            }
                            self.updateIsLoading(isLoading: value)
                        })
                        
                        return
                    case let .callback(requiresPassword, data):
                        let progressPromise = Promise<Bool>()
                        controllerInteraction.requestMessageActionCallback(message, data, false, requiresPassword, progressPromise)
                        self.progressDisposable?.dispose()
                        self.progressDisposable = (progressPromise.get()
                        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                            guard let self else {
                                return
                            }
                            self.updateIsLoading(isLoading: value)
                        })
                        return
                    case let .switchInline(samePeer, query, peerTypes):
                        var botPeer: EnginePeer?

                        var found = false
                        for attribute in message.attributes {
                            if let attribute = attribute as? InlineBotMessageAttribute {
                                if let peerId = attribute.peerId {
                                    botPeer = message.peers[peerId].flatMap(EnginePeer.init)
                                    found = true
                                }
                            }
                        }
                        if !found {
                            botPeer = message.author.flatMap(EnginePeer.init)
                        }

                        var peerId: EnginePeer.Id?
                        if samePeer {
                            peerId = message.id.peerId
                        }
                        if let botPeer = botPeer, let addressName = botPeer.addressName {
                            controllerInteraction.activateSwitchInline(peerId, "@\(addressName) \(query)", peerTypes)
                        }
                        return
                    case .payment:
                        controllerInteraction.openCheckoutOrReceipt(message.id, nil)
                        return
                    case let .urlAuth(url, buttonId):
                        controllerInteraction.requestMessageActionUrlAuth(url, .message(id: message.callbackTargetMessageId, buttonId: buttonId))
                        return
                    case .setupPoll:
                        break
                    case let .openUserProfile(peerId):
                        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                        |> deliverOnMainQueue).startStandalone(next: { peer in
                            if let peer = peer {
                                controllerInteraction.openPeer(peer, .info(nil), nil, .default)
                            }
                        })
                        return
                    case let .openWebView(url, simple):
                        // nil: this panel's buttons have no inline loading state, so the
                        // `.requestInProgress` title panel stays their progress indicator.
                        controllerInteraction.openWebView(button.title, url, simple, .generic, nil)
                        return
                    case .requestPeer:
                        break
                    case let .copyText(payload):
                        controllerInteraction.copyText(payload)
                        return
                    case .disabled:
                        // A forward stripped this button's behaviour; tapping does nothing.
                        return
                    }

                    break
                }
            }
            
            for media in message.media {
                if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, content.type == "telegram_call" {
                    var isConcealed = true
                    if content.url.hasPrefix("tg://") {
                        isConcealed = false
                    }
                    let progressPromise = Promise<Bool>()
                    controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(
                        url: content.url,
                        concealed: isConcealed,
                        message: message,
                        progress: progressPromise
                    ))
                    
                    self.progressDisposable?.dispose()
                    self.progressDisposable = (progressPromise.get()
                    |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                        guard let self else {
                            return
                        }
                        self.updateIsLoading(isLoading: value)
                    })
                    
                    return
                }
            }
        }
    }
}

/// The expanded pinned list (IMG_2488/2489): white cards on the bar's own material, which runs on below the bar,
/// a grey collapse pill, a dimmed chat.
private final class PinnedListOverlayView: UIView {
    struct Item: Equatable {
        let id: EngineMessage.Id
        let text: String
    }
    
    private final class CardView: UIView {
        let id: EngineMessage.Id
        let label = UILabel()
        let icon = UIImageView()
        let button = UIButton(type: .custom)
        
        init(id: EngineMessage.Id) {
            self.id = id
            super.init(frame: .zero)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        // The same slop as the collapsed card's Remove: the button is only as large as its title.
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.button.frame.insetBy(dx: -10.0, dy: -8.0).contains(point) {
                return self.button
            }
            return super.hitTest(point, with: event)
        }
    }

    private let theme: PresentationTheme
    private let unpinTitle: String
    private let removeTitle: String
    private let barBottom: CGFloat
    private let panelTop: CGFloat
    private let dimView = UIView()
    private let panelView = UIView()
    private let panelBackground: NavigationBackgroundNode
    private let pillView = UIButton(type: .custom)
    private let scrollView = UIScrollView()
    private var cardViews: [CardView] = []
    private var items: [Item] = []
    private var removedIds = Set<EngineMessage.Id>()
    private var confirmingId: EngineMessage.Id?
    private let icon = generatePinnedCardIcon()
    
    var onDismiss: (() -> Void)?
    var onSelect: ((EngineMessage.Id) -> Void)?
    var onUnpin: ((EngineMessage.Id) -> Void)?
    
    init(theme: PresentationTheme, unpinTitle: String, removeTitle: String, dimColor: UIColor, barBottom: CGFloat, panelTop: CGFloat) {
        self.theme = theme
        self.unpinTitle = unpinTitle
        self.removeTitle = removeTitle
        self.barBottom = barBottom
        self.panelTop = panelTop
        self.panelBackground = NavigationBackgroundNode(color: ChatControllerImpl.wegramNavigationBarTheme(theme, hideBadge: false).backgroundColor)
        super.init(frame: .zero)

        self.dimView.backgroundColor = dimColor
        self.addSubview(self.dimView)
        self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapped)))

        // The material blurs the dimmed chat under it, as the bar above does, so the two read as one surface.
        self.panelView.clipsToBounds = true
        self.panelView.layer.cornerRadius = 12.0
        self.panelView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        self.panelView.addSubview(self.panelBackground.view)
        self.addSubview(self.panelView)
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.panelView.addSubview(self.scrollView)
        
        self.pillView.backgroundColor = UIColor(rgb: 0xD2D2D2)
        self.pillView.layer.cornerRadius = 8.0
        let chevron = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 15.5, y: 9.5))
        path.addLine(to: CGPoint(x: 19.5, y: 5.5))
        path.addLine(to: CGPoint(x: 23.5, y: 9.5))
        chevron.path = path.cgPath
        chevron.strokeColor = UIColor(rgb: 0x151515).cgColor
        chevron.fillColor = nil
        chevron.lineWidth = 1.5
        chevron.lineCap = .round
        chevron.lineJoin = .round
        self.pillView.layer.addSublayer(chevron)
        self.pillView.addTarget(self, action: #selector(self.dimTapped), for: .touchUpInside)
        self.panelView.addSubview(self.pillView)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    @objc private func dimTapped() {
        self.onDismiss?()
    }
    
    func dismiss() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0.0
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
    
    func setItems(_ items: [Item], animated: Bool) {
        self.items = items.filter { !self.removedIds.contains($0.id) }
        self.rebuildCards()
        self.setNeedsLayout()
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.layoutIfNeeded()
            }
        }
    }
    
    private func rebuildCards() {
        for card in self.cardViews where !self.items.contains(where: { $0.id == card.id }) {
            card.removeFromSuperview()
        }
        var updated: [CardView] = []
        for item in self.items {
            let card: CardView
            if let existing = self.cardViews.first(where: { $0.id == item.id }) {
                card = existing
            } else {
                card = CardView(id: item.id)
                card.backgroundColor = self.theme.list.itemBlocksBackgroundColor
                card.layer.cornerRadius = PinnedCardMetrics.cornerRadius
                card.icon.image = self.icon
                card.addSubview(card.icon)
                card.label.font = Font.regular(PinnedCardMetrics.fontSize)
                card.label.textColor = PinnedCardMetrics.textColor
                card.label.lineBreakMode = .byTruncatingTail
                card.addSubview(card.label)
                card.button.titleLabel?.font = Font.regular(PinnedCardMetrics.fontSize)
                card.button.layer.cornerRadius = 6.0
                card.button.addTarget(self, action: #selector(self.buttonPressed(_:)), for: .touchUpInside)
                card.addSubview(card.button)
                card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.cardTapped(_:))))
                self.scrollView.addSubview(card)
            }
            card.label.text = item.text
            self.updateButton(card)
            updated.append(card)
        }
        self.cardViews = updated
    }
    
    private func updateButton(_ card: CardView) {
        let confirming = self.confirmingId == card.id
        card.button.setTitle(confirming ? self.unpinTitle : self.removeTitle, for: .normal)
        // IMG_2489: the armed confirm is a medium-weight title on a grey box.
        card.button.titleLabel?.font = confirming ? Font.medium(PinnedCardMetrics.fontSize) : Font.regular(PinnedCardMetrics.fontSize)
        card.button.setTitleColor(confirming ? PinnedCardMetrics.textColor : PinnedCardMetrics.removeColor, for: .normal)
        card.button.backgroundColor = confirming ? UIColor(rgb: 0xEDEDED) : .clear
    }
    
    @objc private func cardTapped(_ recognizer: UITapGestureRecognizer) {
        guard let card = recognizer.view as? CardView else {
            return
        }
        if self.confirmingId != nil {
            let previous = self.cardViews.first(where: { $0.id == self.confirmingId })
            self.confirmingId = nil
            if let previous {
                self.updateButton(previous)
                self.setNeedsLayout()
            }
            return
        }
        self.onSelect?(card.id)
    }
    
    @objc private func buttonPressed(_ sender: UIButton) {
        guard let card = sender.superview as? CardView else {
            return
        }
        if self.confirmingId == card.id {
            self.confirmingId = nil
            self.removedIds.insert(card.id)
            self.items.removeAll(where: { $0.id == card.id })
            self.onUnpin?(card.id)
            self.rebuildCards()
            if self.items.isEmpty {
                self.onDismiss?()
                return
            }
        } else {
            let previous = self.cardViews.first(where: { $0.id == self.confirmingId })
            self.confirmingId = card.id
            if let previous {
                self.updateButton(previous)
            }
            self.updateButton(card)
        }
        self.setNeedsLayout()
        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        self.dimView.frame = CGRect(x: 0.0, y: self.barBottom, width: width, height: max(0.0, self.bounds.height - self.barBottom))
        var y: CGFloat = 0.0
        for card in self.cardViews {
            card.frame = CGRect(x: 8.0, y: y, width: width - 16.0, height: PinnedCardMetrics.height)
            card.icon.frame = PinnedCardMetrics.iconFrame
            let confirming = self.confirmingId == card.id
            let title = (confirming ? self.unpinTitle : self.removeTitle) as NSString
            // Sized to its title like the collapsed card's Remove; UIButton's own fitting size put the title 1pt left
            // of IMG_2488, where Remove sits one pixel below the card's centre. The armed box is IMG_2489's 80x29pt,
            // 16pt from the card's edge.
            let font = confirming ? Font.medium(PinnedCardMetrics.fontSize) : Font.regular(PinnedCardMetrics.fontSize)
            let textWidth = ceil(title.size(withAttributes: [.font: font]).width)
            let buttonHeight: CGFloat = confirming ? 29.0 : 24.0
            let buttonWidth = textWidth + (confirming ? 24.0 : 0.0)
            let buttonRight: CGFloat = confirming ? 16.0 : PinnedCardMetrics.trailingInset
            let buttonY = floor((PinnedCardMetrics.height - buttonHeight) / 2.0) + (confirming ? 0.0 : UIScreenPixel)
            card.button.frame = CGRect(x: card.bounds.width - buttonRight - buttonWidth, y: buttonY, width: buttonWidth, height: buttonHeight)
            card.label.frame = CGRect(x: PinnedCardMetrics.textLeft, y: 0.0, width: max(0.0, card.button.frame.minX - 8.0 - PinnedCardMetrics.textLeft), height: PinnedCardMetrics.height)
            y += PinnedCardMetrics.height + 8.0
        }
        let contentHeight = max(0.0, y - 8.0)
        // IMG_2488: 16pt from the last card to the pill, a 16pt pill, 16pt to the panel's bottom edge.
        let cardsTop = self.panelTop - self.barBottom
        let maxVisible = max(PinnedCardMetrics.height, self.bounds.height * 0.62 - cardsTop - 48.0)
        let visibleHeight = min(contentHeight, maxVisible)
        self.scrollView.frame = CGRect(x: 0.0, y: cardsTop, width: width, height: visibleHeight)
        self.scrollView.contentSize = CGSize(width: width, height: contentHeight)
        let pillTop = cardsTop + visibleHeight + 16.0
        self.pillView.frame = CGRect(x: floor((width - 39.0) / 2.0), y: pillTop, width: 39.0, height: 16.0)
        let panelFrame = CGRect(x: 0.0, y: self.barBottom, width: width, height: pillTop + 16.0 + 16.0)
        self.panelView.frame = panelFrame
        self.panelBackground.frame = CGRect(origin: CGPoint(), size: panelFrame.size)
        self.panelBackground.update(size: panelFrame.size, transition: .immediate)
    }
}
