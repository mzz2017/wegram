import UIKit
import Display

private final class WegramMomentActionButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        let icon = min(28, (self.titleLabel?.font.pointSize ?? 15) + 1)
        let width = max(1, self.bounds.width - 24 - icon - 8)
        let textWidth = min(width, ceil(self.titleLabel?.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).width ?? width))
        let x = (self.bounds.width - icon - 8 - textWidth) / 2
        self.imageView?.frame = CGRect(x: x, y: (self.bounds.height - icon) / 2, width: icon, height: icon)
        self.titleLabel?.frame = CGRect(x: x + icon + 8, y: 12, width: textWidth, height: self.bounds.height - 24)
    }
}

final class WegramMomentActionsOverlay: UIControl {
    let bar = UIView()
    let reaction: UIButton = WegramMomentActionButton(frame: .zero)
    let reply: UIButton = WegramMomentActionButton(frame: .zero)
    private let separator = UIView()
    private var anchor = CGRect.zero
    private var reactionAction: WegramStoryInteraction = .like
    var select: ((WegramStoryInteraction) -> Void)?
    var close: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.bar.backgroundColor = UIColor(white: 0.27, alpha: 1)
        self.bar.layer.cornerRadius = 5
        self.separator.isUserInteractionEnabled = false
        self.separator.backgroundColor = UIColor(white: 1, alpha: 0.18)
        self.addSubview(self.bar)
        self.bar.addSubview(self.reaction)
        self.bar.addSubview(self.reply)
        self.bar.addSubview(self.separator)
        for button in [self.reaction, self.reply] {
            button.setTitleColor(.white, for: .normal)
            button.tintColor = .white
            button.imageView?.contentMode = .scaleAspectFit
            button.titleLabel?.lineBreakMode = .byWordWrapping
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = .center
        }
        self.addAction(UIAction(handler: { [weak self] _ in self?.close?() }), for: .touchUpInside)
        self.reaction.addAction(UIAction(handler: { [weak self] _ in
            guard let self else { return }
            self.select?(self.reactionAction)
        }), for: .touchUpInside)
        self.reply.addAction(UIAction(handler: { [weak self] _ in
            guard let self, !self.reply.isHidden else { return }
            self.select?(.reply)
        }), for: .touchUpInside)
        self.reaction.setImage(UIImage(systemName: "heart"), for: .normal)
        self.reply.setImage(UIImage(systemName: "bubble.left"), for: .normal)
        self.reaction.accessibilityIdentifier = "Wegram.Moments.React"
        self.reply.accessibilityIdentifier = "Wegram.Moments.Reply"
        self.isAccessibilityElement = false
        self.accessibilityViewIsModal = true
        self.accessibilityElements = [self.reaction, self.reply]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func load(anchor: CGRect, reacted: Bool, canReply: Bool, chinese: Bool, font: CGFloat) {
        self.anchor = anchor
        self.reactionAction = reacted ? .unlike : .like
        self.reaction.setTitle(reacted ? (chinese ? "取消回应" : "Remove Reaction") : (chinese ? "赞" : "Like"), for: .normal)
        self.reply.setTitle(chinese ? "回复" : "Reply", for: .normal)
        self.reaction.titleLabel?.font = .systemFont(ofSize: font * 15 / 17)
        self.reply.titleLabel?.font = self.reaction.titleLabel?.font
        self.reply.isHidden = !canReply
        self.separator.isHidden = !canReply
        self.accessibilityElements = canReply ? [self.reaction, self.reply] : [self.reaction]
        self.setNeedsLayout()
    }
    override func accessibilityPerformEscape() -> Bool { self.close?(); return true }
    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = (self.reaction.titleLabel?.font.pointSize ?? 15) / 15
        let count: CGFloat = self.reply.isHidden ? 1 : 2
        let icon = min(28, (self.reaction.titleLabel?.font.pointSize ?? 15) + 1)
        let reactionWidth = self.reaction.titleLabel?.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width ?? 0
        let replyWidth = self.reply.isHidden ? 0 : self.reply.titleLabel?.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width ?? 0
        let idealButtonWidth = max(100 * scale, ceil(max(reactionWidth, replyWidth)) + 24 + icon + 8)
        let width = max(44, min(self.bounds.width - 32, count * idealButtonWidth))
        let buttonWidth = width / count
        let textWidth = max(1, buttonWidth - 24 - min(28, (self.reaction.titleLabel?.font.pointSize ?? 15) + 1) - 8)
        let reactionHeight = self.reaction.titleLabel?.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height ?? 0
        let replyHeight = self.reply.isHidden ? 0 : self.reply.titleLabel?.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height ?? 0
        let height = max(44, ceil(max(reactionHeight, replyHeight)) + 24)
        self.bar.frame = CGRect(x: max(16, min(self.bounds.width - width - 16, self.anchor.minX - width - 8)), y: max(self.safeAreaInsets.top + 8, min(self.bounds.height - self.safeAreaInsets.bottom - height - 8, self.anchor.midY - height / 2)), width: width, height: height)
        self.reaction.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: height)
        self.reply.frame = CGRect(x: buttonWidth, y: 0, width: buttonWidth, height: height)
        self.separator.frame = CGRect(x: buttonWidth, y: (height - 18) / 2, width: 1 / max(1, self.traitCollection.displayScale), height: 18)
    }
}
