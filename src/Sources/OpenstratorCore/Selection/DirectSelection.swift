import Foundation

public enum PathComponent: Equatable, Sendable {
    case anchor(Int)
    case incomingHandle(Int)
    case outgoingHandle(Int)
    case segment(Int)

    public static func inHandle(_ index: Int) -> PathComponent { .incomingHandle(index) }
    public static func outHandle(_ index: Int) -> PathComponent { .outgoingHandle(index) }
}

public struct PathComponentHit: Equatable, Sendable {
    public var component: PathComponent
    public var distance: Double
    public init(component: PathComponent, distance: Double) {
        self.component = component
        self.distance = distance
    }
}

public enum HandleSide: Equatable, Sendable {
    case incoming
    case outgoing
}

public enum DirectSelection {
    public static func hitTest(path: BezierPathV6, point: CGPoint, tolerance: Double) -> PathComponentHit? {
        let tol = max(0, tolerance)
        var bestAnchor: PathComponentHit?
        for (i, a) in path.anchors.enumerated() {
            let d = distance(point, a.point)
            if d <= tol, d < (bestAnchor?.distance ?? .greatestFiniteMagnitude) {
                bestAnchor = .init(component: .anchor(i), distance: d)
            }
        }
        if let bestAnchor { return bestAnchor }

        var bestHandle: PathComponentHit?
        for (i, a) in path.anchors.enumerated() {
            if let h = a.inHandle {
                let d = distance(point, h)
                if d <= tol, d < (bestHandle?.distance ?? .greatestFiniteMagnitude) {
                    bestHandle = .init(component: .incomingHandle(i), distance: d)
                }
            }
            if let h = a.outHandle {
                let d = distance(point, h)
                if d <= tol, d < (bestHandle?.distance ?? .greatestFiniteMagnitude) {
                    bestHandle = .init(component: .outgoingHandle(i), distance: d)
                }
            }
        }
        if let bestHandle { return bestHandle }

        guard let hit = BezierGeometry.distance(from: point, to: path, tolerance: max(0.1, tol * 0.2)), hit.distance <= tol else {
            return nil
        }
        return .init(component: .segment(hit.segmentIndex), distance: hit.distance)
    }

    public static func moveAnchor(path: BezierPathV6, index: Int, to point: CGPoint) -> BezierPathV6 {
        guard path.anchors.indices.contains(index) else { return path }
        var result = path
        let old = result.anchors[index].point
        let dx = Double(point.x - old.x), dy = Double(point.y - old.y)
        result.anchors[index].point = point
        if let h = result.anchors[index].inHandle {
            result.anchors[index].inHandle = CGPoint(x: Double(h.x) + dx, y: Double(h.y) + dy)
        }
        if let h = result.anchors[index].outHandle {
            result.anchors[index].outHandle = CGPoint(x: Double(h.x) + dx, y: Double(h.y) + dy)
        }
        return result
    }

    public static func moveHandle(path: BezierPathV6, index: Int, side: HandleSide, to point: CGPoint) -> BezierPathV6 {
        guard path.anchors.indices.contains(index) else { return path }
        var result = path
        var a = result.anchors[index]
        let center = a.point

        switch side {
        case .incoming: a.inHandle = point
        case .outgoing: a.outHandle = point
        }

        switch a.kind {
        case .corner:
            break
        case .symmetric:
            let mirrored = CGPoint(x: 2 * Double(center.x) - Double(point.x), y: 2 * Double(center.y) - Double(point.y))
            switch side {
            case .incoming: a.outHandle = mirrored
            case .outgoing: a.inHandle = mirrored
            }
        case .smooth:
            let opposite: CGPoint?
            switch side {
            case .incoming: opposite = a.outHandle
            case .outgoing: opposite = a.inHandle
            }
            if let opposite {
                let oldLength = distance(center, opposite)
                let vx = Double(point.x - center.x), vy = Double(point.y - center.y)
                let len = hypot(vx, vy)
                if len > 1e-9 {
                    let ux = -vx / len, uy = -vy / len
                    let adjusted = CGPoint(x: Double(center.x) + ux * oldLength, y: Double(center.y) + uy * oldLength)
                    switch side {
                    case .incoming: a.outHandle = adjusted
                    case .outgoing: a.inHandle = adjusted
                    }
                }
            }
        }
        result.anchors[index] = a
        return result
    }

    public static func moveSegment(path: BezierPathV6, segmentIndex: Int, delta: CGSize) -> BezierPathV6 {
        let n = path.anchors.count
        guard n >= 2 else { return path }
        let segmentCount = path.isClosed ? n : n - 1
        guard segmentIndex >= 0 && segmentIndex < segmentCount else { return path }
        let startIndex = segmentIndex
        let endIndex = (segmentIndex + 1) % n
        var result = path
        result = moveAnchor(path: result, index: startIndex, to: CGPoint(
            x: Double(result.anchors[startIndex].point.x) + Double(delta.width),
            y: Double(result.anchors[startIndex].point.y) + Double(delta.height)
        ))
        result = moveAnchor(path: result, index: endIndex, to: CGPoint(
            x: Double(result.anchors[endIndex].point.x) + Double(delta.width),
            y: Double(result.anchors[endIndex].point.y) + Double(delta.height)
        ))
        return result
    }

    public static func convertAnchorKind(path: BezierPathV6, index: Int, to kind: AnchorKindV6) -> BezierPathV6 {
        guard path.anchors.indices.contains(index) else { return path }
        var result = path
        var anchor = result.anchors[index]
        anchor.kind = kind
        guard kind != .corner else {
            result.anchors[index] = anchor
            return result
        }

        if anchor.inHandle == nil && anchor.outHandle == nil {
            let prev = neighborPoint(path: path, index: index, delta: -1)
            let next = neighborPoint(path: path, index: index, delta: 1)
            if let prev, let next {
                let vx = Double(next.x - prev.x), vy = Double(next.y - prev.y)
                let len = hypot(vx, vy)
                if len > 1e-9 {
                    let scale = min(distance(anchor.point, prev), distance(anchor.point, next)) / 3
                    let ux = vx / len, uy = vy / len
                    anchor.inHandle = CGPoint(x: Double(anchor.point.x) - ux * scale, y: Double(anchor.point.y) - uy * scale)
                    anchor.outHandle = CGPoint(x: Double(anchor.point.x) + ux * scale, y: Double(anchor.point.y) + uy * scale)
                }
            }
        } else if kind == .symmetric {
            if let out = anchor.outHandle {
                anchor.inHandle = CGPoint(x: 2*Double(anchor.point.x)-Double(out.x), y: 2*Double(anchor.point.y)-Double(out.y))
            } else if let incoming = anchor.inHandle {
                anchor.outHandle = CGPoint(x: 2*Double(anchor.point.x)-Double(incoming.x), y: 2*Double(anchor.point.y)-Double(incoming.y))
            }
        }
        result.anchors[index] = anchor
        return result
    }

    private static func neighborPoint(path: BezierPathV6, index: Int, delta: Int) -> CGPoint? {
        let n = path.anchors.count
        guard n > 1 else { return nil }
        let candidate = index + delta
        if path.isClosed {
            return path.anchors[(candidate % n + n) % n].point
        }
        guard path.anchors.indices.contains(candidate) else { return nil }
        return path.anchors[candidate].point
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(Double(a.x - b.x), Double(a.y - b.y))
    }
}
