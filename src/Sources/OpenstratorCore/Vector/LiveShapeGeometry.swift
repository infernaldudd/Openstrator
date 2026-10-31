import Foundation

public enum LiveShapeGeometry {
    private static let kappa = 0.552_284_749_830_793_6

    public static func rectangle(in rawRect: CGRect) -> BezierPathV6 {
        let r = rawRect.standardized
        return BezierPathV6(anchors: [
            .init(point:.init(x:r.minX,y:r.minY)), .init(point:.init(x:r.maxX,y:r.minY)),
            .init(point:.init(x:r.maxX,y:r.maxY)), .init(point:.init(x:r.minX,y:r.maxY))
        ], isClosed:true)
    }

    public static func roundedRectangle(in rawRect: CGRect, cornerRadius: Double) -> BezierPathV6 {
        let r = rawRect.standardized
        let radius = min(max(0, cornerRadius), min(Double(r.width), Double(r.height)) / 2)
        if radius <= 1e-9 { return rectangle(in:r) }
        let k = kappa * radius
        var a: [PathAnchorV6] = [
            .init(point:.init(x:Double(r.minX)+radius,y:r.minY)),
            .init(point:.init(x:Double(r.maxX)-radius,y:r.minY)),
            .init(point:.init(x:r.maxX,y:Double(r.minY)+radius)),
            .init(point:.init(x:r.maxX,y:Double(r.maxY)-radius)),
            .init(point:.init(x:Double(r.maxX)-radius,y:r.maxY)),
            .init(point:.init(x:Double(r.minX)+radius,y:r.maxY)),
            .init(point:.init(x:r.minX,y:Double(r.maxY)-radius)),
            .init(point:.init(x:r.minX,y:Double(r.minY)+radius))
        ]
        a[1].outHandle = CGPoint(x:Double(a[1].point.x)+k,y:a[1].point.y)
        a[2].inHandle = CGPoint(x:a[2].point.x,y:Double(a[2].point.y)-k)
        a[3].outHandle = CGPoint(x:a[3].point.x,y:Double(a[3].point.y)+k)
        a[4].inHandle = CGPoint(x:Double(a[4].point.x)+k,y:a[4].point.y)
        a[5].outHandle = CGPoint(x:Double(a[5].point.x)-k,y:a[5].point.y)
        a[6].inHandle = CGPoint(x:a[6].point.x,y:Double(a[6].point.y)+k)
        a[7].outHandle = CGPoint(x:a[7].point.x,y:Double(a[7].point.y)-k)
        a[0].inHandle = CGPoint(x:Double(a[0].point.x)-k,y:a[0].point.y)
        return BezierPathV6(anchors:a,isClosed:true)
    }

    public static func ellipse(in rawRect: CGRect) -> BezierPathV6 {
        let r = rawRect.standardized
        let cx=Double(r.midX), cy=Double(r.midY), rx=Double(r.width)/2, ry=Double(r.height)/2
        let kx=kappa*rx, ky=kappa*ry
        return BezierPathV6(anchors:[
            .init(point:.init(x:cx+rx,y:cy), inHandle:.init(x:cx+rx,y:cy-ky), outHandle:.init(x:cx+rx,y:cy+ky), kind:.smooth),
            .init(point:.init(x:cx,y:cy+ry), inHandle:.init(x:cx+kx,y:cy+ry), outHandle:.init(x:cx-kx,y:cy+ry), kind:.smooth),
            .init(point:.init(x:cx-rx,y:cy), inHandle:.init(x:cx-rx,y:cy+ky), outHandle:.init(x:cx-rx,y:cy-ky), kind:.smooth),
            .init(point:.init(x:cx,y:cy-ry), inHandle:.init(x:cx-kx,y:cy-ry), outHandle:.init(x:cx+kx,y:cy-ry), kind:.smooth)
        ],isClosed:true)
    }

    public static func polygon(center: CGPoint, radius: Double, sides: Int, rotationDegrees: Double = -90) -> BezierPathV6 {
        let n=max(3,sides), r=max(0,radius), base=rotationDegrees * .pi / 180
        return BezierPathV6(anchors:(0..<n).map { i in
            let a=base + Double(i) * 2 * Double.pi / Double(n)
            return PathAnchorV6(point:.init(x:Double(center.x)+cos(a)*r,y:Double(center.y)+sin(a)*r))
        },isClosed:true)
    }

    public static func star(center: CGPoint, outerRadius: Double, innerRadius: Double, points: Int, rotationDegrees: Double = -90) -> BezierPathV6 {
        let n=max(2,points), outer=max(0,outerRadius), inner=max(0,innerRadius), base=rotationDegrees * .pi / 180
        return BezierPathV6(anchors:(0..<(n*2)).map { i in
            let a=base + Double(i) * Double.pi / Double(n), r = i % 2 == 0 ? outer : inner
            return PathAnchorV6(point:.init(x:Double(center.x)+cos(a)*r,y:Double(center.y)+sin(a)*r))
        },isClosed:true)
    }

    public static func arc(center: CGPoint, radius: Double, startAngleDegrees: Double, endAngleDegrees: Double) -> BezierPathV6 {
        let r=max(0,radius)
        let start=startAngleDegrees * .pi / 180, end=endAngleDegrees * .pi / 180
        let delta=end-start
        let count=max(1,Int(ceil(abs(delta)/(.pi/2))))
        let step=delta/Double(count)
        var anchors:[PathAnchorV6]=[]
        for i in 0..<count {
            let a0=start+Double(i)*step, a1=a0+step
            let p0=CGPoint(x:Double(center.x)+cos(a0)*r,y:Double(center.y)+sin(a0)*r)
            let p3=CGPoint(x:Double(center.x)+cos(a1)*r,y:Double(center.y)+sin(a1)*r)
            let factor=4.0/3.0*tan(step/4)*r
            let p1=CGPoint(x:Double(p0.x)-sin(a0)*factor,y:Double(p0.y)+cos(a0)*factor)
            let p2=CGPoint(x:Double(p3.x)+sin(a1)*factor,y:Double(p3.y)-cos(a1)*factor)
            if anchors.isEmpty { anchors.append(.init(point:p0,outHandle:p1,kind:.smooth)) }
            else { anchors[anchors.count-1].outHandle=p1; anchors[anchors.count-1].kind = .smooth }
            anchors.append(.init(point:p3,inHandle:p2,kind:.smooth))
        }
        return BezierPathV6(anchors:anchors)
    }

    public static func spiral(center: CGPoint, startRadius: Double, endRadius: Double, turns: Double, pointsPerTurn: Int = 24) -> BezierPathV6 {
        let count=max(2,Int(ceil(abs(turns)*Double(max(4,pointsPerTurn)))))
        let samples=(0...count).map { i -> CGPoint in
            let t=Double(i)/Double(count), angle=t * turns * 2 * Double.pi, radius=startRadius+(endRadius-startRadius)*t
            return CGPoint(x:Double(center.x)+cos(angle)*radius,y:Double(center.y)+sin(angle)*radius)
        }
        return PencilFitter.fit(samples:samples,tolerance:0.001,smoothing:0.85)
    }

    public static func rectangularGrid(in rawRect: CGRect, rows: Int, columns: Int) -> [BezierPathV6] {
        let r=rawRect.standardized, rowCount=max(1,rows), colCount=max(1,columns)
        var result:[BezierPathV6]=[]
        for i in 0...rowCount {
            let y=Double(r.minY)+Double(r.height)*Double(i)/Double(rowCount)
            result.append(line(.init(x:r.minX,y:y),.init(x:r.maxX,y:y)))
        }
        for i in 0...colCount {
            let x=Double(r.minX)+Double(r.width)*Double(i)/Double(colCount)
            result.append(line(.init(x:x,y:r.minY),.init(x:x,y:r.maxY)))
        }
        return result
    }

    public static func polarGrid(center: CGPoint, radius: Double, radialDivisions: Int, concentricDivisions: Int) -> [BezierPathV6] {
        let r=max(0,radius), radial=max(1,radialDivisions), rings=max(1,concentricDivisions)
        var result:[BezierPathV6]=[]
        for i in 1...rings {
            let rr=r*Double(i)/Double(rings)
            result.append(ellipse(in:CGRect(x:Double(center.x)-rr,y:Double(center.y)-rr,width:2*rr,height:2*rr)))
        }
        for i in 0..<radial {
            let a=Double(i) * 2 * Double.pi / Double(radial)
            result.append(line(center,CGPoint(x:Double(center.x)+cos(a)*r,y:Double(center.y)+sin(a)*r)))
        }
        return result
    }

    private static func line(_ a: CGPoint, _ b: CGPoint) -> BezierPathV6 {
        BezierPathV6(anchors:[.init(point:a),.init(point:b)])
    }
}
