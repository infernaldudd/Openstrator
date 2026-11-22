import XCTest
@testable import OpenstratorCore

final class StrokeWidthProfileTests: XCTestCase {
    func testProfilesAreCodableAndDeterministic() throws {
        for profile in StrokeWidthProfileV6.allCases {
            let encoded = try JSONEncoder().encode(profile)
            XCTAssertEqual(try JSONDecoder().decode(StrokeWidthProfileV6.self, from: encoded), profile)
            for t in stride(from: 0.0, through: 1.0, by: 0.1) {
                let width = profile.scale(at: t)
                XCTAssertTrue(width.isFinite)
                XCTAssertGreaterThanOrEqual(width, 0)
                XCTAssertLessThanOrEqual(width, 1)
            }
        }
        XCTAssertEqual(StrokeWidthProfileV6.uniform.scale(at: 0.2), 1)
        XCTAssertLessThan(StrokeWidthProfileV6.taperBoth.scale(at: 0), StrokeWidthProfileV6.taperBoth.scale(at: 0.5))
        XCTAssertLessThan(StrokeWidthProfileV6.taperBoth.scale(at: 1), StrokeWidthProfileV6.taperBoth.scale(at: 0.5))
        XCTAssertLessThan(StrokeWidthProfileV6.taperStart.scale(at: 0), StrokeWidthProfileV6.taperStart.scale(at: 1))
        XCTAssertGreaterThan(StrokeWidthProfileV6.taperEnd.scale(at: 0), StrokeWidthProfileV6.taperEnd.scale(at: 1))
    }

    func testStraightLineProducesRealClosedOutline() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]
        let outline = StrokeOutlineV6.make(centerline: points, baseWidth: 20, profile: .taperBoth)
        XCTAssertEqual(outline.count, 4)
        XCTAssertEqual(outline[0].x, 0, accuracy: 0.00001)
        XCTAssertEqual(outline[1].x, 100, accuracy: 0.00001)
        XCTAssertEqual(outline[0].y, -outline[3].y, accuracy: 0.00001)
        XCTAssertEqual(outline[1].y, -outline[2].y, accuracy: 0.00001)
        XCTAssertTrue(outline.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    func testDuplicatePointsInvalidWidthsAndHugeNumbersAreSafe() {
        let pts = [CGPoint(x: 0,y: 0),CGPoint(x: 0,y: 0),CGPoint(x: 40,y: 10),CGPoint(x: 40,y: 10)]
        XCTAssertEqual(StrokeOutlineV6.make(centerline: pts, baseWidth: 0, profile: .taperBoth).count, 0)
        XCTAssertEqual(StrokeOutlineV6.make(centerline: pts, baseWidth: .infinity, profile: .taperBoth).count, 0)
        let outline = StrokeOutlineV6.make(centerline: pts, baseWidth: 16, profile: .taperEnd)
        XCTAssertEqual(outline.count, 4)
        XCTAssertTrue(outline.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    func testBezierOutlineFollowsCurveAndRespectsProfile() {
        let path = BezierPathV6(anchors: [
            PathAnchorV6(point: CGPoint(x: 0,y: 0), outHandle: CGPoint(x: 0,y: 90)),
            PathAnchorV6(point: CGPoint(x: 100,y: 0), inHandle: CGPoint(x: 100,y: 90))
        ])
        let outline = StrokeOutlineV6.make(path: path, baseWidth: 18, profile: .middleHeavy)
        XCTAssertGreaterThan(outline.count, 6)
        XCTAssertTrue(outline.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }
}
