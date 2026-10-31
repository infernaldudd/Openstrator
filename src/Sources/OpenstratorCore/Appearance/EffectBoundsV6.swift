import Foundation

public enum EffectBoundsV6 {
    public static func visualBounds(geometricBounds: CGRect, appearance: AppearanceStackV6) -> CGRect {
        var result = geometricBounds
        for entry in appearance.entries {
            guard case .effect(let effect) = entry, effect.enabled else { continue }
            result = bounds(after: effect, geometricBounds: geometricBounds, current: result)
        }
        return result
    }

    private static func number(_ effect: LiveEffectV6, _ key: String, _ fallback: Double = 0) -> Double {
        effect.parameters[key]?.numberValue ?? fallback
    }
    private static func integer(_ effect: LiveEffectV6, _ key: String, _ fallback: Int = 0) -> Int {
        effect.parameters[key]?.integerValue ?? fallback
    }

    private static func bounds(after effect: LiveEffectV6, geometricBounds: CGRect, current: CGRect) -> CGRect {
        switch effect.effectID {
        case "gaussianBlur":
            let margin = max(0, number(effect, "radius")) * 2
            return current.insetBy(dx: -margin, dy: -margin)
        case "motionBlur":
            let distance = max(0, number(effect, "distance"))
            let angle = number(effect, "angle") * .pi / 180
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            return current.union(current.offsetBy(dx: dx, dy: dy))
        case "dropShadow":
            let blur = max(0, number(effect, "blur")) * 2
            let shadow = current.offsetBy(dx: number(effect, "x"), dy: number(effect, "y")).insetBy(dx: -blur, dy: -blur)
            return current.union(shadow)
        case "outerGlow":
            let margin = max(0, number(effect, "blur")) * 2
            return current.insetBy(dx: -margin, dy: -margin)
        case "transform":
            let copies = max(0, integer(effect, "copies"))
            guard copies > 0 else { return transformedRect(current, effect: effect, multiplier: 1).union(current) }
            var union = current
            for copy in 1...copies {
                union = union.union(transformedRect(geometricBounds, effect: effect, multiplier: copy))
            }
            return union
        case "offsetPath":
            let margin = abs(number(effect, "offset"))
            return current.insetBy(dx: -margin, dy: -margin)
        case "roughen", "zigZag":
            let margin = max(0, number(effect, "size"))
            return current.insetBy(dx: -margin, dy: -margin)
        case "warp":
            let bend = abs(number(effect, "bend"))
            let margin = max(current.width, current.height) * bend * 0.25
            return current.insetBy(dx: -margin, dy: -margin)
        default:
            return current
        }
    }

    private static func transformedRect(_ rect: CGRect, effect: LiveEffectV6, multiplier: Int) -> CGRect {
        let m = Double(multiplier)
        let x = number(effect, "x") * m
        let y = number(effect, "y") * m
        let sx = pow(max(0.01, number(effect, "scaleX", 1)), m)
        let sy = pow(max(0.01, number(effect, "scaleY", 1)), m)
        let radians = number(effect, "rotation") * m * .pi / 180
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let cs = cos(radians)
        let sn = sin(radians)
        let matrix = AffineMatrixV6(
            a: cs * sx,
            b: sn * sx,
            c: -sn * sy,
            d: cs * sy,
            tx: x + Double(center.x) - (cs * sx * Double(center.x) + (-sn * sy) * Double(center.y)),
            ty: y + Double(center.y) - (sn * sx * Double(center.x) + cs * sy * Double(center.y))
        )
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)
        ].map { matrix.applying(to: $0) }
        guard let first = corners.first else { return rect }
        var minX = Double(first.x), maxX = Double(first.x), minY = Double(first.y), maxY = Double(first.y)
        for point in corners.dropFirst() {
            minX = min(minX, Double(point.x)); maxX = max(maxX, Double(point.x))
            minY = min(minY, Double(point.y)); maxY = max(maxY, Double(point.y))
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
