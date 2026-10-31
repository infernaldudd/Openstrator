import Foundation

public struct TextGlyphPlacementV6: Equatable, Sendable {
    public var glyphIndex: Int
    public var point: CGPoint
    public var angleDegrees: Double
    public var scaleX: Double
    public var scaleY: Double
    public init(glyphIndex: Int, point: CGPoint, angleDegrees: Double = 0, scaleX: Double = 1, scaleY: Double = 1) {
        self.glyphIndex = glyphIndex
        self.point = point
        self.angleDegrees = angleDegrees
        self.scaleX = scaleX
        self.scaleY = scaleY
    }
}

public enum TextPathLayout {
    public static func placements(
        advances: [Double],
        path: BezierPathV6,
        startOffset: Double,
        endOffset: Double,
        baselineOffset: Double,
        flip: Bool
    ) -> [TextGlyphPlacementV6] {
        guard !advances.isEmpty else { return [] }
        let points = BezierGeometry.flatten(path, tolerance: 0.35)
        guard points.count >= 2 else { return [] }
        var cumulative: [Double] = [0]
        cumulative.reserveCapacity(points.count)
        for i in 1..<points.count {
            cumulative.append(cumulative.last! + hypot(Double(points[i].x - points[i-1].x), Double(points[i].y - points[i-1].y)))
        }
        guard let total = cumulative.last, total > 0 else { return [] }
        let usableEnd = max(startOffset, total - max(0, endOffset))
        var cursor = max(0, startOffset)
        var result: [TextGlyphPlacementV6] = []
        for (index, advanceRaw) in advances.enumerated() {
            let advance = max(0.1, advanceRaw)
            let center = cursor + advance / 2
            guard center <= usableEnd else { break }
            let sample = samplePolyline(points: points, cumulative: cumulative, distance: min(total, center))
            let sign = flip ? -1.0 : 1.0
            let nx = -sin(sample.angleRadians) * baselineOffset * sign
            let ny = cos(sample.angleRadians) * baselineOffset * sign
            var degrees = sample.angleRadians * 180 / Double.pi
            if flip { degrees += 180 }
            result.append(TextGlyphPlacementV6(
                glyphIndex: index,
                point: CGPoint(x: Double(sample.point.x) + nx, y: Double(sample.point.y) + ny),
                angleDegrees: degrees
            ))
            cursor += advance
        }
        return result
    }

    public static func applying(_ transform: GlyphTransformV6, to placement: TextGlyphPlacementV6) -> TextGlyphPlacementV6 {
        var out = placement
        out.point = CGPoint(x: Double(out.point.x) + transform.offsetX, y: Double(out.point.y) + transform.offsetY)
        out.angleDegrees += transform.rotationDegrees
        out.scaleX *= max(0.01, transform.scaleX)
        out.scaleY *= max(0.01, transform.scaleY)
        return out
    }

    private static func samplePolyline(points: [CGPoint], cumulative: [Double], distance: Double) -> (point: CGPoint, angleRadians: Double) {
        let d = min(max(0, distance), cumulative.last ?? 0)
        var index = 1
        while index < cumulative.count && cumulative[index] < d { index += 1 }
        index = min(max(1, index), points.count - 1)
        let a = points[index - 1], b = points[index]
        let start = cumulative[index - 1], end = cumulative[index]
        let t = end > start ? (d - start) / (end - start) : 0
        let p = CGPoint(x: Double(a.x) + Double(b.x - a.x) * t, y: Double(a.y) + Double(b.y - a.y) * t)
        let angle = atan2(Double(b.y - a.y), Double(b.x - a.x))
        return (p, angle)
    }
}

public struct TextWarpOffsetV6: Equatable, Sendable {
    public var dx: Double
    public var dy: Double
    public var rotationDegrees: Double
    public var scaleX: Double
    public var scaleY: Double
    public init(dx: Double = 0, dy: Double = 0, rotationDegrees: Double = 0, scaleX: Double = 1, scaleY: Double = 1) {
        self.dx = dx; self.dy = dy; self.rotationDegrees = rotationDegrees; self.scaleX = scaleX; self.scaleY = scaleY
    }
}

public enum TextWarpEngine {
    public static func offset(normalizedX xRaw: Double, normalizedY yRaw: Double, warp: TextWarpV6, frame: CGSize) -> TextWarpOffsetV6 {
        let x = min(1, max(0, xRaw))
        let y = min(1, max(0, yRaw))
        let centeredX = (x - 0.5) * 2
        let w = max(1, Double(frame.width)), h = max(1, Double(frame.height))
        let bend = min(1, max(-1, warp.bend))
        let hDist = min(1, max(-1, warp.horizontalDistortion))
        let vDist = min(1, max(-1, warp.verticalDistortion))
        var out = TextWarpOffsetV6(dx: hDist * (y - 0.5) * w * 0.35, dy: vDist * centeredX * h * 0.35)
        switch warp.style {
        case .none: break
        case .arc:
            out.dy += (1 - centeredX * centeredX) * bend * h * 0.5
            out.rotationDegrees += -centeredX * bend * 25
        case .arch:
            out.dy += cos(centeredX * Double.pi / 2) * bend * h * 0.45
        case .bulge:
            let bulge = (1 - centeredX * centeredX) * bend
            out.scaleY *= max(0.1, 1 + bulge * 0.8)
        case .flag:
            out.dy += sin(x * Double.pi * 2) * bend * h * 0.35
            out.rotationDegrees += cos(x * Double.pi * 2) * bend * 12
        case .fish:
            out.dy += sin(x * Double.pi) * bend * h * (0.5 - y)
            out.scaleX *= max(0.1, 1 + sin(x * Double.pi) * bend * 0.5)
        case .inflate:
            let k = (1 - centeredX * centeredX) * bend
            out.scaleY *= max(0.1, 1 + k * 0.9)
            out.dy += (y - 0.5) * k * h * 0.25
        case .rise:
            out.dy += centeredX * bend * h * 0.5
        case .shellLower:
            out.dy += x * x * bend * h * 0.55
        case .shellUpper:
            out.dy += (1 - x) * (1 - x) * bend * h * 0.55
        case .squeeze:
            out.scaleX *= max(0.1, 1 - (1 - centeredX * centeredX) * abs(bend) * 0.65)
        case .wave:
            out.dy += sin(x * Double.pi * 2) * bend * h * 0.4
        }
        return out
    }
}
