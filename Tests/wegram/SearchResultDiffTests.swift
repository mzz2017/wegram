import Foundation

private struct PeerResult: Comparable, Identifiable {
    let stableId: Int
    let name: String
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.stableId < rhs.stableId }
}

@main struct SearchResultDiffTests {
    static func main() {
        let peers = [PeerResult(stableId: 1, name: "Alice"), PeerResult(stableId: 2, name: "Alex")]
        let unchanged = mergeListsStableWithUpdates(leftList: peers, rightList: peers)
        precondition(unchanged.0.isEmpty && unchanged.1.isEmpty && unchanged.2.isEmpty)
        let refresh = mergeListsStableWithUpdates(leftList: peers, rightList: peers, allUpdated: true)
        precondition(refresh.0.isEmpty && refresh.1.isEmpty, "Query refresh must preserve result identity and order")
        precondition(refresh.2.map { $0.1.name } == ["Alice", "Alex"], "Same peers need refreshed visual query without changing their data")
        let changed = mergeListsStableWithUpdates(leftList: peers, rightList: [peers[1]], allUpdated: true)
        precondition(changed.0 == [0] && changed.1.isEmpty && changed.2.count == 1)
        precondition(changed.2[0].1.stableId == 2)
        print("Original stable diff refreshes equal results without reinsertion and preserves real removals")
    }
}
