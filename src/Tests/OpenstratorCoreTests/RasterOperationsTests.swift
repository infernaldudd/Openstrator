import XCTest
@testable import OpenstratorCore

final class RasterOperationsTests: XCTestCase {
    func testCropPreservesPixelsAndMakesOutOfBoundsAreaTransparent() throws {
        var src = try RasterTileStoreV6(width: 4, height: 4)
        try src.setPixel(.init(r:255,g:0,b:0,a:255), x: 2, y: 2)
        let out = try RasterOperationsV6.crop(src, x: 1, y: 1, width: 4, height: 4)
        XCTAssertEqual(out.width, 4)
        XCTAssertEqual(out.height, 4)
        XCTAssertEqual(out.pixel(x: 1, y: 1), .init(r:255,g:0,b:0,a:255))
        XCTAssertEqual(out.pixel(x: 3, y: 3), .clear)
    }

    func testBilinearResampleUsesRequestedDimensionsAndPreservesAlphaRange() throws {
        var src = try RasterTileStoreV6(width: 2, height: 2)
        try src.setPixel(.init(r:255,g:0,b:0,a:128), x: 0, y: 0)
        let out = try RasterOperationsV6.resampleBilinear(src, width: 4, height: 4)
        XCTAssertEqual(out.width, 4)
        XCTAssertEqual(out.height, 4)
        XCTAssertGreaterThan(out.pixel(x: 0, y: 0).a, 0)
        XCTAssertLessThanOrEqual(out.pixel(x: 0, y: 0).a, 128)
    }

    func testSourceOverCompositeBlendsAlpha() throws {
        var bottom = try RasterTileStoreV6(width: 1, height: 1)
        var top = try RasterTileStoreV6(width: 1, height: 1)
        try bottom.setPixel(.init(r:0,g:0,b:255,a:255), x:0,y:0)
        try top.setPixel(.init(r:255,g:0,b:0,a:128), x:0,y:0)
        let out = try RasterOperationsV6.composite(source: top, over: bottom, offsetX: 0, offsetY: 0)
        let p = out.pixel(x:0,y:0)
        XCTAssertEqual(p.a, 255)
        XCTAssertGreaterThan(p.r, 100)
        XCTAssertGreaterThan(p.b, 100)
    }

    func testCropAndResampleRejectZeroSizedOutput() throws {
        let src = try RasterTileStoreV6(width: 2, height: 2)
        XCTAssertThrowsError(try RasterOperationsV6.crop(src, x:0,y:0,width:0,height:1))
        XCTAssertThrowsError(try RasterOperationsV6.resampleBilinear(src, width:0,height:1))
    }
}
