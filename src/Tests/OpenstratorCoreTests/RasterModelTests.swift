import XCTest
@testable import OpenstratorCore

final class RasterModelTests: XCTestCase {
    func testMetadataNormalizesUnsafeValues() {
        var metadata = RasterAssetMetadataV6(pixelWidth: -10, pixelHeight: 0, dpi: -3, mimeType: "")
        metadata.normalize()
        XCTAssertEqual(metadata.pixelWidth, 1)
        XCTAssertEqual(metadata.pixelHeight, 1)
        XCTAssertEqual(metadata.dpi, 72)
        XCTAssertEqual(metadata.mimeType, "application/octet-stream")
    }

    func testOldVectorOnlyDocumentStillRoundTripsWithoutRasterPayloads() throws {
        let original = DocumentV6.empty(width: 800, height: 600)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DocumentV6.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testRasterAssetRoundTripKeepsEmbeddedBytes() throws {
        let id = UUID()
        let asset = RasterImageDataV6(
            assetID: id,
            metadata: .init(pixelWidth: 320, pixelHeight: 180, dpi: 144, mimeType: "image/png"),
            embeddedData: Data([1, 2, 3, 4])
        )
        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(RasterImageDataV6.self, from: data)
        XCTAssertEqual(decoded.assetID, id)
        XCTAssertEqual(decoded.embeddedData, Data([1, 2, 3, 4]))
        XCTAssertEqual(decoded.metadata.pixelWidth, 320)
    }

    func testImageNodePayloadRoundTrips() throws {
        let image = RasterImageDataV6(
            assetID: UUID(),
            metadata: .init(pixelWidth: 10, pixelHeight: 20, dpi: 72, mimeType: "image/jpeg"),
            embeddedData: Data([9, 8, 7])
        )
        let node = DocumentNode(name: "Placed Image", payload: .image(image))
        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(DocumentNode.self, from: data)
        guard case let .image(roundTrip) = decoded.payload else { return XCTFail("expected image") }
        XCTAssertEqual(roundTrip, image)
    }

    func testRasterFilterAndMaskRoundTrip() throws {
        var record = RasterFilterRecordV6(id: .gaussianBlur, parameters: ["radius": 9999])
        record.normalize()
        XCTAssertEqual(record.parameters["radius"], 200)

        let mask = RasterMaskV6(width: 2, height: 2, bytes: [0, 64, 128, 255])
        let payload = try JSONEncoder().encode(mask)
        XCTAssertEqual(try JSONDecoder().decode(RasterMaskV6.self, from: payload), mask)
    }
}
