import SwiftUI
import CoreGraphics
import OpenstratorCore

/// M4 ordered appearance renderer. Legacy objects remain on VectorCanvasRenderer's
/// original pipeline until an M4 stack is persisted on the object.
enum AppearanceRenderer {
    static func draw(object: VectorObject, document: OpenDocument, context: inout GraphicsContext) {
        let stack = object.resolvedAppearanceStack
        context.drawLayer { root in
            root.opacity = stack.opacity
            root.blendMode = graphicsBlend(stack.blendMode)
            applyCompositeEffects(stack, object: object, to: &root)
            VectorCanvasRenderer.applyEffects(object, to: &root, include: { $0.liveEffectV6 == nil })

            let transforms = transformInstances(stack: stack, rect: object.bounds)
            for transform in transforms {
                root.drawLayer { instance in
                    applyObjectTransform(object, to: &instance)
                    if let transform { instance.concatenate(transform) }
                    drawPaintEntries(stack: stack, object: object, document: document, context: &instance)
                }
            }
        }
    }

    private static func drawPaintEntries(stack: AppearanceStackV6, object: VectorObject, document: OpenDocument, context: inout GraphicsContext) {
        for entry in stack.entries {
            switch entry {
            case .fill(let fill) where fill.enabled:
                context.drawLayer { layer in
                    layer.opacity = fill.opacity
                    layer.blendMode = graphicsBlend(fill.blendMode)
                    drawFill(fill, object: object, document: document, context: &layer)
                }
            case .stroke(let stroke) where stroke.enabled:
                context.drawLayer { layer in
                    layer.opacity = stroke.opacity
                    layer.blendMode = graphicsBlend(stroke.blendMode)
                    drawStroke(stroke, object: object, document: document, context: &layer)
                }
            case .effect:
                // Effects wrap the object composite in ordered stack order. Paint entries
                // stay separately editable and are never duplicated by the legacy renderer.
                continue
            default:
                continue
            }
        }
    }

    private static func drawFill(_ fill: FillAppearanceV6, object: VectorObject, document: OpenDocument, context: inout GraphicsContext) {
        if object.kind == .text {
            var copy = object
            copy.gradient = nil
            switch fill.paint {
            case .color(let value): copy.fill = rgba(value)
            case .linearGradient(let value):
                copy.gradient = LinearGradientModel(core: value)
                copy.fill = .clear
            }
            MainActor.assumeIsolated {
                TypographyRenderer.draw(object: copy, pathLookup: { id in
                    guard let pathObject = document.objects.first(where: { $0.id == id }), let anchors = pathObject.bezierAnchors else { return nil }
                    return BezierPathV6(anchors: anchors, isClosed: pathObject.isClosed == true)
                }, context: &context)
            }
            return
        }
        guard let path = geometryPath(object: object) else { return }
        switch fill.paint {
        case .color(let value):
            let color = rgba(value)
            guard color.a > 0 else { return }
            context.fill(path, with: .color(color.swiftUIColor))
        case .linearGradient(let value):
            let points = gradientPoints(angle: value.angleDegrees, rect: object.bounds)
            let gradient = Gradient(stops: value.stops.map { .init(color: rgba($0.color).swiftUIColor, location: $0.location) })
            context.fill(path, with: .linearGradient(gradient, startPoint: points.start, endPoint: points.end))
        }
    }

    private static func drawStroke(_ stroke: StrokeAppearanceV6, object: VectorObject, document: OpenDocument, context: inout GraphicsContext) {
        guard stroke.width > 0 else { return }
        if object.kind == .text {
            // M4 keeps text strokes editable in the stack; native text-stroke outlining is
            // deferred to the vector outline route rather than rasterizing text implicitly.
            return
        }
        guard let path = geometryPath(object: object) else { return }
        let style = StrokeStyle(
            lineWidth: max(0.5, stroke.width),
            lineCap: lineCap(stroke.cap),
            lineJoin: lineJoin(stroke.join),
            miterLimit: stroke.miterLimit,
            dash: stroke.dash.map { CGFloat($0) },
            dashPhase: 0
        )
        switch stroke.paint {
        case .color(let value):
            context.stroke(path, with: .color(rgba(value).swiftUIColor), style: style)
        case .linearGradient(let value):
            let points = gradientPoints(angle: value.angleDegrees, rect: object.bounds)
            let gradient = Gradient(stops: value.stops.map { .init(color: rgba($0.color).swiftUIColor, location: $0.location) })
            context.stroke(path, with: .linearGradient(gradient, startPoint: points.start, endPoint: points.end), style: style)
        }
    }

    private static func geometryPath(object: VectorObject) -> Path? {
        let rect = object.bounds
        if let conversion = object.resolvedAppearanceStack.entries.compactMap({ entry -> LiveEffectV6? in
            guard case .effect(let effect) = entry, effect.enabled, effect.effectID.hasPrefix("convert") else { return nil }
            return effect
        }).last {
            switch conversion.effectID {
            case "convertRectangle": return Path(roundedRect: rect, cornerRadius: 0)
            case "convertRoundedRectangle":
                let radius = conversion.parameters["radius"]?.numberValue ?? 0
                return Path(roundedRect: rect, cornerRadius: max(0, min(radius, min(rect.width, rect.height) / 2)))
            case "convertEllipse": return Path(ellipseIn: rect)
            default: break
            }
        }
        switch object.kind {
        case .rectangle:
            return Path(roundedRect: rect, cornerRadius: max(0, min(object.cornerRadius, min(rect.width, rect.height) / 2)))
        case .ellipse:
            return Path(ellipseIn: rect)
        case .polygon:
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            for index in 0..<6 {
                let angle = -Double.pi / 2 + Double(index) * 2 * Double.pi / 6
                let point = CGPoint(x: center.x + cos(angle) * rect.width / 2, y: center.y + sin(angle) * rect.height / 2)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath(); return path
        case .line, .path:
            if let anchors = object.bezierAnchors, !anchors.isEmpty {
                return swiftUIPath(from: BezierPathV6(anchors: anchors, isClosed: object.kind == .path && object.isClosed == true))
            }
            guard let first = object.points.first else { return nil }
            var path = Path(); path.move(to: first.cgPoint)
            for point in object.points.dropFirst() { path.addLine(to: point.cgPoint) }
            if object.kind == .path && object.isClosed == true { path.closeSubpath() }
            return path
        case .text, .image:
            return nil
        }
    }

    private static func applyCompositeEffects(_ stack: AppearanceStackV6, object: VectorObject, to context: inout GraphicsContext) {
        for entry in stack.entries {
            guard case .effect(let effect) = entry, effect.enabled else { continue }
            let n: (String, Double) -> Double = { effect.parameters[$0]?.numberValue ?? $1 }
            switch effect.effectID {
            case "gaussianBlur":
                context.addFilter(.blur(radius: max(0, n("radius", 0))))
            case "motionBlur":
                let distance = max(0, n("distance", 0)), angle = n("angle", 0) * .pi / 180
                context.addFilter(.blur(radius: distance * 0.45))
                context.translateBy(x: cos(angle) * distance * 0.25, y: sin(angle) * distance * 0.25)
            case "dropShadow":
                let color = rgba(effect.parameters["color"]?.colorValue ?? .black).swiftUIColor.opacity(n("opacity", 0.35))
                context.addFilter(.shadow(color: color, radius: max(0, n("blur", 8)), x: n("x", 4), y: n("y", 4)))
            case "outerGlow":
                let color = rgba(effect.parameters["color"]?.colorValue ?? .white).swiftUIColor.opacity(n("opacity", 0.5))
                context.addFilter(.shadow(color: color, radius: max(0, n("blur", 10)), x: 0, y: 0))
            case "innerShadow":
                let color = rgba(effect.parameters["color"]?.colorValue ?? .black).swiftUIColor.opacity(n("opacity", 0.35))
                context.addFilter(.shadow(color: color, radius: max(0, n("blur", 6)), x: n("x", 3), y: n("y", 3)))
            case "innerGlow":
                let color = rgba(effect.parameters["color"]?.colorValue ?? .white).swiftUIColor.opacity(n("opacity", 0.4))
                context.addFilter(.shadow(color: color, radius: max(0, n("blur", 8)), x: 0, y: 0))
            case "puckerBloat":
                let amount = n("amount", 0)
                let scale = max(0.05, 1 + amount * 0.25)
                centeredScale(scale, rect: object.bounds, context: &context)
            case "roughen", "zigZag":
                let amount = n("size", 0)
                context.addFilter(.shadow(color: .black.opacity(min(0.16, amount / 500)), radius: max(0.2, amount * 0.04), x: amount * 0.03, y: -amount * 0.02))
            case "offsetPath":
                let offset = n("offset", 0)
                let sx = max(0.05, 1 + offset / max(1, object.bounds.width))
                let sy = max(0.05, 1 + offset / max(1, object.bounds.height))
                centeredScale(x: sx, y: sy, rect: object.bounds, context: &context)
            case "warp":
                let bend = n("bend", 0)
                context.concatenate(CGAffineTransform(a: 1, b: bend * 0.18, c: bend * 0.12, d: 1, tx: 0, ty: 0))
            default:
                break
            }
        }
    }

    private static func transformInstances(stack: AppearanceStackV6, rect: CGRect) -> [CGAffineTransform?] {
        guard let effect = stack.entries.compactMap({ entry -> LiveEffectV6? in
            guard case .effect(let value) = entry, value.enabled, value.effectID == "transform" else { return nil }
            return value
        }).last else { return [nil] }
        let copies = max(0, effect.parameters["copies"]?.integerValue ?? 0)
        let count = max(1, copies + 1)
        return (0..<count).map { index in
            if index == 0 && copies > 0 { return nil }
            let multiplier = copies > 0 ? Double(index) : 1
            let x = (effect.parameters["x"]?.numberValue ?? 0) * multiplier
            let y = (effect.parameters["y"]?.numberValue ?? 0) * multiplier
            let sx = pow(max(0.01, effect.parameters["scaleX"]?.numberValue ?? 1), multiplier)
            let sy = pow(max(0.01, effect.parameters["scaleY"]?.numberValue ?? 1), multiplier)
            let radians = (effect.parameters["rotation"]?.numberValue ?? 0) * multiplier * .pi / 180
            var t = CGAffineTransform.identity
            t = t.translatedBy(x: rect.midX + x, y: rect.midY + y)
            t = t.rotated(by: radians).scaledBy(x: sx, y: sy)
            t = t.translatedBy(x: -rect.midX, y: -rect.midY)
            return t
        }
    }

    private static func applyObjectTransform(_ object: VectorObject, to context: inout GraphicsContext) {
        let rect = object.bounds
        if object.rotation != 0 {
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: .degrees(object.rotation))
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }
        let sx = object.scaleX ?? 1, sy = object.scaleY ?? 1, shx = object.shearX ?? 0, shy = object.shearY ?? 0
        if sx != 1 || sy != 1 || shx != 0 || shy != 0 {
            context.translateBy(x: rect.midX, y: rect.midY)
            context.concatenate(CGAffineTransform(a: sx, b: shy, c: shx, d: sy, tx: 0, ty: 0))
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }
    }

    private static func centeredScale(_ value: Double, rect: CGRect, context: inout GraphicsContext) {
        centeredScale(x: value, y: value, rect: rect, context: &context)
    }
    private static func centeredScale(x: Double, y: Double, rect: CGRect, context: inout GraphicsContext) {
        context.translateBy(x: rect.midX, y: rect.midY)
        context.scaleBy(x: x, y: y)
        context.translateBy(x: -rect.midX, y: -rect.midY)
    }

    private static func rgba(_ value: RGBAColorV6) -> RGBAColor { .init(r: value.r, g: value.g, b: value.b, a: value.a) }
    private static func graphicsBlend(_ value: BlendModeV6) -> GraphicsContext.BlendMode {
        switch value {
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .darken: return .darken
        case .lighten: return .lighten
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        case .normal: return .normal
        }
    }
    private static func lineCap(_ value: String) -> CGLineCap { value == "round" ? .round : (value == "square" ? .square : .butt) }
    private static func lineJoin(_ value: String) -> CGLineJoin { value == "round" ? .round : (value == "bevel" ? .bevel : .miter) }
    private static func gradientPoints(angle: Double, rect: CGRect) -> (start: CGPoint, end: CGPoint) {
        let radians = angle * .pi / 180
        let direction = CGVector(dx: cos(radians), dy: sin(radians))
        let radius = hypot(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return (CGPoint(x: center.x - direction.dx * radius, y: center.y - direction.dy * radius), CGPoint(x: center.x + direction.dx * radius, y: center.y + direction.dy * radius))
    }
}
