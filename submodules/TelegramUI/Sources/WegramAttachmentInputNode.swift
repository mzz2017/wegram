import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import ChatInputNode
import TelegramCore
import TextFormat
import AccountContext

final class WegramAttachmentInputNode: ChatInputNode, UIScrollViewDelegate {
    struct Item {
        let title: String
        let symbol: String
        let action: () -> Void
        let artwork: WegramIcon?
        let slot: Int?

        init(title: String, symbol: String, artwork: WegramIcon? = nil, slot: Int? = nil, action: @escaping () -> Void) {
            self.title = title
            self.symbol = symbol
            self.artwork = artwork
            self.slot = slot
            self.action = action
        }
    }

    private let items: [Item]
    private let panelBackground = BlurredBackgroundView(color: nil)
    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    // WeChat divides the open panel from the input bar with a hairline (IMG_2413);
    // same colours as the input bar's own top line.
    private let topSeparator = UIView()
    private var buttons: [UIButton] = []
    private var tiles: [UIView] = []
    private var icons: [UIImageView] = []
    private var labels: [UILabel] = []
    private var lastPageWidth: CGFloat = 0
    private var lastRows = 2

    init(items: [Item]) {
        self.items = items
        super.init()
        self.panelBackground.isUserInteractionEnabled = false
        self.panelBackground.accessibilityElementsHidden = true
        self.view.addSubview(self.panelBackground)
        self.topSeparator.isUserInteractionEnabled = false
        self.view.addSubview(self.topSeparator)
        self.scrollView.isPagingEnabled = true
        self.scrollView.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.delegate = self
        self.view.addSubview(self.scrollView)
        self.pageControl.addAction(UIAction { [weak self] _ in self?.pageChanged() }, for: .valueChanged)
        self.pageControl.hidesForSinglePage = true
        self.view.addSubview(self.pageControl)
        for (index, item) in items.enumerated() {
            let button = UIButton(type: .custom)
            button.tag = index
            button.accessibilityLabel = item.title
            button.accessibilityIdentifier = "Wegram.Attachment.\(index)"
            button.addAction(UIAction { [weak self] _ in self?.items[index].action() }, for: .touchUpInside)
            self.scrollView.addSubview(button)
            let tile = UIView()
            tile.isUserInteractionEnabled = false
            tile.layer.cornerRadius = 14
            button.addSubview(tile)
            let icon = UIImageView(image: item.artwork?.image() ?? UIImage(systemName: item.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)))
            icon.contentMode = .scaleAspectFit
            tile.addSubview(icon)
            let label = UILabel()
            label.text = item.title
            label.font = Font.regular(12)
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
            label.isUserInteractionEnabled = false
            button.addSubview(label)
            self.buttons.append(button)
            self.tiles.append(tile)
            self.icons.append(icon)
            self.labels.append(label)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.lastPageWidth > 0 { self.pageControl.currentPage = Int(round(scrollView.contentOffset.x / self.lastPageWidth)) }
    }

    private func pageChanged() {
        guard self.lastPageWidth > 0 else { return }
        self.scrollView.setContentOffset(CGPoint(x: CGFloat(self.pageControl.currentPage) * self.lastPageWidth, y: 0), animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func updatePagingLayout(_ layout: WegramAttachmentLayout, dark: Bool = false, transition: ContainedViewLayoutTransition) {
        let firstVisibleSlot = self.pageControl.currentPage * self.lastRows * 4
        transition.updateFrame(view: self.scrollView, frame: layout.viewport)
        self.scrollView.contentSize = CGSize(width: layout.pageWidth * CGFloat(layout.pageCount), height: layout.viewport.height)
        self.pageControl.numberOfPages = layout.pageCount
        transition.updateFrame(view: self.pageControl, frame: layout.indicators)
        if self.lastPageWidth != layout.pageWidth || self.lastRows != layout.rows {
            self.lastPageWidth = layout.pageWidth
            self.lastRows = layout.rows
            let page = min(firstVisibleSlot / (layout.rows * 4), layout.pageCount - 1)
            self.pageControl.currentPage = page
            self.scrollView.contentOffset = CGPoint(x: CGFloat(page) * layout.pageWidth, y: 0)
        }
        self.backgroundColor = .clear
        let backgroundSize = CGSize(width: layout.width, height: layout.height)
        transition.updateFrame(view: self.panelBackground, frame: CGRect(origin: .zero, size: backgroundSize))
        self.panelBackground.updateColor(color: UIColor(rgb: dark ? 0x1e1e1e : 0xf7f7f7).withAlphaComponent(0.9), transition: transition)
        self.panelBackground.update(size: backgroundSize, transition: transition)
        self.topSeparator.backgroundColor = UIColor(rgb: dark ? 0x343434 : 0xd9d9d9)
        transition.updateFrame(view: self.topSeparator, frame: CGRect(x: 0, y: 0, width: layout.width, height: UIScreenPixel))
        self.pageControl.pageIndicatorTintColor = UIColor(rgb: dark ? 0x4a4a4a : 0xd1d1d1)
        self.pageControl.currentPageIndicatorTintColor = UIColor(rgb: dark ? 0x8e8e8e : 0x8c8c8c)
        for index in self.items.indices {
            let frame = layout.frames[index]
            transition.updateFrame(view: self.buttons[index], frame: frame)
            let size = min(64, frame.width, max(44, frame.height - 24))
            self.tiles[index].frame = CGRect(x: (frame.width - size) / 2, y: 0, width: size, height: size)
            self.tiles[index].backgroundColor = UIColor(rgb: dark ? 0x2c2c2c : 0xffffff)
            self.icons[index].frame = CGRect(x: (size - 30) / 2, y: (size - 30) / 2, width: 30, height: 30)
            self.icons[index].tintColor = UIColor(rgb: dark ? 0xd0d0d0 : 0x4c4c4c)
            self.labels[index].isHidden = frame.height < 70
            self.labels[index].textColor = UIColor(rgb: dark ? 0x999999 : 0x666666)
            self.labels[index].frame = CGRect(x: 0, y: size + 8, width: frame.width, height: 16)
        }
    }

    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, layoutMetrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool) -> (CGFloat, CGFloat) {
        let layout = WegramAttachmentLayout(width: width, left: leftInset, right: rightInset, bottom: bottomInset, maximumHeight: maximumHeight, count: self.items.count, slots: self.items.enumerated().map { $0.element.slot ?? $0.offset })
        self.updatePagingLayout(layout, dark: interfaceState.theme.overallDarkAppearance, transition: transition)
        return (layout.height, 0)
    }
}


func wegramSavedAttachmentForwardIds(current: [EngineMessage.Id]?, selected: EngineMessage.Id, accountPeerId: EnginePeer.Id) -> [EngineMessage.Id]? {
    guard selected.peerId == accountPeerId, selected.namespace == Namespaces.Message.Cloud else { return nil }
    var result = current ?? []
    if !result.contains(selected) { result.append(selected) }
    return result
}


func wegramSavedAttachmentHistoryIsReady(isLoading: Bool, isLoadingEarlier: Bool, holeEarlier: Bool, holeLater: Bool, hasEarlier: Bool, oldest: EngineMessage.Index?, requested: EngineMessage.Index?) -> Bool {
    guard !isLoading, !isLoadingEarlier else { return false }
    if let requested {
        if let oldest, oldest < requested { return true }
        return !holeEarlier && !hasEarlier
    }
    return !holeLater && (oldest != nil || !holeEarlier)
}

func wegramSavedAttachmentRequiredPermissions(media: [EngineMedia], hasComment: Bool) -> Set<TelegramChatBannedRightsFlags> {
    var result: Set<TelegramChatBannedRightsFlags> = hasComment || media.isEmpty ? [.banSendText] : []
    for media in media {
        switch media {
        case .image: result.insert(.banSendPhotos)
        case let .file(file):
            if file.isSticker { result.insert(.banSendStickers) }
            else if file.isAnimated { result.insert(.banSendGifs) }
            else if file.isInstantVideo { result.insert(.banSendInstantVideos) }
            else if file.isVoice { result.insert(.banSendVoice) }
            else if file.isMusic { result.insert(.banSendMusic) }
            else if file.isVideo { result.insert(.banSendVideos) }
            else { result.insert(.banSendFiles) }
        case .webpage: result.insert(.banSendText)
        case .poll: result.insert(.banSendPolls)
        case .game: result.insert(.banSendGames)
        default: break
        }
    }
    return result
}

func wegramSavedAttachmentCommentParts(_ text: String) -> [NSAttributedString] {
    return breakChatInputText(trimChatInputText(NSAttributedString(string: text))).filter { $0.length != 0 }
}

func wegramSavedAttachmentHasHiddenText(_ message: EngineMessage, preview: NSAttributedString? = nil) -> Bool {
    if message.textEntitiesAttribute?.entities.contains(where: { entity in
        if case .Spoiler = entity.type { return true }
        return false
    }) == true { return true }
    var hidden = false
    if let preview {
        preview.enumerateAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), in: NSRange(location: 0, length: preview.length)) { value, _, stop in
            if value != nil { hidden = true; stop.pointee = true }
        }
    }
    return hidden
}

func wegramSavedAttachmentDraftInput(current: ChatTextInputState, comment: String) -> ChatTextInputState {
    let text = trimChatInputText(NSAttributedString(string: comment)).string
    guard !text.isEmpty else { return current }
    if current.content.blocks.isEmpty { return ChatTextInputState(inputText: NSAttributedString(string: text)) }
    return current.replacingFlatRange(NSRange(location: current.content.length, length: 0), with: (current.isEmpty ? "" : "\n") + text)
}
