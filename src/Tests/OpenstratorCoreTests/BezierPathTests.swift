import XCTest
@testable import OpenstratorCore

final class BezierPathTests: XCTestCase {
    func testCubicPointAndDerivativeAtMidpoint() {
        let s = CubicBezierSegmentV6(
            p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 0, y: 100),
            p2: CGPoint(x: 100, y: 100), p3: CGPoint(x: 100, y: 0)
        )
        let p = BezierGeometry.point(on: s, t: 0.5)
        XCTAssertEqual(p.x, 50, accuracy: 0.0001)
        XCTAssertEqual(p.y, 75, accuracy: 0.0001)
        let d = BezierGeometry.derivative(on: s, t: 0.5)
        XCTAssertGreaterThan(d.dx, 0)
        XCTAssertEqual(d.dy, 0, accuracy: 0.0001)
    }

    func testSplitIsContinuousAndExactAtSplitPoint() {
        let s = CubicBezierSegmentV6(p0: .init(x: 0,y: 0), p1: .init(x: 30,y: 80), p2: .init(x: 70,y: -20), p3: .init(x: 100,y: 20))
        let expected = BezierGeometry.point(on: s, t: 0.37)
        let pair = BezierGeometry.split(s, t: 0.37)
        XCTAssertEqual(pair.left.p3.x, expected.x, accuracy: 0.000001)
        XCTAssertEqual(pair.left.p3.y, expected.y, accuracy: 0.000001)
        XCTAssertEqual(pair.right.p0.x, expected.x, accuracy: 0.000001)
        XCTAssertEqual(pair.right.p0.y, expected.y, accuracy: 0.000001)
    }

    func testFlattenPreservesEndpointsAndClosedSeam() {
        let path = BezierPathV6(anchors: [
            PathAnchorV6(point: .init(x: 0,y: 0)),
            PathAnchorV6(point: .init(x: 100,y: 0)),
            PathAnchorV6(point: .init(x: 100,y: 100))
        ], isClosed: true)
        let pts = BezierGeometry.flatten(path, tolerance: 0.5)
        XCTAssertEqual(pts.first, CGPoint(x: 0,y: 0))
        XCTAssertEqual(pts.last, CGPoint(x: 0,y: 0), "closed flattening must include the last→first seam")
    }

    func testAnalyticBoundsIncludeCubicExtremum() {
        let path = BezierPathV6(anchors: [
            PathAnchorV6(point: .init(x: 0,y: 0), outHandle: .init(x: 0,y: 100), kind: .corner),
            PathAnchorV6(point: .init(x: 100,y: 0), inHandle: .init(x: 100,y: 100), kind: .corner)
        ])
        let b = BezierGeometry.bounds(path)
        XCTAssertEqual(b?.minX ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(b?.maxX ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(b?.maxY ?? -1, 75, accuracy: 0.001)
    }

    func testDegenerateSegmentStaysFinite() {
        let p = CGPoint(x: 20, y: 20)
        let s = CubicBezierSegmentV6(p0:p,p1:p,p2:p,p3:p)
        let flat = BezierGeometry.flatten(s, tolerance: 0.25)
        XCTAssertFalse(flat.isEmpty)
        XCTAssertTrue(flat.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        XCTAssertTrue(BezierGeometry.distance(from: CGPoint(x: 22,y:20), to: s, tolerance: 0.25).isFinite)
    }

    func testM1PointOnlyAnchorJSONDecodesAsCornerAnchor() throws {
        let json = #"{"anchors":[{"point":[10,20]},{"point":[40,50]}],"isClosed":false}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BezierPathV6.self, from: json)
        XCTAssertEqual(decoded.anchors.count, 2)
        XCTAssertNil(decoded.anchors[0].inHandle)
        XCTAssertNil(decoded.anchors[0].outHandle)
        XCTAssertEqual(decoded.anchors[0].kind, .corner)
    }
}
