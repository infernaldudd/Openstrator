import Foundation

public enum AnchorKindV6: String, Codable, Equatable, Sendable {
    case corner
    case smooth
    case symmetric
}

public struct PathAnchorV6: Codable, Equatable, Sendable {
    public var point: CGPoint
    public var inHandle: CGPoint?
    public var outHandle: CGPoint?
    public var kind: AnchorKindV6

    public init(
        point: CGPoint,
        inHandle: CGPoint? = nil,
        outHandle: CGPoint? = nil,
        kind: AnchorKindV6 = .corner
    ) {
        self.point = point
        self.inHandle = inHandle
        self.outHandle = outHandle
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey { case point, inHandle, outHandle, kind }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        point = try c.decode(CGPoint.self, forKey: .point)
        inHandle = try c.decodeIfPresent(CGPoint.self, forKey: .inHandle)
        outHandle = try c.decodeIfPresent(CGPoint.self, forKey: .outHandle)
        kind = try c.decodeIfPresent(AnchorKindV6.self, forKey: .kind) ?? .corner
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(point, forKey: .point)
        try c.encodeIfPresent(inHandle, forKey: .inHandle)
        try c.encodeIfPresent(outHandle, forKey: .outHandle)
        try c.encode(kind, forKey: .kind)
    }
}

public struct BezierPathV6: Codable, Equatable, Sendable {
    public var anchors: [PathAnchorV6]
    public var isClosed: Bool

    public init(anchors: [PathAnchorV6], isClosed: Bool = false) {
        self.anchors = anchors
        self.isClosed = isClosed
    }
}

public struct CubicBezierSegmentV6: Equatable, Sendable {
    public var p0: CGPoint
    public var p1: CGPoint
    public var p2: CGPoint
    public var p3: CGPoint

    public init(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) {
        self.p0 = p0; self.p1 = p1; self.p2 = p2; self.p3 = p3
    }
}

public struct Vector2V6: Equatable, Sendable {
    public var dx: Double
    public var dy: Double
    public init(dx: Double, dy: Double) { self.dx = dx; self.dy = dy }
    public var length: Double { hypot(dx, dy) }
}

public enum BezierGeometry {
    public static func segments(of path: BezierPathV6) -> [CubicBezierSegmentV6] {
        guard path.anchors.count >= 2 else { return [] }
        var result: [CubicBezierSegmentV6] = []
        for i in 0..<(path.anchors.count - 1) {
            result.append(segment(from: path.anchors[i], to: path.anchors[i + 1]))
        }
        if path.isClosed, let first = path.anchors.first, let last = path.anchors.last {
            result.append(segment(from: last, to: first))
        }
        return result
    }

    public static func segment(at index: Int, in path: BezierPathV6) -> CubicBezierSegmentV6? {
        let segments = segments(of: path)
        guard segments.indices.contains(index) else { return nil }
        return segments[index]
    }

    public static func segment(from a: PathAnchorV6, to b: PathAnchorV6) -> CubicBezierSegmentV6 {
        CubicBezierSegmentV6(
            p0: a.point,
            p1: a.outHandle ?? a.point,
            p2: b.inHandle ?? b.point,
            p3: b.point
        )
    }

    public static func point(on s: CubicBezierSegmentV6, t rawT: Double) -> CGPoint {
        let t = min(1, max(0, rawT))
        let u = 1 - t
        let uu = u * u, tt = t * t
        let x = uu * u * Double(s.p0.x) + 3 * uu * t * Double(s.p1.x) + 3 * u * tt * Double(s.p2.x) + tt * t * Double(s.p3.x)
        let y = uu * u * Double(s.p0.y) + 3 * uu * t * Double(s.p1.y) + 3 * u * tt * Double(s.p2.y) + tt * t * Double(s.p3.y)
        return CGPoint(x: finite(x), y: finite(y))
    }

    public static func derivative(on s: CubicBezierSegmentV6, t rawT: Double) -> Vector2V6 {
        let t = min(1, max(0, rawT))
        let u = 1 - t
        let dx = 3 * u * u * (Double(s.p1.x) - Double(s.p0.x))
            + 6 * u * t * (Double(s.p2.x) - Double(s.p1.x))
            + 3 * t * t * (Double(s.p3.x) - Double(s.p2.x))
        let dy = 3 * u * u * (Double(s.p1.y) - Double(s.p0.y))
            + 6 * u * t * (Double(s.p2.y) - Double(s.p1.y))
            + 3 * t * t * (Double(s.p3.y) - Double(s.p2.y))
        return Vector2V6(dx: finite(dx), dy: finite(dy))
    }

    public static func split(_ s: CubicBezierSegmentV6, t rawT: Double) -> (left: CubicBezierSegmentV6, right: CubicBezierSegmentV6) {
        let t = min(1, max(0, rawT))
        let a = lerp(s.p0, s.p1, t)
        let b = lerp(s.p1, s.p2, t)
        let c = lerp(s.p2, s.p3, t)
        let d = lerp(a, b, t)
        let e = lerp(b, c, t)
        let f = lerp(d, e, t)
        return (
            CubicBezierSegmentV6(p0: s.p0, p1: a, p2: d, p3: f),
            CubicBezierSegmentV6(p0: f, p1: e, p2: c, p3: s.p3)
        )
    }

    public static func flatten(_ s: CubicBezierSegmentV6, tolerance: Double = 0.5) -> [CGPoint] {
        let tol = max(0.0001, tolerance)
        var output: [CGPoint] = [s.p0]
        flattenRecursive(s, tolerance: tol, depth: 0, into: &output)
        return output
    }

    public static func flatten(_ path: BezierPathV6, tolerance: Double = 0.5) -> [CGPoint] {
        let segs = segments(of: path)
        guard let first = segs.first else { return path.anchors.first.map { [$0.point] } ?? [] }
        var output = [first.p0]
        for s in segs {
            let pts = flatten(s, tolerance: tolerance)
            output.append(contentsOf: pts.dropFirst())
        }
        return output
    }

    public static func bounds(_ path: BezierPathV6) -> CGRect? {
        let segs = segments(of: path)
        if segs.isEmpty {
            guard let p = path.anchors.first?.point else { return nil }
            return CGRect(x: p.x, y: p.y, width: 0, height: 0)
        }
        var xs: [Double] = [], ys: [Double] = []
        for s in segs {
            xs.append(contentsOf: extremaValues(s, axis: 0))
            ys.append(contentsOf: extremaValues(s, axis: 1))
        }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public static func distance(from p: CGPoint, to s: CubicBezierSegmentV6, tolerance: Double = 0.35) -> Double {
        let pts = flatten(s, tolerance: tolerance)
        guard pts.count >= 2 else { return hypot(Double(p.x - s.p0.x), Double(p.y - s.p0.y)) }
        var best = Double.greatestFiniteMagnitude
        for i in 0..<(pts.count - 1) { best = min(best, pointSegmentDistance(p, pts[i], pts[i + 1])) }
        return best
    }

    public static func distance(from p: CGPoint, to path: BezierPathV6, tolerance: Double = 0.35) -> (distance: Double, segmentIndex: Int)? {
        let segs = segments(of: path)
        guard !segs.isEmpty else { return nil }
        var best = (Double.greatestFiniteMagnitude, 0)
        for (i, s) in segs.enumerated() {
            let d = distance(from: p, to: s, tolerance: tolerance)
            if d < best.0 { best = (d, i) }
        }
        return (best.0, best.1)
    }

    private static func flattenRecursive(_ s: CubicBezierSegmentV6, tolerance: Double, depth: Int, into output: inout [CGPoint]) {
        if depth >= 14 || flatness(s) <= tolerance {
            output.append(s.p3)
            return
        }
        let pair = split(s, t: 0.5)
        flattenRecursive(pair.left, tolerance: tolerance, depth: depth + 1, into: &output)
        flattenRecursive(pair.right, tolerance: tolerance, depth: depth + 1, into: &output)
    }

    private static func flatness(_ s: CubicBezierSegmentV6) -> Double {
        max(pointSegmentDistance(s.p1, s.p0, s.p3), pointSegmentDistance(s.p2, s.p0, s.p3))
    }

    private static func extremaValues(_ s: CubicBezierSegmentV6, axis: Int) -> [Double] {
        func v(_ p: CGPoint) -> Double { axis == 0 ? Double(p.x) : Double(p.y) }
        let p0 = v(s.p0), p1 = v(s.p1), p2 = v(s.p2), p3 = v(s.p3)
        var ts: [Double] = [0, 1]
        let a = -p0 + 3*p1 - 3*p2 + p3
        let b = 3*p0 - 6*p1 + 3*p2
        let c = -3*p0 + 3*p1
        let qa = 3*a, qb = 2*b, qc = c
        if abs(qa) < 1e-12 {
            if abs(qb) > 1e-12 {
                let t = -qc/qb
                if t > 0 && t < 1 { ts.append(t) }
            }
        } else {
            let disc = qb*qb - 4*qa*qc
            if disc >= 0 {
                let root = sqrt(max(0, disc))
                let t1 = (-qb + root)/(2*qa), t2 = (-qb - root)/(2*qa)
                if t1 > 0 && t1 < 1 { ts.append(t1) }
                if t2 > 0 && t2 < 1 { ts.append(t2) }
            }
        }
        return ts.map { axis == 0 ? Double(point(on: s, t: $0).x) : Double(point(on: s, t: $0).y) }
    }

    private static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: Double(a.x) + (Double(b.x) - Double(a.x)) * t,
                y: Double(a.y) + (Double(b.y) - Double(a.y)) * t)
    }

    private static func finite(_ v: Double) -> Double { v.isFinite ? v : 0 }
}
