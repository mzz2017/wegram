import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SwiftSignalKit

public enum WegramMessageMenuAction: String, CaseIterable {
    case copy, forward, edit, delete, select, reply, transcribe, playbackProgress

    public var identifier: AnyHashable { return "wegram.message.\(self.rawValue)" }

    fileprivate var symbol: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .forward: return "arrowshape.turn.up.right"
        case .edit: return "square.and.pencil"
        case .delete: return "trash"
        case .select: return "checkmark.circle"
        case .reply: return "quote.bubble"
        case .transcribe: return "text.bubble"
        case .playbackProgress: return "waveform"
        }
    }
}

public final class WegramMessageMenu {
    private enum State { case grid, more, closed }
    public weak var controller: ContextControllerProtocol?
    private var state: State = .grid
    private let original: ContextController.Items
    private let originalSignal: Signal<ContextController.Items, NoError>
    private let presentationData: PresentationData
    private let primary: [(WegramMessageMenuContent.Item, ContextMenuActionItem)]
    private let save: (() -> Void)?

    public init?(items: ContextController.Items, itemsSignal: Signal<ContextController.Items, NoError>, presentationData: PresentationData, save: (() -> Void)?) {
        guard case let .list(list) = items.content else { return nil }
        var primary: [(WegramMessageMenuContent.Item, ContextMenuActionItem)] = []
        let chinese = presentationData.strings.baseLanguageCode.hasPrefix("zh")
        for kind in [WegramMessageMenuAction.copy, .transcribe, .playbackProgress, .forward, .edit, .delete, .select, .reply] {
            guard let item = list.compactMap({ entry -> ContextMenuActionItem? in
                if case let .action(item) = entry, item.id == kind.identifier { return item }
                return nil
            }).first, item.action != nil, item.longPressAction == nil, item.badge == nil,
               item.entities.isEmpty, item.iconSource == nil, item.animationName == nil, item.iconAnimation == nil else { continue }
            let title: String
            if chinese && kind == .select { title = "多选" }
            else if chinese && kind == .reply { title = "引用" }
            else { title = item.text }
            primary.append((.init(title: title, symbol: kind.symbol), item))
        }
        guard !primary.isEmpty else { return nil }
        self.primary = primary
        self.original = items
        self.originalSignal = itemsSignal
        self.presentationData = presentationData
        self.save = primary.contains(where: { $0.1.id == WegramMessageMenuAction.forward.identifier }) ? save : nil
    }

    public var items: ContextController.Items {
        let chinese = self.presentationData.strings.baseLanguageCode.hasPrefix("zh")
        var descriptors = self.primary.map { $0.0 }
        let saveIndex: Int?
        if self.save != nil {
            let index = (self.primary.firstIndex { $0.1.id == WegramMessageMenuAction.forward.identifier } ?? 0) + 1
            descriptors.insert(.init(title: chinese ? "收藏" : "Save", symbol: "star"), at: index)
            saveIndex = index
        } else { saveIndex = nil }
        let moreIndex = descriptors.count
        descriptors.append(.init(title: chinese ? "更多" : "More", symbol: "ellipsis"))
        let content = WegramMessageMenuContent(items: descriptors, isActive: { [self] in self.state == .grid }, action: { [self] index in
            guard self.state == .grid, let controller = self.controller else { return }
            if index == moreIndex {
                self.state = .more
                // setItems updates this level as emoji metadata arrives; pushItems would push a new level per emission.
                controller.setItems(self.originalSignal |> map { [self] items in
                    var result = items
                    if case let .list(list) = result.content {
                        let back = ContextMenuActionItem(text: self.presentationData.strings.Common_Back, icon: { _ in UIImage(systemName: "chevron.left") }, action: { [self] _, _ in
                            guard self.state == .more, let controller = self.controller else { return }
                            self.state = .grid
                            controller.setItems(.single(self.items), minHeight: nil, animated: true)
                        })
                        result.content = .list([.action(back), .separator] + list)
                    }
                    return result
                }, minHeight: nil, animated: true)
            } else if index == saveIndex {
                self.state = .closed
                controller.dismiss(result: .default, completion: self.save)
            } else {
                let primaryIndex = index - ((saveIndex.map { index > $0 } ?? false) ? 1 : 0)
                guard self.primary.indices.contains(primaryIndex) else { return }
                self.state = .closed
                self.primary[primaryIndex].1.action?(ContextMenuActionItem.Action(controller: controller, dismissWithResult: { [weak controller] result in
                    controller?.dismiss(result: result, completion: nil)
                }, updateAction: { _, _ in }))
            }
        })
        var result = ContextController.Items(id: "wegram.message.grid", content: .custom(content), context: self.original.context, disablePositionLock: self.original.disablePositionLock, dismissed: self.original.dismissed)
        // The reaction strip stays above the grid, so picking a reaction is one long press and one tap rather than
        // a detour through More. Everything about it (top reactions, tags title, lock, emoji panel) is the original's.
        result.reactionItems = self.original.reactionItems
        result.selectedReactionItems = self.original.selectedReactionItems
        result.reactionsTitle = self.original.reactionsTitle
        result.reactionsLocked = self.original.reactionsLocked
        result.animationCache = self.original.animationCache
        result.alwaysAllowPremiumReactions = self.original.alwaysAllowPremiumReactions
        result.allPresetReactionsAreAvailable = self.original.allPresetReactionsAreAvailable
        result.getEmojiContent = self.original.getEmojiContent
        result.previewReaction = self.original.previewReaction
        if let tip = self.original.tip {
            switch tip {
            case .messageCopyProtection, .videoProcessing: result.tip = tip
            default: break
            }
        }
        return result
    }

    public func invalidate() { self.state = .closed }
}
