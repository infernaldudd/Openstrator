import Foundation

public struct PathBuilderAddResult: Equatable, Sendable {
    public var closed: Bool
    public var anchorIndex: Int?
    public init(closed: Bool, anchorIndex: Int?) { self.closed = closed; self.anchorIndex = anchorIndex }
}

public struct PenPathBuilder: Equatable, Sendable {
    public private(set) var path: BezierPathV6
    public var closeTolerance: Double

    public init(closeTolerance: Double = 8) {
        self.path = BezierPathV6(anchors: [])
        self.closeTolerance = max(0, closeTolerance)
    }

    @discardableResult
    public mutating func add(point: CGPoint, dragTo: CGPoint? = nil) -> PathBuilderAddResult {
        if path.anchors.count >= 2, let first = path.anchors.first?.point,
           hypot(Double(point.x - first.x), Double(point.y - first.y)) <= closeTolerance {
            path.isClosed = true
            return .init(closed: true, anchorIndex: nil)
        }
        var anchor = PathAnchorV6(point: point)
        if let dragTo, hypot(Double(dragTo.x - point.x), Double(dragTo.y - point.y)) > 0.25 {
            anchor.kind = .symmetric
            anchor.outHandle = dragTo
            anchor.inHandle = CGPoint(x: 2 * Double(point.x) - Double(dragTo.x), y: 2 * Double(point.y) - Double(dragTo.y))
        }
        path.anchors.append(anchor)
        return .init(closed: false, anchorIndex: path.anchors.count - 1)
    }

    public mutating func reset() { path = BezierPathV6(anchors: []) }
}

public struct CurvaturePathBuilder: Equatable, Sendable {
    public private(set) var path: BezierPathV6
    public var closeTolerance: Double

    public init(closeTolerance: Double = 8) {
        self.path = BezierPathV6(anchors: [])
        self.closeTolerance = max(0, closeTolerance)
    }

    @discardableResult
    public mutating func add(point: CGPoint) -> PathBuilderAddResult {
        if path.anchors.count >= 2, let first = path.anchors.first?.point,
           hypot(Double(point.x - first.x), Double(point.y - first.y)) <= closeTolerance {
            path.isClosed = true
            rebuildHandles()
            return .init(closed: true, anchorIndex: nil)
        }
        path.anchors.append(PathAnchorV6(point: point, kind: .smooth))
        rebuildHandles()
        return .init(closed: false, anchorIndex: path.anchors.count - 1)
    }

    public mutating func reset() { path = BezierPathV6(anchors: []) }

    private mutating func rebuildHandles() {
        let points = path.anchors.map(\.point)
        let n = points.count
        guard n >= 2 else {
            if n == 1 { path.anchors[0].inHandle = nil; path.anchors[0].outHandle = nil }
            return
        }
        for i in 0..<n {
            let p = points[i]
            if path.isClosed {
                let prev = points[(i - 1 + n) % n]
                let next = points[(i + 1) % n]
                let vx = Double(next.x - prev.x) / 6
                let vy = Double(next.y - prev.y) / 6
                path.anchors[i].inHandle = CGPoint(x: Double(p.x) - vx, y: Double(p.y) - vy)
                path.anchors[i].outHandle = CGPoint(x: Double(p.x) + vx, y: Double(p.y) + vy)
                path.anchors[i].kind = .smooth
            } else if i == 0 {
                let next = points[1]
                path.anchors[i].inHandle = nil
                path.anchors[i].outHandle = CGPoint(x: Double(p.x) + Double(next.x - p.x) / 3, y: Double(p.y) + Double(next.y - p.y) / 3)
                path.anchors[i].kind = .smooth
            } else if i == n - 1 {
                let prev = points[n - 2]
                path.anchors[i].inHandle = CGPoint(x: Double(p.x) - Double(p.x - prev.x) / 3, y: Double(p.y) - Double(p.y - prev.y) / 3)
                path.anchors[i].outHandle = nil
                path.anchors[i].kind = .smooth
            } else {
                let prev = points[i - 1], next = points[i + 1]
                let vx = Double(next.x - prev.x) / 6
                let vy = Double(next.y - prev.y) / 6
                path.anchors[i].inHandle = CGPoint(x: Double(p.x) - vx, y: Double(p.y) - vy)
                path.anchors[i].outHandle = CGPoint(x: Double(p.x) + vx, y: Double(p.y) + vy)
                path.anchors[i].kind = .smooth
            }
        }
    }
}
