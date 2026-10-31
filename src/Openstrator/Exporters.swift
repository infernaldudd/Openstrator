import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OpenstratorCore

struct SVGExporter {
    static func string(for document: OpenDocument) -> String {
        var defs: [String] = []
        var elements: [String] = []

        for object in document.objects where object.isVisible {
            if object.appearanceStack != nil {
                let rendered = m4SVGElements(for: object)
                defs.append(contentsOf: rendered.defs)
                elements.append(contentsOf: rendered.elements)
                continue
            }
            let gradientID = "gradient-\(object.id.uuidString)"
            if let gradient = object.gradient, gradient.stops.count >= 2 {
                let stops = gradient.stops
                    .sorted { $0.location < $1.location }
                    .map { stop in
                        "<stop offset=\"\(format(stop.location * 100))%\" stop-color=\"\(hex(stop.color))\" stop-opacity=\"\(format(stop.color.a))\"/>"
                    }
                    .joined()
                defs.append("<linearGradient id=\"\(gradientID)\" gradientTransform=\"rotate(\(format(gradient.angleDegrees)) .5 .5)\">\(stops)</linearGradient>")
            }

            let fill: String
            let fillOpacity: Double
            if object.gradient != nil {
                fill = "url(#\(gradientID))"
                fillOpacity = 1
            } else {
                fill = object.fill.a <= 0 ? "none" : hex(object.fill)
                fillOpacity = object.fill.a
            }

            let stroke = object.stroke.a <= 0 || object.strokeWidth <= 0 ? "none" : hex(object.stroke)
            let cx = object.bounds.midX, cy = object.bounds.midY
            let sx = object.scaleX ?? 1, sy = object.scaleY ?? 1
            let shx = object.shearX ?? 0, shy = object.shearY ?? 0
            var transforms: [String] = []
            if object.rotation != 0 { transforms.append("rotate(\(format(object.rotation)) \(format(cx)) \(format(cy)))") }
            if sx != 1 || sy != 1 || shx != 0 || shy != 0 {
                transforms.append("translate(\(format(cx)) \(format(cy))) matrix(\(format(sx)) \(format(shy)) \(format(shx)) \(format(sy)) 0 0) translate(\(format(-cx)) \(format(-cy)))")
            }
            let transform = transforms.isEmpty ? "" : " transform=\"\(transforms.joined(separator: " "))\""
            let dash = (object.strokeDash ?? []).isEmpty ? "" : " stroke-dasharray=\"\((object.strokeDash ?? []).map(format).joined(separator: ","))\""
            let cap = " stroke-linecap=\"\(object.lineCap ?? "butt")\""
            let join = " stroke-linejoin=\"\(object.lineJoin ?? "miter")\""
            let style = svgStyle(for: object)
            let common = "fill=\"\(fill)\" fill-opacity=\"\(format(fillOpacity))\" stroke=\"\(stroke)\" stroke-opacity=\"\(format(object.stroke.a))\" stroke-width=\"\(format(object.strokeWidth))\" opacity=\"\(format(object.opacity))\"\(dash)\(cap)\(join)\(transform)\(style)"

            switch object.kind {
            case .rectangle:
                elements.append("<rect x=\"\(format(object.x))\" y=\"\(format(object.y))\" width=\"\(format(object.width))\" height=\"\(format(object.height))\" rx=\"\(format(object.cornerRadius))\" \(common)/>")

            case .ellipse:
                elements.append("<ellipse cx=\"\(format(object.x + object.width / 2))\" cy=\"\(format(object.y + object.height / 2))\" rx=\"\(format(object.width / 2))\" ry=\"\(format(object.height / 2))\" \(common)/>")

            case .polygon:
                let points = polygonPoints(for: object.bounds, sides: 6)
                    .map { "\(format($0.x)),\(format($0.y))" }
                    .joined(separator: " ")
                elements.append("<polygon points=\"\(points)\" \(common)/>")

            case .line:
                if object.points.count >= 2 {
                    let a = object.points[0]
                    let b = object.points[1]
                    elements.append("<line x1=\"\(format(a.x))\" y1=\"\(format(a.y))\" x2=\"\(format(b.x))\" y2=\"\(format(b.y))\" \(common)/>")
                }

            case .text:
                elements.append(svgTextElement(for: object, common: common))

            case .image:
                if let assetID = object.rasterAssetID,
                   let asset = document.rasterAssets?.first(where: { $0.id == assetID }) {
                    let base64 = asset.embeddedData.base64EncodedString()
                    elements.append("<image x=\"\(format(object.x))\" y=\"\(format(object.y))\" width=\"\(format(object.width))\" height=\"\(format(object.height))\" href=\"data:\(asset.metadata.mimeType);base64,\(base64)\"\(transform)/>")
                }

            case .path:
                if let anchors = object.bezierAnchors, let first = anchors.first {
                    var commands = ["M \(format(Double(first.point.x))) \(format(Double(first.point.y)))"]
                    if anchors.count >= 2 {
                        for index in 0..<(anchors.count - 1) {
                            let a = anchors[index], b = anchors[index + 1]
                            let c1 = a.outHandle ?? a.point
                            let c2 = b.inHandle ?? b.point
                            commands.append("C \(format(Double(c1.x))) \(format(Double(c1.y))) \(format(Double(c2.x))) \(format(Double(c2.y))) \(format(Double(b.point.x))) \(format(Double(b.point.y)))")
                        }
                        if object.isClosed == true, let last = anchors.last {
                            let c1 = last.outHandle ?? last.point
                            let c2 = first.inHandle ?? first.point
                            commands.append("C \(format(Double(c1.x))) \(format(Double(c1.y))) \(format(Double(c2.x))) \(format(Double(c2.y))) \(format(Double(first.point.x))) \(format(Double(first.point.y)))")
                            commands.append("Z")
                        }
                    }
                    elements.append("<path id=\"path-\(object.id.uuidString)\" d=\"\(commands.joined(separator: " "))\" \(common)/>")
                } else if let first = object.points.first {
                    let pathData = "M \(format(first.x)) \(format(first.y)) " + object.points.dropFirst().map { "L \(format($0.x)) \(format($0.y))" }.joined(separator: " ") + (object.isClosed == true ? " Z" : "")
                    elements.append("<path id=\"path-\(object.id.uuidString)\" d=\"\(pathData)\" \(common)/>")
                }
            }
        }

        let background = document.background.a > 0
            ? "<rect width=\"100%\" height=\"100%\" fill=\"\(hex(document.background))\" fill-opacity=\"\(format(document.background.a))\"/>"
            : ""
        let defsBlock = defs.isEmpty ? "" : "<defs>\(defs.joined())</defs>"

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(format(document.artboardWidth))" height="\(format(document.artboardHeight))" viewBox="0 0 \(format(document.artboardWidth)) \(format(document.artboardHeight))">
        \(defsBlock)
        \(background)
        \(elements.joined(separator: "\n"))
        </svg>
        """
    }

    private static func m4SVGElements(for object: VectorObject) -> (defs: [String], elements: [String]) {
        let stack = object.resolvedAppearanceStack
        var defs: [String] = []
        var paintElements: [String] = []

        let objectTransform = svgTransform(for: object)
        for entry in stack.entries {
            switch entry {
            case .fill(let fill) where fill.enabled:
                let paint = svgPaint(fill.paint, id: "m4-fill-\(fill.id.uuidString)", defs: &defs)
                let common = "fill=\"\(paint.value)\" fill-opacity=\"\(format(paint.opacity * fill.opacity))\" stroke=\"none\" opacity=\"1\"\(objectTransform)"
                if let element = svgGeometryElement(for: object, common: common) { paintElements.append(element) }
            case .stroke(let stroke) where stroke.enabled:
                let paint = svgPaint(stroke.paint, id: "m4-stroke-\(stroke.id.uuidString)", defs: &defs)
                let dash = stroke.dash.isEmpty ? "" : " stroke-dasharray=\"\(stroke.dash.map(format).joined(separator: ","))\""
                let common = "fill=\"none\" stroke=\"\(paint.value)\" stroke-opacity=\"\(format(paint.opacity * stroke.opacity))\" stroke-width=\"\(format(stroke.width))\" stroke-linecap=\"\(escape(stroke.cap))\" stroke-linejoin=\"\(escape(stroke.join))\" stroke-miterlimit=\"\(format(stroke.miterLimit))\"\(dash) opacity=\"1\"\(objectTransform)"
                if let element = svgGeometryElement(for: object, common: common) { paintElements.append(element) }
            case .effect, .fill, .stroke:
                continue
            }
        }

        let metadata: String = {
            guard let data = try? JSONEncoder().encode(stack) else { return "" }
            return data.base64EncodedString()
        }()
        let effectStyle = m4EffectStyle(stack)
        let inner = paintElements.joined(separator: "\n")
        let transformed = m4TransformCopies(stack: stack, object: object, content: inner)
        let group = "<g opacity=\"\(format(stack.opacity))\" data-openstrator-appearance=\"\(escape(metadata))\"\(effectStyle)>\(transformed)</g>"
        return (defs, [group])
    }

    private static func svgPaint(_ paint: AppearancePaintV6, id: String, defs: inout [String]) -> (value: String, opacity: Double) {
        switch paint {
        case .color(let value):
            let app = RGBAColor(r: value.r, g: value.g, b: value.b, a: value.a)
            return (value.a <= 0 ? "none" : hex(app), value.a)
        case .linearGradient(let gradient):
            let stops = gradient.stops.sorted { $0.location < $1.location }.map { stop -> String in
                let color = RGBAColor(r: stop.color.r, g: stop.color.g, b: stop.color.b, a: stop.color.a)
                return "<stop offset=\"\(format(stop.location * 100))%\" stop-color=\"\(hex(color))\" stop-opacity=\"\(format(color.a))\"/>"
            }.joined()
            defs.append("<linearGradient id=\"\(id)\" gradientTransform=\"rotate(\(format(gradient.angleDegrees)) .5 .5)\">\(stops)</linearGradient>")
            return ("url(#\(id))", 1)
        }
    }

    private static func svgGeometryElement(for object: VectorObject, common: String) -> String? {
        switch object.kind {
        case .rectangle:
            return "<rect x=\"\(format(object.x))\" y=\"\(format(object.y))\" width=\"\(format(object.width))\" height=\"\(format(object.height))\" rx=\"\(format(object.cornerRadius))\" \(common)/>"
        case .ellipse:
            return "<ellipse cx=\"\(format(object.x + object.width / 2))\" cy=\"\(format(object.y + object.height / 2))\" rx=\"\(format(object.width / 2))\" ry=\"\(format(object.height / 2))\" \(common)/>"
        case .polygon:
            let points = polygonPoints(for: object.bounds, sides: 6).map { "\(format($0.x)),\(format($0.y))" }.joined(separator: " ")
            return "<polygon points=\"\(points)\" \(common)/>"
        case .line:
            if let anchors = object.bezierAnchors, anchors.count >= 2 {
                let pathObject = VectorObject(name: object.name, kind: .path, x: object.x, y: object.y, width: object.width, height: object.height, points: object.points, bezierAnchors: anchors, isClosed: false)
                return svgGeometryElement(for: pathObject, common: common)
            }
            guard object.points.count >= 2 else { return nil }
            let a = object.points[0], b = object.points[1]
            return "<line x1=\"\(format(a.x))\" y1=\"\(format(a.y))\" x2=\"\(format(b.x))\" y2=\"\(format(b.y))\" \(common)/>"
        case .text:
            return svgTextElement(for: object, common: common)
        case .image:
            return nil
        case .path:
            if let anchors = object.bezierAnchors, let first = anchors.first {
                var commands = ["M \(format(Double(first.point.x))) \(format(Double(first.point.y)))"]
                if anchors.count >= 2 {
                    for index in 0..<(anchors.count - 1) {
                        let a = anchors[index], b = anchors[index + 1]
                        let c1 = a.outHandle ?? a.point, c2 = b.inHandle ?? b.point
                        commands.append("C \(format(Double(c1.x))) \(format(Double(c1.y))) \(format(Double(c2.x))) \(format(Double(c2.y))) \(format(Double(b.point.x))) \(format(Double(b.point.y)))")
                    }
                    if object.isClosed == true, let last = anchors.last {
                        let c1 = last.outHandle ?? last.point, c2 = first.inHandle ?? first.point
                        commands.append("C \(format(Double(c1.x))) \(format(Double(c1.y))) \(format(Double(c2.x))) \(format(Double(c2.y))) \(format(Double(first.point.x))) \(format(Double(first.point.y)))")
                        commands.append("Z")
                    }
                }
                return "<path id=\"path-\(object.id.uuidString)\" d=\"\(commands.joined(separator: " "))\" \(common)/>"
            }
            guard let first = object.points.first else { return nil }
            let data = "M \(format(first.x)) \(format(first.y)) " + object.points.dropFirst().map { "L \(format($0.x)) \(format($0.y))" }.joined(separator: " ") + (object.isClosed == true ? " Z" : "")
            return "<path id=\"path-\(object.id.uuidString)\" d=\"\(data)\" \(common)/>"
        }
    }

    private static func svgTransform(for object: VectorObject) -> String {
        let cx = object.bounds.midX, cy = object.bounds.midY
        let sx = object.scaleX ?? 1, sy = object.scaleY ?? 1, shx = object.shearX ?? 0, shy = object.shearY ?? 0
        var transforms: [String] = []
        if object.rotation != 0 { transforms.append("rotate(\(format(object.rotation)) \(format(cx)) \(format(cy)))") }
        if sx != 1 || sy != 1 || shx != 0 || shy != 0 {
            transforms.append("translate(\(format(cx)) \(format(cy))) matrix(\(format(sx)) \(format(shy)) \(format(shx)) \(format(sy)) 0 0) translate(\(format(-cx)) \(format(-cy)))")
        }
        return transforms.isEmpty ? "" : " transform=\"\(transforms.joined(separator: " "))\""
    }

    private static func m4EffectStyle(_ stack: AppearanceStackV6) -> String {
        var filters: [String] = []
        for entry in stack.entries {
            guard case .effect(let effect) = entry, effect.enabled else { continue }
            let n: (String, Double) -> Double = { effect.parameters[$0]?.numberValue ?? $1 }
            switch effect.effectID {
            case "gaussianBlur": filters.append("blur(\(format(max(0,n("radius",0))))px)")
            case "motionBlur": filters.append("blur(\(format(max(0,n("distance",0) * 0.45)))px)")
            case "dropShadow": filters.append("drop-shadow(\(format(n("x",4)))px \(format(n("y",4)))px \(format(max(0,n("blur",8))))px rgba(0,0,0,\(format(n("opacity",0.35)))))")
            case "outerGlow": filters.append("drop-shadow(0 0 \(format(max(0,n("blur",10))))px rgba(255,255,255,\(format(n("opacity",0.5)))))")
            default: break
            }
        }
        var styles: [String] = []
        if stack.blendMode != .normal { styles.append("mix-blend-mode:\(stack.blendMode.rawValue)") }
        if !filters.isEmpty { styles.append("filter:\(filters.joined(separator: " "))") }
        return styles.isEmpty ? "" : " style=\"\(styles.joined(separator: ";"))\""
    }

    private static func m4TransformCopies(stack: AppearanceStackV6, object: VectorObject, content: String) -> String {
        guard let effect = stack.entries.compactMap({ entry -> LiveEffectV6? in
            guard case .effect(let e) = entry, e.enabled, e.effectID == "transform" else { return nil }; return e
        }).last else { return content }
        let copies = max(0, effect.parameters["copies"]?.integerValue ?? 0)
        let indices = copies > 0 ? Array(0...copies) : [1]
        let cx = object.bounds.midX, cy = object.bounds.midY
        return indices.map { index in
            if index == 0 { return content }
            let m = Double(index)
            let x = (effect.parameters["x"]?.numberValue ?? 0) * m
            let y = (effect.parameters["y"]?.numberValue ?? 0) * m
            let sx = pow(max(0.01,effect.parameters["scaleX"]?.numberValue ?? 1), m)
            let sy = pow(max(0.01,effect.parameters["scaleY"]?.numberValue ?? 1), m)
            let r = (effect.parameters["rotation"]?.numberValue ?? 0) * m
            return "<g transform=\"translate(\(format(cx + x)) \(format(cy + y))) rotate(\(format(r))) scale(\(format(sx)) \(format(sy))) translate(\(format(-cx)) \(format(-cy)))\">\(content)</g>"
        }.joined(separator: "\n")
    }

    private static func svgTextElement(for object: VectorObject, common: String) -> String {
        let data = object.resolvedTypography
        let character = data.character
        let paragraph = data.paragraph
        let weight = Int((100 + character.legacyWeight * 800).rounded())
        let letterSpacing = character.trackingPoints
        let anchor: String
        switch paragraph.alignment {
        case .left, .justify: anchor = "start"
        case .center: anchor = "middle"
        case .right: anchor = "end"
        }
        let direction: String
        switch paragraph.direction {
        case .natural: direction = ""
        case .leftToRight: direction = " direction=\"ltr\""
        case .rightToLeft: direction = " direction=\"rtl\""
        }
        var decorations: [String] = []
        if character.underline { decorations.append("underline") }
        if character.strikethrough { decorations.append("line-through") }
        let decoration = decorations.isEmpty ? "" : " text-decoration=\"\(decorations.joined(separator: " "))\""
        let italic = character.fontFace.localizedCaseInsensitiveContains("italic") || character.fontFace.localizedCaseInsensitiveContains("oblique")
        let fontStyle = italic ? "italic" : "normal"
        let warp = data.warp.map { " data-openstrator-warp=\"\(escape($0.style.rawValue))\" data-openstrator-warp-bend=\"\(format($0.bend))\"" } ?? ""
        let metadata = "data-openstrator-layout=\"\(data.layoutMode.rawValue)\"\(warp)"
        let attributes = "font-family=\"\(escape(character.fontFamily))\" font-size=\"\(format(character.fontSize))\" font-weight=\"\(weight)\" font-style=\"\(fontStyle)\" letter-spacing=\"\(format(letterSpacing))\" text-anchor=\"\(anchor)\"\(direction)\(decoration) \(metadata)"
        let y = object.y + character.fontSize + character.baselineShift
        let content = escape(data.text)

        switch data.layoutMode {
        case .path, .verticalPath:
            if let path = data.path, let reference = path.pathReference {
                let startOffset = max(0, path.startOffset)
                return "<text x=\"\(format(object.x))\" y=\"\(format(y))\" \(attributes) \(common)><textPath href=\"#path-\(reference.uuidString)\" startOffset=\"\(format(startOffset))\">\(content)</textPath></text>"
            }
            fallthrough
        default:
            return "<text x=\"\(format(object.x))\" y=\"\(format(y))\" \(attributes) \(common)>\(content)</text>"
        }
    }

    private static func svgStyle(for object: VectorObject) -> String {
        var pieces: [String] = []
        if object.kind == .text {
            let layout = object.resolvedTypography.layoutMode
            if layout == .verticalPoint || layout == .verticalArea || layout == .verticalPath {
                pieces.append("writing-mode:vertical-rl")
            }
        }
        if object.blendMode != .normal {
            pieces.append("mix-blend-mode:\(object.blendMode.rawValue)")
        }

        var filters: [String] = []
        for effect in object.effects where effect.enabled {
            switch effect.kind {
            case .blur, .gaussianBlur, .radialBlur, .zoomBlur, .smartBlur, .motionBlur, .feather:
                filters.append("blur(\(format(max(0, effect.amount * 0.75)))px)")
            case .shadow, .innerShadow:
                filters.append("drop-shadow(0 \(format(effect.amount * 0.45))px \(format(abs(effect.amount)))px rgba(0,0,0,.30))")
            case .glow, .innerGlow, .neonGlow, .neonEdge:
                filters.append("drop-shadow(0 0 \(format(max(2,abs(effect.amount))))px \(rgba(object.fill, forcedAlpha: 0.68)))")
            case .brightness, .exposure:
                filters.append("brightness(\(format(max(0.05, 1 + effect.amount))) )")
            case .contrast:
                filters.append("contrast(\(format(max(0,effect.amount))))")
            case .saturation, .vibrance, .colorBoost:
                filters.append("saturate(\(format(max(0,effect.amount))))")
            case .hueRotate:
                filters.append("hue-rotate(\(format(effect.amount))deg)")
            case .grayscale, .charcoal, .graphicPen, .photocopy, .stamp:
                filters.append("grayscale(\(format(max(0,min(1,effect.amount == 0 ? 1 : effect.amount)))))")
            case .sepia:
                filters.append("sepia(\(format(max(0,min(1,effect.amount)))))")
            case .invert:
                filters.append("invert(\(format(max(0,min(1,effect.amount)))))")
            default:
                filters.append("contrast(1.05)")
            }
        }
        if !filters.isEmpty { pieces.append("filter:\(filters.joined(separator: " "))") }
        return pieces.isEmpty ? "" : " style=\"\(pieces.joined(separator: ";"))\""
    }

    private static func polygonPoints(for rect: CGRect, sides: Int) -> [CGPoint] {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return (0..<sides).map { index in
            let angle = -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(sides)
            return CGPoint(x: center.x + cos(angle) * rect.width / 2, y: center.y + sin(angle) * rect.height / 2)
        }
    }

    private static func escape(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func hex(_ color: RGBAColor) -> String {
        let r = Int(max(0, min(255, color.r * 255)).rounded())
        let g = Int(max(0, min(255, color.g * 255)).rounded())
        let b = Int(max(0, min(255, color.b * 255)).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private static func rgba(_ color: RGBAColor, forcedAlpha: Double? = nil) -> String {
        let r = Int(max(0, min(255, color.r * 255)).rounded())
        let g = Int(max(0, min(255, color.g * 255)).rounded())
        let b = Int(max(0, min(255, color.b * 255)).rounded())
        return "rgba(\(r),\(g),\(b),\(format(forcedAlpha ?? color.a)))"
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }

    private static func format(_ value: CGFloat) -> String {
        format(Double(value))
    }
}

@MainActor
enum NativeExporter {
    enum ExportError: LocalizedError {
        case couldNotRender
        case couldNotEncode

        var errorDescription: String? {
            switch self {
            case .couldNotRender: return "The artboard could not be rendered."
            case .couldNotEncode: return "The rendered artboard could not be encoded."
            }
        }
    }

    static func exportPNG(document: OpenDocument, to url: URL, scale: CGFloat = 1) throws {
        let width = max(1, document.artboardWidth)
        let height = max(1, document.artboardHeight)
        let content = DocumentArtworkView(document: document, includeGrid: false)
            .frame(width: width, height: height)

        let view = NSHostingView(rootView: content)
        view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        view.layoutSubtreeIfNeeded()

        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw ExportError.couldNotRender
        }
        rep.size = NSSize(width: width, height: height)
        view.cacheDisplay(in: view.bounds, to: rep)

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ExportError.couldNotEncode
        }
        try data.write(to: url, options: .atomic)
    }

    static func exportPDF(document: OpenDocument, to url: URL) throws {
        let width = max(1, document.artboardWidth)
        let height = max(1, document.artboardHeight)
        let content = DocumentArtworkView(document: document, includeGrid: false)
            .frame(width: width, height: height)

        let view = NSHostingView(rootView: content)
        view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        view.layoutSubtreeIfNeeded()
        let data = view.dataWithPDF(inside: view.bounds)
        guard !data.isEmpty else { throw ExportError.couldNotRender }
        try data.write(to: url, options: .atomic)
    }
}

enum PerformanceBudget {
    static var targetWorkingSetMB: Int { ArchitectureProfile.current.targetWorkingSetMB }
    static var hardWarningMB: Int { ArchitectureProfile.current.hardWarningMB }
    static var maxUndoSnapshots: Int { ArchitectureProfile.current.undoLimit }
    static let maxLiveRasterDimension = 8192

    static func recommendation(forPixelCount pixels: Int) -> String? {
        let approximateMB = Double(pixels * 4) / 1_048_576
        if approximateMB > 512 {
            return "Large raster image (~\(Int(approximateMB)) MB uncompressed). Consider linking or downsampling it."
        }
        return nil
    }
}
