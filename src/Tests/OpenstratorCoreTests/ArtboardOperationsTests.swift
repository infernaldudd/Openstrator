import XCTest
@testable import OpenstratorCore

final class ArtboardOperationsTests: XCTestCase {
    func testAddAndActivateSecondArtboard() throws {
        var d=DocumentV6.empty(width:800,height:600)
        let id=try d.addArtboard(rect:CGRect(x:900,y:0,width:400,height:300),name:"Artboard 2",makeActive:true)
        XCTAssertEqual(d.artboardIDs.count,2)
        XCTAssertEqual(d.activeArtboardID,id)
        XCTAssertEqual(d.node(id:id)?.name,"Artboard 2")
    }

    func testDuplicateArtboardOffsetsRectAndTopLevelArtwork() throws {
        var d=DocumentV6.empty(width:800,height:600)
        var r=DocumentNode.rectangle(name:"R",rect:CGRect(x:-50,y:-25,width:100,height:50))
        r.transform = .translation(x:200,y:150)
        try d.insert(r,parent:d.activeArtboardID,index:0)
        let cloneID=try d.duplicateArtboard(id:d.activeArtboardID,offset:CGSize(width:900,height:20),makeActive:true)
        guard let clone=d.node(id:cloneID), case let .artboard(data)=clone.payload else { return XCTFail("missing clone") }
        XCTAssertEqual(data.rect.minX,900,accuracy:0.001)
        XCTAssertEqual(data.rect.minY,20,accuracy:0.001)
        let childID=try XCTUnwrap(clone.children.first)
        XCTAssertNotEqual(childID,r.id)
        let child = try XCTUnwrap(d.node(id: childID))
        XCTAssertEqual(child.transform.translationX,1100,accuracy:0.001)
        XCTAssertEqual(child.transform.translationY,170,accuracy:0.001)
    }

    func testCannotRemoveFinalArtboard() {
        var d=DocumentV6.empty(width:800,height:600)
        XCTAssertThrowsError(try d.removeArtboard(id:d.activeArtboardID)) { error in
            XCTAssertEqual(error as? ArtboardError,.cannotRemoveFinalArtboard)
        }
    }

    func testRemovingActiveArtboardSelectsRemainingArtboard() throws {
        var d=DocumentV6.empty(width:800,height:600)
        let first=d.activeArtboardID
        let second=try d.addArtboard(rect:CGRect(x:900,y:0,width:400,height:300),makeActive:true)
        XCTAssertEqual(d.activeArtboardID,second)
        try d.removeArtboard(id:second)
        XCTAssertEqual(d.activeArtboardID,first)
    }
}


extension ArtboardOperationsTests {
    func testSetArtboardPortraitPreservesCenterAndArtworkAndIsIdempotent() throws {
        var d = DocumentV6.empty(width: 900, height: 600)
        let id = d.activeArtboardID
        var artwork = DocumentNode.rectangle(name: "Artwork", rect: CGRect(x: -20, y: -10, width: 40, height: 20))
        artwork.transform = .translation(x: 234, y: 321)
        try d.insert(artwork, parent: id, index: 0)

        guard let beforeNode = d.node(id: id), case let .artboard(before) = beforeNode.payload else { return XCTFail("missing artboard") }
        let artworkBefore = try XCTUnwrap(d.node(id: artwork.id))

        try d.setArtboardOrientation(.portrait, id: id)

        guard let afterNode = d.node(id: id), case let .artboard(after) = afterNode.payload else { return XCTFail("missing artboard") }
        XCTAssertGreaterThanOrEqual(after.rect.height, after.rect.width)
        XCTAssertEqual(after.rect.midX, before.rect.midX, accuracy: 0.001)
        XCTAssertEqual(after.rect.midY, before.rect.midY, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(d.node(id: artwork.id)), artworkBefore)

        let once = after.rect
        try d.setArtboardOrientation(.portrait, id: id)
        guard let twiceNode = d.node(id: id), case let .artboard(twice) = twiceNode.payload else { return XCTFail("missing artboard") }
        XCTAssertEqual(twice.rect, once)
        XCTAssertEqual(try XCTUnwrap(d.node(id: artwork.id)), artworkBefore)
    }

    func testSetArtboardLandscapePreservesCenterAndArtwork() throws {
        var d = DocumentV6.empty(width: 500, height: 800)
        let id = d.activeArtboardID
        var artwork = DocumentNode.ellipse(name: "Artwork", rect: CGRect(x: 0, y: 0, width: 100, height: 60))
        artwork.transform = .translation(x: 111, y: 222)
        try d.insert(artwork, parent: id, index: 0)

        guard let beforeNode = d.node(id: id), case let .artboard(before) = beforeNode.payload else { return XCTFail("missing artboard") }
        let artworkBefore = try XCTUnwrap(d.node(id: artwork.id))

        try d.setArtboardOrientation(.landscape, id: id)

        guard let afterNode = d.node(id: id), case let .artboard(after) = afterNode.payload else { return XCTFail("missing artboard") }
        XCTAssertGreaterThanOrEqual(after.rect.width, after.rect.height)
        XCTAssertEqual(after.rect.midX, before.rect.midX, accuracy: 0.001)
        XCTAssertEqual(after.rect.midY, before.rect.midY, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(d.node(id: artwork.id)), artworkBefore)
    }
}
