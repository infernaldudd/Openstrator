import SwiftUI
import AppKit
import OpenstratorCore
import UniformTypeIdentifiers

struct EditorCanvasView: View {
    @EnvironmentObject var store: EditorStore

    @State private var dragStart: CGPoint?
    @State private var lastDragLocation: CGPoint?
    @State private var panAtDragStart: CGSize = .zero
    @State private var didMoveSelection = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(nsColor: .underPageBackgroundColor)

                artboard
                    .scaleEffect(store.zoom, anchor: .center)
                    .rotationEffect(.degrees(store.viewRotation))
                    .offset(store.pan)
                    .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(editorGesture(in: geo.size))
            .dropDestination(for: URL.self) { urls, location in
                guard !urls.isEmpty else { return false }
                store.placeImages(at: urls, dropPoint: toDocument(location, in: geo.size))
                return true
            }
        }
    }

    private var artboard: some View {
        ZStack(alignment: .topLeading) {
            DocumentArtworkView(document: store.document, zoom: store.zoom)

            if store.document.showGuides {
                guidesOverlay
            }

            if let rect = store.draftShapeRect {
                RoundedRectangle(cornerRadius: store.activeTool == .ellipse ? min(rect.width, rect.height) / 2 : 5)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .background(Color.accentColor.opacity(0.06))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
            }

            if let draft = store.draftBezierPath, !draft.anchors.isEmpty {
                Canvas { context, _ in
                    context.stroke(swiftUIPath(from: draft), with: .color(.accentColor), style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                }
                .allowsHitTesting(false)
            } else if store.draftPath.count > 1 {
                Canvas { context, _ in
                    var path = Path()
                    path.move(to: store.draftPath[0])
                    for point in store.draftPath.dropFirst() { path.addLine(to: point) }
                    context.stroke(path, with: .color(.accentColor), lineWidth: 2)
                }
                .allowsHitTesting(false)
            }

            selectionOverlays
        }
        .frame(width: store.document.artboardWidth, height: store.document.artboardHeight)
        .overlay(Rectangle().stroke(.black.opacity(0.16), lineWidth: 1))
    }

    @ViewBuilder
    private var guidesOverlay: some View {
        ForEach(store.document.guides) { guide in
            if guide.axis == .vertical {
                Rectangle()
                    .fill(Color.cyan.opacity(0.72))
                    .frame(width: 1, height: store.document.artboardHeight)
                    .position(x: guide.position, y: store.document.artboardHeight / 2)
                    .allowsHitTesting(false)
            } else {
                Rectangle()
                    .fill(Color.cyan.opacity(0.72))
                    .frame(width: store.document.artboardWidth, height: 1)
                    .position(x: store.document.artboardWidth / 2, y: guide.position)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var selectionOverlays: some View {
        let selected = store.document.objects.filter { store.selection.contains($0.id) && $0.isVisible }
        ForEach(selected) { object in
            SelectionOverlay(object: object, isPrimary: selected.count == 1)
                .environmentObject(store)
        }

        if selected.count > 1, let bounds = store.selectionBounds {
            Rectangle()
                .fill(Color.clear)
                .overlay(Rectangle().stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.4, dash: [5, 3])))
                .frame(width: bounds.width, height: bounds.height)
                .position(x: bounds.midX, y: bounds.midY)
                .allowsHitTesting(false)
        }
    }

    private func editorGesture(in viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let current = toDocument(value.location, in: viewportSize)

                if dragStart == nil {
                    dragStart = current
                    lastDragLocation = current
                    didMoveSelection = false

                    switch store.activeTool {
                    case .select, .groupSelect:
                        let additive = NSEvent.modifierFlags.contains(.shift)
                        store.select(at: current, additive: additive)
                        if !store.selection.isEmpty { store.beginMove(pointer: current) }
                    case .directSelect:
                        let additive = NSEvent.modifierFlags.contains(.shift)
                        store.selectDirect(at: current, additive: additive)
                        if store.hasDirectComponentSelection { store.beginDirectComponentMove(pointer: current) }
                        else if !store.selection.isEmpty { store.beginMove(pointer: current) }
                    case .magicWand:
                        store.selectSimilarAppearance(at: current)
                    case .lasso:
                        store.draftShapeRect = CGRect(origin: current, size: .zero)
                    case .pen:
                        store.draftPath = [current, current]
                    case .curvature:
                        store.draftPath.removeAll()
                    case .pencil, .paintbrush, .blobBrush, .eraser, .pathEraser:
                        store.draftPath = [current]
                    case .rectangle, .roundedRectangle, .ellipse, .polygon, .star, .arc, .spiral, .rectGrid, .polarGrid, .flare, .areaText, .verticalAreaText, .graph, .artboard, .slice:
                        store.draftShapeRect = CGRect(origin: current, size: .zero)
                    case .line, .gradient, .measure:
                        store.draftPath = [current, current]
                    case .rotate, .scale, .shear, .width, .freeTransform, .reshape:
                        if !store.selection.isEmpty { store.snapshot() }
                    case .hand:
                        panAtDragStart = store.pan
                    case .reflect, .smooth, .scissors, .knife, .joinTool, .text, .verticalText, .typeOnPath, .verticalTypeOnPath, .touchType, .mesh, .eyedropper, .blend, .shapeBuilder, .symbolSprayer, .perspectiveGrid, .zoom:
                        break
                    default:
                        break
                    }
                }

                switch store.activeTool {
                case .select, .groupSelect:
                    if let start = dragStart, !store.selection.isEmpty {
                        let distance = hypot(current.x - start.x, current.y - start.y)
                        if distance > max(0.75, 3 / max(0.1, store.zoom)) {
                            store.updateMove(pointer: current)
                            didMoveSelection = true
                        }
                    }
                    lastDragLocation = current

                case .directSelect:
                    if let start = dragStart, !store.selection.isEmpty {
                        let distance = hypot(current.x - start.x, current.y - start.y)
                        if distance > max(0.75, 3 / max(0.1, store.zoom)) {
                            if store.hasDirectComponentSelection { store.updateDirectComponentMove(pointer: current) }
                            else { store.updateMove(pointer: current) }
                            didMoveSelection = true
                        }
                    }
                    lastDragLocation = current

                case .lasso, .rectangle, .roundedRectangle, .ellipse, .polygon, .star, .arc, .spiral, .rectGrid, .polarGrid, .flare, .areaText, .verticalAreaText, .graph, .artboard, .slice:
                    if let start = dragStart { store.draftShapeRect = rect(from: start, to: current) }

                case .pen:
                    if let start = dragStart { store.draftPath = [start, current] }
                case .curvature:
                    if let last = store.draftBezierPath?.anchors.last?.point { store.draftPath = [last, current] }

                case .pencil, .paintbrush, .blobBrush, .eraser, .pathEraser:
                    if let last = store.draftPath.last, hypot(last.x-current.x, last.y-current.y) > 2.2 { store.draftPath.append(current) }

                case .line, .gradient, .measure:
                    if let start = dragStart { store.draftPath = [start, current] }

                case .rotate:
                    if let last = lastDragLocation { store.rotateSelection(by: Double(current.x - last.x) * 0.45) }
                    lastDragLocation = current
                case .scale:
                    if let last = lastDragLocation { store.scaleSelection(by: 1.0 + Double(current.x - last.x) / 180.0) }
                    lastDragLocation = current
                case .shear:
                    if let start = dragStart { store.shearSelection(x: Double(current.x - start.x) / 180.0, y: Double(current.y - start.y) / 180.0) }
                case .width:
                    if let last = lastDragLocation { store.adjustWidth(by: Double(current.x - last.x) * 0.16) }
                    lastDragLocation = current
                case .freeTransform, .reshape:
                    if let last = lastDragLocation, !store.selection.isEmpty {
                        store.moveSelection(by: CGSize(width: current.x-last.x, height: current.y-last.y))
                    }
                    lastDragLocation = current

                case .hand:
                    store.pan = CGSize(width: panAtDragStart.width + value.translation.width, height: panAtDragStart.height + value.translation.height)

                case .magicWand, .reflect, .smooth, .scissors, .knife, .joinTool, .text, .verticalText, .typeOnPath, .verticalTypeOnPath, .touchType, .mesh, .eyedropper, .blend, .shapeBuilder, .symbolSprayer, .perspectiveGrid, .zoom:
                    break
                default:
                    break
                }
            }
            .onEnded { value in
                let end = toDocument(value.location, in: viewportSize)
                let drawnRect = store.draftShapeRect ?? CGRect(x: end.x, y: end.y, width: 160, height: 120)

                switch store.activeTool {
                case .select, .groupSelect:
                    store.endMove(commit: didMoveSelection)
                case .directSelect:
                    if store.hasDirectComponentSelection { store.endDirectComponentMove(commit: didMoveSelection) }
                    else { store.endMove(commit: didMoveSelection) }
                case .magicWand:
                    break
                case .lasso:
                    store.selectIntersecting(drawnRect, additive: NSEvent.modifierFlags.contains(.shift))
                    store.draftShapeRect = nil

                case .rectangle:
                    store.addShape(kind: .rectangle, in: drawnRect); store.draftShapeRect = nil
                case .roundedRectangle:
                    store.addRoundedRectangle(in: drawnRect); store.draftShapeRect = nil
                case .ellipse:
                    store.addShape(kind: .ellipse, in: drawnRect); store.draftShapeRect = nil
                case .polygon:
                    store.addShape(kind: .polygon, in: drawnRect); store.draftShapeRect = nil
                case .star:
                    store.addStar(in: drawnRect); store.draftShapeRect = nil
                case .arc:
                    store.addArc(in: drawnRect); store.draftShapeRect = nil
                case .spiral:
                    store.addSpiral(in: drawnRect); store.draftShapeRect = nil
                case .rectGrid:
                    store.addRectangularGrid(in: drawnRect); store.draftShapeRect = nil
                case .polarGrid:
                    store.addPolarGrid(in: drawnRect); store.draftShapeRect = nil
                case .flare:
                    store.addFlare(in: drawnRect); store.draftShapeRect = nil
                case .line:
                    if let start = dragStart { store.addLine(from: start, to: end) }
                    store.draftPath.removeAll()

                case .pen:
                    let start = dragStart ?? end
                    let dragged = hypot(end.x - start.x, end.y - start.y) > max(1.5, 3 / max(0.1, store.zoom))
                    store.penAddAnchor(point: start, dragTo: dragged ? end : nil)
                    store.draftPath.removeAll()
                case .curvature:
                    store.curvatureAddAnchor(point: dragStart ?? end)
                    store.draftPath.removeAll()
                case .pencil:
                    store.addPencilPath(store.draftPath); store.draftPath.removeAll()
                case .paintbrush:
                    if store.canRasterEditSelection { store.paintSelectedRaster(along: store.draftPath, eraser: false) }
                    else { store.addBrushPath(store.draftPath) }
                    store.draftPath.removeAll()
                case .blobBrush:
                    store.addBrushPath(store.draftPath, blob: true); store.draftPath.removeAll()
                case .smooth:
                    store.smoothSelectedPaths()
                case .eraser, .pathEraser:
                    if store.activeTool == .eraser && store.canRasterEditSelection { store.paintSelectedRaster(along: store.draftPath, eraser: true) }
                    else { store.eraseObjects(along: store.draftPath, radius: store.activeTool == .pathEraser ? 7 : 14) }
                    store.draftPath.removeAll()
                case .scissors, .knife:
                    store.splitSelectedPath(at: end)
                case .joinTool:
                    store.joinSelectedPaths()

                case .text:
                    store.addText(at: end); store.activeTool = .select
                case .areaText:
                    store.addAreaText(in: drawnRect); store.draftShapeRect = nil
                case .verticalText:
                    store.addVerticalText(at: end); store.activeTool = .select
                case .verticalAreaText:
                    store.addAreaText(in: drawnRect, vertical: true); store.draftShapeRect = nil
                case .typeOnPath:
                    store.addTypeOnSelectedPath(vertical: false); store.activeTool = .select
                case .verticalTypeOnPath:
                    store.addTypeOnSelectedPath(vertical: true); store.activeTool = .select
                case .touchType:
                    store.touchType(at: dragStart ?? end, dragTo: end)

                case .rotate, .scale, .shear, .width, .freeTransform, .reshape:
                    store.commitMutation(status: store.activeTool.title + " applied")
                case .reflect:
                    store.reflectSelection(horizontal: !NSEvent.modifierFlags.contains(.option))

                case .gradient:
                    if let start = dragStart { store.snapshot(); store.setGradientFromDrag(start: start, end: end) }
                    store.draftPath.removeAll()
                case .mesh:
                    store.applyMeshStyle()
                case .eyedropper:
                    store.applyEyedropper(at: end)
                case .measure:
                    if let start = dragStart {
                        let d = hypot(end.x-start.x, end.y-start.y)
                        let angle = atan2(Double(end.y - start.y), Double(end.x - start.x)) * (180.0 / Double.pi)
                        store.status = "Measure: \(Int(d.rounded())) px · \(Int(angle.rounded()))°"
                    }
                    store.draftPath.removeAll()
                case .blend:
                    store.blendSelection()
                case .shapeBuilder:
                    store.shapeBuilderMergeSelection()
                case .symbolSprayer:
                    store.spraySelection(around: end)
                case .graph:
                    store.addBarGraph(in: drawnRect); store.draftShapeRect = nil
                case .perspectiveGrid:
                    store.createPerspectiveGrid()
                case .artboard:
                    store.setArtboard(from: drawnRect); store.draftShapeRect = nil
                case .slice:
                    store.createSliceGuides(from: drawnRect); store.draftShapeRect = nil

                case .zoom:
                    if NSEvent.modifierFlags.contains(.option) { store.zoom = max(0.10, store.zoom / 1.25) }
                    else { store.zoom = min(8, store.zoom * 1.25) }
                case .hand:
                    break
                default:
                    store.performSpecialTool(store.activeTool, start: dragStart ?? end, end: end)
                }

                dragStart = nil
                lastDragLocation = nil
                didMoveSelection = false
            }
    }

    private func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func toDocument(_ point: CGPoint, in viewport: CGSize) -> CGPoint {
        store.canvasTransform(viewportSize: viewport, screenScale: Double(NSScreen.main?.backingScaleFactor ?? 2))
            .documentPoint(fromViewport: point)
    }
}

struct DocumentArtworkView: View {
    let document: OpenDocument
    var zoom: Double = 1
    var includeGrid: Bool = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            document.background.swiftUIColor

            if includeGrid && document.showGrid {
                Canvas { context, size in
                    let screenScale = Double(NSScreen.main?.backingScaleFactor ?? 2)
                    let metrics = GridMetrics.make(baseSpacing: max(4, document.gridSpacing), zoom: max(0.1, zoom), screenScale: screenScale)
                    let spacing = metrics.documentSpacing
                    var path = Path()
                    var x = 0.0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }
                    var y = 0.0
                    while y <= size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }
                    context.stroke(path, with: .color(.secondary.opacity(0.10)), lineWidth: CGFloat(metrics.viewportLineWidth / max(0.1, zoom)))
                }
            }

            Canvas { context, _ in
                CompositedDocumentRenderer.draw(document: document, context: &context)
            }
        }
        .frame(width: document.artboardWidth, height: document.artboardHeight)
        .clipped()
    }
}

private struct SelectionOverlay: View {
    @EnvironmentObject var store: EditorStore
    let object: VectorObject
    let isPrimary: Bool

    @State private var resizeStartRect: CGRect?
    @State private var coreResizeSession: OpenstratorCore.ResizeSession?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.35, dash: [5, 3]))
                )
                .frame(width: object.width, height: object.height)
                .position(x: object.bounds.midX, y: object.bounds.midY)
                .allowsHitTesting(false)

            if isPrimary, store.activeTool == .directSelect, let path = store.bezierPath(for: object) {
                DirectPathOverlay(path: path, selection: store.directComponentSelection)
                    .allowsHitTesting(false)
            }

            if isPrimary && !object.isLocked && store.activeTool != .directSelect {
                ForEach(ResizeHandle.allCases) { handle in
                    ZStack {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 1.5))
                            .frame(width: 9, height: 9)
                    }
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                    .position(handle.position(in: object.bounds))
                    .gesture(resizeGesture(handle))
                }
            }
        }
    }

    private func resizeGesture(_ handle: ResizeHandle) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if resizeStartRect == nil {
                    let start = object.bounds
                    resizeStartRect = start
                    coreResizeSession = OpenstratorCore.ResizeSession(
                        originalBounds: start,
                        originals: [NodeID(object.id): .identity],
                        handle: handle.coreHandle,
                        startPointer: handle.position(in: start)
                    )
                    store.snapshot()
                }
                guard let start = resizeStartRect, let session = coreResizeSession else { return }
                let origin = handle.position(in: start)
                let pointer = CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height)
                var modifiers: TransformModifiers = []
                if NSEvent.modifierFlags.contains(.shift) { modifiers.insert(.preserveAspect) }
                if NSEvent.modifierFlags.contains(.option) { modifiers.insert(.fromCenter) }
                let result = session.result(pointerDocumentPoint: pointer, modifiers: modifiers)
                store.resizeObject(id: object.id, to: result.bounds)
            }
            .onEnded { _ in
                resizeStartRect = nil
                coreResizeSession = nil
                store.commitMutation(status: "Resized")
            }
    }
}

private struct DirectPathOverlay: View {
    let path: BezierPathV6
    let selection: DirectComponentSelection?

    var body: some View {
        ZStack {
            Canvas { context, _ in
                var handleLines = Path()
                for anchor in path.anchors {
                    if let incoming = anchor.inHandle {
                        handleLines.move(to: anchor.point)
                        handleLines.addLine(to: incoming)
                    }
                    if let outgoing = anchor.outHandle {
                        handleLines.move(to: anchor.point)
                        handleLines.addLine(to: outgoing)
                    }
                }
                context.stroke(handleLines, with: .color(.accentColor.opacity(0.55)), lineWidth: 1)
            }
            ForEach(Array(path.anchors.enumerated()), id: \.offset) { item in
                let index = item.offset
                let anchor = item.element
                Rectangle()
                    .fill(isSelected(.anchor(index)) ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 1.2))
                    .frame(width: 8, height: 8)
                    .position(anchor.point)
                if let incoming = anchor.inHandle {
                    Circle()
                        .fill(isSelected(.incomingHandle(index)) ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.1))
                        .frame(width: 7, height: 7)
                        .position(incoming)
                }
                if let outgoing = anchor.outHandle {
                    Circle()
                        .fill(isSelected(.outgoingHandle(index)) ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.1))
                        .frame(width: 7, height: 7)
                        .position(outgoing)
                }
            }
        }
    }

    private func isSelected(_ component: PathComponent) -> Bool {
        selection?.component == component
    }
}

func swiftUIPath(from bezier: BezierPathV6) -> Path {
    var path = Path()
    guard let first = bezier.anchors.first else { return path }
    path.move(to: first.point)
    let anchors = bezier.anchors
    if anchors.count >= 2 {
        for index in 0..<(anchors.count - 1) {
            let a = anchors[index], b = anchors[index + 1]
            path.addCurve(to: b.point, control1: a.outHandle ?? a.point, control2: b.inHandle ?? b.point)
        }
        if bezier.isClosed, let last = anchors.last {
            path.addCurve(to: first.point, control1: last.outHandle ?? last.point, control2: first.inHandle ?? first.point)
            path.closeSubpath()
        }
    }
    return path
}

private enum ResizeHandle: String, CaseIterable, Identifiable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    var id: String { rawValue }

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    var coreHandle: ResizeHandleV6 {
        switch self {
        case .topLeft: return .topLeft
        case .top: return .top
        case .topRight: return .topRight
        case .right: return .right
        case .bottomRight: return .bottomRight
        case .bottom: return .bottom
        case .bottomLeft: return .bottomLeft
        case .left: return .left
        }
    }

    func resized(_ rect: CGRect, translation: CGSize) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch self {
        case .topLeft:
            minX += translation.width; minY += translation.height
        case .top:
            minY += translation.height
        case .topRight:
            maxX += translation.width; minY += translation.height
        case .right:
            maxX += translation.width
        case .bottomRight:
            maxX += translation.width; maxY += translation.height
        case .bottom:
            maxY += translation.height
        case .bottomLeft:
            minX += translation.width; maxY += translation.height
        case .left:
            minX += translation.width
        }

        if maxX - minX < 4 {
            if self == .left || self == .topLeft || self == .bottomLeft { minX = maxX - 4 }
            else { maxX = minX + 4 }
        }
        if maxY - minY < 4 {
            if self == .top || self == .topLeft || self == .topRight { minY = maxY - 4 }
            else { maxY = minY + 4 }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

enum VectorCanvasRenderer {
    static func draw(_ object: VectorObject, document: OpenDocument, context: inout GraphicsContext, embeddedDepth: Int = 0) {
        if let resourceID = object.embeddedObjectID {
            EmbeddedObjectRuntime.draw(proxy: object, resourceID: resourceID, document: document, context: &context, depth: embeddedDepth)
            return
        }
        if let definitionID = object.symbolDefinitionID {
            SymbolRuntime.draw(proxy: object, definitionID: definitionID, document: document, context: &context, depth: embeddedDepth)
            return
        }
        if object.appearanceStack != nil {
            AppearanceRenderer.draw(object: object, document: document, context: &context)
            return
        }
        context.drawLayer { layer in
            layer.opacity = object.opacity
            layer.blendMode = object.blendMode.graphicsBlendMode
            applyEffects(object, to: &layer)

            let rect = object.bounds
            if object.rotation != 0 {
                layer.translateBy(x: rect.midX, y: rect.midY)
                layer.rotate(by: .degrees(object.rotation))
                layer.translateBy(x: -rect.midX, y: -rect.midY)
            }

            let sx = object.scaleX ?? 1
            let sy = object.scaleY ?? 1
            let shx = object.shearX ?? 0
            let shy = object.shearY ?? 0
            if sx != 1 || sy != 1 || shx != 0 || shy != 0 {
                layer.translateBy(x: rect.midX, y: rect.midY)
                layer.concatenate(CGAffineTransform(a: sx, b: shy, c: shx, d: sy, tx: 0, ty: 0))
                layer.translateBy(x: -rect.midX, y: -rect.midY)
            }

            // Non-destructive Convert to Shape effects override the rendered geometry
            // while keeping the underlying object editable.
            if let conversion = object.effects.last(where: { $0.enabled && $0.kind.category == .convertShape }) {
                let path: Path
                switch conversion.kind {
                case .convertRectangle:
                    path = Path(roundedRect: rect, cornerRadius: 0)
                case .convertRoundedRectangle:
                    path = Path(roundedRect: rect, cornerRadius: max(0, min(conversion.amount, min(rect.width, rect.height) / 2)))
                case .convertEllipse:
                    path = Path(ellipseIn: rect)
                default:
                    path = Path(roundedRect: rect, cornerRadius: 0)
                }
                fill(path, object: object, rect: rect, context: &layer)
                stroke(path, object: object, context: &layer)
                return
            }

            switch object.kind {
            case .rectangle:
                let path = Path(roundedRect: rect, cornerRadius: max(0, min(object.cornerRadius, min(rect.width, rect.height) / 2)))
                fill(path, object: object, rect: rect, context: &layer)
                stroke(path, object: object, context: &layer)

            case .ellipse:
                let path = Path(ellipseIn: rect)
                fill(path, object: object, rect: rect, context: &layer)
                stroke(path, object: object, context: &layer)

            case .polygon:
                let path = polygonPath(in: rect, sides: 6)
                fill(path, object: object, rect: rect, context: &layer)
                stroke(path, object: object, context: &layer)

            case .line:
                let path: Path
                if let anchors = object.bezierAnchors, anchors.count >= 2 {
                    path = swiftUIPath(from: BezierPathV6(anchors: anchors, isClosed: false))
                } else {
                    guard object.points.count >= 2 else { return }
                    var fallback = Path()
                    fallback.move(to: object.points[0].cgPoint)
                    fallback.addLine(to: object.points[1].cgPoint)
                    path = fallback
                }
                layer.stroke(path, with: .color(object.stroke.swiftUIColor), style: strokeStyle(for: object))

            case .image:
                MainActor.assumeIsolated {
                    let nsImage: NSImage?
                    if !(object.rasterFilters ?? []).isEmpty {
                        nsImage = RasterFilterRuntime.filteredImage(for: object, document: document, quality: .preview)
                    } else if let linkedAssetID = object.linkedAssetID {
                        nsImage = LinkedAssetRuntime.image(resourceID: linkedAssetID, document: document, maxPixelDimension: 2048)
                            ?? object.rasterAssetID.flatMap { RasterImageRuntime.image(assetID: $0, document: document, maxPixelDimension: 2048) }
                    } else if let assetID = object.rasterAssetID {
                        nsImage = RasterImageRuntime.image(assetID: assetID, document: document, maxPixelDimension: 2048)
                    } else {
                        nsImage = nil
                    }
                    if let nsImage { layer.draw(Image(nsImage: nsImage), in: rect) }
                    else { missingImagePlaceholder(in: rect, context: &layer) }
                }

            case .text:
                // SwiftUI Canvas uses a synchronous renderer here. Typography resolution
                // touches AppKit's font catalog, which is main-actor isolated, so bridge
                // explicitly instead of calling an actor-isolated method from the
                // nonisolated Canvas renderer closure.
                MainActor.assumeIsolated {
                    TypographyRenderer.draw(object: object, pathLookup: { id in
                        guard let pathObject = document.objects.first(where: { $0.id == id }),
                              let anchors = pathObject.bezierAnchors else { return nil }
                        return BezierPathV6(anchors: anchors, isClosed: pathObject.isClosed == true)
                    }, context: &layer)
                }

            case .path:
                let path: Path
                if let anchors = object.bezierAnchors, !anchors.isEmpty {
                    path = swiftUIPath(from: BezierPathV6(anchors: anchors, isClosed: object.isClosed == true))
                } else {
                    guard let first = object.points.first else { return }
                    var fallback = Path()
                    fallback.move(to: first.cgPoint)
                    for point in object.points.dropFirst() { fallback.addLine(to: point.cgPoint) }
                    if object.isClosed == true { fallback.closeSubpath() }
                    path = fallback
                }
                if object.fill.a > 0 || object.gradient != nil {
                    fill(path, object: object, rect: rect, context: &layer)
                }
                if object.strokeWidth > 0 && object.stroke.a > 0 {
                    layer.stroke(path, with: .color(object.stroke.swiftUIColor), style: strokeStyle(for: object))
                }
            }
        }
    }

    static func clippingPath(for object: VectorObject) -> Path? {
        let rect = object.bounds
        let raw: Path
        switch object.kind {
        case .rectangle:
            raw = Path(roundedRect: rect, cornerRadius: max(0, min(object.cornerRadius, min(rect.width, rect.height) / 2)))
        case .ellipse:
            raw = Path(ellipseIn: rect)
        case .polygon:
            raw = polygonPath(in: rect, sides: 6)
        case .path:
            if let anchors = object.bezierAnchors, !anchors.isEmpty {
                raw = swiftUIPath(from: BezierPathV6(anchors: anchors, isClosed: object.isClosed == true))
            } else if let first = object.points.first {
                var path = Path(); path.move(to: first.cgPoint)
                for point in object.points.dropFirst() { path.addLine(to: point.cgPoint) }
                if object.isClosed == true { path.closeSubpath() }
                raw = path
            } else { return nil }
        case .line, .text, .image:
            raw = Path(rect)
        }

        var transform = CGAffineTransform.identity
        if object.rotation != 0 {
            transform = transform.translatedBy(x: rect.midX, y: rect.midY)
            transform = transform.rotated(by: object.rotation * .pi / 180)
            transform = transform.translatedBy(x: -rect.midX, y: -rect.midY)
        }
        let sx = object.scaleX ?? 1, sy = object.scaleY ?? 1, shx = object.shearX ?? 0, shy = object.shearY ?? 0
        if sx != 1 || sy != 1 || shx != 0 || shy != 0 {
            transform = transform.translatedBy(x: rect.midX, y: rect.midY)
            transform = transform.concatenating(CGAffineTransform(a: sx, b: shy, c: shx, d: sy, tx: 0, ty: 0))
            transform = transform.translatedBy(x: -rect.midX, y: -rect.midY)
        }
        return raw.applying(transform)
    }

    private static func missingImagePlaceholder(in rect: CGRect, context: inout GraphicsContext) {
        let box = Path(rect)
        context.stroke(box, with: .color(.secondary.opacity(0.65)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        let label = Text("Missing Image").font(.system(size: 12)).foregroundColor(.secondary)
        context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY))
    }

    private static func fill(_ path: Path, object: VectorObject, rect: CGRect, context: inout GraphicsContext) {
        if let gradient = object.gradient, gradient.stops.count >= 2 {
            let points = gradientPoints(angle: gradient.angleDegrees, rect: rect)
            let swiftGradient = Gradient(stops: gradient.stops.map {
                Gradient.Stop(color: $0.color.swiftUIColor, location: $0.location)
            })
            context.fill(path, with: .linearGradient(swiftGradient, startPoint: points.start, endPoint: points.end))
        } else if object.fill.a > 0 {
            context.fill(path, with: .color(object.fill.swiftUIColor))
        }
    }

    private static func stroke(_ path: Path, object: VectorObject, context: inout GraphicsContext) {
        guard object.strokeWidth > 0, object.stroke.a > 0 else { return }
        context.stroke(path, with: .color(object.stroke.swiftUIColor), style: strokeStyle(for: object))
    }

    private static func strokeStyle(for object: VectorObject) -> StrokeStyle {
        let cap: CGLineCap
        switch object.lineCap {
        case "round": cap = .round
        case "square": cap = .square
        default: cap = .butt
        }
        let join: CGLineJoin
        switch object.lineJoin {
        case "round": join = .round
        case "bevel": join = .bevel
        default: join = .miter
        }
        return StrokeStyle(lineWidth: max(0.5, object.strokeWidth), lineCap: cap, lineJoin: join, miterLimit: 10, dash: (object.strokeDash ?? []).map { CGFloat($0) }, dashPhase: 0)
    }

    private static func polygonPath(in rect: CGRect, sides: Int) -> Path {
        var path = Path()
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<sides {
            let angle = -Double.pi / 2 + Double(i) * 2 * Double.pi / Double(sides)
            let point = CGPoint(
                x: center.x + cos(angle) * radiusX,
                y: center.y + sin(angle) * radiusY
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private static func gradientPoints(angle: Double, rect: CGRect) -> (start: CGPoint, end: CGPoint) {
        let radians = angle * Double.pi / 180
        let direction = CGVector(dx: cos(radians), dy: sin(radians))
        let radius = hypot(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return (
            CGPoint(x: center.x - direction.dx * radius, y: center.y - direction.dy * radius),
            CGPoint(x: center.x + direction.dx * radius, y: center.y + direction.dy * radius)
        )
    }

    static func applyEffects(_ object: VectorObject, to context: inout GraphicsContext, include: (VectorEffect) -> Bool = { _ in true }) {
        let rect = object.bounds
        func centered(_ transform: CGAffineTransform) {
            context.translateBy(x: rect.midX, y: rect.midY)
            context.concatenate(transform)
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }

        for effect in object.effects where effect.enabled && include(effect) {
            let a = effect.amount
            switch effect.kind {
            // Core + blur
            case .blur, .gaussianBlur:
                context.addFilter(.blur(radius: max(0, a)))
            case .radialBlur:
                context.addFilter(.blur(radius: max(0, a * 0.75)))
                centered(CGAffineTransform(scaleX: 1.005 + a/2500, y: 1.005 + a/2500))
            case .zoomBlur:
                context.addFilter(.blur(radius: max(0, a * 0.55)))
                centered(CGAffineTransform(scaleX: 1 + a/700, y: 1 + a/700))
            case .smartBlur:
                context.addFilter(.blur(radius: max(0, a * 0.45)))
                context.addFilter(.contrast(1.0 + a/80))
            case .motionBlur:
                context.addFilter(.blur(radius: max(0, a * 0.55)))
                context.translateBy(x: a * 0.18, y: 0)

            // Convert-to-shape geometry is handled by drawObject above.
            case .convertRectangle, .convertRoundedRectangle, .convertEllipse:
                break

            // Stylize
            case .shadow:
                context.addFilter(.shadow(color: .black.opacity(0.30), radius: max(0,a), x: 0, y: a * 0.45))
            case .glow:
                context.addFilter(.shadow(color: object.fill.swiftUIColor.opacity(0.68), radius: max(0,a), x: 0, y: 0))
            case .innerShadow:
                context.addFilter(.shadow(color: .black.opacity(0.38), radius: max(0,a*0.65), x: -a*0.22, y: a*0.22))
                context.addFilter(.contrast(1.04))
            case .innerGlow:
                context.addFilter(.shadow(color: .white.opacity(0.58), radius: max(0,a*0.55), x: 0, y: 0))
            case .feather:
                context.addFilter(.blur(radius: max(0,a*0.42)))
            case .roundCorners:
                context.addFilter(.blur(radius: min(2.4, max(0,a/16))))
                context.addFilter(.contrast(1.06))
            case .scribble:
                context.addFilter(.shadow(color: object.stroke.swiftUIColor.opacity(0.55), radius: max(0.5,a*0.12), x: a*0.15, y: -a*0.10))
            case .neonEdge, .glowingEdges:
                context.addFilter(.contrast(1.45))
                context.addFilter(.saturation(1.5))
                context.addFilter(.shadow(color: object.fill.swiftUIColor.opacity(0.86), radius: max(3,a), x: 0, y: 0))

            // Color
            case .brightness:
                context.addFilter(.brightness(a))
            case .contrast:
                context.addFilter(.contrast(max(0,a)))
            case .saturation:
                context.addFilter(.saturation(max(0,a)))
            case .hueRotate:
                context.addFilter(.hueRotation(.degrees(a)))
            case .grayscale:
                context.addFilter(.grayscale(max(0,min(1,a))))
            case .sepia:
                context.addFilter(.colorMultiply(Color(red: 1, green: max(0.55, 0.94 - a * 0.10), blue: max(0.35, 0.88 - a * 0.35))))
            case .invert:
                context.addFilter(.colorInvert(max(0,min(1,a))))
            case .exposure:
                context.addFilter(.brightness(a * 0.55)); context.addFilter(.contrast(1 + abs(a)*0.20))
            case .vibrance:
                context.addFilter(.saturation(max(0,a))); context.addFilter(.contrast(1.04))
            case .temperature:
                if a >= 0 { context.addFilter(.colorMultiply(Color(red: 1, green: 1-a*0.08, blue: 1-a*0.28))) }
                else { context.addFilter(.colorMultiply(Color(red: 1+a*0.28, green: 1+a*0.06, blue: 1))) }
            case .posterize:
                context.addFilter(.contrast(1 + a*0.9)); context.addFilter(.saturation(1+a*0.25))
            case .threshold:
                context.addFilter(.grayscale(1)); context.addFilter(.contrast(1 + a*4))
            case .colorBoost:
                context.addFilter(.saturation(max(0,a))); context.addFilter(.contrast(1.08))
            case .fade:
                context.addFilter(.contrast(max(0.25,1-a*0.35))); context.addFilter(.brightness(a*0.16))

            // Distort & transform
            case .offset:
                context.translateBy(x: a, y: a*0.45)
            case .transformScale:
                centered(CGAffineTransform(scaleX: max(0.05,a), y: max(0.05,a)))
            case .transformRotate:
                context.translateBy(x: rect.midX, y: rect.midY); context.rotate(by: .degrees(a)); context.translateBy(x: -rect.midX, y: -rect.midY)
            case .freeDistort:
                centered(CGAffineTransform(a: 1, b: a*0.18, c: -a*0.22, d: 1, tx: 0, ty: 0))
            case .puckerBloat:
                let s = max(0.35, 1 + (a-0.5)*0.52); centered(CGAffineTransform(scaleX: s, y: s))
            case .roughen:
                context.addFilter(.shadow(color: .black.opacity(0.22), radius: 0.8+a*2.2, x: a*3.5, y: -a*2.2))
            case .tweak:
                centered(CGAffineTransform(a: 1, b: a*0.12, c: a*0.16, d: 1-a*0.06, tx: 0, ty: 0))
            case .twist:
                context.translateBy(x: rect.midX, y: rect.midY); context.rotate(by: .degrees(a*0.32)); context.translateBy(x: -rect.midX, y: -rect.midY)
                centered(CGAffineTransform(a: 1, b: a/500, c: -a/600, d: 1, tx: 0, ty: 0))
            case .zigZag:
                centered(CGAffineTransform(a: 1, b: a*0.08, c: -a*0.08, d: 1, tx: 0, ty: 0))
                context.addFilter(.shadow(color: object.stroke.swiftUIColor.opacity(0.35), radius: 0.5+a*1.5, x: a*3, y: 0))

            // Warp approximations
            case .warpArc:
                centered(CGAffineTransform(a: 1, b: a*0.22, c: 0, d: 1-a*0.10, tx: 0, ty: 0))
            case .warpArch:
                centered(CGAffineTransform(a: 1-a*0.08, b: 0, c: 0, d: 1+a*0.22, tx: 0, ty: 0))
            case .warpBulge:
                centered(CGAffineTransform(scaleX: 1+a*0.28, y: 1-a*0.08))
            case .warpFlag:
                centered(CGAffineTransform(a: 1, b: a*0.18, c: a*0.06, d: 1, tx: 0, ty: 0))
            case .warpFish:
                centered(CGAffineTransform(a: 1+a*0.20, b: a*0.08, c: -a*0.10, d: 1-a*0.08, tx: 0, ty: 0))
            case .warpInflate:
                centered(CGAffineTransform(scaleX: 1+a*0.25, y: 1+a*0.25))
            case .warpRise:
                centered(CGAffineTransform(a: 1, b: -a*0.10, c: 0, d: 1+a*0.16, tx: 0, ty: 0))
            case .warpShellLower:
                centered(CGAffineTransform(a: 1-a*0.10, b: 0, c: a*0.18, d: 1, tx: 0, ty: 0))
            case .warpShellUpper:
                centered(CGAffineTransform(a: 1+a*0.10, b: 0, c: -a*0.18, d: 1, tx: 0, ty: 0))
            case .warpSqueeze:
                centered(CGAffineTransform(scaleX: max(0.25,1-a*0.45), y: 1+a*0.10))
            case .warpWave:
                centered(CGAffineTransform(a: 1, b: a*0.20, c: -a*0.20, d: 1, tx: 0, ty: 0))

            // Path-ish appearance
            case .offsetPath:
                context.addFilter(.shadow(color: object.fill.swiftUIColor.opacity(0.75), radius: abs(a)*0.25, x: a*0.35, y: a*0.35))
            case .outlineObject:
                context.addFilter(.contrast(1.7)); context.addFilter(.grayscale(0.25))
            case .outlineStroke:
                context.addFilter(.shadow(color: object.stroke.swiftUIColor.opacity(0.9), radius: max(1,abs(a)*0.12), x: 0, y: 0))

            // Pathfinder effects are resolved at selection level by EditorStore.
            // Retained instances render safely if loaded from a document.
            case .pathfinderAdd, .pathfinderIntersect, .pathfinderExclude, .pathfinderSubtract, .pathfinderMinusBack,
                 .pathfinderDivide, .pathfinderTrim, .pathfinderMerge, .pathfinderCrop, .pathfinderOutline:
                context.addFilter(.contrast(1.0 + a * 0.04))

            // 3D-ish native approximations
            case .plane3D:
                context.addFilter(.contrast(1.04)); context.addFilter(.brightness(0.02))
            case .extrude3D:
                context.addFilter(.shadow(color: .black.opacity(0.38), radius: max(2,abs(a)*0.28), x: a*0.65, y: a*0.65)); context.addFilter(.contrast(1.10))
            case .revolve3D:
                context.addFilter(.contrast(1.22)); context.addFilter(.brightness(0.05)); context.addFilter(.shadow(color: .black.opacity(0.24), radius: 9, x: 7, y: 3))
            case .inflate3D:
                context.addFilter(.brightness(0.08+a*0.06)); context.addFilter(.contrast(1.18)); context.addFilter(.shadow(color: .white.opacity(0.30), radius: 5+a*4, x: -4, y: -4))

            // Artistic
            case .coloredPencil:
                context.addFilter(.saturation(1.35)); context.addFilter(.contrast(1.18)); context.addFilter(.blur(radius: a*0.6))
            case .cutout:
                context.addFilter(.contrast(1.55+a*0.6)); context.addFilter(.saturation(0.82))
            case .dryBrush:
                context.addFilter(.contrast(1.28)); context.addFilter(.saturation(0.72)); context.addFilter(.blur(radius: a*0.45))
            case .filmGrain:
                context.addFilter(.contrast(1.18)); context.addFilter(.grayscale(a*0.25))
            case .fresco:
                context.addFilter(.saturation(1.14)); context.addFilter(.contrast(1.30)); context.addFilter(.brightness(0.04))
            case .neonGlow:
                context.addFilter(.contrast(1.45)); context.addFilter(.saturation(1.65)); context.addFilter(.shadow(color: object.fill.swiftUIColor.opacity(0.85), radius: 8+a*10, x: 0, y: 0))
            case .paintDaubs:
                context.addFilter(.blur(radius: a*1.25)); context.addFilter(.contrast(1.22)); context.addFilter(.saturation(1.12))
            case .paletteKnife:
                context.addFilter(.contrast(1.48)); context.addFilter(.saturation(1.08)); context.addFilter(.blur(radius: a*0.45))
            case .plasticWrap:
                context.addFilter(.contrast(1.40)); context.addFilter(.brightness(0.10)); context.addFilter(.shadow(color: .white.opacity(0.35), radius: 4+a*5, x: -2, y: -2))
            case .posterEdges:
                context.addFilter(.contrast(1.60)); context.addFilter(.saturation(0.82))
            case .roughPastels:
                context.addFilter(.saturation(0.76)); context.addFilter(.contrast(1.16)); context.addFilter(.blur(radius: a*0.55))
            case .smudgeStick:
                context.addFilter(.blur(radius: 1+a*2.6)); context.addFilter(.contrast(1.10))
            case .sponge:
                context.addFilter(.saturation(0.82)); context.addFilter(.contrast(1.32)); context.addFilter(.brightness(0.03))
            case .underpainting:
                context.addFilter(.blur(radius: 0.8+a)); context.addFilter(.saturation(0.88)); context.addFilter(.contrast(1.18))
            case .watercolor:
                context.addFilter(.blur(radius: 0.7+a*1.3)); context.addFilter(.saturation(0.80)); context.addFilter(.contrast(1.24))

            // Brush Strokes
            case .accentedEdges:
                context.addFilter(.contrast(1.55)); context.addFilter(.shadow(color: .white.opacity(0.24), radius: 1+a*1.2, x: -1, y: -1))
            case .angledStrokes:
                centered(CGAffineTransform(a: 1, b: a*0.06, c: -a*0.04, d: 1, tx: 0, ty: 0)); context.addFilter(.contrast(1.25))
            case .crosshatch:
                context.addFilter(.grayscale(0.18)); context.addFilter(.contrast(1.48)); context.addFilter(.shadow(color: .black.opacity(0.20), radius: 0.6+a, x: 2, y: -2))
            case .darkStrokes:
                context.addFilter(.contrast(1.65)); context.addFilter(.brightness(-0.08-a*0.08))
            case .inkOutlines:
                context.addFilter(.grayscale(0.62)); context.addFilter(.contrast(1.88))
            case .spatter:
                context.addFilter(.contrast(1.38)); context.addFilter(.blur(radius: 0.4+a*1.2)); context.addFilter(.shadow(color: .black.opacity(0.18), radius: 1+a, x: 2, y: 1))
            case .sprayedStrokes:
                context.addFilter(.saturation(1.18)); context.addFilter(.contrast(1.30)); context.addFilter(.blur(radius: 0.5+a))
            case .sumiE:
                context.addFilter(.grayscale(0.82)); context.addFilter(.contrast(1.72)); context.addFilter(.blur(radius: 0.3+a*0.8))

            // Raster Distort
            case .diffuseGlow:
                context.addFilter(.brightness(0.08+a*0.08)); context.addFilter(.blur(radius: 1+a*3)); context.addFilter(.shadow(color: .white.opacity(0.38), radius: 4+a*8, x: 0, y: 0))
            case .glass:
                centered(CGAffineTransform(a: 1, b: a*0.05, c: -a*0.07, d: 1, tx: 0, ty: 0)); context.addFilter(.blur(radius: 0.7+a*1.8)); context.addFilter(.contrast(1.18))
            case .oceanRipple:
                centered(CGAffineTransform(a: 1, b: a*0.08, c: a*0.08, d: 1, tx: 0, ty: 0)); context.addFilter(.saturation(1.10)); context.addFilter(.blur(radius: 0.4+a))

            // Pixelate approximations using native filters only
            case .colorHalftone:
                context.addFilter(.contrast(1.45)); context.addFilter(.saturation(1.16)); context.addFilter(.blur(radius: max(0.3, a/18)))
            case .crystallize:
                context.addFilter(.blur(radius: 0.8+a*1.8)); context.addFilter(.contrast(1.55))
            case .mezzotint:
                context.addFilter(.grayscale(0.72)); context.addFilter(.contrast(1.8+a))
            case .mosaic:
                context.addFilter(.blur(radius: 1+a*3)); context.addFilter(.contrast(1.7))
            case .pointillize:
                context.addFilter(.blur(radius: 0.6+a*2)); context.addFilter(.saturation(1.24)); context.addFilter(.contrast(1.34))

            // Sketch / texture
            case .basRelief:
                context.addFilter(.grayscale(0.85)); context.addFilter(.contrast(1.55)); context.addFilter(.shadow(color: .white.opacity(0.34), radius: 2, x: -2, y: -2))
            case .chalkCharcoal:
                context.addFilter(.grayscale(0.92)); context.addFilter(.contrast(1.74)); context.addFilter(.blur(radius: 0.3+a*0.7))
            case .charcoal:
                context.addFilter(.grayscale(1)); context.addFilter(.contrast(1.75)); context.addFilter(.blur(radius: a*0.35))
            case .chrome:
                context.addFilter(.grayscale(0.82)); context.addFilter(.contrast(1.85)); context.addFilter(.brightness(0.08))
            case .conteCrayon:
                context.addFilter(.grayscale(0.72)); context.addFilter(.contrast(1.52))
            case .graphicPen:
                context.addFilter(.grayscale(1)); context.addFilter(.contrast(2.15))
            case .halftonePattern:
                context.addFilter(.grayscale(0.55)); context.addFilter(.contrast(1.62))
            case .notePaper:
                context.addFilter(.grayscale(0.40)); context.addFilter(.contrast(1.30)); context.addFilter(.brightness(0.10))
            case .photocopy:
                context.addFilter(.grayscale(1)); context.addFilter(.contrast(2.35))
            case .plaster:
                context.addFilter(.grayscale(0.78)); context.addFilter(.contrast(1.42)); context.addFilter(.brightness(0.08))
            case .reticulation:
                context.addFilter(.contrast(1.58)); context.addFilter(.saturation(0.65))
            case .stamp:
                context.addFilter(.grayscale(1)); context.addFilter(.contrast(2.8))
            case .tornEdges:
                context.addFilter(.grayscale(0.85)); context.addFilter(.contrast(1.95)); context.addFilter(.blur(radius: 0.5+a*0.7))
            case .waterPaper:
                context.addFilter(.blur(radius: 0.7+a*1.5)); context.addFilter(.saturation(0.84)); context.addFilter(.contrast(1.18))

            // Texture
            case .craquelure:
                context.addFilter(.contrast(1.42)); context.addFilter(.grayscale(0.22))
            case .grain:
                context.addFilter(.contrast(1.22)); context.addFilter(.grayscale(a*0.20))
            case .mosaicTiles:
                context.addFilter(.blur(radius: 1+a*2)); context.addFilter(.contrast(1.62)); context.addFilter(.saturation(1.08))
            case .patchwork:
                context.addFilter(.contrast(1.52)); context.addFilter(.saturation(0.92))
            case .stainedGlass:
                context.addFilter(.contrast(1.75)); context.addFilter(.saturation(1.42))
            case .texturizer:
                context.addFilter(.contrast(1.25)); context.addFilter(.saturation(0.90)); context.addFilter(.blur(radius: a*0.35))

            // Video
            case .deInterlace:
                context.addFilter(.blur(radius: 0.35+a*0.45)); context.addFilter(.contrast(1.04))
            case .ntscColors:
                context.addFilter(.saturation(0.82)); context.addFilter(.contrast(0.96))

            // Rasterize / SVG equivalents
            case .rasterize:
                // Openstrator stays resolution-independent internally; this preview mimics
                // a rasterized appearance without destructively replacing the source.
                context.addFilter(.blur(radius: a > 250 ? 0.15 : 0.45))
            case .svgFilter:
                context.addFilter(.shadow(color: object.fill.swiftUIColor.opacity(0.30), radius: 4 + a*8, x: 1, y: 2))
                context.addFilter(.contrast(1.03 + a*0.08))
            }
        }
    }
}

private extension BlendModeKind {
    var graphicsBlendMode: GraphicsContext.BlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .darken: return .darken
        case .lighten: return .lighten
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .difference: return .difference
        case .exclusion: return .exclusion
        }
    }
}

private extension Font.Weight {
    init(weightValue: Double) {
        switch weightValue {
        case ..<0.15: self = .ultraLight
        case ..<0.28: self = .light
        case ..<0.42: self = .regular
        case ..<0.56: self = .medium
        case ..<0.70: self = .semibold
        case ..<0.84: self = .bold
        default: self = .heavy
        }
    }
}
