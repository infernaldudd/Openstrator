import XCTest
@testable import OpenstratorCore

final class PathEditingTests: XCTestCase {
    private var curve: BezierPathV6 {
        .init(anchors: [
            .init(point:.init(x:0,y:0), outHandle:.init(x:20,y:80), kind:.corner),
            .init(point:.init(x:100,y:20), inHandle:.init(x:70,y:-10), kind:.corner)
        ])
    }

    func testInsertAnchorKeepsExactOriginalCurve() throws {
        let original = curve
        let inserted = try PathEditor.insertAnchor(path:original, segmentIndex:0, t:0.4)
        XCTAssertEqual(inserted.anchors.count, 3)
        for step in 0...20 {
            let t = Double(step)/20
            let old = BezierGeometry.point(on: BezierGeometry.segments(of:original)[0], t:t)
            // insertion at .4 maps [0,.4] and [.4,1]
            let newPoint: CGPoint
            if t <= 0.4 {
                newPoint = BezierGeometry.point(on:BezierGeometry.segments(of:inserted)[0], t:t/0.4)
            } else {
                newPoint = BezierGeometry.point(on:BezierGeometry.segments(of:inserted)[1], t:(t-0.4)/0.6)
            }
            XCTAssertEqual(newPoint.x, old.x, accuracy:0.0005)
            XCTAssertEqual(newPoint.y, old.y, accuracy:0.0005)
        }
    }

    func testReverseSwapsIncomingAndOutgoingHandles() {
        let reversed = PathEditor.reverse(curve)
        XCTAssertEqual(reversed.anchors.first?.point, curve.anchors.last?.point)
        XCTAssertEqual(reversed.anchors.first?.outHandle, curve.anchors.last?.inHandle)
        XCTAssertEqual(reversed.anchors.last?.inHandle, curve.anchors.first?.outHandle)
    }

    func testJoinAvoidsDuplicateCoincidentEndpoint() throws {
        let a = BezierPathV6(anchors:[.init(point:.init(x:0,y:0)), .init(point:.init(x:50,y:0))])
        let b = BezierPathV6(anchors:[.init(point:.init(x:50,y:0)), .init(point:.init(x:100,y:20))])
        let joined = try PathEditor.join(a,b,tolerance:0.01)
        XCTAssertEqual(joined.anchors.count, 3)
        XCTAssertEqual(joined.anchors[1].point, CGPoint(x:50,y:0))
    }

    func testSplitProducesTwoValidOpenPaths() throws {
        let parts = try PathEditor.split(path:curve, segmentIndex:0, t:0.5)
        XCTAssertFalse(parts.left.isClosed)
        XCTAssertFalse(parts.right.isClosed)
        XCTAssertEqual(parts.left.anchors.last?.point, parts.right.anchors.first?.point)
        XCTAssertEqual(parts.left.anchors.count, 2)
        XCTAssertEqual(parts.right.anchors.count, 2)
    }

    func testClosedSeamInsertionAppendsAnchorBetweenLastAndFirst() throws {
        let closed = BezierPathV6(anchors:[.init(point:.init(x:0,y:0)),.init(point:.init(x:100,y:0)),.init(point:.init(x:100,y:100))],isClosed:true)
        let inserted = try PathEditor.insertAnchor(path:closed,segmentIndex:2,t:0.5)
        XCTAssertEqual(inserted.anchors.count,4)
        XCTAssertEqual(inserted.anchors.last?.point, CGPoint(x:50,y:50))
        XCTAssertTrue(inserted.isClosed)
    }
}

extension PathEditingTests {
    func testCutClosedSeamOpensPathAtExactCutPoint() throws {
        let closed = BezierPathV6(anchors: [
            PathAnchorV6(point: CGPoint(x: 0, y: 0)),
            PathAnchorV6(point: CGPoint(x: 100, y: 0)),
            PathAnchorV6(point: CGPoint(x: 100, y: 100))
        ], isClosed: true)
        let originalSeam = try XCTUnwrap(BezierGeometry.segment(at: 2, in: closed))
        let expectedCut = BezierGeometry.point(on: originalSeam, t: 0.5)
        let parts = try PathEditor.cut(path: closed, segmentIndex: 2, t: 0.5)
        XCTAssertEqual(parts.count, 1)
        let opened = try XCTUnwrap(parts.first)
        XCTAssertFalse(opened.isClosed)
        let first = try XCTUnwrap(opened.anchors.first)
        let last = try XCTUnwrap(opened.anchors.last)
        XCTAssertEqual(first.point.x, expectedCut.x, accuracy: 0.0001)
        XCTAssertEqual(first.point.y, expectedCut.y, accuracy: 0.0001)
        XCTAssertEqual(last.point.x, expectedCut.x, accuracy: 0.0001)
        XCTAssertEqual(last.point.y, expectedCut.y, accuracy: 0.0001)
        XCTAssertEqual(opened.anchors.count, closed.anchors.count + 2)
    }
}
