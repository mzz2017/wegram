import Foundation
import UIKit
import CoreImage
import Display
import TelegramPresentationData

// WeChat 8's voice-call screen, laid over `PrivateCallScreen` while no video is on. Positions are
// measured on a 402x874 outgoing-call screenshot;
// vertical ones are kept relative to the top or bottom safe-area edge they hang from.
final class WegramVoiceCallView: UIView {
    struct Content: Equatable {
        enum Phase: Equatable {
            case waiting(isOutgoing: Bool)
            case connecting
            case active(startTime: Double)
            case terminated(duration: Double)
        }

        var strings: PresentationStrings
        var phase: Phase
        var name: String
        var avatarImage: UIImage?
        var isMicrophoneMuted: Bool
        var isSpeakerOn: Bool
        var canSwitchAudioOutput: Bool
        var canEnableVideo: Bool
        var canAddParticipant: Bool
        var canShowEncryptionKey: Bool
        var isEncryptionKeyShown: Bool

        static func ==(lhs: Content, rhs: Content) -> Bool {
            return lhs.strings === rhs.strings && lhs.phase == rhs.phase && lhs.name == rhs.name && lhs.avatarImage === rhs.avatarImage && lhs.isMicrophoneMuted == rhs.isMicrophoneMuted && lhs.isSpeakerOn == rhs.isSpeakerOn && lhs.canSwitchAudioOutput == rhs.canSwitchAudioOutput && lhs.canEnableVideo == rhs.canEnableVideo && lhs.canAddParticipant == rhs.canAddParticipant && lhs.canShowEncryptionKey == rhs.canShowEncryptionKey && lhs.isEncryptionKeyShown == rhs.isEncryptionKeyShown
        }
    }

    private final class RoundButton: HighlightTrackingButton {
        let circleView = UIImageView()
        let glyphView = UIImageView()
        let captionLabel = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.circleView.isUserInteractionEnabled = false
            self.glyphView.isUserInteractionEnabled = false
            self.captionLabel.isUserInteractionEnabled = false
            self.addSubview(self.circleView)
            self.addSubview(self.glyphView)
            self.addSubview(self.captionLabel)
            self.captionLabel.font = UIFont.systemFont(ofSize: 14.0)
            self.captionLabel.textColor = .white
            self.captionLabel.textAlignment = .center
            self.highligthedChanged = { [weak self] highlighted in
                self?.circleView.alpha = highlighted ? 0.7 : 1.0
                self?.glyphView.alpha = highlighted ? 0.7 : 1.0
            }
        }

        required init?(coder: NSCoder) {
            fatalError()
        }
    }

    static let buttonDiameter: CGFloat = 72.0
    private static let red = UIColor(rgb: 0xfa5151)

    private let backgroundImageView = UIImageView()
    private let dimLayer = CAGradientLayer()
    private let minimizeButton = HighlightableButton()
    private let addButton = UIButton(type: .custom)
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let durationLabel = UILabel()
    private let microphoneButton = RoundButton()
    private let endButton = RoundButton()
    private let speakerButton = RoundButton()

    private var content: Content?
    private var blurredAvatarSource: UIImage?
    private var tickTimer: Foundation.Timer?
    private var dotCount = 2

    var minimizeAction: (() -> Void)?
    var microphoneAction: (() -> Void)?
    var endAction: (() -> Void)?
    var speakerAction: (() -> Void)?
    var videoAction: (() -> Void)?
    var addParticipantAction: (() -> Void)?
    var encryptionKeyAction: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor(rgb: 0x2f2f2e)
        self.backgroundImageView.contentMode = .scaleAspectFill
        self.backgroundImageView.clipsToBounds = true
        self.addSubview(self.backgroundImageView)
        // Measured: the blurred avatar shows at ~38% of its brightness at the top and ~28% at the bottom.
        self.dimLayer.colors = [UIColor(white: 0.0, alpha: 0.62).cgColor, UIColor(white: 0.0, alpha: 0.72).cgColor]
        self.layer.addSublayer(self.dimLayer)

        self.minimizeButton.setImage(generateImage(CGSize(width: 28.0, height: 28.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width * 0.5, y: size.height * 0.5)
            drawWegramCallMinimize(context, color: UIColor.white.cgColor)
        }), for: .normal)
        self.minimizeButton.addTarget(self, action: #selector(self.minimizePressed), for: .touchUpInside)
        self.addSubview(self.minimizeButton)

        self.addButton.showsMenuAsPrimaryAction = true
        self.addSubview(self.addButton)

        self.avatarView.contentMode = .scaleAspectFill
        self.avatarView.clipsToBounds = true
        self.avatarView.layer.cornerRadius = 8.0
        self.addSubview(self.avatarView)

        self.nameLabel.font = UIFont.systemFont(ofSize: 21.0)
        self.nameLabel.textColor = .white
        self.nameLabel.textAlignment = .center
        self.nameLabel.lineBreakMode = .byTruncatingTail
        self.addSubview(self.nameLabel)

        self.statusLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 17.0, weight: .regular)
        self.statusLabel.textAlignment = .center
        self.addSubview(self.statusLabel)

        // Connected, the duration moves to the top bar (IMG_2458): 17pt regular white
        // with proportional digits, "02:50:44" measuring 69pt wide.
        self.durationLabel.font = UIFont.systemFont(ofSize: 17.0)
        self.durationLabel.textColor = .white
        self.durationLabel.textAlignment = .center
        self.addSubview(self.durationLabel)

        for button in [self.microphoneButton, self.endButton, self.speakerButton] {
            self.addSubview(button)
        }
        self.microphoneButton.addTarget(self, action: #selector(self.microphonePressed), for: .touchUpInside)
        self.endButton.addTarget(self, action: #selector(self.endPressed), for: .touchUpInside)
        self.speakerButton.addTarget(self, action: #selector(self.speakerPressed), for: .touchUpInside)
        self.endButton.circleView.image = generateFilledCircleImage(diameter: WegramVoiceCallView.buttonDiameter, color: WegramVoiceCallView.red)
        self.endButton.glyphView.image = WegramVoiceCallView.glyphImage { context in
            drawWegramCallHangUp(context, color: UIColor.white.cgColor)
        }
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        self.tickTimer?.invalidate()
    }

    private static func glyphImage(_ draw: (CGContext) -> Void) -> UIImage? {
        return generateImage(CGSize(width: 48.0, height: 48.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width * 0.5, y: size.height * 0.5)
            draw(context)
        })
    }

    @objc private func minimizePressed() {
        self.minimizeAction?()
    }

    @objc private func microphonePressed() {
        self.microphoneAction?()
    }

    @objc private func endPressed() {
        self.endAction?()
    }

    @objc private func speakerPressed() {
        self.speakerAction?()
    }

    private func text(_ zh: String, _ en: String) -> String {
        guard let strings = self.content?.strings else {
            return en
        }
        return strings.primaryComponent.languageCode.hasPrefix("zh") ? zh : en
    }

    private static func durationString(_ duration: Double) -> String {
        let duration = max(0, Int(duration))
        if duration >= 3600 {
            return String(format: "%02d:%02d:%02d", duration / 3600, duration / 60 % 60, duration % 60)
        }
        return String(format: "%02d:%02d", duration / 60, duration % 60)
    }

    private func statusText() -> NSAttributedString {
        guard let content = self.content else {
            return NSAttributedString()
        }
        let font = self.statusLabel.font!
        let color = UIColor(white: 1.0, alpha: 0.55)
        func waiting(_ text: String) -> NSAttributedString {
            // WeChat centres the full "..." and reveals the dots one by one, so the text never shifts.
            let result = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
            for index in 0 ..< 3 {
                result.append(NSAttributedString(string: ".", attributes: [.font: font, .foregroundColor: index < self.dotCount ? color : UIColor.clear]))
            }
            return result
        }
        switch content.phase {
        case let .waiting(isOutgoing):
            if isOutgoing {
                return waiting(self.text("等待对方接受邀请", "Waiting for acceptance"))
            } else {
                return NSAttributedString(string: self.text("邀请你语音通话", "Invites you to a voice call"), attributes: [.font: font, .foregroundColor: color])
            }
        case .connecting:
            return waiting(self.text("连接中", "Connecting"))
        case let .active(startTime):
            return NSAttributedString(string: WegramVoiceCallView.durationString(Date().timeIntervalSince1970 - startTime), attributes: [.font: font, .foregroundColor: color])
        case let .terminated(duration):
            var text = self.text("通话结束", "Call Ended")
            if duration >= 1.0 {
                text += " " + WegramVoiceCallView.durationString(duration)
            }
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        }
    }

    private func durationText() -> String? {
        if case let .active(startTime) = self.content?.phase {
            return WegramVoiceCallView.durationString(Date().timeIntervalSince1970 - startTime)
        }
        return nil
    }

    private func updateTickTimer() {
        let needsTimer: Bool
        switch self.content?.phase {
        case .waiting(isOutgoing: true), .connecting, .active:
            needsTimer = true
        default:
            needsTimer = false
        }
        if needsTimer {
            if self.tickTimer == nil {
                self.tickTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.dotCount = self.dotCount % 3 + 1
                    self.statusLabel.attributedText = self.statusText()
                    self.durationLabel.text = self.durationText()
                })
            }
        } else {
            self.tickTimer?.invalidate()
            self.tickTimer = nil
        }
    }

    private func updateAddMenu(content: Content) {
        var actions: [UIAction] = []
        if content.canEnableVideo {
            actions.append(UIAction(title: self.text("开启摄像头", "Turn On Camera"), image: UIImage(systemName: "video"), handler: { [weak self] _ in
                self?.videoAction?()
            }))
        }
        if content.canAddParticipant {
            actions.append(UIAction(title: self.text("添加成员", "Add Participants"), image: UIImage(systemName: "person.badge.plus"), handler: { [weak self] _ in
                self?.addParticipantAction?()
            }))
        }
        // Telegram's key emoji, which WeChat has no place for: it opens the same expanded key upstream shows.
        if content.canShowEncryptionKey {
            actions.append(UIAction(title: self.text("加密密钥", "Encryption Key"), image: UIImage(systemName: "lock"), handler: { [weak self] _ in
                self?.encryptionKeyAction?()
            }))
        }
        let isEnabled = !actions.isEmpty
        self.addButton.menu = isEnabled ? UIMenu(children: actions) : nil
        self.addButton.isEnabled = isEnabled
        self.addButton.setImage(generateImage(CGSize(width: 28.0, height: 28.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width * 0.5, y: size.height * 0.5)
            // Dimmed while WeChat's invite is unavailable (outgoing call): white at 30%.
            drawWegramCallPlus(context, color: UIColor(white: 1.0, alpha: isEnabled ? 1.0 : 0.3).cgColor)
        }), for: .normal)
        self.addButton.accessibilityLabel = self.text("更多", "More")
    }

    private func updateBackground(avatarImage: UIImage?) {
        guard self.blurredAvatarSource !== avatarImage else {
            return
        }
        self.blurredAvatarSource = avatarImage
        guard let avatarImage, let cgImage = avatarImage.cgImage else {
            self.backgroundImageView.image = nil
            return
        }
        // Blurring a 48pt-wide thumbnail keeps the cost negligible; the result is stretched over the screen.
        let input = CIImage(cgImage: cgImage)
        let scale = 48.0 / max(1.0, input.extent.width)
        let small = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let filter = CIFilter(name: "CIGaussianBlur") else {
            return
        }
        filter.setValue(small.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(6.0, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: small.extent), let blurred = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(output, from: small.extent) else {
            return
        }
        self.backgroundImageView.image = UIImage(cgImage: blurred)
    }

    func update(size: CGSize, insets: UIEdgeInsets, content: Content) {
        let previousContent = self.content
        self.content = content

        if previousContent?.avatarImage !== content.avatarImage {
            self.avatarView.image = content.avatarImage
            self.updateBackground(avatarImage: content.avatarImage)
        }
        if previousContent?.phase != content.phase {
            self.dotCount = 2
        }
        self.updateTickTimer()
        if previousContent?.canEnableVideo != content.canEnableVideo || previousContent?.canAddParticipant != content.canAddParticipant || previousContent?.canShowEncryptionKey != content.canShowEncryptionKey || previousContent?.strings !== content.strings {
            self.updateAddMenu(content: content)
        }

        self.backgroundImageView.frame = CGRect(origin: CGPoint(), size: size)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.dimLayer.frame = CGRect(origin: CGPoint(), size: size)
        CATransaction.commit()

        // Top bar: the minimize glyph is centred 30pt below the safe area, the plus 26pt below it (insets.top
        // is 54 on the 402x874 reference device).
        self.minimizeButton.frame = CGRect(x: 40.0 - 22.0, y: insets.top + 30.1 - 22.0, width: 44.0, height: 44.0)
        self.minimizeButton.accessibilityLabel = self.text("最小化", "Minimize")
        self.addButton.frame = CGRect(x: size.width - 28.2 - 22.0, y: insets.top + 26.2 - 22.0, width: 44.0, height: 44.0)

        let avatarSize: CGFloat = 96.0
        let avatarFrame = CGRect(x: floor((size.width - avatarSize) * 0.5), y: insets.top + 196.4, width: avatarSize, height: avatarSize)
        self.avatarView.frame = avatarFrame
        // The expanded encryption key card covers the avatar and the name.
        let identityAlpha: CGFloat = content.isEncryptionKeyShown ? 0.0 : 1.0
        if self.avatarView.alpha != identityAlpha {
            UIView.animate(withDuration: 0.2, animations: {
                self.avatarView.alpha = identityAlpha
                self.nameLabel.alpha = identityAlpha
            })
        }

        var isTerminated = false
        var isActive = false
        switch content.phase {
        case .terminated:
            isTerminated = true
        case .active:
            isActive = true
        default:
            break
        }

        self.nameLabel.text = content.name
        let nameHeight = ceil(self.nameLabel.font.lineHeight)
        // PingFang's CJK ink starts ~0.27em below the line box: ink top at avatar bottom + 21pt, and 15.3pt
        // once connected, when the status line under the name is gone (the two references' names have the
        // same ink top, so this is layout, not glyphs).
        let nameInkSpacing: CGFloat = isActive ? 15.3 : 21.0
        self.nameLabel.frame = CGRect(x: 24.0, y: avatarFrame.maxY + nameInkSpacing - 5.7, width: size.width - 48.0, height: nameHeight)
        self.nameLabel.accessibilityLabel = content.name

        self.statusLabel.attributedText = self.statusText()
        let statusHeight = ceil(self.statusLabel.font.lineHeight)
        // insets.bottom is 20 on the reference device (iOS 26 reports the home-indicator inset that way).
        let buttonCenterY = size.height - insets.bottom - 130.0
        // The status ink sits 195pt above the button centres (ink top 521pt on the reference).
        self.statusLabel.frame = CGRect(x: 16.0, y: buttonCenterY - 203.1 - 4.6, width: size.width - 32.0, height: statusHeight)
        self.statusLabel.isHidden = isActive

        self.durationLabel.text = self.durationText()
        self.durationLabel.isHidden = !isActive
        let durationFont = self.durationLabel.font!
        // Digit ink centred 30.8pt below the safe area, on the minimize button's row.
        self.durationLabel.frame = CGRect(x: 80.0, y: insets.top + 30.8 - (durationFont.ascender - durationFont.capHeight * 0.5), width: size.width - 160.0, height: ceil(durationFont.lineHeight))

        let spacing: CGFloat = 118.5
        let buttons: [(RoundButton, CGFloat)] = [(self.microphoneButton, -spacing), (self.endButton, 0.0), (self.speakerButton, spacing)]
        for (button, offset) in buttons {
            let width: CGFloat = 110.0
            button.frame = CGRect(x: floor(size.width * 0.5 + offset - width * 0.5), y: buttonCenterY - WegramVoiceCallView.buttonDiameter * 0.5, width: width, height: WegramVoiceCallView.buttonDiameter + 40.0)
            button.circleView.frame = CGRect(x: (width - WegramVoiceCallView.buttonDiameter) * 0.5, y: 0.0, width: WegramVoiceCallView.buttonDiameter, height: WegramVoiceCallView.buttonDiameter)
            button.glyphView.frame = CGRect(x: (width - 48.0) * 0.5, y: (WegramVoiceCallView.buttonDiameter - 48.0) * 0.5, width: 48.0, height: 48.0)
            let titleHeight = ceil(button.captionLabel.font.lineHeight)
            // Label ink top 13.5pt below the circle; PingFang 14 ink starts ~3.6pt into its line box.
            button.captionLabel.frame = CGRect(x: -10.0, y: WegramVoiceCallView.buttonDiameter + 13.5 - 3.6, width: width + 20.0, height: titleHeight)
            button.isEnabled = !isTerminated
            button.alpha = isTerminated ? 0.5 : 1.0
        }

        if previousContent?.isMicrophoneMuted != content.isMicrophoneMuted || previousContent == nil {
            let isOn = !content.isMicrophoneMuted
            self.microphoneButton.circleView.image = generateFilledCircleImage(diameter: WegramVoiceCallView.buttonDiameter, color: isOn ? .white : UIColor(white: 0.0, alpha: 0.5))
            self.microphoneButton.glyphView.image = WegramVoiceCallView.glyphImage { context in
                drawWegramCallMicrophone(context, color: (isOn ? UIColor.black : UIColor.white).cgColor, isMuted: !isOn)
            }
        }
        self.microphoneButton.captionLabel.text = content.isMicrophoneMuted ? self.text("麦克风已关", "Mic Off") : self.text("麦克风已开", "Mic On")
        self.microphoneButton.accessibilityLabel = self.microphoneButton.captionLabel.text

        self.endButton.captionLabel.text = isActive || isTerminated ? self.text("挂断", "Hang Up") : self.text("取消", "Cancel")
        self.endButton.accessibilityLabel = self.endButton.captionLabel.text

        if previousContent?.isSpeakerOn != content.isSpeakerOn || previousContent == nil {
            let isOn = content.isSpeakerOn
            self.speakerButton.circleView.image = generateFilledCircleImage(diameter: WegramVoiceCallView.buttonDiameter, color: isOn ? .white : UIColor(white: 0.0, alpha: 0.5))
            self.speakerButton.glyphView.image = WegramVoiceCallView.glyphImage { context in
                drawWegramCallSpeaker(context, color: (isOn ? UIColor.black : UIColor.white).cgColor, isOn: isOn)
            }
        }
        self.speakerButton.captionLabel.text = content.isSpeakerOn ? self.text("扬声器已开", "Speaker On") : self.text("扬声器已关", "Speaker Off")
        self.speakerButton.accessibilityLabel = self.speakerButton.captionLabel.text
        if !content.canSwitchAudioOutput {
            self.speakerButton.isEnabled = false
        }
    }
}
