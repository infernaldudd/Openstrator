import SwiftUI
import OpenstratorCore

/// Turns a non-uniform stroke profile on an open path into a proper filled
/// outline. Both the classic and M4 appearance renderers use this geometry.
enum StrokeProfileRenderer {
    static func outlinePoints(for object: VectorObject, width: Double) -> [CGPoint]? {
        guard let profile = object.strokeProfile, profile != .uniform,
              width.isFinite, width > 0,
              (object.kind == .line || object.kind == .path),
              object.isClosed != true else { return nil }

        if let anchors = object.bezierAnchors, anchors.count >= 2 {
            let bezier = BezierPathV6(anchors: anchors, isClosed: false)
            let points = StrokeOutlineV6.make(path: bezier, baseWidth: width, profile: profile)
            return points.count >= 4 ? points : nil
        }
        guard object.points.count >= 2 else { return nil }
        let points = StrokeOutlineV6.make(centerline: object.points.map(\.cgPoint), baseWidth: width, profile: profile)
        return points.count >= 4 ? points : nil
    }

    static func outlinePath(for object: VectorObject, width: Double) -> Path? {
        guard let points = outlinePoints(for: object, width: width), let first = points.first else { return nil }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}
