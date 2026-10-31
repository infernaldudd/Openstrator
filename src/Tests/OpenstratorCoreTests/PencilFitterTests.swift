import XCTest
@testable import OpenstratorCore

final class PencilFitterTests: XCTestCase {
    func testNoisyLineIsSimplifiedAndEndpointsArePreserved() {
        let samples = (0...100).map { i in CGPoint(x:Double(i), y:Double(i % 2 == 0 ? 0.35 : -0.35)) }
        let path = PencilFitter.fit(samples:samples,tolerance:1.0,smoothing:0.75)
        XCTAssertLessThan(path.anchors.count, 12)
        XCTAssertEqual(path.anchors.first?.point, samples.first)
        XCTAssertEqual(path.anchors.last?.point, samples.last)
        XCTAssertGreaterThanOrEqual(path.anchors.count, 2)
    }

    func testCurvedStrokeGetsSmoothInternalHandles() {
        let samples = (0...20).map { i -> CGPoint in
            let t = Double(i)/20
            return CGPoint(x:t*100,y:sin(t * .pi)*80)
        }
        let path = PencilFitter.fit(samples:samples,tolerance:2,smoothing:1)
        XCTAssertGreaterThan(path.anchors.count,2)
        let internalAnchors = path.anchors.dropFirst().dropLast()
        XCTAssertTrue(internalAnchors.allSatisfy { $0.kind == .smooth })
        XCTAssertTrue(internalAnchors.contains { $0.inHandle != nil && $0.outHandle != nil })
    }

    func testDuplicateSamplesDoNotCreateNaN() {
        let samples = [CGPoint(x:10,y:10),CGPoint(x:10,y:10),CGPoint(x:10,y:10),CGPoint(x:20,y:20)]
        let path = PencilFitter.fit(samples:samples,tolerance:0.5,smoothing:1)
        XCTAssertGreaterThanOrEqual(path.anchors.count,2)
        for a in path.anchors {
            XCTAssertTrue(a.point.x.isFinite && a.point.y.isFinite)
            XCTAssertTrue(a.inHandle.map { $0.x.isFinite && $0.y.isFinite } ?? true)
            XCTAssertTrue(a.outHandle.map { $0.x.isFinite && $0.y.isFinite } ?? true)
        }
    }
}
