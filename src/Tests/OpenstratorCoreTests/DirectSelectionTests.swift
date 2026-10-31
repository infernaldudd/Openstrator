import XCTest
@testable import OpenstratorCore

final class DirectSelectionTests: XCTestCase {
    private var curve: BezierPathV6 {
        BezierPathV6(anchors: [
            PathAnchorV6(point: .init(x: 0,y:0), outHandle: .init(x:0,y:100), kind: .corner),
            PathAnchorV6(point: .init(x:100,y:0), inHandle: .init(x:100,y:100), kind: .corner)
        ])
    }

    func testAnchorWinsOverNearbySegment() {
        let hit = DirectSelection.hitTest(path: curve, point: .init(x: 1,y:1), tolerance: 8)
        XCTAssertEqual(hit?.component, .anchor(0))
    }

    func testHandleCanBeHit() {
        let hit = DirectSelection.hitTest(path: curve, point: .init(x: 1,y:99), tolerance: 6)
        XCTAssertEqual(hit?.component, .outgoingHandle(0))
    }

    func testCurvedSegmentCanBeHitAwayFromAnchorChord() {
        let hit = DirectSelection.hitTest(path: curve, point: .init(x: 50,y:75), tolerance: 3)
        XCTAssertEqual(hit?.component, .segment(0))
    }

    func testClosedSeamIsSelectable() {
        let p = BezierPathV6(anchors: [
            .init(point:.init(x:0,y:0)), .init(point:.init(x:100,y:0)), .init(point:.init(x:100,y:100))
        ], isClosed: true)
        let hit = DirectSelection.hitTest(path:p, point:.init(x:50,y:50), tolerance:2)
        XCTAssertEqual(hit?.component, .segment(2))
    }

    func testMovingAnchorMovesItsHandlesBySameDelta() {
        let moved = DirectSelection.moveAnchor(path: curve, index: 0, to: .init(x:10,y:20))
        XCTAssertEqual(moved.anchors[0].point, .init(x:10,y:20))
        XCTAssertEqual(moved.anchors[0].outHandle, .init(x:10,y:120))
    }

    func testCornerHandleMovesIndependently() {
        let changed = DirectSelection.moveHandle(path: curve, index: 1, side: .incoming, to: .init(x:80,y:70))
        XCTAssertEqual(changed.anchors[1].inHandle, .init(x:80,y:70))
        XCTAssertNil(changed.anchors[1].outHandle)
    }

    func testSymmetricHandleMirrorsOppositeExactly() {
        var p = curve
        p.anchors[1].kind = .symmetric
        p.anchors[1].outHandle = .init(x:120,y:-20)
        let changed = DirectSelection.moveHandle(path:p,index:1,side:.incoming,to:.init(x:70,y:40))
        XCTAssertEqual(changed.anchors[1].outHandle?.x ?? -1, 130, accuracy: 0.0001)
        XCTAssertEqual(changed.anchors[1].outHandle?.y ?? -1, -40, accuracy: 0.0001)
    }

    func testSmoothHandleKeepsOppositeLengthAndCollinearity() {
        var p = curve
        p.anchors[1].kind = .smooth
        p.anchors[1].outHandle = .init(x:130,y:0) // length 30
        let changed = DirectSelection.moveHandle(path:p,index:1,side:.incoming,to:.init(x:100,y:50))
        let out = changed.anchors[1].outHandle!
        XCTAssertEqual(out.x, 100, accuracy: 0.0001)
        XCTAssertEqual(out.y, -30, accuracy: 0.0001)
    }
    func testMoveClosedSeamMovesBothEndpointAnchors() {
        let p = BezierPathV6(anchors:[.init(point:.init(x:0,y:0)),.init(point:.init(x:100,y:0)),.init(point:.init(x:100,y:100))],isClosed:true)
        let moved = DirectSelection.moveSegment(path:p,segmentIndex:2,delta:CGSize(width:10,height:-5))
        XCTAssertEqual(moved.anchors[2].point,CGPoint(x:110,y:95))
        XCTAssertEqual(moved.anchors[0].point,CGPoint(x:10,y:-5))
        XCTAssertEqual(moved.anchors[1].point,CGPoint(x:100,y:0))
    }

}
