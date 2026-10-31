import Foundation

public enum SnapAxisV6: String, Equatable, Sendable { case x, y }
public enum SnapKindV6: String, Equatable, Sendable { case grid, guide, anchor, artboardEdge, artboardCenter }

public struct SnapCandidate: Equatable, Sendable {
    public var axis: SnapAxisV6
    public var position: Double
    public var kind: SnapKindV6
    public var distance: Double
    public init(axis: SnapAxisV6, position: Double, kind: SnapKindV6, distance: Double) {
        self.axis=axis; self.position=position; self.kind=kind; self.distance=distance
    }
}

public struct SnapOptionsV6: Equatable, Sendable {
    public var tolerance: Double
    public var grid: Bool
    public var guides: Bool
    public var anchors: Bool
    public var artboards: Bool
    public init(tolerance: Double = 6, grid: Bool = true, guides: Bool = true, anchors: Bool = true, artboards: Bool = true) {
        self.tolerance=max(0,tolerance); self.grid=grid; self.guides=guides; self.anchors=anchors; self.artboards=artboards
    }
}

public struct SnapResultV6: Equatable, Sendable {
    public var point: CGPoint
    public var candidates: [SnapCandidate]
    public init(point: CGPoint, candidates: [SnapCandidate]) { self.point=point; self.candidates=candidates }
}

public enum SnapEngine {
    public static func snap(point: CGPoint, document: DocumentV6, options: SnapOptionsV6 = SnapOptionsV6()) -> SnapResultV6 {
        var xCandidates: [SnapCandidate] = []
        var yCandidates: [SnapCandidate] = []
        let px=Double(point.x), py=Double(point.y), tolerance=options.tolerance

        func addX(_ position: Double, _ kind: SnapKindV6) {
            let d=abs(px-position); if d <= tolerance { xCandidates.append(.init(axis:.x,position:position,kind:kind,distance:d)) }
        }
        func addY(_ position: Double, _ kind: SnapKindV6) {
            let d=abs(py-position); if d <= tolerance { yCandidates.append(.init(axis:.y,position:position,kind:kind,distance:d)) }
        }

        if options.grid {
            let spacing=max(0.000001,document.grid.spacing)
            addX((px/spacing).rounded()*spacing,.grid)
            addY((py/spacing).rounded()*spacing,.grid)
        }

        if options.guides {
            for node in document.guides {
                guard case let .guide(g)=node.payload else { continue }
                if g.axis.lowercased().hasPrefix("v") { addX(g.position,.guide) }
                else { addY(g.position,.guide) }
            }
        }

        if options.anchors {
            for (id,node) in document.nodes {
                guard node.isVisible, !node.isLocked else { continue }
                let path: BezierPathV6
                switch node.payload {
                case let .path(p), let .line(p): path=p
                default: continue
                }
                guard let matrix=GeometryResolver.worldTransform(nodeID:id,in:document) else { continue }
                for anchor in path.anchors {
                    let world=matrix.applying(to:anchor.point)
                    addX(Double(world.x),.anchor); addY(Double(world.y),.anchor)
                }
            }
        }

        if options.artboards {
            for id in document.artboardIDs {
                guard let node=document.node(id:id), case let .artboard(a)=node.payload else { continue }
                let r=a.rect
                addX(Double(r.minX),.artboardEdge); addX(Double(r.maxX),.artboardEdge); addX(Double(r.midX),.artboardCenter)
                addY(Double(r.minY),.artboardEdge); addY(Double(r.maxY),.artboardEdge); addY(Double(r.midY),.artboardCenter)
            }
        }

        func better(_ a: SnapCandidate, _ b: SnapCandidate) -> Bool {
            if abs(a.distance-b.distance) > 1e-9 { return a.distance < b.distance }
            return priority(a.kind) < priority(b.kind)
        }
        let bestX=xCandidates.min(by:{ better($0,$1) })
        let bestY=yCandidates.min(by:{ better($0,$1) })
        let snapped=CGPoint(x:bestX?.position ?? px,y:bestY?.position ?? py)
        return SnapResultV6(point:snapped,candidates:[bestX,bestY].compactMap{$0})
    }

    private static func priority(_ kind: SnapKindV6) -> Int {
        switch kind { case .anchor:return 0; case .guide:return 1; case .artboardEdge:return 2; case .artboardCenter:return 3; case .grid:return 4 }
    }
}
