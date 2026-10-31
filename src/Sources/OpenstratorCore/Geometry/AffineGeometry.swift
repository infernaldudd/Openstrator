import Foundation

public struct AffineMatrixV6: Equatable, Sendable {
    public var a: Double; public var b: Double; public var c: Double; public var d: Double; public var tx: Double; public var ty: Double
    public init(a: Double=1,b: Double=0,c: Double=0,d: Double=1,tx: Double=0,ty: Double=0){self.a=a;self.b=b;self.c=c;self.d=d;self.tx=tx;self.ty=ty}
    public static let identity = AffineMatrixV6()
    public func applying(to p: CGPoint) -> CGPoint { CGPoint(x: a*Double(p.x)+c*Double(p.y)+tx, y: b*Double(p.x)+d*Double(p.y)+ty) }
    public func concatenating(_ rhs: AffineMatrixV6) -> AffineMatrixV6 {
        AffineMatrixV6(a: a*rhs.a+c*rhs.b, b: b*rhs.a+d*rhs.b, c: a*rhs.c+c*rhs.d, d: b*rhs.c+d*rhs.d, tx: a*rhs.tx+c*rhs.ty+tx, ty: b*rhs.tx+d*rhs.ty+ty)
    }
    public func inverted() -> AffineMatrixV6? {
        let det = a*d-b*c; guard abs(det) > 1e-12 else { return nil }
        let ia=d/det, ib = -b/det, ic = -c/det, id = a/det
        return AffineMatrixV6(a: ia,b: ib,c: ic,d: id,tx: -(ia*tx+ic*ty),ty: -(ib*tx+id*ty))
    }
}

public extension NodeTransform {
    var affineMatrix: AffineMatrixV6 {
        let r = rotationDegrees * .pi / 180
        let cs = cos(r), sn = sin(r)
        let la = scaleX, lb = shearY, lc = shearX, ld = scaleY
        return AffineMatrixV6(
            a: cs*la - sn*lb,
            b: sn*la + cs*lb,
            c: cs*lc - sn*ld,
            d: sn*lc + cs*ld,
            tx: translationX,
            ty: translationY
        )
    }
}

public enum GeometryResolver {
    public static func localBounds(of node: DocumentNode) -> CGRect? {
        switch node.payload {
        case let .rectangle(v): return v.rect
        case let .ellipse(v): return v.rect
        case let .polygon(v): return v.rect
        case let .text(v): return v.frame
        case let .line(v), let .path(v):
            return BezierGeometry.bounds(v)
        default: return nil
        }
    }

    public static func worldTransform(nodeID: NodeID, in document: DocumentV6) -> AffineMatrixV6? {
        guard let node = document.node(id: nodeID) else { return nil }
        var chain: [DocumentNode] = [node]
        var current = nodeID
        while let parent = document.parent(of: current), parent != document.rootID {
            guard let pn = document.node(id: parent) else { break }
            chain.append(pn); current = parent
        }
        var matrix = AffineMatrixV6.identity
        for n in chain.reversed() { matrix = matrix.concatenating(n.transform.affineMatrix) }
        return matrix
    }

    public static func transformedCorners(nodeID: NodeID, in document: DocumentV6) -> [CGPoint] {
        guard let node=document.node(id:nodeID), let bounds=localBounds(of:node), let m=worldTransform(nodeID:nodeID,in:document) else { return [] }
        let pts=[CGPoint(x:bounds.minX,y:bounds.minY),CGPoint(x:bounds.maxX,y:bounds.minY),CGPoint(x:bounds.maxX,y:bounds.maxY),CGPoint(x:bounds.minX,y:bounds.maxY)]
        return pts.map{m.applying(to:$0)}
    }

    public static func geometricBounds(nodeID: NodeID, in document: DocumentV6) -> CGRect? {
        let points=transformedCorners(nodeID:nodeID,in:document); guard let f=points.first else{return nil}
        var minX=Double(f.x), maxX=minX, minY=Double(f.y), maxY=minY
        for p in points.dropFirst(){ minX=min(minX,Double(p.x)); maxX=max(maxX,Double(p.x)); minY=min(minY,Double(p.y)); maxY=max(maxY,Double(p.y)) }
        return CGRect(x:minX,y:minY,width:maxX-minX,height:maxY-minY)
    }
}

func pointSegmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
    let px=Double(p.x), py=Double(p.y), ax=Double(a.x), ay=Double(a.y), bx=Double(b.x), by=Double(b.y)
    let dx=bx-ax, dy=by-ay, l2=dx*dx+dy*dy
    if l2 <= 1e-12 { return hypot(px-ax,py-ay) }
    let t=max(0,min(1,((px-ax)*dx+(py-ay)*dy)/l2))
    return hypot(px-(ax+t*dx),py-(ay+t*dy))
}
