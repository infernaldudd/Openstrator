import XCTest
@testable import OpenstratorCore

final class LayerObjectWorkflowTests: XCTestCase {
    func testNestedReparentPreservesOrderAndParentLinks() throws {
        var tree = LayerTreeV6()
        let artboard = LayerNodeV6(name: "Artboard 1", kind: .artboard)
        let groupA = LayerNodeV6(name: "Group A", kind: .group)
        let groupB = LayerNodeV6(name: "Group B", kind: .group)
        let first = LayerNodeV6(name: "First", kind: .object, objectID: UUID())
        let second = LayerNodeV6(name: "Second", kind: .object, objectID: UUID())

        try tree.insert(artboard, parent: nil, index: 0)
        try tree.insert(groupA, parent: artboard.id, index: 0)
        try tree.insert(groupB, parent: artboard.id, index: 1)
        try tree.insert(first, parent: groupA.id, index: 0)
        try tree.insert(second, parent: groupA.id, index: 1)

        try tree.move(second.id, toParent: groupB.id, index: 0)

        XCTAssertEqual(tree.nodes[groupA.id]?.children, [first.id])
        XCTAssertEqual(tree.nodes[groupB.id]?.children, [second.id])
        XCTAssertEqual(tree.nodes[second.id]?.parentID, groupB.id)
        XCTAssertEqual(try tree.validate(), true)
    }

    func testMoveRejectsCycle() throws {
        var tree = LayerTreeV6()
        let groupA = LayerNodeV6(name: "A", kind: .group)
        let groupB = LayerNodeV6(name: "B", kind: .group)
        try tree.insert(groupA, parent: nil, index: 0)
        try tree.insert(groupB, parent: groupA.id, index: 0)

        XCTAssertThrowsError(try tree.move(groupA.id, toParent: groupB.id, index: 0)) { error in
            XCTAssertEqual(error as? LayerTreeErrorV6, .cycle)
        }
    }

    func testRemoveSubtreeRemovesEveryDescendant() throws {
        var tree = LayerTreeV6()
        let group = LayerNodeV6(name: "Group", kind: .group)
        let child = LayerNodeV6(name: "Child", kind: .object, objectID: UUID())
        let nested = LayerNodeV6(name: "Nested", kind: .group)
        let grandchild = LayerNodeV6(name: "Grandchild", kind: .object, objectID: UUID())
        try tree.insert(group, parent: nil, index: 0)
        try tree.insert(child, parent: group.id, index: 0)
        try tree.insert(nested, parent: group.id, index: 1)
        try tree.insert(grandchild, parent: nested.id, index: 0)

        let removed = try tree.removeSubtree(group.id)

        XCTAssertEqual(Set(removed.keys), Set([group.id, child.id, nested.id, grandchild.id]))
        XCTAssertTrue(tree.nodes.isEmpty)
        XCTAssertTrue(tree.roots.isEmpty)
    }

    func testLayerTreeAndResourcesRoundTrip() throws {
        let objectID = UUID()
        let layer = LayerNodeV6(
            name: "Artwork",
            kind: .object,
            objectID: objectID,
            isExpanded: false,
            accent: RGBAColorV6(r: 0.2, g: 0.4, b: 0.9)
        )
        var tree = LayerTreeV6()
        try tree.insert(layer, parent: nil, index: 0)

        let embedded = EmbeddedObjectResourceV6(
            name: "Embedded",
            originalBounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            payloadData: Data([1, 2, 3])
        )
        let symbol = SymbolDefinitionV6(
            name: "Badge",
            originalBounds: CGRect(x: 0, y: 0, width: 40, height: 40),
            payloadData: Data([4, 5, 6])
        )
        let style = GraphicStyleV6(name: "Blue", appearance: AppearanceStackV6())
        let link = LinkedAssetResourceV6(
            displayName: "photo.png",
            sourceURLString: "file:///tmp/photo.png",
            originalFilename: "photo.png",
            fallbackRasterAssetID: UUID()
        )
        let library = ResourceLibraryV6(
            embeddedObjects: [embedded],
            linkedAssets: [link],
            symbols: [symbol],
            graphicStyles: [style]
        )

        struct Envelope: Codable, Equatable {
            var tree: LayerTreeV6
            var library: ResourceLibraryV6
        }

        let original = Envelope(tree: tree, library: library)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Envelope.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testResourceLibraryRejectsDuplicateIDs() {
        let id = UUID()
        let first = GraphicStyleV6(id: id, name: "One", appearance: AppearanceStackV6())
        let second = GraphicStyleV6(id: id, name: "Two", appearance: AppearanceStackV6())
        let library = ResourceLibraryV6(graphicStyles: [first, second])
        XCTAssertFalse(library.hasUniqueResourceIDs)
    }
}
