import XCTest
@testable import OpenstratorCore

final class TextPathLayoutTests: XCTestCase {
    func testPathPlacementFollowsDistanceAndTangent() {
        let path = BezierPathV6(anchors: [
            PathAnchorV6(point: CGPoint(x: 0, y: 0)),
            PathAnchorV6(point: CGPoint(x: 100, y: 0)),
            PathAnchorV6(point: CGPoint(x: 100, y: 100))
        ])
        let placements = TextPathLayout.placements(advances: [20, 20, 20, 20, 20, 20], path: path, startOffset: 0, endOffset: 0, baselineOffset: 0, flip: false)
        XCTAssertEqual(placements.count, 6)
        XCTAssertEqual(placements[0].point.y, 0, accuracy: 0.5)
        XCTAssertEqual(placements[0].angleDegrees, 0, accuracy: 1)
        XCTAssertGreaterThan(placements[5].point.y, 0)
        XCTAssertEqual(abs(placements[5].angleDegrees), 90, accuracy: 4)
    }

    func testPathPlacementHandlesEmptyInput() {
        XCTAssertTrue(TextPathLayout.placements(advances: [], path: BezierPathV6(anchors: []), startOffset: 0, endOffset: 0, baselineOffset: 0, flip: false).isEmpty)
    }

    func testGlyphTransformAppliesOffsetScaleAndRotation() {
        let base = TextGlyphPlacementV6(glyphIndex: 2, point: CGPoint(x: 10, y: 20), angleDegrees: 5)
        let transformed = TextPathLayout.applying(GlyphTransformV6(glyphIndex: 2, offsetX: 3, offsetY: -4, scaleX: 1.2, scaleY: 0.8, rotationDegrees: 15), to: base)
        XCTAssertEqual(transformed.point, CGPoint(x: 13, y: 16))
        XCTAssertEqual(transformed.angleDegrees, 20, accuracy: 0.001)
        XCTAssertEqual(transformed.scaleX, 1.2, accuracy: 0.001)
        XCTAssertEqual(transformed.scaleY, 0.8, accuracy: 0.001)
    }

    func testArcWarpMovesMiddleMoreThanEdges() {
        let warp = TextWarpV6(style: .arc, bend: 0.8)
        let left = TextWarpEngine.offset(normalizedX: 0, normalizedY: 0.5, warp: warp, frame: CGSize(width: 200, height: 80))
        let mid = TextWarpEngine.offset(normalizedX: 0.5, normalizedY: 0.5, warp: warp, frame: CGSize(width: 200, height: 80))
        let right = TextWarpEngine.offset(normalizedX: 1, normalizedY: 0.5, warp: warp, frame: CGSize(width: 200, height: 80))
        XCTAssertGreaterThan(abs(mid.dy), abs(left.dy))
        XCTAssertGreaterThan(abs(mid.dy), abs(right.dy))
    }
}
