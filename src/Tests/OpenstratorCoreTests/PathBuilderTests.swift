import XCTest
@testable import OpenstratorCore

final class PathBuilderTests: XCTestCase {
    func testPenDragCreatesMirroredSymmetricHandles() {
        var b = PenPathBuilder(closeTolerance:8)
        _ = b.add(point:.init(x:50,y:50), dragTo:.init(x:80,y:70))
        let a = b.path.anchors[0]
        XCTAssertEqual(a.kind,.symmetric)
        XCTAssertEqual(a.outHandle,CGPoint(x:80,y:70))
        XCTAssertEqual(a.inHandle,CGPoint(x:20,y:30))
    }

    func testPenClickNearFirstClosesWithoutDuplicateAnchor() {
        var b = PenPathBuilder(closeTolerance:10)
        _ = b.add(point:.init(x:0,y:0))
        _ = b.add(point:.init(x:100,y:0))
        _ = b.add(point:.init(x:100,y:100))
        let result = b.add(point:.init(x:4,y:3))
        XCTAssertTrue(result.closed)
        XCTAssertTrue(b.path.isClosed)
        XCTAssertEqual(b.path.anchors.count,3)
    }

    func testCurvatureBuilderCreatesSmoothInternalHandles() {
        var b = CurvaturePathBuilder(closeTolerance:8)
        _ = b.add(point:.init(x:0,y:0))
        _ = b.add(point:.init(x:50,y:100))
        _ = b.add(point:.init(x:100,y:0))
        let a = b.path.anchors[1]
        XCTAssertEqual(a.kind,.smooth)
        XCTAssertNotNil(a.inHandle)
        XCTAssertNotNil(a.outHandle)
        let vin = Vector2V6(dx:Double((a.inHandle?.x ?? 0)-a.point.x),dy:Double((a.inHandle?.y ?? 0)-a.point.y))
        let vout = Vector2V6(dx:Double((a.outHandle?.x ?? 0)-a.point.x),dy:Double((a.outHandle?.y ?? 0)-a.point.y))
        XCTAssertEqual(vin.dx * vout.dy - vin.dy * vout.dx, 0, accuracy:0.0001)
        XCTAssertLessThan(vin.dx*vout.dx + vin.dy*vout.dy,0)
    }

    func testCurvatureCloseUsesClosedNeighborTangents() {
        var b = CurvaturePathBuilder(closeTolerance:12)
        _ = b.add(point:.init(x:0,y:0)); _ = b.add(point:.init(x:100,y:0)); _ = b.add(point:.init(x:100,y:100))
        let r = b.add(point:.init(x:5,y:4))
        XCTAssertTrue(r.closed)
        XCTAssertTrue(b.path.isClosed)
        XCTAssertNotNil(b.path.anchors[0].inHandle)
    }
}
