import XCTest
@testable import OpenstratorCore

final class SnappingTests: XCTestCase {
    func testAdaptiveGridKeepsScreenSpacingReadable() {
        XCTAssertEqual(GridMetrics.make(baseSpacing: 24, zoom: 0.25, screenScale: 2).documentSpacing, 96)
        XCTAssertEqual(GridMetrics.make(baseSpacing: 24, zoom: 1.0, screenScale: 2).documentSpacing, 24)
        XCTAssertEqual(GridMetrics.make(baseSpacing: 24, zoom: 4.0, screenScale: 2).documentSpacing, 6)
    }

    func testSnapUsesRequestedSpacing() {
        let p = snap(point: CGPoint(x: 25, y: 47), spacing: 24)
        XCTAssertEqual(p.x, 24)
        XCTAssertEqual(p.y, 48)
    }
}
