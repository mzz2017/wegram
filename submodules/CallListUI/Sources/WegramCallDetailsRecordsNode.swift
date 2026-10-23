import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import PeerInfoUI
import ItemListUI

final class WegramCallDetailsRecordsNode: ASDisplayNode {
    var heightChanged: ((CGFloat) -> Void)?
    private var itemNode: ListViewItemNode?
    private var creating = false
    private var generation = 0
    private var latest: (PresentationData, [EngineMessage], CGFloat)?

    func update(presentationData: PresentationData, messages: [EngineMessage], width: CGFloat) {
        self.latest = (presentationData, messages, width)
        self.generation += 1
        self.applyLatest()
    }

    private func applyLatest() {
        guard let (data, messages, width) = self.latest else { return }
        let generation = self.generation
        let item = ItemListCallListItem(presentationData: ItemListPresentationData(data), dateTimeFormat: data.dateTimeFormat, messages: messages, sectionId: 0, style: .blocks, displayDecorations: false)
        let params = ListViewItemLayoutParams(width: width, leftInset: 0, rightInset: 0, availableHeight: 1000)
        if let node = self.itemNode {
            item.updateNode(async: { $0() }, node: { node }, params: params, neighbors: .none, animation: .None, completion: { [weak self] layout, apply in
                guard let self, generation == self.generation else { return }
                node.contentSize = layout.contentSize
                node.insets = layout.insets
                apply(ListViewItemApply())
                self.finish(node: node, width: width)
            })
        } else {
            guard !self.creating else { return }
            self.creating = true
            item.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, neighbors: .none, completion: { [weak self] node, apply in
                guard let self else { return }
                self.creating = false
                self.itemNode = node
                node.isUserInteractionEnabled = false
                self.addSubnode(node)
                apply().1(ListViewItemApply())
                if generation == self.generation {
                    self.finish(node: node, width: width)
                } else {
                    self.applyLatest()
                }
            })
        }
    }

    private func finish(node: ListViewItemNode, width: CGFloat) {
        node.frame = CGRect(x: 0, y: 8, width: width, height: node.contentSize.height)
        let height = node.contentSize.height + 16
        self.frame = CGRect(x: 0, y: 0, width: width, height: height)
        self.heightChanged?(height)
    }
}
