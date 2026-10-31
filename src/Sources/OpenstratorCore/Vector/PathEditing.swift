import Foundation

public enum PathEditingError: Error, Equatable {
    case invalidSegment
    case invalidAnchor
    case insufficientAnchors
    case closedPathSplitRequiresTwoCuts
}

public enum PathEditor {
    public static func insertAnchor(path: BezierPathV6, segmentIndex: Int, t: Double) throws -> BezierPathV6 {
        guard path.anchors.count >= 2, let segment = BezierGeometry.segment(at: segmentIndex, in: path) else {
            throw PathEditingError.invalidSegment
        }
        let split = BezierGeometry.split(segment, t: min(1, max(0, t)))
        var result = path
        let n = path.anchors.count
        let isSeam = path.isClosed && segmentIndex == n - 1
        let startIndex = isSeam ? n - 1 : segmentIndex
        let endIndex = isSeam ? 0 : segmentIndex + 1
        guard result.anchors.indices.contains(startIndex), result.anchors.indices.contains(endIndex) else {
            throw PathEditingError.invalidSegment
        }

        result.anchors[startIndex].outHandle = split.left.p1
        result.anchors[endIndex].inHandle = split.right.p2
        let inserted = PathAnchorV6(
            point: split.left.p3,
            inHandle: split.left.p2,
            outHandle: split.right.p1,
            kind: .smooth
        )
        if isSeam { result.anchors.append(inserted) }
        else { result.anchors.insert(inserted, at: endIndex) }
        return result
    }

    public static func deleteAnchor(path: BezierPathV6, index: Int) throws -> BezierPathV6 {
        guard path.anchors.indices.contains(index) else { throw PathEditingError.invalidAnchor }
        guard path.anchors.count > 2 else { throw PathEditingError.insufficientAnchors }
        var result = path
        result.anchors.remove(at: index)
        return result
    }

    public static func reverse(_ path: BezierPathV6) -> BezierPathV6 {
        var reversed: [PathAnchorV6] = []
        reversed.reserveCapacity(path.anchors.count)
        for anchor in path.anchors.reversed() {
            reversed.append(PathAnchorV6(
                point: anchor.point,
                inHandle: anchor.outHandle,
                outHandle: anchor.inHandle,
                kind: anchor.kind
            ))
        }
        return BezierPathV6(anchors: reversed, isClosed: path.isClosed)
    }

    public static func join(_ lhs: BezierPathV6, _ rhs: BezierPathV6, tolerance: Double = 0.5) throws -> BezierPathV6 {
        guard !lhs.isClosed, !rhs.isClosed, lhs.anchors.count >= 1, rhs.anchors.count >= 1 else {
            throw PathEditingError.insufficientAnchors
        }
        let orientations: [(BezierPathV6, BezierPathV6)] = [
            (lhs, rhs), (reverse(lhs), rhs), (lhs, reverse(rhs)), (reverse(lhs), reverse(rhs))
        ]
        let best = orientations.min { a, b in
            endpointDistance(a.0, a.1) < endpointDistance(b.0, b.1)
        }!
        var a = best.0
        var b = best.1
        guard let aEnd = a.anchors.last, let bStart = b.anchors.first else { throw PathEditingError.insufficientAnchors }
        if pointDistance(aEnd.point, bStart.point) <= max(0, tolerance) {
            var merged = aEnd
            merged.outHandle = bStart.outHandle
            if merged.kind == .corner && bStart.kind != .corner { merged.kind = bStart.kind }
            a.anchors[a.anchors.count - 1] = merged
            b.anchors.removeFirst()
        }
        a.anchors.append(contentsOf: b.anchors)
        return a
    }

    public static func split(path: BezierPathV6, segmentIndex: Int, t: Double) throws -> (left: BezierPathV6, right: BezierPathV6) {
        if path.isClosed { throw PathEditingError.closedPathSplitRequiresTwoCuts }
        let inserted = try insertAnchor(path: path, segmentIndex: segmentIndex, t: t)
        let splitIndex = segmentIndex + 1
        guard inserted.anchors.indices.contains(splitIndex) else { throw PathEditingError.invalidSegment }
        var leftAnchors = Array(inserted.anchors[0...splitIndex])
        var rightAnchors = Array(inserted.anchors[splitIndex...])
        leftAnchors[leftAnchors.count - 1].outHandle = nil
        rightAnchors[0].inHandle = nil
        return (BezierPathV6(anchors: leftAnchors), BezierPathV6(anchors: rightAnchors))
    }

    /// Cuts a path at a segment parameter. Open paths become two paths; a closed path
    /// becomes one open path whose coincident endpoints are the exact cut location.
    public static func cut(path: BezierPathV6, segmentIndex: Int, t: Double) throws -> [BezierPathV6] {
        if !path.isClosed {
            let pair = try split(path: path, segmentIndex: segmentIndex, t: t)
            return [pair.left, pair.right]
        }
        let originalCount = path.anchors.count
        guard originalCount >= 2 else { throw PathEditingError.insufficientAnchors }
        let inserted = try insertAnchor(path: path, segmentIndex: segmentIndex, t: t)
        let cutIndex = segmentIndex == originalCount - 1 ? inserted.anchors.count - 1 : segmentIndex + 1
        guard inserted.anchors.indices.contains(cutIndex) else { throw PathEditingError.invalidSegment }

        let cutAnchor = inserted.anchors[cutIndex]
        var start = cutAnchor
        start.inHandle = nil
        var end = cutAnchor
        end.outHandle = nil

        var anchors: [PathAnchorV6] = [start]
        if inserted.anchors.count > 1 {
            for offset in 1..<inserted.anchors.count {
                let index = (cutIndex + offset) % inserted.anchors.count
                anchors.append(inserted.anchors[index])
            }
        }
        anchors.append(end)
        return [BezierPathV6(anchors: anchors, isClosed: false)]
    }

    public static func close(_ path: BezierPathV6) -> BezierPathV6 {
        var result = path
        if result.anchors.count >= 2 { result.isClosed = true }
        return result
    }

    public static func open(_ path: BezierPathV6) -> BezierPathV6 {
        var result = path
        result.isClosed = false
        return result
    }

    private static func endpointDistance(_ a: BezierPathV6, _ b: BezierPathV6) -> Double {
        guard let p = a.anchors.last?.point, let q = b.anchors.first?.point else { return .greatestFiniteMagnitude }
        return pointDistance(p, q)
    }

    private static func pointDistance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(Double(a.x - b.x), Double(a.y - b.y))
    }
}
