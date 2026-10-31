import XCTest
@testable import OpenstratorCore

final class CommandHistoryTests: XCTestCase {
    func testMoveCommandsCoalesceIntoOneUndoStep() throws {
        var document = makeDocumentWithOneRect()
        let id = document.artworkChildren[0]
        var history = CommandHistory(limit: 36)
        try history.execute(.setTransform(id: id, from: .identity, to: .translation(x: 10, y: 0), coalescingKey: "drag:\(id.rawValue)"), on: &document)
        try history.coalesce(.setTransform(id: id, from: .translation(x: 10, y: 0), to: .translation(x: 25, y: 0), coalescingKey: "drag:\(id.rawValue)"), on: &document)
        XCTAssertEqual(document.node(id: id)?.transform.translationX, 25)
        try history.undo(on: &document)
        XCTAssertEqual(document.node(id: id)?.transform, .identity)
        XCTAssertFalse(history.canUndo)
    }

    func testInsertUndoRedo() throws {
        var document = DocumentV6.empty(width: 100, height: 100)
        let rect = DocumentNode.rectangle(name: "R", rect: CGRect(x: 0, y: 0, width: 10, height: 10))
        let subtree = NodeSubtree(rootID: rect.id, nodes: [rect.id: rect])
        var history = CommandHistory(limit: 5)
        try history.execute(.insert(subtree: subtree, parent: document.activeArtboardID, index: 0), on: &document)
        XCTAssertEqual(document.artworkChildren, [rect.id])
        try history.undo(on: &document)
        XCTAssertTrue(document.artworkChildren.isEmpty)
        try history.redo(on: &document)
        XCTAssertEqual(document.artworkChildren, [rect.id])
    }

    func testDeleteUndoRestoresOriginalIndexAndChildren() throws {
        var document = DocumentV6.empty(width: 100, height: 100)
        var group = DocumentNode.group(name: "G")
        let child = DocumentNode.rectangle(name: "C", rect: CGRect(x: 0, y: 0, width: 10, height: 10))
        group.children = [child.id]
        try document.insert(group, parent: document.activeArtboardID, index: 0)
        document.nodes[child.id] = child
        let subtree = NodeSubtree(rootID: group.id, nodes: [group.id: group, child.id: child])
        var history = CommandHistory(limit: 5)
        try history.execute(.remove(subtree: subtree, parent: document.activeArtboardID, index: 0), on: &document)
        XCTAssertNil(document.node(id: child.id))
        try history.undo(on: &document)
        XCTAssertEqual(document.artworkChildren, [group.id])
        XCTAssertEqual(document.node(id: group.id)?.children, [child.id])
        XCTAssertNotNil(document.node(id: child.id))
    }
}
