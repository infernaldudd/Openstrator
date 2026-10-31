import XCTest
@testable import OpenstratorCore

final class RasterBrushTests: XCTestCase {
    func testPaintStampClipsAtEdges() throws {
        var store = try RasterTileStoreV6(width: 5, height: 5)
        try RasterBrushV6.paint(&store, centerX: 0, centerY: 0, radius: 2, color: .init(r:255,g:0,b:0,a:255), opacity: 1)
        XCTAssertGreaterThan(store.pixel(x:0,y:0).a, 0)
        XCTAssertEqual(store.pixel(x:4,y:4), .clear)
    }

    func testPaintIsRestrictedToSelectionAndMask() throws {
        var store = try RasterTileStoreV6(width: 5, height: 5)
        let selection = RasterSelectionV6.rectangle(canvasWidth:5, canvasHeight:5, x:1, y:1, width:3, height:3)
        var bytes = Array(repeating: UInt8(255), count:25)
        bytes[2 * 5 + 2] = 0
        let mask = RasterMaskV6(width:5, height:5, bytes:bytes)
        try RasterBrushV6.paint(&store, centerX:2, centerY:2, radius:3, color:.init(r:0,g:255,b:0,a:255), opacity:1, selection:selection, mask:mask)
        XCTAssertEqual(store.pixel(x:0,y:0).a,0)
        XCTAssertEqual(store.pixel(x:2,y:2).a,0)
        XCTAssertGreaterThan(store.pixel(x:1,y:1).a,0)
    }

    func testEraseReducesAlphaWithoutChangingRGB() throws {
        var store = try RasterTileStoreV6(width:3,height:3)
        try store.setPixel(.init(r:10,g:20,b:30,a:255), x:1, y:1)
        try RasterBrushV6.erase(&store, centerX:1, centerY:1, radius:1, opacity:0.5)
        let pixel = store.pixel(x:1,y:1)
        XCTAssertEqual(pixel.r,10)
        XCTAssertEqual(pixel.g,20)
        XCTAssertEqual(pixel.b,30)
        XCTAssertLessThan(pixel.a,255)
        XCTAssertGreaterThan(pixel.a,100)
    }
}
