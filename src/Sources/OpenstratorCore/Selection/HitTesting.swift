import Foundation

public struct HitTestOptions: Equatable, Sendable {
    public var includeLocked: Bool
    public var tolerance: Double
    public init(includeLocked: Bool=false, tolerance: Double=4) { self.includeLocked=includeLocked; self.tolerance=tolerance }
}
public enum HitPart: String, Equatable, Sendable { case fill, stroke, text }
public struct HitResult: Equatable, Sendable { public var nodeID: NodeID; public var part: HitPart; public var distance: Double; public init(nodeID:NodeID,part:HitPart,distance:Double){self.nodeID=nodeID;self.part=part;self.distance=distance} }

public enum HitTester {
    public static func hitTest(point: CGPoint, in document: DocumentV6, options: HitTestOptions = HitTestOptions()) -> HitResult? {
        var candidates: [(Int, HitResult)] = []
        var paintIndex = 0
        func walk(_ id: NodeID, inheritedVisible: Bool, inheritedLocked: Bool) {
            guard let node=document.node(id:id) else{return}
            let visible=inheritedVisible && node.isVisible
            let locked=inheritedLocked || node.isLocked
            guard visible else{return}
            for child in node.children { walk(child, inheritedVisible: visible, inheritedLocked: locked) }
            defer { paintIndex += 1 }
            guard !(locked && !options.includeLocked), let m=GeometryResolver.worldTransform(nodeID:id,in:document), let inv=m.inverted() else{return}
            let lp=inv.applying(to:point)
            if let hit=localHit(node:node,point:lp,tolerance:options.tolerance){ candidates.append((paintIndex,HitResult(nodeID:id,part:hit.0,distance:hit.1))) }
        }
        walk(document.rootID,inheritedVisible:true,inheritedLocked:false)
        return candidates.sorted { l,r in
            if abs(l.1.distance-r.1.distance) > 0.0001 { return l.1.distance < r.1.distance }
            return l.0 > r.0
        }.first?.1
    }

    private static func localHit(node: DocumentNode, point p: CGPoint, tolerance: Double) -> (HitPart,Double)? {
        let tol=max(0,tolerance)
        switch node.payload {
        case let .rectangle(v): return rectHit(v.rect,node:node,p:p,tol:tol)
        case let .polygon(v): return rectHit(v.rect,node:node,p:p,tol:tol)
        case let .ellipse(v):
            let r=v.rect; guard r.width>0,r.height>0 else{return nil}
            let cx=Double(r.midX),cy=Double(r.midY),rx=Double(r.width)/2,ry=Double(r.height)/2
            let nx=(Double(p.x)-cx)/rx, ny=(Double(p.y)-cy)/ry, q=nx*nx+ny*ny
            if q <= 1 && (node.appearance.fill.a>0 || node.appearance.gradient != nil){return(.fill,0)}
            let edge=abs(sqrt(q)-1)*min(rx,ry)
            if node.appearance.stroke.width>0 && edge <= node.appearance.stroke.width/2+tol{return(.stroke,edge)}
            return nil
        case let .line(path), let .path(path):
            guard path.anchors.count >= 2 else { return nil }
            let best = BezierGeometry.distance(from: p, to: path, tolerance: max(0.15, tol * 0.25))?.distance ?? .greatestFiniteMagnitude
            if best <= max(tol, 0.5) + node.appearance.stroke.width / 2 { return (.stroke, best) }
            let pts = BezierGeometry.flatten(path, tolerance: max(0.2, tol * 0.25))
            if path.isClosed && node.appearance.fill.a > 0 && pts.count >= 3 && pointInPolygon(p, pts) { return (.fill, 0) }
            return nil
        case let .text(v): return v.frame.insetBy(dx:-tol,dy:-tol).contains(p) ? (.text,0) : nil
        default:return nil
        }
    }

    private static func rectHit(_ r:CGRect,node:DocumentNode,p:CGPoint,tol:Double)->(HitPart,Double)?{
        if r.contains(p) && (node.appearance.fill.a>0 || node.appearance.gradient != nil){return(.fill,0)}
        if node.appearance.stroke.width>0 && r.insetBy(dx:-(node.appearance.stroke.width/2+tol),dy:-(node.appearance.stroke.width/2+tol)).contains(p){return(.stroke,0)}
        return nil
    }

    private static func pointInPolygon(_ p:CGPoint,_ pts:[CGPoint])->Bool{
        var inside=false; var j=pts.count-1
        for i in 0..<pts.count {
            let xi=Double(pts[i].x), yi=Double(pts[i].y), xj=Double(pts[j].x), yj=Double(pts[j].y), py=Double(p.y), px=Double(p.x)
            if ((yi>py) != (yj>py)) && px < (xj-xi)*(py-yi)/(yj-yi+1e-15)+xi { inside.toggle() }
            j=i
        }
        return inside
    }
}
