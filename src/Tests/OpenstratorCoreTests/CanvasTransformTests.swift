import XCTest
@testable import OpenstratorCore

final class CanvasTransformTests: XCTestCase {
    func testViewportDocumentRoundTripAcrossZoomPanAndRotation() {
        for zoom in [0.25, 0.5, 1.0, 2.0, 4.0] {
            let transform = CanvasTransform(viewportSize: CGSize(width: 1440, height: 900), artboardSize: CGSize(width: 1200, height: 800), zoom: zoom, pan: CGSize(width: 137, height: -83), rotationDegrees: 13)
            let input = CGPoint(x: 387.25, y: 221.75)
            let viewport = transform.viewportPoint(fromDocument: input)
            let output = transform.documentPoint(fromViewport: viewport)
            XCTAssertEqual(output.x, input.x, accuracy: 0.001)
            XCTAssertEqual(output.y, input.y, accuracy: 0.001)
        }
    }

    func testViewportDeltaScalesIntoDocumentDelta() {
        let t = CanvasTransform(viewportSize: CGSize(width: 1000, height: 800), artboardSize: CGSize(width: 1200, height: 800), zoom: 0.5, pan: .zero, rotationDegrees: 0)
        let d = t.documentDelta(fromViewportDelta: CGVector(dx: 100, dy: 0))
        XCTAssertEqual(d.dx, 200, accuracy: 0.001)
        XCTAssertEqual(d.dy, 0, accuracy: 0.001)
    }
}
