import Foundation

/// Editable variable-width profiles for open vector paths. Older documents without
/// the optional profile retain their normal constant-width stroke behavior.
public enum StrokeWidthProfileV6: String, Codable, CaseIterable, Identifiable, Sendable {
    case uniform, taperBoth, taperStart, taperEnd, middleHeavy

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .uniform: return "Uniform"
        case .taperBoth: return "Taper Both Ends"
        case .taperStart: return "Taper Start"
        case .taperEnd: return "Taper End"
        case .middleHeavy: return "Middle Heavy"
        }
    }

    public func scale(at fraction: Double) -> Double {
        let t = fraction.isFinite ? min(1, max(0, fraction)) : 0
        let s = t * t * (3 - 2 * t) // smoothstep
        switch self {
        case .uniform: return 1
        case .taperBoth: return 0.04 + 0.96 * sin(Double.pi * t)
        case .taperStart: return 0.04 + 0.96 * s
        case .taperEnd: return 0.04 + 0.96 * (1 - s)
        case .middleHeavy: return 0.38 + 0.62 * sin(Double.pi * t)
        }
    }
}

/// Builds a fillable, finite outline polygon from a curve/polyline. This is
/// geometric stroke expansion, not a filter or a variable-width-looking shader.
public enum StrokeOutlineV6 {
    public static func make(path: BezierPathV6, baseWidth: Double, profile: StrokeWidthProfileV6, tolerance: Double = 0.35) -> [CGPoint] {
        guard !path.isClosed else { return [] } // closed seams need periodic width geometry
        let points = BezierGeometry.flatten(path, tolerance: min(2, max(0.1, tolerance)))
        return make(centerline: points, baseWidth: baseWidth, profile: profile)
    }

    public static func make(centerline: [CGPoint], baseWidth: Double, profile: StrokeWidthProfileV6) -> [CGPoint] {
        guard baseWidth.isFinite, baseWidth > 0, baseWidth < 100_000 else { return [] }
        var clean: [CGPoint] = []
        for point in centerline {
            guard point.x.isFinite, point.y.isFinite else { continue }
            if let last = clean.last, hypot(Double(point.x - last.x), Double(point.y - last.y)) < 0.000001 { continue }
            clean.append(point)
        }
        guard clean.count >= 2, clean.count <= 50_000 else { return [] }
        var distances = Array(repeating: 0.0, count: clean.count)
        for i in 1..<clean.count {
            distances[i] = distances[i-1] + hypot(Double(clean[i].x - clean[i-1].x), Double(clean[i].y - clean[i-1].y))
        }
        guard let total = distances.last, total.isFinite, total > 0 else { return [] }
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in clean.indices {
            let start = clean[max(0, i-1)]
            let end = clean[min(clean.count-1, i+1)]
            var dx = Double(end.x - start.x), dy = Double(end.y - start.y)
            let magnitude = hypot(dx, dy)
            guard magnitude.isFinite, magnitude > 0 else { return [] }
            dx /= magnitude; dy /= magnitude
            let radius = (baseWidth * profile.scale(at: distances[i] / total)) / 2
            let x = Double(clean[i].x), y = Double(clean[i].y)
            left.append(CGPoint(x: x - dy * radius, y: y + dx * radius))
            right.append(CGPoint(x: x + dy * radius, y: y - dx * radius))
        }
        return left + right.reversed()
    }
}
