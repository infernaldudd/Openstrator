import Foundation

public struct GridMetrics: Equatable, Sendable {
    public var documentSpacing: Double
    public var viewportLineWidth: Double
    public var pixelAlignedOffset: Double

    public static func make(baseSpacing: Double, zoom: Double, screenScale: Double) -> GridMetrics {
        let safeZoom = max(0.000_001, zoom)
        let safeBase = max(0.000_001, baseSpacing)
        let target = safeBase / safeZoom
        let ratio = target / safeBase
        let exponent = round(log2(ratio))
        let spacing = safeBase * pow(2, exponent)
        let scale = max(1, screenScale)
        return GridMetrics(documentSpacing: spacing, viewportLineWidth: 1 / scale, pixelAlignedOffset: 0.5 / scale)
    }
}

public func snap(point: CGPoint, spacing: Double) -> CGPoint {
    let s = max(0.000_001, spacing)
    return CGPoint(x: (Double(point.x) / s).rounded() * s, y: (Double(point.y) / s).rounded() * s)
}
