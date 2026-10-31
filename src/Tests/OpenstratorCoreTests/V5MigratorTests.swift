import XCTest
@testable import OpenstratorCore

final class V5MigratorTests: XCTestCase {
    static let groupID = "11111111-1111-1111-1111-111111111111"
    static let legacyFixture = """
    {
      "formatVersion":2,"name":"Legacy","artboardWidth":1440,"artboardHeight":900,
      "background":{"r":0.95,"g":0.96,"b":0.97,"a":1},
      "objects":[
        {"id":"22222222-2222-2222-2222-222222222222","name":"Gradient Card","kind":"rectangle","x":80,"y":90,"width":500,"height":260,"rotation":0,"opacity":0.9,
         "fill":{"r":0.1,"g":0.2,"b":0.3,"a":1},
         "gradient":{"angleDegrees":45,"stops":[{"id":"44444444-4444-4444-4444-444444444444","location":0,"color":{"r":1,"g":0,"b":0,"a":1}},{"id":"55555555-5555-5555-5555-555555555555","location":1,"color":{"r":0,"g":0,"b":1,"a":1}}]},
         "stroke":{"r":0,"g":0,"b":0,"a":1},"strokeWidth":3,"cornerRadius":18,"blendMode":"multiply","text":"Text","fontSize":42,"fontWeight":0.4,"points":[],
         "effects":[{"id":"66666666-6666-6666-6666-666666666666","kind":"shadow","amount":12,"enabled":true}],"isVisible":true,"isLocked":false,"groupID":"11111111-1111-1111-1111-111111111111","isClosed":false,"scaleX":1,"scaleY":1,"shearX":0,"shearY":0,"strokeDash":[8,4],"lineCap":"round","lineJoin":"bevel"},
        {"id":"33333333-3333-3333-3333-333333333333","name":"Headline","kind":"text","x":130,"y":160,"width":300,"height":80,"rotation":17,"opacity":1,
         "fill":{"r":1,"g":1,"b":1,"a":1},"stroke":{"r":0,"g":0,"b":0,"a":0},"strokeWidth":0,"cornerRadius":0,"blendMode":"normal","text":"OPENSTRATOR","fontSize":64,"fontWeight":0.7,"points":[],"effects":[],"isVisible":true,"isLocked":false,"groupID":"11111111-1111-1111-1111-111111111111","isClosed":false,"scaleX":1.2,"scaleY":0.9,"shearX":0.1,"shearY":0,"strokeDash":[],"lineCap":"butt","lineJoin":"miter"}
      ],
      "guides":[{"id":"77777777-7777-7777-7777-777777777777","axis":"vertical","position":320}],
      "gridSpacing":32,"showGrid":true,"snapToGrid":true,"showGuides":true
    }
    """.data(using: .utf8)!

    func testMigratedRotationUsesLegacyObjectCenterAsPivot() throws {
        let json = """
        {"formatVersion":2,"name":"Rot","artboardWidth":800,"artboardHeight":600,"background":{"r":1,"g":1,"b":1,"a":1},"objects":[{"id":"88888888-8888-8888-8888-888888888888","name":"Rotated","kind":"rectangle","x":100,"y":100,"width":200,"height":100,"rotation":45,"opacity":1,"fill":{"r":1,"g":0,"b":0,"a":1},"stroke":{"r":0,"g":0,"b":0,"a":0},"strokeWidth":0,"cornerRadius":0,"blendMode":"normal","text":"Text","fontSize":42,"fontWeight":0.4,"points":[],"effects":[],"isVisible":true,"isLocked":false,"isClosed":false,"scaleX":1,"scaleY":1,"shearX":0,"shearY":0,"strokeDash":[],"lineCap":"butt","lineJoin":"miter"}],"guides":[],"gridSpacing":24,"showGrid":true,"snapToGrid":false,"showGuides":true}
        """.data(using:.utf8)!
        let v6 = try V5Migrator.decodeAndMigrate(json)
        let id = v6.artworkChildren[0]
        let corners = GeometryResolver.transformedCorners(nodeID:id,in:v6)
        let cx = corners.map(\.x).reduce(0,+) / CGFloat(corners.count)
        let cy = corners.map(\.y).reduce(0,+) / CGFloat(corners.count)
        XCTAssertEqual(cx, 200, accuracy: 0.001)
        XCTAssertEqual(cy, 150, accuracy: 0.001)
        XCTAssertEqual(HitTester.hitTest(point:CGPoint(x:200,y:150),in:v6)?.nodeID,id)
    }

    func testMigratesLegacyGeometryAppearanceGroupingAndCanvasSettings() throws {
        let legacy = try JSONDecoder().decode(LegacyDocumentV5.self, from: Self.legacyFixture)
        let v6 = try V5Migrator.migrate(legacy)
        XCTAssertEqual(v6.artboardSize.width, 1440)
        XCTAssertEqual(v6.grid.spacing, 32)
        XCTAssertTrue(v6.grid.snapEnabled)
        XCTAssertEqual(v6.guides.count, 1)
        let topLevel = v6.artworkChildren.compactMap(v6.node(id:))
        XCTAssertEqual(topLevel.count, 1)
        guard case .group = topLevel[0].payload else { return XCTFail("legacy group must migrate to GroupNode") }
        let children = topLevel[0].children.compactMap(v6.node(id:))
        XCTAssertEqual(children.map(\.name), ["Gradient Card", "Headline"])
        XCTAssertEqual(children[0].appearance.effects.first?.kind, "shadow")
        XCTAssertGreaterThan(children[0].appearance.effects.first?.boundsInflation ?? 0, 0)
        XCTAssertEqual(children[1].transform.rotationDegrees, 17)
        XCTAssertEqual(children[1].transform.scaleX, 1.2)
        XCTAssertEqual(children[0].appearance.stroke.dash, [8,4])
    }
}
