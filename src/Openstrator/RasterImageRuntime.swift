import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers
import OpenstratorCore

@MainActor
final class RasterImageCache {
    static let shared = RasterImageCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 64
        cache.totalCostLimit = 256 * 1024 * 1024
    }

    func image(for key: String) -> NSImage? { cache.object(forKey: key as NSString) }
    func insert(_ image: NSImage, key: String, cost: Int) {
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    func removeAll() { cache.removeAllObjects() }
}

@MainActor
enum RasterImageRuntime {
    enum ImportError: Error {
        case unreadable
        case unsupportedImage
    }

    static func image(assetID: UUID, document: OpenDocument, maxPixelDimension: Int) -> NSImage? {
        guard let asset = document.rasterAssets?.first(where: { $0.id == assetID }) else { return nil }
        return image(data: asset.embeddedData, cacheKey: assetID.uuidString, maxPixelDimension: maxPixelDimension)
    }

    static func image(data: Data, cacheKey: String, maxPixelDimension: Int) -> NSImage? {
        let dimension = max(64, min(8192, maxPixelDimension))
        let key = "\(cacheKey)-\(dimension)"
        if let cached = RasterImageCache.shared.image(for: key) { return cached }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: dimension,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width), height: CGFloat(cg.height)))
        RasterImageCache.shared.insert(image, key: key, cost: cg.width * cg.height * 4)
        return image
    }

    static func tileStore(assetID: UUID, document: OpenDocument, maxEditablePixels: Int = 40_000_000) -> RasterTileStoreV6? {
        guard maxEditablePixels > 0,
              let asset = document.rasterAssets?.first(where: { $0.id == assetID }),
              let source = CGImageSourceCreateWithData(asset.embeddedData as CFData, nil) else { return nil }
        let maxDimension = max(asset.metadata.pixelWidth, asset.metadata.pixelHeight)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              cg.width > 0, cg.height > 0,
              cg.width <= maxEditablePixels, cg.height <= maxEditablePixels / cg.width else { return nil }
        let width = cg.width
        let height = cg.height
        var bytes = Array(repeating: UInt8(0), count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: colorSpace, bitmapInfo: info.rawValue
        ) else { return nil }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        for index in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Int(bytes[index + 3])
            if alpha > 0 && alpha < 255 {
                bytes[index] = UInt8(min(255, Int(bytes[index]) * 255 / alpha))
                bytes[index + 1] = UInt8(min(255, Int(bytes[index + 1]) * 255 / alpha))
                bytes[index + 2] = UInt8(min(255, Int(bytes[index + 2]) * 255 / alpha))
            }
        }
        return try? RasterTileStoreV6(width: width, height: height, rgbaBytes: bytes)
    }

    static func pngData(from store: RasterTileStoreV6) -> Data? {
        var bytes = store.rgbaBytes()
        guard !bytes.isEmpty else { return nil }
        for index in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Int(bytes[index + 3])
            if alpha < 255 {
                bytes[index] = UInt8(Int(bytes[index]) * alpha / 255)
                bytes[index + 1] = UInt8(Int(bytes[index + 1]) * alpha / 255)
                bytes[index + 2] = UInt8(Int(bytes[index + 2]) * alpha / 255)
            }
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(
                width: store.width, height: store.height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: store.width * 4, space: colorSpace, bitmapInfo: info, provider: provider,
                decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func metadataAndEmbeddedAsset(from url: URL) throws -> RasterAssetRecord {
        let embeddedData = try Data(contentsOf: url)
        guard let source = CGImageSourceCreateWithData(embeddedData as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw ImportError.unsupportedImage
        }

        let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        guard width > 0, height > 0 else { throw ImportError.unreadable }

        let dpiWidth = (props[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue
        let dpiHeight = (props[kCGImagePropertyDPIHeight] as? NSNumber)?.doubleValue
        let dpi = [dpiWidth, dpiHeight].compactMap { $0 }.first(where: { $0.isFinite && $0 > 0 }) ?? 72
        let type = UTType(filenameExtension: url.pathExtension)
        let mime = type?.preferredMIMEType ?? "application/octet-stream"

        return RasterAssetRecord(
            id: UUID(),
            metadata: RasterAssetMetadataV6(pixelWidth: width, pixelHeight: height, dpi: dpi, mimeType: mime),
            embeddedData: embeddedData
        )
    }
}
