import Foundation

public enum RasterPixelFormatV6: String, Codable, Equatable, Sendable {
    case rgba8
}

public struct RasterAssetMetadataV6: Codable, Equatable, Sendable {
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var dpi: Double
    public var mimeType: String
    public var pixelFormat: RasterPixelFormatV6

    public init(pixelWidth: Int, pixelHeight: Int, dpi: Double = 72, mimeType: String, pixelFormat: RasterPixelFormatV6 = .rgba8) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.dpi = dpi
        self.mimeType = mimeType
        self.pixelFormat = pixelFormat
        normalize()
    }

    public mutating func normalize() {
        pixelWidth = max(1, pixelWidth)
        pixelHeight = max(1, pixelHeight)
        if !dpi.isFinite || dpi <= 0 { dpi = 72 }
        if mimeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { mimeType = "application/octet-stream" }
    }
}

public enum RasterFilterIDV6: String, Codable, CaseIterable, Equatable, Sendable {
    case gaussianBlur, motionBlur, exposure, brightnessContrast, saturation, hue, sepia, sharpen, noise, pixelate, crystallize, colorControls
}

public struct RasterFilterRecordV6: Codable, Equatable, Sendable, Identifiable {
    public var uuid: UUID
    public var id: RasterFilterIDV6
    public var parameters: [String: Double]
    public var enabled: Bool

    public init(uuid: UUID = UUID(), id: RasterFilterIDV6, parameters: [String: Double] = [:], enabled: Bool = true) {
        self.uuid = uuid
        self.id = id
        self.parameters = parameters
        self.enabled = enabled
    }

    public mutating func normalize() {
        func clamp(_ key: String, _ range: ClosedRange<Double>, _ fallback: Double) {
            let raw = parameters[key] ?? fallback
            let value = raw.isFinite ? raw : fallback
            parameters[key] = min(range.upperBound, max(range.lowerBound, value))
        }
        switch id {
        case .gaussianBlur: clamp("radius", 0...200, 8)
        case .motionBlur:
            clamp("distance", 0...500, 20)
            clamp("angle", -360...360, 0)
        case .exposure: clamp("ev", -10...10, 0)
        case .brightnessContrast:
            clamp("brightness", -1...1, 0)
            clamp("contrast", 0...4, 1)
        case .saturation: clamp("saturation", 0...2, 1)
        case .hue: clamp("angle", -360...360, 0)
        case .sepia: clamp("intensity", 0...1, 0.8)
        case .sharpen: clamp("sharpness", 0...2, 0.4)
        case .noise: clamp("amount", 0...1, 0.08)
        case .pixelate: clamp("scale", 1...250, 12)
        case .crystallize: clamp("radius", 1...250, 18)
        case .colorControls:
            clamp("brightness", -1...1, 0)
            clamp("contrast", 0...4, 1)
            clamp("saturation", 0...2, 1)
        }
    }
}

public struct RasterMaskV6: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var bytes: [UInt8]

    public init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = max(1, width)
        self.height = max(1, height)
        let (count, overflow) = self.width.multipliedReportingOverflow(by: self.height)
        let safeCount = overflow ? 1 : count
        if bytes.count == safeCount { self.bytes = bytes }
        else if bytes.count > safeCount { self.bytes = Array(bytes.prefix(safeCount)) }
        else { self.bytes = bytes + Array(repeating: 255, count: safeCount - bytes.count) }
        if overflow {
            self.width = 1
            self.height = 1
        }
    }
}

public struct RasterImageDataV6: Codable, Equatable, Sendable {
    public var assetID: UUID
    public var metadata: RasterAssetMetadataV6
    public var embeddedData: Data
    public var filters: [RasterFilterRecordV6]
    public var mask: RasterMaskV6?

    public init(assetID: UUID = UUID(), metadata: RasterAssetMetadataV6, embeddedData: Data, filters: [RasterFilterRecordV6] = [], mask: RasterMaskV6? = nil) {
        self.assetID = assetID
        self.metadata = metadata
        self.embeddedData = embeddedData
        self.filters = filters
        self.mask = mask
    }
}
