import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown
import SolidRoundedButtonNode
import AuthorizationUtils

private func roundCorners(diameter: CGFloat) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}

final class AuthorizationSequenceSignUpControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let usesWegramAppearance: Bool
    private let formScrollNode = ASScrollNode()
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let addPhoto: () -> Void
    
    private let titleNode: ASTextNode
    private let currentOptionNode: ASTextNode
    private let termsNode: ImmediateTextNode
    
    private let firstNameField: TextFieldNode
    private let lastNameField: TextFieldNode
    private let firstSeparatorNode: ASDisplayNode
    private let lastSeparatorNode: ASDisplayNode
    private let currentPhotoNode: ASImageNode
    private let addPhotoButton: HighlightableButtonNode
    private let proceedNode: SolidRoundedButtonNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    private let appearanceTimestamp = CACurrentMediaTime()
    
    var currentName: (String, String) {
        return (self.firstNameField.textField.text ?? "", self.lastNameField.textField.text ?? "")
    }
    
    var currentPhoto: UIImage? = nil {
        didSet {
            if let currentPhoto = self.currentPhoto {
                self.currentPhotoNode.image = generateImage(CGSize(width: self.usesWegramAppearance ? 64 : 110, height: self.usesWegramAppearance ? 64 : 110), contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    if self.usesWegramAppearance {
                        context.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4).cgPath)
                        context.clip()
                    }
                    context.setBlendMode(.copy)
                    context.draw(currentPhoto.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    if !self.usesWegramAppearance {
                        context.setBlendMode(.destinationOut)
                        context.draw(roundCorners(diameter: size.width).cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    }
                })
            } else {
                self.currentPhotoNode.image = nil
            }
        }
    }
    
    var signUpWithName: ((String, String) -> Void)?
    var openTermsOfService: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.firstNameField.alpha = self.inProgress ? 0.6 : 1.0
            self.lastNameField.alpha = self.inProgress ? 0.6 : 1.0
            
            if self.inProgress != oldValue {
                if self.inProgress {
                    self.proceedNode.transitionToProgress()
                } else {
                    self.proceedNode.transitionFromProgress()
                }
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, usesWegramAppearance: Bool = false, addPhoto: @escaping () -> Void) {
        self.usesWegramAppearance = usesWegramAppearance
        self.theme = theme
        self.strings = strings
        self.addPhoto = addPhoto
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_InfoTitle, font: usesWegramAppearance ? Font.regular(22) : Font.semibold(28.0), textColor: theme.list.itemPrimaryTextColor)
        self.titleNode.accessibilityIdentifier = "Auth.SetName.Title"

        self.currentOptionNode = ASTextNode()
        self.currentOptionNode.isUserInteractionEnabled = false
        self.currentOptionNode.displaysAsynchronously = false
        self.currentOptionNode.attributedText = NSAttributedString(string: self.strings.Login_InfoHelp, font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        self.termsNode = ImmediateTextNode()
        self.termsNode.textAlignment = .center
        self.termsNode.maximumNumberOfLines = 0
        self.termsNode.displaysAsynchronously = false
        let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.itemSecondaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(13.0), textColor: usesWegramAppearance ? UIColor(rgb: theme.overallDarkAppearance ? 0x7d90a9 : 0x576b95) : theme.list.itemAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.termsNode.attributedText = parseMarkdownIntoAttributedString(strings.Login_TermsOfServiceLabel.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        self.firstSeparatorNode = ASDisplayNode()
        self.firstSeparatorNode.isLayerBacked = true
        self.firstSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.lastSeparatorNode = ASDisplayNode()
        self.lastSeparatorNode.isLayerBacked = true
        self.lastSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.firstNameField = TextFieldNode()
        self.firstNameField.textField.font = Font.regular(usesWegramAppearance ? 17 : 20)
        self.firstNameField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.firstNameField.textField.textAlignment = .natural
        self.firstNameField.textField.returnKeyType = .next
        self.firstNameField.textField.attributedPlaceholder = NSAttributedString(string: self.strings.UserInfo_FirstNamePlaceholder, font: self.firstNameField.textField.font, textColor: self.theme.list.itemPlaceholderTextColor)
        self.firstNameField.textField.autocapitalizationType = .words
        self.firstNameField.textField.autocorrectionType = .no
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.firstNameField.textField.textContentType = .givenName
        }
        self.firstNameField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.firstNameField.textField.tintColor = usesWegramAppearance ? UIColor(rgb: 0x07c160) : theme.list.itemAccentColor
        self.firstNameField.textField.accessibilityIdentifier = "Auth.SetName.FirstNameField"

        self.lastNameField = TextFieldNode()
        self.lastNameField.textField.font = Font.regular(usesWegramAppearance ? 17 : 20)
        self.lastNameField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.lastNameField.textField.textAlignment = .natural
        self.lastNameField.textField.returnKeyType = .done
        self.lastNameField.textField.attributedPlaceholder = NSAttributedString(string: strings.UserInfo_LastNamePlaceholder, font: self.lastNameField.textField.font, textColor: self.theme.list.itemPlaceholderTextColor)
        self.lastNameField.textField.autocapitalizationType = .words
        self.lastNameField.textField.autocorrectionType = .no
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.lastNameField.textField.textContentType = .familyName
        }
        self.lastNameField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.lastNameField.textField.tintColor = usesWegramAppearance ? UIColor(rgb: 0x07c160) : theme.list.itemAccentColor
        self.lastNameField.textField.accessibilityIdentifier = "Auth.SetName.LastNameField"

        self.currentPhotoNode = ASImageNode()
        self.currentPhotoNode.isUserInteractionEnabled = false
        self.currentPhotoNode.displaysAsynchronously = false
        self.currentPhotoNode.displayWithoutProcessing = true
        
        self.addPhotoButton = HighlightableButtonNode()
        self.addPhotoButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIconLarge"), color: self.theme.list.itemAccentColor), for: .normal)
        self.addPhotoButton.setBackgroundImage(generateFilledCircleImage(diameter: 110.0, color: self.theme.list.itemAccentColor.withAlphaComponent(0.1), strokeColor: nil, strokeWidth: nil, backgroundColor: nil), for: .normal)
                
        if usesWegramAppearance {
            self.addPhotoButton.setImage(generateTintedImage(image: UIImage(systemName: "person.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32, weight: .regular)), color: theme.list.itemSecondaryTextColor), for: .normal)
            self.addPhotoButton.setBackgroundImage(generateImage(CGSize(width: 64, height: 64), contextGenerator: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(theme.list.itemPrimaryTextColor.withAlphaComponent(0.05).cgColor)
                context.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4).cgPath)
                context.fillPath()
            }), for: .normal)
        }
        self.addPhotoButton.accessibilityIdentifier = "Auth.SetName.Photo"
        self.addPhotoButton.accessibilityLabel = self.strings.Settings_SetProfilePhoto
        self.addPhotoButton.accessibilityTraits = [.button]
        self.termsNode.accessibilityIdentifier = "Auth.SetName.Terms"

        self.addPhotoButton.addSubnode(self.currentPhotoNode)
        self.addPhotoButton.allowsGroupOpacity = true
        
        self.proceedNode = SolidRoundedButtonNode(title: self.strings.Login_Continue, theme: usesWegramAppearance ? SolidRoundedButtonTheme(backgroundColor: UIColor(rgb: 0x07c160), foregroundColor: .white) : SolidRoundedButtonTheme(theme: self.theme), glass: false, font: usesWegramAppearance ? .regular : .bold, height: usesWegramAppearance ? 44 : 50, cornerRadius: usesWegramAppearance ? 5 : 25)
        self.proceedNode.progressType = .embedded
        self.proceedNode.accessibilityIdentifier = "Auth.SetName.ContinueButton"
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.theme.list.plainBackgroundColor
        
        self.firstNameField.textField.delegate = self
        self.lastNameField.textField.delegate = self
        
        let formNode: ASDisplayNode
        if usesWegramAppearance {
            self.formScrollNode.accessibilityIdentifier = "Auth.SetName.Form"
            self.formScrollNode.clipsToBounds = true
            self.formScrollNode.view.contentInsetAdjustmentBehavior = .never
            self.formScrollNode.view.alwaysBounceVertical = false
            self.addSubnode(self.formScrollNode)
            formNode = self.formScrollNode
        } else {
            formNode = self
        }
        formNode.addSubnode(self.firstSeparatorNode)
        formNode.addSubnode(self.lastSeparatorNode)
        formNode.addSubnode(self.firstNameField)
        formNode.addSubnode(self.lastNameField)
        formNode.addSubnode(self.titleNode)
        formNode.addSubnode(self.currentOptionNode)
        formNode.addSubnode(self.termsNode)
        self.termsNode.isHidden = true
        formNode.addSubnode(self.addPhotoButton)
        self.addSubnode(self.proceedNode)
        
        self.addPhotoButton.addTarget(self, action: #selector(self.addPhotoPressed), forControlEvents: .touchUpInside)
        
        self.termsNode.linkHighlightColor = self.theme.list.itemAccentColor.withAlphaComponent(0.2)
        self.termsNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.termsNode.tapAttributeAction = { [weak self] attributes, _ in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                self?.openTermsOfService?()
            }
        }
        
        self.proceedNode.pressed = { [weak self] in
            if let strongSelf = self {
                let name = strongSelf.currentName
                strongSelf.signUpWithName?(name.0, name.1)
            }
        }
    }
    
    func updateData(firstName: String, lastName: String, hasTermsOfService: Bool) {
        self.termsNode.isHidden = !hasTermsOfService
        self.firstNameField.textField.attributedText = NSAttributedString(string: firstName, font: Font.regular(self.usesWegramAppearance ? 17 : 20), textColor: self.usesWegramAppearance ? self.theme.list.itemPrimaryTextColor : self.theme.list.itemPlaceholderTextColor)
        self.lastNameField.textField.attributedText = NSAttributedString(string: lastName, font: Font.regular(self.usesWegramAppearance ? 17 : 20), textColor: self.usesWegramAppearance ? self.theme.list.itemPrimaryTextColor : self.theme.list.itemPlaceholderTextColor)
        
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let previousInputHeight = self.layoutArguments?.0.inputHeight ?? 0.0
        let newInputHeight = layout.inputHeight ?? 0.0
        
        self.layoutArguments = (layout, navigationBarHeight)
        
        var layout = layout
        if CACurrentMediaTime() - self.appearanceTimestamp < 2.0, newInputHeight < previousInputHeight {
            layout = layout.withUpdatedInputHeight(previousInputHeight)
        }
        
        let maximumWidth: CGFloat = min(430.0, layout.size.width)
        
        var insets = layout.insets(options: [.statusBar])
        if let inputHeight = layout.inputHeight {
            insets.bottom = self.usesWegramAppearance ? max(inputHeight, insets.bottom) : max(inputHeight, layout.standardInputHeight)
        }
        
        if self.usesWegramAppearance {
            insets.top = navigationBarHeight
        }
        let additionalBottomInset: CGFloat = self.usesWegramAppearance ? 82 : (layout.size.width > 320.0 ? 90 : 10)
                
        self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_InfoTitle, font: self.usesWegramAppearance ? Font.regular(22) : Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth, height: CGFloat.greatestFiniteMagnitude))
        
        let fieldHeight: CGFloat = self.usesWegramAppearance ? 52 : 54
        
        let sideInset: CGFloat = self.usesWegramAppearance ? 30 : 24
        let innerInset: CGFloat = self.usesWegramAppearance ? 0 : 16
        
        let noticeSize = self.currentOptionNode.measure(CGSize(width: maximumWidth - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let termsSize = self.termsNode.updateLayout(CGSize(width: maximumWidth - 28.0, height: CGFloat.greatestFiniteMagnitude))
        
        let avatarSize: CGSize = CGSize(width: self.usesWegramAppearance ? 64 : 110, height: self.usesWegramAppearance ? 64 : 110)
        var items: [AuthorizationLayoutItem] = []
        items.append(AuthorizationLayoutItem(node: self.addPhotoButton, size: avatarSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 16.0, maxValue: 16.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        self.currentPhotoNode.frame = CGRect(origin: CGPoint(), size: avatarSize)
        
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 20.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.firstNameField, size: CGSize(width: (self.usesWegramAppearance ? maximumWidth : layout.size.width) - (sideInset + innerInset) * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 32.0, maxValue: 60.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.firstSeparatorNode, size: CGSize(width: (self.usesWegramAppearance ? maximumWidth : layout.size.width) - sideInset * 2.0, height: UIScreenPixel), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.lastNameField, size: CGSize(width: (self.usesWegramAppearance ? maximumWidth : layout.size.width) - (sideInset + innerInset) * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.lastSeparatorNode, size: CGSize(width: (self.usesWegramAppearance ? maximumWidth : layout.size.width) - sideInset * 2.0, height: UIScreenPixel), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.termsNode, size: termsSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 48.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        if self.usesWegramAppearance {
            let avatar = items.removeFirst()
            items.insert(avatar, at: 1)
            if self.termsNode.isHidden {
                items.removeLast()
            }
            items = items.enumerated().map { index, item in
                let gap: CGFloat = index == 0 ? 0 : (index == 1 || index == 2 || item.node === self.termsNode ? 18 : (item.node === self.firstNameField ? 24 : 0))
                return AuthorizationLayoutItem(node: item.node!, size: item.size, spacingBefore: AuthorizationLayoutItemSpacing(weight: gap, maxValue: gap), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0, maxValue: 0))
            }
        }

        if self.usesWegramAppearance || layout.size.width > 320.0 {
            self.proceedNode.isHidden = false
            
            let inset: CGFloat = self.usesWegramAppearance ? 30 : 24
            let proceedHeight = self.proceedNode.updateLayout(width: maximumWidth - inset * 2, transition: transition)
            let proceedSize = CGSize(width: maximumWidth - inset * 2, height: proceedHeight)
            transition.updateFrame(node: self.proceedNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - proceedSize.width) / 2.0), y: layout.size.height - insets.bottom - proceedSize.height - inset), size: proceedSize))
        } else {
            insets.top = navigationBarHeight
            self.proceedNode.isHidden = true
        }
        
        if self.usesWegramAppearance {
            let visibleHeight = max(0, layout.size.height - insets.top - insets.bottom - additionalBottomInset)
            let contentHeight = max(visibleHeight, items.reduce(CGFloat(0)) { $0 + $1.size.height + $1.spacingBefore.maxValue + $1.spacingAfter.maxValue })
            transition.updateFrame(node: self.formScrollNode, frame: CGRect(x: 0, y: insets.top, width: layout.size.width, height: visibleHeight))
            self.formScrollNode.view.contentSize = CGSize(width: layout.size.width, height: contentHeight)
            let _ = layoutAuthorizationItems(bounds: CGRect(x: 0, y: 0, width: layout.size.width, height: contentHeight), items: items, transition: transition, failIfDoesNotFit: false)
            if self.firstNameField.textField.isFirstResponder {
                self.formScrollNode.view.scrollRectToVisible(self.firstNameField.frame.insetBy(dx: 0, dy: -8), animated: false)
            } else if self.lastNameField.textField.isFirstResponder {
                self.formScrollNode.view.scrollRectToVisible(self.lastNameField.frame.insetBy(dx: 0, dy: -8), animated: false)
            }
        } else {
            let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - additionalBottomInset)), items: items, transition: transition, failIfDoesNotFit: false)
        }
    }
    
    func activateInput() {
        self.firstNameField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        if self.firstNameField.textField.text == nil || self.firstNameField.textField.text!.isEmpty {
            self.firstNameField.layer.addShakeAnimation()
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if self.usesWegramAppearance {
            let field = textField === self.firstNameField.textField ? self.firstNameField : self.lastNameField
            self.formScrollNode.view.scrollRectToVisible(field.frame.insetBy(dx: 0, dy: -8), animated: true)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === self.firstNameField.textField {
            self.lastNameField.textField.becomeFirstResponder()
        } else {
            let name = self.currentName
            self.signUpWithName?(name.0, name.1)
        }
        return false
    }
    
    @objc private func addPhotoPressed() {
        self.addPhoto()
    }
}
