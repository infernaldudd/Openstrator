import XCTest
@testable import OpenstratorCore

final class DocumentV6Tests: XCTestCase {
    func testInsertChildMaintainsParentAndOrder() throws {
        var document = DocumentV6.empty(width: 1200, height: 800)
        let group = DocumentNode.group(name: "Group")
        let rect = DocumentNode.rectangle(name: "Rect", rect: CGRect(x: 20, y: 30, width: 100, height: 60))
        try document.insert(group, parent: document.activeArtboardID, index: 0)
        try document.insert(rect, parent: group.id, index: 0)
        XCTAssertEqual(document.parent(of: rect.id), group.id)
        XCTAssertEqual(document.node(id: group.id)?.children, [rect.id])
    }

    func testDocumentRoundTripsAsFormatSix() throws {
        var document = DocumentV6.empty(width: 640, height: 480)
        let text = DocumentNode.text(name: "Title", text: "Openstrator", frame: CGRect(x: 12, y: 18, width: 300, height: 80))
        try document.insert(text, parent: document.activeArtboardID, index: 0)
        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(DocumentV6.self, from: data)
        XCTAssertEqual(decoded.formatVersion, 6)
        XCTAssertEqual(decoded, document)
    }
}
