import Foundation

public enum ResizeHandleV6: String, Codable, Sendable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight
}

public struct TransformModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let preserveAspect = TransformModifiers(rawValue: 1 << 0)
    public static let fromCenter = TransformModifiers(rawValue: 1 << 1)
    public static let axisConstraint = TransformModifiers(rawValue: 1 << 2)
}

public struct MoveSession: Sendable {
    public var startPointer: CGPoint
    public var originals: [NodeID: NodeTransform]
    public init(startPointer: CGPoint, originals: [NodeID: NodeTransform]) { self.startPointer=startPointer; self.originals=originals }
    public func transforms(currentPointer: CGPoint) -> [NodeID: NodeTransform] {
        let dx = Double(currentPointer.x - startPointer.x)
        let dy = Double(currentPointer.y - startPointer.y)
        return originals.mapValues { original in
            var result = original
            result.translationX = original.translationX + dx
            result.translationY = original.translationY + dy
            return result
        }
    }
}

public struct ResizeResult: Sendable {
    public var bounds: CGRect
    public var transforms: [NodeID: NodeTransform]
}

public struct ResizeSession: Sendable {
    public let originalBounds: CGRect
    public let originals: [NodeID: NodeTransform]
    public let handle: ResizeHandleV6
    public let startPointer: CGPoint
    public let minimumSize: Double

    public init(originalBounds: CGRect, originals: [NodeID: NodeTransform], handle: ResizeHandleV6, startPointer: CGPoint, minimumSize: Double = 4) {
        self.originalBounds=originalBounds; self.originals=originals; self.handle=handle; self.startPointer=startPointer; self.minimumSize=minimumSize
    }

    public func result(pointerDocumentPoint p: CGPoint, modifiers: TransformModifiers) -> ResizeResult {
        let minSize = max(0.001, minimumSize)
        let originalCenter = CGPoint(x: originalBounds.midX, y: originalBounds.midY)
        var left = Double(originalBounds.minX), right = Double(originalBounds.maxX)
        var top = Double(originalBounds.minY), bottom = Double(originalBounds.maxY)
        var px = Double(p.x), py = Double(p.y)
        let affectsLeft = handle == .topLeft || handle == .left || handle == .bottomLeft
        let affectsRight = handle == .topRight || handle == .right || handle == .bottomRight
        let affectsTop = handle == .topLeft || handle == .top || handle == .topRight
        let affectsBottom = handle == .bottomLeft || handle == .bottom || handle == .bottomRight

        if modifiers.contains(.preserveAspect) && (affectsLeft || affectsRight) && (affectsTop || affectsBottom) {
            let ratio = max(0.000001, Double(originalBounds.width) / max(0.000001, Double(originalBounds.height)))
            if modifiers.contains(.fromCenter) {
                var dx = abs(px - Double(originalCenter.x))
                var dy = abs(py - Double(originalCenter.y))
                if dx >= dy { dy = dx / ratio } else { dx = dy * ratio }
                px = Double(originalCenter.x) + (px >= Double(originalCenter.x) ? dx : -dx)
                py = Double(originalCenter.y) + (py >= Double(originalCenter.y) ? dy : -dy)
            } else {
                let fixedX = affectsRight ? Double(originalBounds.minX) : Double(originalBounds.maxX)
                let fixedY = affectsBottom ? Double(originalBounds.minY) : Double(originalBounds.maxY)
                var dx = abs(px-fixedX), dy = abs(py-fixedY)
                if dx >= dy { dy = dx / ratio } else { dx = dy * ratio }
                px = fixedX + (px >= fixedX ? dx : -dx)
                py = fixedY + (py >= fixedY ? dy : -dy)
            }
        }

        if modifiers.contains(.fromCenter) {
            if affectsLeft || affectsRight {
                let half = abs(px - Double(originalCenter.x)); left = Double(originalCenter.x)-half; right = Double(originalCenter.x)+half
            }
            if affectsTop || affectsBottom {
                let half = abs(py - Double(originalCenter.y)); top = Double(originalCenter.y)-half; bottom = Double(originalCenter.y)+half
            }
        } else {
            if affectsLeft { left = px }
            if affectsRight { right = px }
            if affectsTop { top = py }
            if affectsBottom { bottom = py }
        }

        if right < left { swap(&left,&right) }
        if bottom < top { swap(&top,&bottom) }
        if right-left < minSize {
            let c=(left+right)/2; left=c-minSize/2; right=c+minSize/2
        }
        if bottom-top < minSize {
            let c=(top+bottom)/2; top=c-minSize/2; bottom=c+minSize/2
        }
        let bounds = CGRect(x:left,y:top,width:right-left,height:bottom-top)
        let sx = Double(bounds.width) / max(0.000001, Double(originalBounds.width))
        let sy = Double(bounds.height) / max(0.000001, Double(originalBounds.height))
        let tx = Double(bounds.midX - originalBounds.midX)
        let ty = Double(bounds.midY - originalBounds.midY)
        var transformed: [NodeID:NodeTransform] = [:]
        for (id,o) in originals {
            var n=o
            n.translationX = o.translationX + tx
            n.translationY = o.translationY + ty
            n.scaleX = o.scaleX * sx
            n.scaleY = o.scaleY * sy
            transformed[id]=n
        }
        return ResizeResult(bounds:bounds,transforms:transformed)
    }
}
