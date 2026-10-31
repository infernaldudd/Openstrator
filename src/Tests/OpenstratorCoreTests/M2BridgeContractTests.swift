import XCTest
@testable import OpenstratorCore

final class M2BridgeContractTests: XCTestCase {
    func testM1LegacyFixtureStillDecodesWithMissingBezierMetadata() throws {
        let legacy = try JSONDecoder().decode(LegacyDocumentV5.self, from: V5MigratorTests.legacyFixture)
        XCTAssertNil(legacy.objects[0].bezierAnchors)
    }

    func testBezierMetadataMigratesToLocalCoordinatesAndPreservesHandles() throws {
        let json = #"{"formatVersion":2,"name":"B","artboardWidth":500,"artboardHeight":400,"background":{"r":1,"g":1,"b":1,"a":1},"objects":[{"id":"99999999-9999-9999-9999-999999999999","name":"Curve","kind":"path","x":100,"y":100,"width":100,"height":100,"rotation":0,"opacity":1,"fill":{"r":0,"g":0,"b":0,"a":0},"stroke":{"r":0,"g":0,"b":0,"a":1},"strokeWidth":2,"cornerRadius":0,"blendMode":"normal","text":"","fontSize":12,"fontWeight":0.4,"points":[{"x":100,"y":100},{"x":200,"y":200}],"bezierAnchors":[{"point":[100,100],"outHandle":[120,100],"kind":"corner"},{"point":[200,200],"inHandle":[180,200],"kind":"corner"}],"effects":[],"isVisible":true,"isLocked":false,"isClosed":false}],"guides":[],"gridSpacing":24,"showGrid":true,"snapToGrid":false,"showGuides":true}"#.data(using:.utf8)!
        let d = try V5Migrator.decodeAndMigrate(json)
        guard case let .path(path) = d.node(id:d.artworkChildren[0])?.payload else { return XCTFail("path missing") }
        XCTAssertEqual(path.anchors[0].point,CGPoint(x:-50,y:-50))
        XCTAssertEqual(path.anchors[0].outHandle,CGPoint(x:-30,y:-50))
        XCTAssertEqual(path.anchors[1].inHandle,CGPoint(x:30,y:50))
    }

    func testCompatibilityFlattenDropsDuplicateClosingPoint() {
        let p = LiveShapeGeometry.ellipse(in:CGRect(x:0,y:0,width:100,height:50))
        let points = PathCompatibility.flattenedPoints(p,tolerance:0.5)
        XCTAssertGreaterThan(points.count,4)
        XCTAssertNotEqual(points.first,points.last)
        XCTAssertEqual(points.first,CGPoint(x:100,y:25))
    }
}
