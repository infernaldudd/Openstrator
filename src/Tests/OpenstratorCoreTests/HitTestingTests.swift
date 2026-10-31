import XCTest
@testable import OpenstratorCore

final class HitTestingTests: XCTestCase {
    func testRotatedRectangleHitsVisibleGeometryButNotAABBCorner() throws {
        var document = DocumentV6.empty(width: 800, height: 600)
        var rect = DocumentNode.rectangle(name: "Rotated", rect: CGRect(x: -50, y: -25, width: 100, height: 50))
        rect.transform = NodeTransform(translationX: 300, translationY: 200, rotationDegrees: 45, scaleX: 1, scaleY: 1, shearX: 0, shearY: 0)
        try document.insert(rect, parent: document.rootID, index: 0)
        XCTAssertEqual(HitTester.hitTest(point: CGPoint(x: 300, y: 200), in: document)?.nodeID, rect.id)
        XCTAssertNil(HitTester.hitTest(point: CGPoint(x: 350, y: 150), in: document))
    }

    func testEllipseRejectsBoundingBoxCorner() throws {
        var document = DocumentV6.empty(width: 500, height: 400)
        var e = DocumentNode.ellipse(name: "E", rect: CGRect(x: 0, y: 0, width: 100, height: 60))
        e.transform = .translation(x: 100, y: 100)
        try document.insert(e, parent: document.activeArtboardID, index: 0)
        XCTAssertNotNil(HitTester.hitTest(point: CGPoint(x: 150, y: 130), in: document))
        XCTAssertNil(HitTester.hitTest(point: CGPoint(x: 101, y: 101), in: document))
    }

    func testThinLineUsesTolerance() throws {
        var document = DocumentV6.empty(width: 500, height: 400)
        var line = DocumentNode(name: "Line", appearance: AppearanceV6(fill: .clear, stroke: StrokeV6(color: .black, width: 2)), payload: .line(PathData(anchors: [PathAnchorM1(point: CGPoint(x: 0, y: 0)), PathAnchorM1(point: CGPoint(x: 100, y: 0))])))
        line.transform = .translation(x: 50, y: 50)
        try document.insert(line, parent: document.activeArtboardID, index: 0)
        XCTAssertNotNil(HitTester.hitTest(point: CGPoint(x: 90, y: 56), in: document, options: HitTestOptions(tolerance: 8)))
        XCTAssertNil(HitTester.hitTest(point: CGPoint(x: 90, y: 70), in: document, options: HitTestOptions(tolerance: 8)))
    }

    func testOpenPathSegmentDistance() throws {
        var document = DocumentV6.empty(width: 500, height: 400)
        let path = DocumentNode(name: "Path", appearance: AppearanceV6(fill: .clear, stroke: StrokeV6(color: .black, width: 2)), payload: .path(PathData(anchors: [PathAnchorM1(point: CGPoint(x: 0, y: 0)), PathAnchorM1(point: CGPoint(x: 100, y: 100))], isClosed: false)))
        try document.insert(path, parent: document.activeArtboardID, index: 0)
        XCTAssertNotNil(HitTester.hitTest(point: CGPoint(x: 52, y: 48), in: document, options: HitTestOptions(tolerance: 5)))
        XCTAssertNil(HitTester.hitTest(point: CGPoint(x: 80, y: 40), in: document, options: HitTestOptions(tolerance: 5)))
    }

    func testHiddenAndLockedNodesAreRejectedByDefault() throws {
        var document = DocumentV6.empty(width: 500, height: 400)
        var hidden = DocumentNode.rectangle(name: "H", rect: CGRect(x: 0, y: 0, width: 100, height: 100)); hidden.isVisible = false
        var locked = DocumentNode.rectangle(name: "L", rect: CGRect(x: 0, y: 0, width: 100, height: 100)); locked.transform = .translation(x: 150, y: 0); locked.isLocked = true
        try document.insert(hidden, parent: document.activeArtboardID, index: 0)
        try document.insert(locked, parent: document.activeArtboardID, index: 1)
        XCTAssertNil(HitTester.hitTest(point: CGPoint(x: 50, y: 50), in: document))
        XCTAssertNil(HitTester.hitTest(point: CGPoint(x: 200, y: 50), in: document))
        XCTAssertEqual(HitTester.hitTest(point: CGPoint(x: 200, y: 50), in: document, options: HitTestOptions(includeLocked: true))?.nodeID, locked.id)
    }

    func testTransformedCornersReflectRotation() throws {
        var document = DocumentV6.empty(width: 500, height: 400)
        var rect = DocumentNode.rectangle(name: "R", rect: CGRect(x: -50, y: -25, width: 100, height: 50))
        rect.transform = NodeTransform(translationX: 200, translationY: 150, rotationDegrees: 90, scaleX: 1, scaleY: 1, shearX: 0, shearY: 0)
        try document.insert(rect, parent: document.activeArtboardID, index: 0)
        let corners = GeometryResolver.transformedCorners(nodeID: rect.id, in: document)
        XCTAssertEqual(corners.count, 4)
        XCTAssertEqual(corners[0].x, 225, accuracy: 0.001)
        XCTAssertEqual(corners[0].y, 100, accuracy: 0.001)
    }
}
