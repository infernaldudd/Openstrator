import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#else
public struct CGVector: Equatable, Sendable {
    public var dx: Double
    public var dy: Double
    public init(dx: Double, dy: Double) { self.dx = dx; self.dy = dy }
}
#endif

public struct CanvasTransform: Equatable, Sendable {
    public var viewportSize: CGSize
    public var artboardSize: CGSize
    public var zoom: Double
    public var pan: CGSize
    public var rotationDegrees: Double

    public init(viewportSize: CGSize, artboardSize: CGSize, zoom: Double, pan: CGSize, rotationDegrees: Double) {
        self.viewportSize = viewportSize
        self.artboardSize = artboardSize
        self.zoom = max(0.000_001, zoom)
        self.pan = pan
        self.rotationDegrees = rotationDegrees
    }

    private var angle: Double { rotationDegrees * .pi / 180 }

    public func viewportPoint(fromDocument p: CGPoint) -> CGPoint {
        let x = Double(p.x) - Double(artboardSize.width) / 2
        let y = Double(p.y) - Double(artboardSize.height) / 2
        let c = cos(angle), s = sin(angle)
        let rx = x * c - y * s
        let ry = x * s + y * c
        return CGPoint(
            x: rx * zoom + Double(viewportSize.width) / 2 + Double(pan.width),
            y: ry * zoom + Double(viewportSize.height) / 2 + Double(pan.height)
        )
    }

    public func documentPoint(fromViewport p: CGPoint) -> CGPoint {
        let sx = (Double(p.x) - Double(viewportSize.width) / 2 - Double(pan.width)) / zoom
        let sy = (Double(p.y) - Double(viewportSize.height) / 2 - Double(pan.height)) / zoom
        let c = cos(angle), s = sin(angle)
        let x = sx * c + sy * s
        let y = -sx * s + sy * c
        return CGPoint(x: x + Double(artboardSize.width) / 2, y: y + Double(artboardSize.height) / 2)
    }

    public func documentDelta(fromViewportDelta d: CGVector) -> CGVector {
        let sx = Double(d.dx) / zoom
        let sy = Double(d.dy) / zoom
        let c = cos(angle), s = sin(angle)
        return CGVector(dx: sx * c + sy * s, dy: -sx * s + sy * c)
    }
}
