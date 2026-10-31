import Foundation

public struct RasterPixelV6: Codable, Equatable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public static let clear = RasterPixelV6(r: 0, g: 0, b: 0, a: 0)
}

public enum RasterBufferError: Error, Equatable {
    case invalidDimensions
    case invalidByteCount
    case outOfBounds
}

public struct RasterTileKeyV6: Hashable, Codable, Sendable {
    public var x: Int
    public var y: Int
    public init(x: Int, y: Int) { self.x = x; self.y = y }
}

public struct RasterTileStoreV6: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let tileSize: Int
    private var tiles: [RasterTileKeyV6: [UInt8]]

    public init(width: Int, height: Int, tileSize: Int = 256) throws {
        guard width > 0, height > 0, tileSize > 0,
              Self.checkedByteCount(width: width, height: height) != nil,
              Self.checkedByteCount(width: tileSize, height: tileSize) != nil else {
            throw RasterBufferError.invalidDimensions
        }
        self.width = width
        self.height = height
        self.tileSize = tileSize
        self.tiles = [:]
    }

    public init(width: Int, height: Int, tileSize: Int = 256, rgbaBytes: [UInt8]) throws {
        guard width > 0, height > 0, tileSize > 0,
              let expectedCount = Self.checkedByteCount(width: width, height: height),
              let tileByteCount = Self.checkedByteCount(width: tileSize, height: tileSize) else {
            throw RasterBufferError.invalidDimensions
        }
        guard rgbaBytes.count == expectedCount else { throw RasterBufferError.invalidByteCount }
        self.width = width
        self.height = height
        self.tileSize = tileSize
        self.tiles = [:]

        let tileColumns = (width + tileSize - 1) / tileSize
        let tileRows = (height + tileSize - 1) / tileSize
        for tileY in 0..<tileRows {
            for tileX in 0..<tileColumns {
                var tile = Array(repeating: UInt8(0), count: tileByteCount)
                var hasData = false
                let startX = tileX * tileSize
                let startY = tileY * tileSize
                let endX = min(width, startX + tileSize)
                let endY = min(height, startY + tileSize)
                for y in startY..<endY {
                    for x in startX..<endX {
                        let source = (y * width + x) * 4
                        let local = ((y - startY) * tileSize + (x - startX)) * 4
                        tile[local] = rgbaBytes[source]
                        tile[local + 1] = rgbaBytes[source + 1]
                        tile[local + 2] = rgbaBytes[source + 2]
                        tile[local + 3] = rgbaBytes[source + 3]
                        if rgbaBytes[source] != 0 || rgbaBytes[source + 1] != 0 || rgbaBytes[source + 2] != 0 || rgbaBytes[source + 3] != 0 {
                            hasData = true
                        }
                    }
                }
                if hasData { tiles[RasterTileKeyV6(x: tileX, y: tileY)] = tile }
            }
        }
    }

    public var allocatedTileCount: Int { tiles.count }

    public func rgbaBytes() -> [UInt8] {
        guard let count = Self.checkedByteCount(width: width, height: height) else { return [] }
        var bytes = Array(repeating: UInt8(0), count: count)
        for y in 0..<height {
            for x in 0..<width {
                let pixel = pixel(x: x, y: y)
                let index = (y * width + x) * 4
                bytes[index] = pixel.r
                bytes[index + 1] = pixel.g
                bytes[index + 2] = pixel.b
                bytes[index + 3] = pixel.a
            }
        }
        return bytes
    }

    public func pixel(x: Int, y: Int) -> RasterPixelV6 {
        guard x >= 0, y >= 0, x < width, y < height else { return .clear }
        let key = RasterTileKeyV6(x: x / tileSize, y: y / tileSize)
        guard let data = tiles[key] else { return .clear }
        let localX = x % tileSize
        let localY = y % tileSize
        let index = (localY * tileSize + localX) * 4
        guard index >= 0, index + 3 < data.count else { return .clear }
        return .init(r: data[index], g: data[index + 1], b: data[index + 2], a: data[index + 3])
    }

    public mutating func setPixel(_ pixel: RasterPixelV6, x: Int, y: Int) throws {
        guard x >= 0, y >= 0, x < width, y < height else { throw RasterBufferError.outOfBounds }
        guard let tileByteCount = Self.checkedByteCount(width: tileSize, height: tileSize) else {
            throw RasterBufferError.invalidDimensions
        }
        let key = RasterTileKeyV6(x: x / tileSize, y: y / tileSize)
        var data = tiles[key] ?? Array(repeating: UInt8(0), count: tileByteCount)
        let localX = x % tileSize
        let localY = y % tileSize
        let index = (localY * tileSize + localX) * 4
        data[index] = pixel.r
        data[index + 1] = pixel.g
        data[index + 2] = pixel.b
        data[index + 3] = pixel.a
        tiles[key] = data
    }

    private static func checkedByteCount(width: Int, height: Int) -> Int? {
        let (pixels, pixelsOverflow) = width.multipliedReportingOverflow(by: height)
        guard !pixelsOverflow, pixels > 0 else { return nil }
        let (bytes, bytesOverflow) = pixels.multipliedReportingOverflow(by: 4)
        guard !bytesOverflow, bytes > 0 else { return nil }
        return bytes
    }
}
