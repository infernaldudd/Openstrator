import XCTest
@testable import OpenstratorCore

final class M1AcceptanceTests: XCTestCase {
    func testCoordinateRoundTripAllRequiredZooms() {
        for zoom in [0.25,0.5,1.0,2.0,4.0] {
            let t=CanvasTransform(viewportSize: CGSize(width:1400,height:900), artboardSize: CGSize(width:1200,height:800), zoom: zoom, pan: CGSize(width:91,height:-47), rotationDegrees: 11)
            let p=CGPoint(x:321.25,y:244.5); let q=t.documentPoint(fromViewport:t.viewportPoint(fromDocument:p))
            XCTAssertEqual(q.x,p.x,accuracy:0.001); XCTAssertEqual(q.y,p.y,accuracy:0.001)
        }
    }

    func testTransformedSelectionAndCorners() throws {
        var d=DocumentV6.empty(width:800,height:600)
        var r=DocumentNode.rectangle(name:"R",rect:CGRect(x:-50,y:-25,width:100,height:50))
        r.transform=NodeTransform(translationX:300,translationY:200,rotationDegrees:45,scaleX:1,scaleY:1,shearX:0,shearY:0)
        try d.insert(r,parent:d.activeArtboardID,index:0)
        XCTAssertEqual(HitTester.hitTest(point:CGPoint(x:300,y:200),in:d)?.nodeID,r.id)
        let corners=GeometryResolver.transformedCorners(nodeID:r.id,in:d)
        XCTAssertEqual(corners.count,4)
        XCTAssertNotEqual(corners[0].y,corners[1].y)
    }

    func testStableMoveAndResizeModifiers() {
        let id=NodeID(); let move=MoveSession(startPointer:CGPoint(x:0,y:0), originals:[id:.identity])
        XCTAssertEqual(move.transforms(currentPointer:CGPoint(x:30,y:0))[id]?.translationX,30)
        let resize=ResizeSession(originalBounds:CGRect(x:100,y:100,width:200,height:100),originals:[id:.identity],handle:.bottomRight,startPointer:CGPoint(x:300,y:200))
        let shift=resize.result(pointerDocumentPoint:CGPoint(x:400,y:260),modifiers:[.preserveAspect])
        XCTAssertEqual(shift.bounds.width/shift.bounds.height,2,accuracy:0.001)
        let option=resize.result(pointerDocumentPoint:CGPoint(x:400,y:260),modifiers:[.fromCenter])
        XCTAssertEqual(option.bounds.midX,200,accuracy:0.001); XCTAssertEqual(option.bounds.midY,150,accuracy:0.001)
        let both=resize.result(pointerDocumentPoint:CGPoint(x:400,y:260),modifiers:[.fromCenter,.preserveAspect])
        XCTAssertEqual(both.bounds.midX,200,accuracy:0.001); XCTAssertEqual(both.bounds.width/both.bounds.height,2,accuracy:0.001)
    }

    func testMigrationRoundTripGridAndEffectBounds() throws {
        let legacy=try JSONDecoder().decode(LegacyDocumentV5.self,from:V5MigratorTests.legacyFixture)
        let v6=try V5Migrator.migrate(legacy)
        XCTAssertEqual(v6.grid.spacing,32)
        let data=try JSONEncoder().encode(v6); XCTAssertEqual(try JSONDecoder().decode(DocumentV6.self,from:data),v6)
        let group=v6.artworkChildren.compactMap(v6.node(id:)).first!
        let child=group.children.compactMap(v6.node(id:)).first!
        XCTAssertGreaterThan(child.appearance.effects.first?.boundsInflation ?? 0,0)
        XCTAssertEqual(GridMetrics.make(baseSpacing:24,zoom:0.25,screenScale:2).documentSpacing,96)
        XCTAssertEqual(GridMetrics.make(baseSpacing:24,zoom:4,screenScale:2).documentSpacing,6)
    }

    func testUndoRedoMoveAndDelete() throws {
        var d=makeDocumentWithOneRect(); let id=d.artworkChildren[0]; var h=CommandHistory(limit:10)
        try h.execute(.setTransform(id:id,from:.identity,to:.translation(x:20,y:0),coalescingKey:nil),on:&d)
        try h.undo(on:&d); XCTAssertEqual(d.node(id:id)?.transform,.identity); try h.redo(on:&d); XCTAssertEqual(d.node(id:id)?.transform.translationX,20)
        let node=d.node(id:id)!; let tree=NodeSubtree(rootID:id,nodes:[id:node]); try h.execute(.remove(subtree:tree,parent:d.activeArtboardID,index:0),on:&d)
        XCTAssertNil(d.node(id:id)); try h.undo(on:&d); XCTAssertNotNil(d.node(id:id))
    }
}
