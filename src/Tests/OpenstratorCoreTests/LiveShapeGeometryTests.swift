import XCTest
@testable import OpenstratorCore

final class LiveShapeGeometryTests: XCTestCase {
    func testEllipseUsesFourCubicAnchorsAndExactBounds() {
        let p = LiveShapeGeometry.ellipse(in:CGRect(x:10,y:20,width:200,height:100))
        XCTAssertTrue(p.isClosed)
        XCTAssertEqual(p.anchors.count,4)
        let b = BezierGeometry.bounds(p)!
        XCTAssertEqual(b.minX,10,accuracy:0.001); XCTAssertEqual(b.maxX,210,accuracy:0.001)
        XCTAssertEqual(b.minY,20,accuracy:0.001); XCTAssertEqual(b.maxY,120,accuracy:0.001)
    }

    func testRoundedRectangleClampsRadiusToHalfShortestSide() {
        let p = LiveShapeGeometry.roundedRectangle(in:CGRect(x:0,y:0,width:100,height:40),cornerRadius:99)
        XCTAssertTrue(p.isClosed)
        XCTAssertEqual(p.anchors.count,8)
        let b = BezierGeometry.bounds(p)!
        XCTAssertEqual(b.width,100,accuracy:0.001); XCTAssertEqual(b.height,40,accuracy:0.001)
    }

    func testPolygonAndStarHaveExpectedVertexCounts() {
        XCTAssertEqual(LiveShapeGeometry.polygon(center:.init(x:0,y:0),radius:50,sides:7).anchors.count,7)
        XCTAssertEqual(LiveShapeGeometry.star(center:.init(x:0,y:0),outerRadius:50,innerRadius:25,points:5).anchors.count,10)
    }

    func testArcPreservesRequestedEndpoints() {
        let p = LiveShapeGeometry.arc(center:.init(x:10,y:10),radius:40,startAngleDegrees:0,endAngleDegrees:180)
        XCTAssertFalse(p.isClosed)
        XCTAssertEqual(p.anchors.first?.point.x ?? -1,50,accuracy:0.001)
        XCTAssertEqual(p.anchors.first?.point.y ?? -1,10,accuracy:0.001)
        XCTAssertEqual(p.anchors.last?.point.x ?? -1,-30,accuracy:0.001)
        XCTAssertEqual(p.anchors.last?.point.y ?? -1,10,accuracy:0.001)
    }

    func testSpiralAndGridGeneratorsStayFinite() {
        let spiral = LiveShapeGeometry.spiral(center:.init(x:0,y:0),startRadius:2,endRadius:80,turns:3,pointsPerTurn:12)
        XCTAssertGreaterThan(spiral.anchors.count,20)
        XCTAssertTrue(spiral.anchors.allSatisfy { $0.point.x.isFinite && $0.point.y.isFinite })
        let rectangular = LiveShapeGeometry.rectangularGrid(in:CGRect(x:0,y:0,width:120,height:80),rows:4,columns:6)
        XCTAssertEqual(rectangular.count,12) // 5 horizontal + 7 vertical
        let polar = LiveShapeGeometry.polarGrid(center:.init(x:0,y:0),radius:100,radialDivisions:8,concentricDivisions:4)
        XCTAssertEqual(polar.count,12)
        XCTAssertTrue(polar.flatMap(\.anchors).allSatisfy { $0.point.x.isFinite && $0.point.y.isFinite })
    }
}
