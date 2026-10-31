import Foundation

public enum PencilFitter {
    public static func fit(samples: [CGPoint], tolerance: Double = 1.5, smoothing: Double = 0.75) -> BezierPathV6 {
        let cleaned = removeConsecutiveDuplicates(samples)
        guard cleaned.count > 1 else {
            return BezierPathV6(anchors: cleaned.map { PathAnchorV6(point: $0) })
        }
        let simplified = rdp(cleaned, epsilon: max(0.0001, tolerance))
        let points = simplified.count >= 2 ? simplified : [cleaned.first!, cleaned.last!]
        let smooth = min(1, max(0, smoothing))
        var anchors = points.map { PathAnchorV6(point: $0) }
        guard smooth > 0, anchors.count >= 2 else { return BezierPathV6(anchors: anchors) }

        for i in anchors.indices {
            let p = points[i]
            if i == 0 {
                let next = points[1]
                anchors[i].outHandle = CGPoint(
                    x: Double(p.x) + Double(next.x - p.x) * smooth / 3,
                    y: Double(p.y) + Double(next.y - p.y) * smooth / 3
                )
                anchors[i].kind = .smooth
            } else if i == anchors.count - 1 {
                let prev = points[i - 1]
                anchors[i].inHandle = CGPoint(
                    x: Double(p.x) - Double(p.x - prev.x) * smooth / 3,
                    y: Double(p.y) - Double(p.y - prev.y) * smooth / 3
                )
                anchors[i].kind = .smooth
            } else {
                let prev = points[i - 1], next = points[i + 1]
                let vx = Double(next.x - prev.x) * smooth / 6
                let vy = Double(next.y - prev.y) * smooth / 6
                anchors[i].inHandle = CGPoint(x: Double(p.x) - vx, y: Double(p.y) - vy)
                anchors[i].outHandle = CGPoint(x: Double(p.x) + vx, y: Double(p.y) + vy)
                anchors[i].kind = .smooth
            }
        }
        return BezierPathV6(anchors: anchors)
    }

    private static func removeConsecutiveDuplicates(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        for p in points {
            if let last = result.last, hypot(Double(p.x - last.x), Double(p.y - last.y)) < 1e-9 { continue }
            result.append(p)
        }
        return result
    }

    private static func rdp(_ points: [CGPoint], epsilon: Double) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let first = points[0], last = points[points.count - 1]
        var maxDistance = -1.0
        var splitIndex = 0
        for i in 1..<(points.count - 1) {
            let d = pointSegmentDistance(points[i], first, last)
            if d > maxDistance { maxDistance = d; splitIndex = i }
        }
        if maxDistance > epsilon {
            let left = rdp(Array(points[0...splitIndex]), epsilon: epsilon)
            let right = rdp(Array(points[splitIndex...]), epsilon: epsilon)
            return Array(left.dropLast()) + right
        }
        return [first, last]
    }
}
