import Foundation

public enum PathCompatibility {
    public static func flattenedPoints(_ path: BezierPathV6, tolerance: Double = 0.75) -> [CGPoint] {
        var points = BezierGeometry.flatten(path, tolerance: tolerance)
        if path.isClosed, points.count > 1, points.first == points.last { points.removeLast() }
        return points
    }

    public static func translatedAnchor(_ anchor: PathAnchorV6, dx: Double, dy: Double) -> PathAnchorV6 {
        func shift(_ p: CGPoint?) -> CGPoint? {
            p.map { CGPoint(x: Double($0.x) + dx, y: Double($0.y) + dy) }
        }
        return PathAnchorV6(
            point: CGPoint(x: Double(anchor.point.x) + dx, y: Double(anchor.point.y) + dy),
            inHandle: shift(anchor.inHandle),
            outHandle: shift(anchor.outHandle),
            kind: anchor.kind
        )
    }
}
