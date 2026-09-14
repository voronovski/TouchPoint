import Foundation

@main
struct OccasionOrderingRegression {
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        precondition(value(), message)
    }

    static func main() throws {
        let group = OccasionNode(id: "group", name: "Group", isGroup: true)
        let zulu = OccasionNode(id: "zulu", name: "Zulu", parentID: group.id)
        let alpha = OccasionNode(id: "alpha", name: "Alpha", parentID: group.id)
        let beta = OccasionNode(id: "beta", name: "Beta", parentID: group.id, sortOrder: 1)
        let root = OccasionNode(id: "root", name: "Root", sortOrder: 5)
        let store = AppStore(people: [], events: [], templates: [],
                             occasionNodes: [group, zulu, alpha, beta, root])

        expect(store.occasionChildren(of: group.id).map(\.id) == [alpha.id, zulu.id, beta.id],
               "Equal positions must use the displayed title order, not storage order")
        expect(store.moveOccasionNodes(parentID: group.id, fromOffsets: IndexSet(integer: 0), toOffset: 3),
               "Move the displayed first sibling to the end")
        expect(store.occasionChildren(of: group.id).map(\.id) == [zulu.id, beta.id, alpha.id],
               "The selected Alpha must move, not Zulu")
        expect(store.occasionNodes.first { $0.id == root.id } == root, "Other parents are unchanged")

        expect(store.moveOccasionNodes(parentID: group.id, fromOffsets: IndexSet([1, 2]), toOffset: 0),
               "Move multiple siblings upward")
        expect(store.occasionChildren(of: group.id).map(\.id) == [beta.id, alpha.id, zulu.id],
               "Moved siblings retain their relative order")

        let archive = try store.exportArchive()
        let restored = AppStore(people: [], events: [], templates: [])
        expect(restored.importArchive(archive), "Reordered archive imports")
        expect(restored.occasionChildren(of: group.id).map(\.id) == [beta.id, alpha.id, zulu.id],
               "Order survives persistence")

        let beforeInvalidMove = store.occasionNodes
        expect(!store.moveOccasionNodes(parentID: group.id, fromOffsets: IndexSet(integer: 3), toOffset: 0),
               "Reject a stale source index without crashing")
        expect(!store.moveOccasionNodes(parentID: group.id, fromOffsets: IndexSet(integer: 0), toOffset: 4),
               "Reject an invalid destination")
        expect(store.occasionNodes == beforeInvalidMove, "Invalid moves do not mutate the tree")

        let blocked = AppStore(people: [], events: [], templates: [],
                               occasionNodes: store.occasionNodes, allowsEphemeralPersistence: false)
        expect(!blocked.moveOccasionNodes(parentID: group.id, fromOffsets: IndexSet(integer: 0), toOffset: 3),
               "Report persistence failure")
        expect(blocked.occasionNodes == store.occasionNodes, "Failed saves restore the complete order")

        let duplicateB = OccasionNode(id: "b", name: "Same", parentID: group.id)
        let duplicateA = OccasionNode(id: "a", name: "Same", parentID: group.id)
        let tied = AppStore(people: [], events: [], templates: [],
                            occasionNodes: [group, duplicateB, duplicateA])
        expect(tied.occasionChildren(of: group.id).map(\.id) == ["a", "b"],
               "Equal positions and titles have a deterministic identifier tie-breaker")

        let promoted = AppStore(people: [], events: [], templates: [],
                                occasionNodes: [group, zulu, alpha, beta, root])
        expect(promoted.deleteOccasionNode(id: group.id), "Delete a group and promote its children")
        expect(promoted.moveOccasionNodes(parentID: nil, fromOffsets: IndexSet(integer: 0), toOffset: 4),
               "Reorder promoted nodes with duplicate positions")
        expect(promoted.occasionChildren(of: nil).map(\.id) == [zulu.id, beta.id, root.id, alpha.id],
               "Promotion still moves the displayed node")
        print("PASS: occasion ordering, duplicate positions, multiple moves, persistence, rollback and promotion")
    }
}
