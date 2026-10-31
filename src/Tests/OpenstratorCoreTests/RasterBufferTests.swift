import XCTest
@testable import OpenstratorCore

final class RasterBufferTests: XCTestCase {
    func testTransparentByDefaultAndTileAddressingAcrossBoundary() throws {
        var store = try RasterTileStoreV6(width: 300, height: 270)
        XCTAssertEqual(store.tileSize, 256)
        XCTAssertEqual(store.pixel(x: 0, y: 0), .clear)
        try store.setPixel(.init(r: 12, g: 34, b: 56, a: 78), x: 256, y: 256)
        XCTAssertEqual(store.pixel(x: 256, y: 256), .init(r: 12, g: 34, b: 56, a: 78))
        XCTAssertEqual(store.allocatedTileCount, 1)
        XCTAssertEqual(store.pixel(x: 299, y: 269), .clear)
        XCTAssertEqual(store.pixel(x: 300, y: 269), .clear)
    }

    func testRejectsZeroSizeStoreAndInvalidBulkByteCount() {
        XCTAssertThrowsError(try RasterTileStoreV6(width: 0, height: 10))
        XCTAssertThrowsError(try RasterTileStoreV6(width: 10, height: 0))
        XCTAssertThrowsError(try RasterTileStoreV6(width: 2, height: 2, rgbaBytes: [0, 1]))
    }

    func testBulkRGBAImportAndExportRoundTripIncludingEdgeTile() throws {
        var bytes = Array(repeating: UInt8(0), count: 257 * 2 * 4)
        let last = ((1 * 257) + 256) * 4
        bytes[last] = 21; bytes[last + 1] = 22; bytes[last + 2] = 23; bytes[last + 3] = 24
        let store = try RasterTileStoreV6(width: 257, height: 2, rgbaBytes: bytes)
        XCTAssertEqual(store.pixel(x: 256, y: 1), .init(r:21,g:22,b:23,a:24))
        XCTAssertEqual(store.rgbaBytes(), bytes)
        XCTAssertEqual(store.allocatedTileCount, 1)
    }
}
