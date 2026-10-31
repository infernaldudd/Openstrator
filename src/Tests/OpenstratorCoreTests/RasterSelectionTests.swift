import XCTest
@testable import OpenstratorCore

final class RasterSelectionTests: XCTestCase {
    func testRectangleSelectionClipsToCanvas() {
        let selection = RasterSelectionV6.rectangle(canvasWidth: 6, canvasHeight: 5, x: -2, y: 1, width: 5, height: 3)
        XCTAssertEqual(selection.width, 6)
        XCTAssertEqual(selection.height, 5)
        XCTAssertEqual(selection.value(x: 0, y: 1), 255)
        XCTAssertEqual(selection.value(x: 2, y: 3), 255)
        XCTAssertEqual(selection.value(x: 3, y: 2), 0)
    }

    func testEllipseSelectionHasTransparentCornersAndOpaqueCenter() {
        let selection = RasterSelectionV6.ellipse(canvasWidth: 5, canvasHeight: 5, x: 0, y: 0, width: 5, height: 5)
        XCTAssertEqual(selection.value(x: 2, y: 2), 255)
        XCTAssertEqual(selection.value(x: 0, y: 0), 0)
    }

    func testMaskAndSelectionOutsideBoundsAreZero() {
        let mask = RasterMaskV6(width: 2, height: 2, bytes: [255,255,255,255])
        XCTAssertEqual(mask.value(x: -1, y: 0), 0)
        XCTAssertEqual(mask.value(x: 2, y: 0), 0)
        let selection = RasterSelectionV6(width: 2, height: 2, bytes: [255,255,255,255])
        XCTAssertEqual(selection.value(x: 0, y: 2), 0)
    }
}
