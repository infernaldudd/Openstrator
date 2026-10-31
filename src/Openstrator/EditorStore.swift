import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OpenstratorCore

struct DirectComponentSelection: Equatable {
    var objectID: UUID
    var component: PathComponent
}

@MainActor
final class EditorStore: ObservableObject {
    @Published var document = OpenDocument()
    @Published var selection: Set<UUID> = []
    @Published var activeTool: ToolKind = .select
    @Published var zoom: Double = 1
    @Published var pan: CGSize = .zero
    @Published var viewRotation: Double = 0
    @Published var didFinishSplash = false
    @Published var status = "Ready"
    @Published var draftPath: [CGPoint] = []
    @Published var draftBezierPath: BezierPathV6? = nil
    @Published var directComponentSelection: DirectComponentSelection? = nil
    @Published var draftShapeRect: CGRect? = nil
    @Published var currentFileURL: URL? = nil
    @Published var keybinds: [KeybindDefinition] = EditorStore.loadKeybinds() {
        didSet { persistKeybinds() }
    }
    @Published var recentFontFamilies: [String] = UserDefaults.standard.stringArray(forKey: "recentFontFamilies.v3") ?? []
    @Published var favoriteFontFamilies: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "favoriteFontFamilies.v3") ?? [])

    let architecture = ArchitectureProfile.current

    private var keyMonitor: Any?
    private var undoStack: [OpenDocument] = []
    private var redoStack: [OpenDocument] = []
    private var internalClipboard: [VectorObject] = []
    private var internalClipboardRasterAssets: [UUID: RasterAssetRecord] = [:]
    private var internalClipboardResources: ResourceLibraryV6?
    private var autosaveTask: Task<Void, Never>?
    private var interactiveMoveOriginals: [UUID: VectorObject] = [:]
    private var interactiveMoveStart: CGPoint?
    private var interactiveMoveDidSnapshot = false
    private var penBuilder = PenPathBuilder(closeTolerance: 8)
    private var curvatureBuilder = CurvaturePathBuilder(closeTolerance: 8)
    private var draftBezierTool: ToolKind?
    private var directMoveOriginalPath: BezierPathV6?
    private var directMoveStart: CGPoint?
    private var directMoveDidSnapshot = false
    private var appearancePreviewObjectID: UUID?
    private var appearancePreviewOriginalObject: VectorObject?
    private var appearancePreviewOriginalDocument: OpenDocument?
    private var rasterFilterPreviewObjectID: UUID?
    private var rasterFilterPreviewOriginalObject: VectorObject?
    private var rasterFilterPreviewOriginalDocument: OpenDocument?

    init() {
        seedWelcomeDocument()
        ensureM6LayerTree()
    }


    private func seedWelcomeDocument() {
        guard document.objects.isEmpty else { return }

        var title = VectorObject.text(at: CGPoint(x: 132, y: 155))
        title.text = "Openstrator"
        title.fontSize = 64
        title.width = 410

        var subtitle = VectorObject.text(at: CGPoint(x: 138, y: 247))
        subtitle.text = "Native vector design for macOS"
        subtitle.fontSize = 22
        subtitle.fill = RGBAColor(r: 0.30, g: 0.33, b: 0.39)
        subtitle.width = 450

        var card = VectorObject.rectangle(at: CGPoint(x: 695, y: 180), size: CGSize(width: 300, height: 300))
        card.cornerRadius = 38
        card.gradient = LinearGradientModel(
            angleDegrees: 42,
            stops: [
                GradientStopModel(location: 0, color: RGBAColor(r: 0.10, g: 0.17, b: 0.28)),
                GradientStopModel(location: 1, color: RGBAColor(r: 0.10, g: 0.48, b: 0.98))
            ]
        )
        card.effects = [VectorEffect(kind: .shadow, amount: 15)]

        var circle = VectorObject.ellipse(at: CGPoint(x: 765, y: 250), size: CGSize(width: 160, height: 160))
        circle.fill = .clear
        circle.stroke = .white
        circle.strokeWidth = 8
        circle.opacity = 0.88

        document.objects = [title, subtitle, card, circle]
    }

    // MARK: - Keyboard

    func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if NSApp.keyWindow?.firstResponder is NSTextView { return event }
            return self.handleShortcut(event) ? nil : event
        }
    }

    func handleCanvasKeyCode(_ keyCode: UInt16, textEditingActive: Bool) -> Bool {
        guard !textEditingActive else { return false }
        if keyCode == 53, draftBezierPath != nil { // Escape
            cancelDraftBezierPath()
            return true
        }
        if keyCode == 36, draftBezierPath != nil { // Return
            finishDraftBezierPath()
            return true
        }
        if (keyCode == 51 || keyCode == 117), directComponentSelection != nil {
            deleteDirectComponentSelection()
            return true
        }
        if CanvasKeyRouting.shouldHandleDelete(keyCode: keyCode, hasSelection: !selection.isEmpty, textEditingActive: false) {
            deleteSelection()
            return true
        }
        switch keyCode {
        case 123: guard !selection.isEmpty else { return false }; nudgeSelection(dx: -1, dy: 0, coarse: false); return true
        case 124: guard !selection.isEmpty else { return false }; nudgeSelection(dx: 1, dy: 0, coarse: false); return true
        case 125: guard !selection.isEmpty else { return false }; nudgeSelection(dx: 0, dy: 1, coarse: false); return true
        case 126: guard !selection.isEmpty else { return false }; nudgeSelection(dx: 0, dy: -1, coarse: false); return true
        default: return false
        }
    }

    private func handleShortcut(_ event: NSEvent) -> Bool {
        let filtered = event.modifierFlags.intersection([.command, .shift, .option, .control])

        if filtered.isEmpty, handleCanvasKeyCode(event.keyCode, textEditingActive: NSApp.keyWindow?.firstResponder is NSTextView) {
            return true
        }

        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        for bind in keybinds where bind.key.lowercased() == key {
            let needed = modifierFlags(for: bind.modifiers)
            guard needed == filtered else { continue }
            performKeybind(bind.id)
            return true
        }
        return false
    }

    private func modifierFlags(for modifiers: [String]) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains("command") { flags.insert(.command) }
        if modifiers.contains("shift") { flags.insert(.shift) }
        if modifiers.contains("option") { flags.insert(.option) }
        if modifiers.contains("control") { flags.insert(.control) }
        return flags
    }

    private func performKeybind(_ id: String) {
        switch id {
        case "select": activeTool = .select
        case "pen": activeTool = .pen
        case "pencil": activeTool = .pencil
        case "addText": addText()
        case "addRectangle": addRectangle()
        case "addEllipse": addEllipse()
        case "addPolygon": addPolygon()
        case "duplicate": duplicateSelection()
        case "zoomActual": zoom = 1; pan = .zero
        case "exportSVG": exportSVG()
        case "alignCenter": alignSelection(.horizontalCenter)
        default: break
        }
    }

    private func persistKeybinds() {
        guard let data = try? JSONEncoder().encode(keybinds) else { return }
        UserDefaults.standard.set(data, forKey: "customKeybinds.v2")
    }

    static func loadKeybinds() -> [KeybindDefinition] {
        guard let data = UserDefaults.standard.data(forKey: "customKeybinds.v2"),
              let decoded = try? JSONDecoder().decode([KeybindDefinition].self, from: data) else {
            return defaultKeybinds
        }
        return decoded
    }

    func resetKeybinds() {
        keybinds = Self.defaultKeybinds
    }

    func keybindConflict(for candidate: KeybindDefinition) -> String? {
        let normalizedModifiers = candidate.modifiers.sorted()
        if let other = keybinds.first(where: {
            $0.id != candidate.id &&
            $0.key.lowercased() == candidate.key.lowercased() &&
            $0.modifiers.sorted() == normalizedModifiers
        }) {
            return "Already used by \(other.title)."
        }
        return nil
    }

    // MARK: - Selection

    var selectedIndices: [Int] {
        document.objects.indices.filter { selection.contains(document.objects[$0].id) }
    }

    var selectedObjects: [VectorObject] {
        selectedIndices.map { document.objects[$0] }
    }

    var primarySelectedIndex: Int? {
        guard let id = selection.first else { return nil }
        return document.objects.firstIndex { $0.id == id }
    }

    var primarySelectedObject: VectorObject? {
        guard let i = primarySelectedIndex else { return nil }
        return document.objects[i]
    }

    var selectionBounds: CGRect? {
        let objects = selectedObjects
        guard let first = objects.first else { return nil }
        return objects.dropFirst().reduce(first.bounds) { $0.union($1.bounds) }
    }

    func select(at point: CGPoint, additive: Bool = false) {
        guard let hit = hitTest(point) else {
            if !additive { selection.removeAll() }
            return
        }

        let ids: Set<UUID>
        if let group = hit.groupID {
            ids = Set(document.objects.filter { $0.groupID == group }.map(\.id))
        } else {
            ids = [hit.id]
        }

        if additive {
            for id in ids {
                if selection.contains(id) { selection.remove(id) }
                else { selection.insert(id) }
            }
        } else {
            selection = ids
        }
    }

    private func hitTest(_ point: CGPoint) -> VectorObject? {
        if let data = try? JSONEncoder().encode(document),
           let v6 = try? V5Migrator.decodeAndMigrate(data),
           let hit = HitTester.hitTest(point: point, in: v6, options: HitTestOptions(tolerance: max(2, 6 / max(0.1, zoom)))) {
            return document.objects.first { $0.id == hit.nodeID.rawValue }
        }
        return document.objects.reversed().first { object in
            guard object.isVisible, !object.isLocked else { return false }
            return object.bounds.insetBy(dx: -max(5, object.strokeWidth), dy: -max(5, object.strokeWidth)).contains(point)
        }
    }

    func selectAll() {
        selection = Set(document.objects.filter { $0.isVisible && !$0.isLocked }.map(\.id))
    }

    func deselectAll() {
        selection.removeAll()
    }

    // MARK: - History

    func snapshot() {
        if undoStack.last != document { undoStack.append(document) }
        if undoStack.count > architecture.undoLimit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(document)
        document = previous
        LayerThumbnailCache.shared.removeAll()
        selection.removeAll()
        status = "Undo"
        scheduleAutosave()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(document)
        document = next
        LayerThumbnailCache.shared.removeAll()
        selection.removeAll()
        status = "Redo"
        scheduleAutosave()
    }

    func commitMutation(status message: String = "Edited") {
        reconcileM6LayerTree()
        LayerThumbnailCache.shared.removeAll()
        status = message
        scheduleAutosave()
    }

    // MARK: - File operations

    private var openstratorType: UTType {
        UTType(filenameExtension: "openstrator") ?? .json
    }

    func newDocument() {
        snapshot()
        document = OpenDocument()
        currentFileURL = nil
        selection.removeAll()
        zoom = 1
        pan = .zero
        undoStack.removeAll()
        redoStack.removeAll()
        ensureM6LayerTree()
        status = "New document"
        scheduleAutosave()
    }

    func saveDocument(saveAs: Bool = false) {
        if !saveAs, let currentFileURL {
            writeDocument(to: currentFileURL)
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Openstrator Document"
        panel.nameFieldStringValue = document.name + ".openstrator"
        panel.allowedContentTypes = [openstratorType]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        writeDocument(to: url)
    }

    private func writeDocument(to url: URL) {
        do {
            var output = document
            output.name = url.deletingPathExtension().lastPathComponent
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(output).write(to: url, options: .atomic)
            document.name = output.name
            currentFileURL = url
            status = "Saved \(url.lastPathComponent)"
            scheduleAutosave()
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.title = "Open Openstrator Document"
        panel.allowedContentTypes = [openstratorType, .json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openDocument(at: url)
    }

    func openDocument(at url: URL) {
        do {
            let loaded = try JSONDecoder().decode(OpenDocument.self, from: Data(contentsOf: url))
            document = loaded
            ensureM6LayerTree()
            document.name = url.deletingPathExtension().lastPathComponent
            currentFileURL = url
            selection.removeAll()
            undoStack.removeAll()
            redoStack.removeAll()
            zoom = 1
            pan = .zero
            status = "Opened \(url.lastPathComponent)"
            scheduleAutosave()
        } catch {
            status = "Open failed: \(error.localizedDescription)"
        }
    }

    func placeImages() {
        let panel = NSOpenPanel()
        panel.title = "Place Images"
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        placeImages(at: panel.urls, dropPoint: nil)
    }

    func placeImages(at urls: [URL], dropPoint: CGPoint? = nil) {
        guard !urls.isEmpty else { return }

        var imports: [(RasterAssetRecord, URL)] = []
        imports.reserveCapacity(urls.count)
        for url in urls {
            if let asset = try? RasterImageRuntime.metadataAndEmbeddedAsset(from: url) {
                imports.append((asset, url))
            }
        }
        guard !imports.isEmpty else {
            status = "No supported images were placed"
            return
        }

        snapshot()
        var assets = document.rasterAssets ?? []
        var created: [UUID] = []
        created.reserveCapacity(imports.count)
        let artW = CGFloat(document.artboardWidth)
        let artH = CGFloat(document.artboardHeight)
        let maxW = max(CGFloat(1), artW * 0.60)
        let maxH = max(CGFloat(1), artH * 0.60)
        let base = dropPoint ?? CGPoint(x: artW / 2, y: artH / 2)

        for (index, item) in imports.enumerated() {
            let asset = item.0
            let pixelW = CGFloat(asset.metadata.pixelWidth)
            let pixelH = CGFloat(asset.metadata.pixelHeight)
            let scale = min(CGFloat(1), min(maxW / pixelW, maxH / pixelH))
            let size = CGSize(
                width: max(CGFloat(1), pixelW * scale),
                height: max(CGFloat(1), pixelH * scale)
            )
            let stagger = CGFloat(index) * 24
            let origin = CGPoint(
                x: base.x - size.width / 2 + stagger,
                y: base.y - size.height / 2 + stagger
            )
            var object = VectorObject.image(
                assetID: asset.id,
                at: origin,
                size: size,
                name: item.1.deletingPathExtension().lastPathComponent
            )
            object.rasterFilters = []
            assets.append(asset)
            document.objects.append(object)
            created.append(object.id)
        }

        document.rasterAssets = assets
        selection = Set(created)
        commitMutation(status: imports.count == 1 ? "Image placed" : "\(imports.count) images placed")
    }

    func exportSVG() {
        let panel = NSSavePanel()
        panel.title = "Export SVG"
        panel.nameFieldStringValue = document.name + ".svg"
        if let svg = UTType(filenameExtension: "svg") { panel.allowedContentTypes = [svg] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SVGExporter.string(for: document).write(to: url, atomically: true, encoding: .utf8)
            status = "Exported \(url.lastPathComponent)"
        } catch {
            status = "SVG export failed: \(error.localizedDescription)"
        }
    }

    func exportPNG() {
        let panel = NSSavePanel()
        panel.title = "Export PNG"
        panel.nameFieldStringValue = document.name + ".png"
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try NativeExporter.exportPNG(document: document, to: url)
            status = "Exported \(url.lastPathComponent)"
        } catch {
            status = "PNG export failed: \(error.localizedDescription)"
        }
    }

    func exportPDF() {
        let panel = NSSavePanel()
        panel.title = "Export PDF"
        panel.nameFieldStringValue = document.name + ".pdf"
        panel.allowedContentTypes = [.pdf]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try NativeExporter.exportPDF(document: document, to: url)
            status = "Exported \(url.lastPathComponent)"
        } catch {
            status = "PDF export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Recovery

    private var recoveryURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let directory = appSupport.appendingPathComponent("Openstrator", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Autosave.openstrator")
    }

    var hasRecoverySnapshot: Bool {
        guard let recoveryURL else { return false }
        return FileManager.default.fileExists(atPath: recoveryURL.path)
    }

    func restoreRecoverySnapshot() {
        guard let recoveryURL else { return }
        do {
            let loaded = try JSONDecoder().decode(OpenDocument.self, from: Data(contentsOf: recoveryURL))
            snapshot()
            document = loaded
            currentFileURL = nil
            selection.removeAll()
            status = "Recovered autosave"
        } catch {
            status = "Recovery failed: \(error.localizedDescription)"
        }
    }

    private func scheduleAutosave() {
        guard UserDefaults.standard.object(forKey: "autosaveEnabled") as? Bool ?? true else { return }
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.writeRecoverySnapshot()
        }
    }

    private func writeRecoverySnapshot() {
        guard let recoveryURL else { return }
        do {
            let encoder = JSONEncoder()
            try encoder.encode(document).write(to: recoveryURL, options: .atomic)
        } catch {
            // Recovery is best-effort and should never interrupt drawing.
        }
    }

    // MARK: - Object creation

    func addRectangle(at point: CGPoint = CGPoint(x: 260, y: 220), size: CGSize = CGSize(width: 180, height: 120)) {
        snapshot()
        let object = VectorObject.rectangle(at: snapped(point), size: size)
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: "Rectangle created")
    }

    func addEllipse(at point: CGPoint = CGPoint(x: 300, y: 250), size: CGSize = CGSize(width: 140, height: 140)) {
        snapshot()
        let object = VectorObject.ellipse(at: snapped(point), size: size)
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: "Ellipse created")
    }

    func addPolygon(at point: CGPoint = CGPoint(x: 320, y: 250), size: CGSize = CGSize(width: 160, height: 150)) {
        snapshot()
        let object = VectorObject.polygon(at: snapped(point), size: size)
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: "Polygon created")
    }

    func addLine(from start: CGPoint, to end: CGPoint) {
        snapshot()
        let object = VectorObject.line(from: snapped(start), to: snapped(end))
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: "Line created")
    }

    func addText(at point: CGPoint = CGPoint(x: 280, y: 280)) {
        snapshot()
        var object = VectorObject.text(at: snapped(point))
        var data = object.resolvedTypography
        data.layoutMode = .point
        object.applyTypography(data)
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: "Text created")
    }

    func addVerticalText(at point: CGPoint = CGPoint(x: 280, y: 280)) {
        snapshot()
        var object = VectorObject.text(at: snapped(point))
        object.name = "Vertical Type"
        object.width = 90
        object.height = 320
        var data = object.resolvedTypography
        data.text = "Vertical"
        object.text = data.text
        data.frame = object.bounds
        data.layoutMode = .verticalPoint
        object.applyTypography(data)
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: "Vertical type created")
    }

    func addPath(_ points: [CGPoint], name: String = "Path") {
        guard points.count > 1 else { return }
        snapshot()
        let object = VectorObject.path(points: points, name: name)
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: "Path created")
    }

    func addShape(kind: ToolKind, in rawRect: CGRect) {
        let rect = normalizedRect(rawRect)
        guard rect.width > 2, rect.height > 2 else { return }
        switch kind {
        case .rectangle:
            addRectangle(at: rect.origin, size: rect.size)
        case .ellipse:
            addEllipse(at: rect.origin, size: rect.size)
        case .polygon:
            addPolygon(at: rect.origin, size: rect.size)
        default:
            break
        }
    }

    func canvasTransform(viewportSize: CGSize, screenScale: Double = 2) -> OpenstratorCore.CanvasTransform {
        OpenstratorCore.CanvasTransform(
            viewportSize: viewportSize,
            artboardSize: CGSize(width: document.artboardWidth, height: document.artboardHeight),
            zoom: zoom,
            pan: pan,
            rotationDegrees: viewRotation
        )
    }

    func beginMove(pointer: CGPoint) {
        interactiveMoveStart = pointer
        interactiveMoveOriginals = Dictionary(uniqueKeysWithValues: selectedObjects.map { ($0.id, $0) })
        interactiveMoveDidSnapshot = false
    }

    func updateMove(pointer: CGPoint) {
        guard let start = interactiveMoveStart else { return }
        if !interactiveMoveDidSnapshot, !interactiveMoveOriginals.isEmpty {
            snapshot()
            interactiveMoveDidSnapshot = true
        }
        let dx = pointer.x - start.x
        let dy = pointer.y - start.y
        for index in document.objects.indices {
            let id = document.objects[index].id
            guard let original = interactiveMoveOriginals[id], !original.isLocked else { continue }
            document.objects[index] = original
            document.objects[index].x = original.x + dx
            document.objects[index].y = original.y + dy
            if original.kind == .line || original.kind == .path {
                document.objects[index].points = original.points.map { CodablePoint(x: $0.x + dx, y: $0.y + dy) }
                document.objects[index].bezierAnchors = translatedBezierAnchors(original.bezierAnchors, dx: dx, dy: dy)
            }
        }
    }

    func endMove(commit: Bool) {
        defer { interactiveMoveStart = nil; interactiveMoveOriginals.removeAll(); interactiveMoveDidSnapshot = false }
        guard commit else { return }
        if document.snapToGrid { snapSelectionToGrid() }
        commitMutation(status: "Moved")
    }

    // MARK: - Editing

    func deleteSelection() {
        let doomed = selection
        guard !doomed.isEmpty else { return }
        snapshot()
        selection.removeAll()
        directComponentSelection = nil
        directMoveOriginalPath = nil
        directMoveStart = nil
        document.objects.removeAll { doomed.contains($0.id) }
        repairReferencesAfterDeletion(doomed)
        commitMutation(status: "Deleted")
    }

    private func repairReferencesAfterDeletion(_ doomed: Set<UUID>) {
        guard !doomed.isEmpty else { return }

        let brokenClipGroups = Set(document.objects.compactMap { object -> UUID? in
            guard object.clippingRole == .clippingPath, doomed.contains(object.id) else { return nil }
            return object.clippingGroupID
        })
        for index in document.objects.indices {
            if let maskID = document.objects[index].opacityMaskObjectID, doomed.contains(maskID) {
                document.objects[index].opacityMaskObjectID = nil
                document.objects[index].opacityMaskInverted = nil
            }
            if let groupID = document.objects[index].clippingGroupID, brokenClipGroups.contains(groupID) {
                document.objects[index].clippingGroupID = nil
                document.objects[index].clippingRole = nil
                if document.objects[index].groupID == groupID { document.objects[index].groupID = nil }
            }
        }

        for index in document.objects.indices where document.objects[index].kind == .text {
            var data = document.objects[index].resolvedTypography
            var changed = false

            if let reference = data.path?.pathReference, doomed.contains(reference) {
                data.path?.pathReference = nil
                changed = true
            }
            if let previous = data.thread.previousFrameID, doomed.contains(previous) {
                data.thread.previousFrameID = nil
                changed = true
            }
            if let next = data.thread.nextFrameID, doomed.contains(next) {
                data.thread.nextFrameID = nil
                changed = true
            }

            if changed {
                document.objects[index].applyTypography(data)
            }
        }
    }

    func duplicateSelection() {
        let indices = selectedIndices
        guard !indices.isEmpty else { return }
        snapshot()
        let originals = indices.map { document.objects[$0] }
        let idMap = Dictionary(uniqueKeysWithValues: originals.map { ($0.id, UUID()) })
        let groupRemap = Dictionary(uniqueKeysWithValues: Set(originals.compactMap(\.groupID)).map { ($0, UUID()) })
        let clippingRemap = Dictionary(uniqueKeysWithValues: Set(originals.compactMap(\.clippingGroupID)).map { ($0, UUID()) })
        var copies: [VectorObject] = []

        for original in originals {
            var copy = original
            copy.id = idMap[original.id]!
            copy.layerNodeID = nil
            copy.name += " Copy"
            copy.x += 18
            copy.y += 18
            if let oldGroup = original.groupID { copy.groupID = groupRemap[oldGroup] }
            if let oldClip = original.clippingGroupID { copy.clippingGroupID = clippingRemap[oldClip] }
            if let mask = original.opacityMaskObjectID { copy.opacityMaskObjectID = idMap[mask] ?? mask }
            if copy.kind == .line || copy.kind == .path {
                copy.points = copy.points.map { CodablePoint(x: $0.x + 18, y: $0.y + 18) }
                copy.bezierAnchors = translatedBezierAnchors(copy.bezierAnchors, dx: 18, dy: 18)
            }
            copies.append(copy)
        }

        document.objects.append(contentsOf: copies)
        selection = Set(copies.map(\.id))
        commitMutation(status: "Duplicated")
    }

    func copySelection() {
        internalClipboard = selectedObjects
        let referencedAssetIDs = Set(internalClipboard.compactMap(\.rasterAssetID))
            .union(Set(internalClipboard.compactMap(\.linkedAssetID).compactMap { linkID in
                document.resourceLibrary?.linkedAssets.first(where: { $0.id == linkID })?.fallbackRasterAssetID
            }))
        internalClipboardRasterAssets = Dictionary(uniqueKeysWithValues: (document.rasterAssets ?? [])
            .filter { referencedAssetIDs.contains($0.id) }
            .map { ($0.id, $0) })
        // Definitions are shared by UUID when pasted; keeping one clipboard copy avoids payload duplication.
        internalClipboardResources = document.resourceLibrary
        status = internalClipboard.isEmpty ? "Nothing to copy" : "Copied \(internalClipboard.count) object\(internalClipboard.count == 1 ? "" : "s")"
    }

    func cutSelection() {
        copySelection()
        deleteSelection()
    }

    func paste() {
        guard !internalClipboard.isEmpty else { status = "Clipboard is empty"; return }
        snapshot()
        let originals = internalClipboard
        let idMap = Dictionary(uniqueKeysWithValues: originals.map { ($0.id, UUID()) })
        let groupMap = Dictionary(uniqueKeysWithValues: Set(originals.compactMap(\.groupID)).map { ($0, UUID()) })
        let clipMap = Dictionary(uniqueKeysWithValues: Set(originals.compactMap(\.clippingGroupID)).map { ($0, UUID()) })
        let destinationObjectIDs = Set(document.objects.map(\.id))
        var pasted: [VectorObject] = []

        for original in originals {
            var copy = original
            copy.id = idMap[original.id]!
            copy.layerNodeID = nil
            copy.x += 24
            copy.y += 24
            if let oldGroup = original.groupID { copy.groupID = groupMap[oldGroup] }
            if let oldClip = original.clippingGroupID { copy.clippingGroupID = clipMap[oldClip] }
            if let mask = original.opacityMaskObjectID {
                copy.opacityMaskObjectID = idMap[mask] ?? (destinationObjectIDs.contains(mask) ? mask : nil)
            }
            if copy.kind == .line || copy.kind == .path {
                copy.points = copy.points.map { CodablePoint(x: $0.x + 24, y: $0.y + 24) }
                copy.bezierAnchors = translatedBezierAnchors(copy.bezierAnchors, dx: 24, dy: 24)
            }
            pasted.append(copy)
        }

        let destinationAssetIDs = Set((document.rasterAssets ?? []).map(\.id))
        let pastedAssetIDs = Set(pasted.compactMap(\.rasterAssetID))
        let missingClipboardAssets = pastedAssetIDs
            .subtracting(destinationAssetIDs)
            .compactMap { internalClipboardRasterAssets[$0] }
        if !missingClipboardAssets.isEmpty {
            var assets = document.rasterAssets ?? []
            assets.append(contentsOf: missingClipboardAssets)
            document.rasterAssets = assets
        }
        if let resources = internalClipboardResources { mergeResourceLibrary(resources) }

        document.objects.append(contentsOf: pasted)
        selection = Set(pasted.map(\.id))
        internalClipboard = pasted
        commitMutation(status: "Pasted")
    }

    func updateObject(id: UUID, recordHistory: Bool = true, _ mutation: (inout VectorObject) -> Void) {
        guard let index = document.objects.firstIndex(where: { $0.id == id }) else { return }
        if recordHistory { snapshot() }
        mutation(&document.objects[index])
        if document.objects[index].kind == .text, document.objects[index].typography != nil {
            var data = document.objects[index].resolvedTypography
            data.text = document.objects[index].text
            data.frame = document.objects[index].bounds
            document.objects[index].applyTypography(data)
        }
        commitMutation()
    }

    // MARK: - M4 Appearance stack

    func appearanceStack(objectID: UUID) -> AppearanceStackV6? {
        document.objects.first(where: { $0.id == objectID })?.resolvedAppearanceStack
    }

    func updateAppearanceStack(objectID: UUID, recordHistory: Bool = true, status message: String = "Appearance updated", _ mutation: (inout AppearanceStackV6) -> Void) {
        guard let index = document.objects.firstIndex(where: { $0.id == objectID }) else { return }
        if recordHistory { snapshot() }
        var stack = document.objects[index].resolvedAppearanceStack
        mutation(&stack)
        stack.normalize()
        document.objects[index].applyAppearanceStack(stack)
        commitMutation(status: message)
    }

    func addAppearanceFill(objectID: UUID) {
        updateAppearanceStack(objectID: objectID, status: "Fill added") { stack in
            stack.entries.append(.fill(FillAppearanceV6(paint: .color(.white))))
        }
    }

    func addAppearanceStroke(objectID: UUID) {
        updateAppearanceStack(objectID: objectID, status: "Stroke added") { stack in
            stack.entries.append(.stroke(StrokeAppearanceV6(paint: .color(.black), width: 1)))
        }
    }

    func addLiveEffect(_ effectID: String, objectID: UUID) {
        guard let effect = EffectRegistryV6.descriptor(id: effectID)?.makeDefaultEffect() else { return }
        updateAppearanceStack(objectID: objectID, status: "Effect added") { stack in
            stack.entries.append(.effect(effect))
        }
    }

    func removeAppearanceEntry(objectID: UUID, entryID: UUID) {
        updateAppearanceStack(objectID: objectID, status: "Appearance entry removed") { stack in
            stack.entries.removeAll { $0.id == entryID }
        }
    }

    func toggleAppearanceEntry(objectID: UUID, entryID: UUID) {
        updateAppearanceStack(objectID: objectID, status: "Appearance toggled") { stack in
            guard let index = stack.entries.firstIndex(where: { $0.id == entryID }) else { return }
            switch stack.entries[index] {
            case .fill(var value): value.enabled.toggle(); stack.entries[index] = .fill(value)
            case .stroke(var value): value.enabled.toggle(); stack.entries[index] = .stroke(value)
            case .effect(var value): value.enabled.toggle(); stack.entries[index] = .effect(value)
            }
        }
    }

    func duplicateAppearanceEntry(objectID: UUID, entryID: UUID) {
        updateAppearanceStack(objectID: objectID, status: "Appearance entry duplicated") { stack in
            guard let index = stack.entries.firstIndex(where: { $0.id == entryID }) else { return }
            let copy: AppearanceEntryV6
            switch stack.entries[index] {
            case .fill(var value): value.id = UUID(); copy = .fill(value)
            case .stroke(var value): value.id = UUID(); copy = .stroke(value)
            case .effect(var value): value.id = UUID(); copy = .effect(value)
            }
            stack.entries.insert(copy, at: index + 1)
        }
    }

    func moveAppearanceEntry(objectID: UUID, entryID: UUID, offset: Int) {
        updateAppearanceStack(objectID: objectID, status: "Appearance reordered") { stack in
            guard let index = stack.entries.firstIndex(where: { $0.id == entryID }) else { return }
            let destination = max(0, min(stack.entries.count - 1, index + offset))
            guard destination != index else { return }
            let value = stack.entries.remove(at: index)
            stack.entries.insert(value, at: destination)
        }
    }

    func beginAppearancePreview(objectID: UUID) {
        guard appearancePreviewObjectID == nil,
              let object = document.objects.first(where: { $0.id == objectID }) else { return }
        appearancePreviewObjectID = objectID
        appearancePreviewOriginalObject = object
        appearancePreviewOriginalDocument = document
    }

    func updateAppearancePreview(objectID: UUID, mutation: (inout AppearanceStackV6) -> Void) {
        if appearancePreviewObjectID == nil { beginAppearancePreview(objectID: objectID) }
        guard appearancePreviewObjectID == objectID,
              let index = document.objects.firstIndex(where: { $0.id == objectID }) else { return }
        var stack = document.objects[index].resolvedAppearanceStack
        mutation(&stack)
        stack.normalize()
        document.objects[index].applyAppearanceStack(stack)
        status = "Effect preview"
    }

    func resetAppearancePreview(objectID: UUID) {
        guard appearancePreviewObjectID == objectID,
              let original = appearancePreviewOriginalObject,
              let index = document.objects.firstIndex(where: { $0.id == objectID }) else { return }
        document.objects[index] = original
        status = "Preview reset"
    }

    func commitAppearancePreview(objectID: UUID) {
        guard appearancePreviewObjectID == objectID else { return }
        if let originalDocument = appearancePreviewOriginalDocument, originalDocument != document {
            if undoStack.last != originalDocument { undoStack.append(originalDocument) }
            if undoStack.count > architecture.undoLimit { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        appearancePreviewObjectID = nil
        appearancePreviewOriginalObject = nil
        appearancePreviewOriginalDocument = nil
        commitMutation(status: "Appearance applied")
    }

    func cancelAppearancePreview(objectID: UUID) {
        guard appearancePreviewObjectID == objectID else { return }
        if let original = appearancePreviewOriginalObject,
           let index = document.objects.firstIndex(where: { $0.id == objectID }) {
            document.objects[index] = original
        }
        appearancePreviewObjectID = nil
        appearancePreviewOriginalObject = nil
        appearancePreviewOriginalDocument = nil
        status = "Appearance cancelled"
    }

    func expandAppearance() {
        let targets = document.objects.filter { selection.contains($0.id) }
        guard !targets.isEmpty else { status = "Select artwork to expand"; return }

        let analyses = targets.map { ($0.id, ExpandAppearanceV6.expand(appearance: $0.resolvedAppearanceStack)) }
        let blocking = analyses.filter { $0.1.requiresRasterExpansion }.flatMap { $0.1.blockingEffectIDs }
        if !blocking.isEmpty {
            let names = Array(Set(blocking)).sorted().compactMap { EffectRegistryV6.descriptor(id: $0)?.displayName }
            status = "Raster expansion arrives in M5: " + names.joined(separator: ", ")
            return
        }

        snapshot()
        var newSelection: Set<UUID> = []
        for target in targets {
            guard let index = document.objects.firstIndex(where: { $0.id == target.id }) else { continue }
            let result = ExpandAppearanceV6.expand(appearance: target.resolvedAppearanceStack)
            var expanded: [VectorObject] = []
            for piece in result.pieces {
                var copy = target
                copy.id = UUID()
                copy.name = target.name + expandedPieceSuffix(piece)
                copy.x += piece.translationX
                copy.y += piece.translationY
                copy.rotation += piece.rotationDegrees
                copy.scaleX = (copy.scaleX ?? 1) * piece.scaleX
                copy.scaleY = (copy.scaleY ?? 1) * piece.scaleY
                copy.appearanceStack = nil
                let single = AppearanceStackV6(entries: [piece.entry], opacity: target.resolvedAppearanceStack.opacity, blendMode: target.resolvedAppearanceStack.blendMode)
                copy.applyAppearanceStack(single)
                applyExpandedGeometryEffects(piece.geometryEffects, to: &copy)
                expanded.append(copy)
                newSelection.insert(copy.id)
            }
            document.objects.remove(at: index)
            document.objects.insert(contentsOf: expanded, at: index)
        }
        selection = newSelection
        directComponentSelection = nil
        commitMutation(status: "Appearance expanded")
    }

    private func expandedPieceSuffix(_ piece: ExpandedAppearancePieceV6) -> String {
        let role: String
        switch piece.entry { case .fill: role = " Fill"; case .stroke: role = " Stroke"; case .effect: role = " Effect" }
        return role + (piece.copyIndex > 0 ? " Copy \(piece.copyIndex)" : "")
    }

    private func applyExpandedGeometryEffects(_ effects: [LiveEffectV6], to object: inout VectorObject) {
        for effect in effects where effect.enabled {
            switch effect.effectID {
            case "offsetPath":
                let offset = effect.parameters["offset"]?.numberValue ?? 0
                expandObjectGeometry(&object, offset: offset)
            case "roundCorners":
                if object.kind == .rectangle { object.cornerRadius = max(0, effect.parameters["radius"]?.numberValue ?? 0) }
            case "convertRectangle":
                object.kind = .rectangle; object.cornerRadius = 0; object.points = []; object.bezierAnchors = nil
            case "convertRoundedRectangle":
                object.kind = .rectangle; object.cornerRadius = max(0, effect.parameters["radius"]?.numberValue ?? 0); object.points = []; object.bezierAnchors = nil
            case "convertEllipse":
                object.kind = .ellipse; object.points = []; object.bezierAnchors = nil
            default:
                break
            }
        }
    }

    private func expandObjectGeometry(_ object: inout VectorObject, offset: Double) {
        guard offset != 0 else { return }
        if object.kind == .path || object.kind == .line, var anchors = object.bezierAnchors, !anchors.isEmpty {
            let bounds = object.bounds
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let sx = max(0.01, (bounds.width + 2 * offset) / max(1, bounds.width))
            let sy = max(0.01, (bounds.height + 2 * offset) / max(1, bounds.height))
            func scaled(_ point: CGPoint?) -> CGPoint? {
                guard let point else { return nil }
                return CGPoint(x: center.x + (point.x - center.x) * sx, y: center.y + (point.y - center.y) * sy)
            }
            for i in anchors.indices {
                anchors[i].point = scaled(anchors[i].point) ?? anchors[i].point
                anchors[i].inHandle = scaled(anchors[i].inHandle)
                anchors[i].outHandle = scaled(anchors[i].outHandle)
            }
            object.bezierAnchors = anchors
            object.points = PathCompatibility.flattenedPoints(BezierPathV6(anchors: anchors, isClosed: object.isClosed == true), tolerance: 0.8).map(CodablePoint.init)
            object.x -= offset; object.y -= offset; object.width += 2 * offset; object.height += 2 * offset
        } else {
            object.x -= offset; object.y -= offset
            object.width = max(1, object.width + 2 * offset)
            object.height = max(1, object.height + 2 * offset)
        }
    }

    private func textTargetIDs(explicit id: UUID? = nil) -> [UUID] {
        if let id, document.objects.contains(where: { $0.id == id && $0.kind == .text }) { return [id] }
        return document.objects.filter { selection.contains($0.id) && $0.kind == .text }.map(\.id)
    }

    private func mutateTypography(ids: [UUID], status message: String, _ mutation: (inout TextDataV6) -> Void) {
        guard !ids.isEmpty else { status = "Select a text object"; return }
        snapshot()
        for id in ids {
            guard let index = document.objects.firstIndex(where: { $0.id == id && $0.kind == .text }) else { continue }
            var data = document.objects[index].resolvedTypography
            mutation(&data)
            data.text = document.objects[index].text
            data.frame = document.objects[index].bounds
            data.normalize()
            document.objects[index].applyTypography(data)
        }
        commitMutation(status: message)
    }

    func updateCharacterStyle(id: UUID? = nil, _ mutation: (inout CharacterStyleV6) -> Void) {
        mutateTypography(ids: textTargetIDs(explicit: id), status: "Character formatting updated") { data in
            mutation(&data.character)
        }
    }

    func updateParagraphStyle(id: UUID? = nil, _ mutation: (inout ParagraphStyleV6) -> Void) {
        mutateTypography(ids: textTargetIDs(explicit: id), status: "Paragraph formatting updated") { data in
            mutation(&data.paragraph)
        }
    }

    func setTextLayout(_ mode: TextLayoutModeV6, pathReference: UUID? = nil, objectID: UUID? = nil) {
        mutateTypography(ids: textTargetIDs(explicit: objectID), status: "Text layout changed") { data in
            data.layoutMode = mode
            switch mode {
            case .path, .verticalPath:
                var options = data.path ?? TextPathOptionsV6()
                options.pathReference = pathReference ?? options.pathReference
                data.path = options
            default:
                data.path = nil
            }
        }
    }

    func toggleBullets(id: UUID? = nil) {
        mutateTypography(ids: textTargetIDs(explicit: id), status: "Bullets toggled") { data in
            data.paragraph.listStyle = data.paragraph.listStyle == .bullets ? .none : .bullets
        }
    }

    func toggleNumbering(id: UUID? = nil) {
        mutateTypography(ids: textTargetIDs(explicit: id), status: "Numbering toggled") { data in
            data.paragraph.listStyle = data.paragraph.listStyle == .numbered ? .none : .numbered
        }
    }

    func threadSelectedTextFrames() {
        let indices = document.objects.indices.filter { selection.contains(document.objects[$0].id) && document.objects[$0].kind == .text }
        guard indices.count >= 2 else { status = "Select at least two text frames"; return }
        snapshot()
        let ids = indices.map { document.objects[$0].id }
        for (offset, index) in indices.enumerated() {
            var data = document.objects[index].resolvedTypography
            data.thread.previousFrameID = offset > 0 ? ids[offset - 1] : nil
            data.thread.nextFrameID = offset + 1 < ids.count ? ids[offset + 1] : nil
            document.objects[index].applyTypography(data)
        }
        commitMutation(status: "Text frames threaded")
    }

    func unthreadSelectedTextFrame() {
        guard let currentIndex = primarySelectedIndex, document.objects[currentIndex].kind == .text else { status = "Select a text frame"; return }
        let id = document.objects[currentIndex].id
        let data = document.objects[currentIndex].resolvedTypography
        snapshot()
        if let previous = data.thread.previousFrameID,
           let index = document.objects.firstIndex(where: { $0.id == previous && $0.kind == .text }) {
            var previousData = document.objects[index].resolvedTypography
            if previousData.thread.nextFrameID == id { previousData.thread.nextFrameID = data.thread.nextFrameID }
            document.objects[index].applyTypography(previousData)
        }
        if let next = data.thread.nextFrameID,
           let index = document.objects.firstIndex(where: { $0.id == next && $0.kind == .text }) {
            var nextData = document.objects[index].resolvedTypography
            if nextData.thread.previousFrameID == id { nextData.thread.previousFrameID = data.thread.previousFrameID }
            document.objects[index].applyTypography(nextData)
        }
        var current = document.objects[currentIndex].resolvedTypography
        current.thread = TextThreadV6()
        document.objects[currentIndex].applyTypography(current)
        commitMutation(status: "Text frame unthreaded")
    }

    func applyTextWarp(style: TextWarpStyleV6, bend: Double = 0, horizontalDistortion: Double = 0, verticalDistortion: Double = 0) {
        mutateTypography(ids: textTargetIDs(), status: style == .none ? "Text warp removed" : "Text warp applied") { data in
            data.warp = style == .none ? nil : TextWarpV6(style: style, bend: bend, horizontalDistortion: horizontalDistortion, verticalDistortion: verticalDistortion)
        }
    }

    func setGlyphTransform(_ transform: GlyphTransformV6, objectID: UUID? = nil) {
        mutateTypography(ids: textTargetIDs(explicit: objectID), status: "Glyph transformed") { data in
            data.glyphTransforms.removeAll { $0.glyphIndex == transform.glyphIndex }
            data.glyphTransforms.append(transform)
            data.glyphTransforms.sort { $0.glyphIndex < $1.glyphIndex }
        }
    }

    func setFontFamily(_ familyName: String, objectID: UUID? = nil) {
        let family = MacFontCatalog.shared.family(named: familyName)
        let face = family?.faces.first
        updateCharacterStyle(id: objectID) { style in
            style.fontFamily = familyName
            if let face {
                style.fontFace = face.displayName
                style.postScriptName = face.postScriptName
                style.variableAxes = Dictionary(uniqueKeysWithValues: face.variableAxes.map { (String($0.id), $0.defaultValue) })
            } else {
                style.fontFace = "Regular"
                style.postScriptName = nil
                style.variableAxes = [:]
            }
        }
        noteRecentFont(familyName)
    }

    func setFontFace(_ faceName: String, objectID: UUID? = nil) {
        guard let object = objectID.flatMap({ id in document.objects.first(where: { $0.id == id }) }) ?? primarySelectedObject,
              object.kind == .text else { status = "Select text first"; return }
        let current = object.resolvedTypography
        guard let family = MacFontCatalog.shared.family(named: current.character.fontFamily),
              let face = family.faces.first(where: { $0.displayName == faceName }) else {
            status = "Font face is unavailable"
            return
        }
        updateCharacterStyle(id: object.id) { style in
            style.fontFace = face.displayName
            style.postScriptName = face.postScriptName
            style.variableAxes = Dictionary(uniqueKeysWithValues: face.variableAxes.map { (String($0.id), $0.defaultValue) })
        }
        noteRecentFont(current.character.fontFamily)
    }

    func noteRecentFont(_ family: String) {
        recentFontFamilies.removeAll { $0 == family }
        recentFontFamilies.insert(family, at: 0)
        if recentFontFamilies.count > 12 { recentFontFamilies.removeLast(recentFontFamilies.count - 12) }
        UserDefaults.standard.set(recentFontFamilies, forKey: "recentFontFamilies.v3")
    }

    func toggleFavoriteFont(_ family: String) {
        if favoriteFontFamilies.contains(family) { favoriteFontFamilies.remove(family) }
        else { favoriteFontFamilies.insert(family) }
        UserDefaults.standard.set(Array(favoriteFontFamilies).sorted(), forKey: "favoriteFontFamilies.v3")
    }

    func fillPlaceholderText() {
        let ids = textTargetIDs()
        guard !ids.isEmpty else { status = "Select text first"; return }
        snapshot()
        let placeholder = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
        for id in ids {
            guard let index = document.objects.firstIndex(where: { $0.id == id }) else { continue }
            document.objects[index].text = placeholder
            var data = document.objects[index].resolvedTypography
            data.text = placeholder
            document.objects[index].applyTypography(data)
        }
        commitMutation(status: "Placeholder text inserted")
    }

    func insertSpecialCharacter(_ character: String) {
        let ids = textTargetIDs()
        guard !ids.isEmpty else { status = "Select text first"; return }
        snapshot()
        for id in ids {
            guard let index = document.objects.firstIndex(where: { $0.id == id }) else { continue }
            document.objects[index].text.append(character)
            var data = document.objects[index].resolvedTypography
            data.text = document.objects[index].text
            document.objects[index].applyTypography(data)
        }
        commitMutation(status: "Special character inserted")
    }

    func checkSpelling() {
        guard let object = primarySelectedObject, object.kind == .text else { status = "Select text first"; return }
        let ranges = TypographyRuntime.misspellings(in: object.text)
        if let first = ranges.first {
            let word = (object.text as NSString).substring(with: first)
            status = ranges.count == 1 ? "Possible misspelling: \(word)" : "\(ranges.count) possible misspellings; first: \(word)"
        } else {
            status = "No spelling issues found"
        }
    }

    func convertPointAreaText() {
        mutateTypography(ids: textTargetIDs(), status: "Text type converted") { data in
            switch data.layoutMode {
            case .point: data.layoutMode = .area
            case .area: data.layoutMode = .point
            case .verticalPoint: data.layoutMode = .verticalArea
            case .verticalArea: data.layoutMode = .verticalPoint
            case .path, .verticalPath: break
            }
        }
    }

    func setTextOrientation(vertical: Bool) {
        mutateTypography(ids: textTargetIDs(), status: vertical ? "Vertical text" : "Horizontal text") { data in
            switch (data.layoutMode, vertical) {
            case (.point, true): data.layoutMode = .verticalPoint
            case (.area, true): data.layoutMode = .verticalArea
            case (.path, true): data.layoutMode = .verticalPath
            case (.verticalPoint, false): data.layoutMode = .point
            case (.verticalArea, false): data.layoutMode = .area
            case (.verticalPath, false): data.layoutMode = .path
            default: break
            }
        }
    }

    func setParagraphAlignment(_ alignment: TextAlignmentV6) {
        updateParagraphStyle { $0.alignment = alignment }
    }

    func moveSelection(by delta: CGSize) {
        guard !selection.isEmpty else { return }
        for index in selectedIndices where !document.objects[index].isLocked {
            document.objects[index].x += delta.width
            document.objects[index].y += delta.height
            if document.objects[index].kind == .line || document.objects[index].kind == .path {
                document.objects[index].points = document.objects[index].points.map {
                    CodablePoint(x: $0.x + delta.width, y: $0.y + delta.height)
                }
                document.objects[index].bezierAnchors = translatedBezierAnchors(
                    document.objects[index].bezierAnchors,
                    dx: delta.width,
                    dy: delta.height
                )
            }
        }
    }

    func finishInteractiveMove() {
        if document.snapToGrid {
            snapSelectionToGrid()
        }
        commitMutation(status: "Moved")
    }

    func resizeObject(id: UUID, to newRect: CGRect) {
        guard let index = document.objects.firstIndex(where: { $0.id == id }), !document.objects[index].isLocked else { return }
        let oldRect = document.objects[index].bounds
        let rect = normalizedRect(newRect)
        guard rect.width >= 2, rect.height >= 2 else { return }

        if document.objects[index].kind == .path || document.objects[index].kind == .line {
            let sx = rect.width / max(1, oldRect.width)
            let sy = rect.height / max(1, oldRect.height)
            document.objects[index].points = document.objects[index].points.map { point in
                CodablePoint(
                    x: rect.minX + (point.x - oldRect.minX) * sx,
                    y: rect.minY + (point.y - oldRect.minY) * sy
                )
            }
            document.objects[index].bezierAnchors = scaledBezierAnchors(
                document.objects[index].bezierAnchors,
                from: oldRect,
                to: rect
            )
        }
        document.objects[index].x = rect.minX
        document.objects[index].y = rect.minY
        document.objects[index].width = rect.width
        document.objects[index].height = rect.height
    }

    func nudgeSelection(dx: Double, dy: Double, coarse: Bool) {
        guard !selection.isEmpty else { return }
        snapshot()
        let multiplier = coarse ? 10.0 : 1.0
        moveSelection(by: CGSize(width: dx * multiplier, height: dy * multiplier))
        finishInteractiveMove()
    }

    func toggleVisibility(id: UUID) {
        updateObject(id: id) { $0.isVisible.toggle() }
    }

    func toggleLock(id: UUID) {
        updateObject(id: id) { $0.isLocked.toggle() }
    }

    func renameObject(id: UUID, name: String) {
        updateObject(id: id) { $0.name = name }
    }

    func createOutlines() {
        let textObjects = document.objects.filter { selection.contains($0.id) && $0.kind == .text }
        guard !textObjects.isEmpty else { status = "Select text to create outlines"; return }
        snapshot()
        var newObjects: [VectorObject] = []
        let selectedIDs = Set(textObjects.map(\.id))
        for source in textObjects {
            let group = UUID()
            for (index, path) in TextOutliner.paths(for: source).enumerated() where !path.anchors.isEmpty {
                var outline = VectorObject.path(points: PathCompatibility.flattenedPoints(path, tolerance: 0.6), name: "\(source.name) Outline \(index + 1)", closed: path.isClosed)
                outline.fill = source.fill
                outline.stroke = source.stroke
                outline.strokeWidth = source.strokeWidth
                outline.bezierAnchors = path.anchors
                outline.isClosed = path.isClosed
                outline.groupID = group
                newObjects.append(outline)
            }
        }
        guard !newObjects.isEmpty else { undoStack.removeLast(); status = "No glyph outlines were produced"; return }
        document.objects.removeAll { selectedIDs.contains($0.id) }
        document.objects.append(contentsOf: newObjects)
        selection = Set(newObjects.map(\.id))
        commitMutation(status: "Text converted to outlines")
    }

    // MARK: - Grouping & ordering

    func groupSelection() {
        groupSelectionM6()
    }

    func ungroupSelection() {
        ungroupSelectionM6()
    }

    enum ZOrderAction { case front, forward, backward, back }

    func changeZOrder(_ action: ZOrderAction) {
        guard !selection.isEmpty else { return }
        snapshot()

        switch action {
        case .front:
            let moving = document.objects.filter { selection.contains($0.id) }
            document.objects.removeAll { selection.contains($0.id) }
            document.objects.append(contentsOf: moving)
        case .back:
            let moving = document.objects.filter { selection.contains($0.id) }
            document.objects.removeAll { selection.contains($0.id) }
            document.objects.insert(contentsOf: moving, at: 0)
        case .forward:
            guard let highest = selectedIndices.max(), highest < document.objects.count - 1 else { break }
            var items = document.objects
            for i in selectedIndices.sorted(by: >) where i < items.count - 1 {
                items.swapAt(i, i + 1)
            }
            document.objects = items
        case .backward:
            guard let lowest = selectedIndices.min(), lowest > 0 else { break }
            var items = document.objects
            for i in selectedIndices.sorted() where i > 0 {
                items.swapAt(i, i - 1)
            }
            document.objects = items
        }
        commitMutation(status: "Layer order changed")
    }

    func moveLayer(from index: Int, direction: Int) {
        let destination = index + direction
        guard document.objects.indices.contains(index), document.objects.indices.contains(destination) else { return }
        snapshot()
        document.objects.swapAt(index, destination)
        commitMutation(status: "Layer order changed")
    }

    // MARK: - Alignment

    enum AlignmentAction {
        case left, horizontalCenter, right, top, verticalCenter, bottom
    }

    func alignSelection(_ action: AlignmentAction) {
        let indices = selectedIndices
        guard indices.count > 1, let bounds = selectionBounds else { return }
        snapshot()

        for index in indices where !document.objects[index].isLocked {
            let object = document.objects[index]
            var dx = 0.0
            var dy = 0.0
            switch action {
            case .left: dx = bounds.minX - object.x
            case .horizontalCenter: dx = bounds.midX - object.bounds.midX
            case .right: dx = bounds.maxX - object.bounds.maxX
            case .top: dy = bounds.minY - object.y
            case .verticalCenter: dy = bounds.midY - object.bounds.midY
            case .bottom: dy = bounds.maxY - object.bounds.maxY
            }
            translateObject(at: index, dx: dx, dy: dy)
        }
        commitMutation(status: "Aligned")
    }

    func distributeSelection(horizontal: Bool) {
        var indices = selectedIndices
        guard indices.count > 2 else { return }
        snapshot()

        if horizontal {
            indices.sort { document.objects[$0].bounds.midX < document.objects[$1].bounds.midX }
            let first = document.objects[indices.first!].bounds.midX
            let last = document.objects[indices.last!].bounds.midX
            let step = (last - first) / Double(indices.count - 1)
            for (offset, index) in indices.enumerated().dropFirst().dropLast() {
                let target = first + Double(offset) * step
                let dx = target - document.objects[index].bounds.midX
                translateObject(at: index, dx: dx, dy: 0)
            }
        } else {
            indices.sort { document.objects[$0].bounds.midY < document.objects[$1].bounds.midY }
            let first = document.objects[indices.first!].bounds.midY
            let last = document.objects[indices.last!].bounds.midY
            let step = (last - first) / Double(indices.count - 1)
            for (offset, index) in indices.enumerated().dropFirst().dropLast() {
                let target = first + Double(offset) * step
                let dy = target - document.objects[index].bounds.midY
                translateObject(at: index, dx: 0, dy: dy)
            }
        }
        commitMutation(status: "Distributed")
    }

    private func translateObject(at index: Int, dx: Double, dy: Double) {
        document.objects[index].x += dx
        document.objects[index].y += dy
        if document.objects[index].kind == .line || document.objects[index].kind == .path {
            document.objects[index].points = document.objects[index].points.map {
                CodablePoint(x: $0.x + dx, y: $0.y + dy)
            }
            document.objects[index].bezierAnchors = translatedBezierAnchors(document.objects[index].bezierAnchors, dx: dx, dy: dy)
        }
    }

    // MARK: - Guides & grid

    func addGuide(axis: GuideAxis) {
        snapshot()
        let position = axis == .horizontal ? document.artboardHeight / 2 : document.artboardWidth / 2
        document.guides.append(CanvasGuide(axis: axis, position: position))
        commitMutation(status: "Guide added")
    }

    func clearGuides() {
        guard !document.guides.isEmpty else { return }
        snapshot()
        document.guides.removeAll()
        commitMutation(status: "Guides cleared")
    }

    func snapSelectionToGrid() {
        guard document.snapToGrid, document.gridSpacing > 0 else { return }
        let spacing = document.gridSpacing
        for index in selectedIndices {
            let object = document.objects[index]
            let targetX = (object.x / spacing).rounded() * spacing
            let targetY = (object.y / spacing).rounded() * spacing
            translateObject(at: index, dx: targetX - object.x, dy: targetY - object.y)
        }
    }

    func snapped(_ point: CGPoint) -> CGPoint {
        if let data = try? JSONEncoder().encode(document),
           let v6 = try? V5Migrator.decodeAndMigrate(data) {
            var migrated = v6
            migrated.grid.spacing = max(0.000_001, document.gridSpacing)
            let result = SnapEngine.snap(
                point: point,
                document: migrated,
                options: SnapOptionsV6(
                    tolerance: max(2, 7 / max(0.1, zoom)),
                    grid: document.snapToGrid,
                    guides: document.showGuides,
                    anchors: true,
                    artboards: true
                )
            )
            return result.point
        }
        guard document.snapToGrid, document.gridSpacing > 0 else { return point }
        return OpenstratorCore.snap(point: point, spacing: document.gridSpacing)
    }

    private func normalizedRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: min(rect.minX, rect.maxX),
            y: min(rect.minY, rect.maxY),
            width: abs(rect.width),
            height: abs(rect.height)
        )
    }
}

extension EditorStore {
    static let defaultKeybinds: [KeybindDefinition] = [
        .init(id: "select", title: "Selection Tool", key: "v", modifiers: [], explanation: "Selects, moves, and resizes objects on the artboard.", preview: .select),
        .init(id: "pen", title: "Pen Tool", key: "p", modifiers: [], explanation: "Draws a vector path from sampled points. Use Pencil for a freer stroke.", preview: .pen),
        .init(id: "pencil", title: "Pencil Tool", key: "n", modifiers: [], explanation: "Draws a smooth freehand-style vector path.", preview: .pen),
        .init(id: "addText", title: "Add Text", key: "t", modifiers: ["command", "shift"], explanation: "Creates a new editable text object on the current artboard.", preview: .text),
        .init(id: "addRectangle", title: "Rectangle", key: "r", modifiers: ["command", "shift"], explanation: "Creates a rectangle with editable fill, gradient, stroke, corner radius, size, and rotation.", preview: .rectangle),
        .init(id: "addEllipse", title: "Ellipse", key: "e", modifiers: ["command", "shift"], explanation: "Creates an ellipse or circle vector object.", preview: .ellipse),
        .init(id: "addPolygon", title: "Polygon", key: "y", modifiers: ["command", "shift"], explanation: "Creates a six-sided vector polygon.", preview: .polygon),
        .init(id: "duplicate", title: "Duplicate Selection", key: "d", modifiers: ["command"], explanation: "Duplicates the selected objects while preserving groups and styling.", preview: .duplicate),
        .init(id: "zoomActual", title: "Actual Size", key: "0", modifiers: ["command"], explanation: "Returns the artboard to 100% zoom and centers the pan offset.", preview: .zoom),
        .init(id: "exportSVG", title: "Export SVG", key: "e", modifiers: ["command", "shift"], explanation: "Exports visible vector artwork to an SVG file.", preview: .export),
        .init(id: "alignCenter", title: "Align Horizontal Centers", key: "c", modifiers: ["command", "option"], explanation: "Aligns the horizontal centers of two or more selected objects.", preview: .align)
    ]
}

// MARK: - Pro toolkit operations
extension EditorStore {
    func object(at point: CGPoint) -> VectorObject? {
        hitTest(point)
    }

    func selectIntersecting(_ rect: CGRect, additive: Bool = false) {
        let normalized = CGRect(x: min(rect.minX, rect.maxX), y: min(rect.minY, rect.maxY), width: abs(rect.width), height: abs(rect.height))
        let hits = Set(document.objects.filter { $0.isVisible && !$0.isLocked && $0.bounds.intersects(normalized) }.map(\.id))
        if additive { selection.formUnion(hits) } else { selection = hits }
        status = hits.isEmpty ? "Lasso: no objects" : "Lasso selected \(hits.count) object\(hits.count == 1 ? "" : "s")"
    }

    func selectSimilarAppearance(at point: CGPoint) {
        guard let source = hitTest(point) else { selection.removeAll(); return }
        let tolerance = 0.035
        func close(_ a: RGBAColor, _ b: RGBAColor) -> Bool {
            abs(a.r-b.r) < tolerance && abs(a.g-b.g) < tolerance && abs(a.b-b.b) < tolerance && abs(a.a-b.a) < tolerance
        }
        selection = Set(document.objects.filter {
            $0.isVisible && !$0.isLocked && close($0.fill, source.fill) && close($0.stroke, source.stroke) && abs($0.strokeWidth-source.strokeWidth) < 0.5
        }.map(\.id))
        status = "Magic Wand selected \(selection.count) similar object\(selection.count == 1 ? "" : "s")"
    }

    func addRoundedRectangle(in rect: CGRect) {
        let r = rect.standardized
        guard r.width > 2, r.height > 2 else { return }
        snapshot()
        var object = VectorObject.rectangle(at: snapped(r.origin), size: r.size)
        object.name = "Rounded Rectangle"
        object.cornerRadius = min(28, min(r.width, r.height) * 0.22)
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: "Rounded rectangle created")
    }

    func addStar(in rect: CGRect, points count: Int = 5) {
        let r = rect.standardized
        guard r.width > 4, r.height > 4 else { return }
        let path = LiveShapeGeometry.star(
            center: CGPoint(x: r.midX, y: r.midY),
            outerRadius: min(r.width, r.height) / 2,
            innerRadius: min(r.width, r.height) * 0.23,
            points: count
        )
        snapshot()
        var object = VectorObject.path(points: PathCompatibility.flattenedPoints(path), name: "Star", closed: true)
        object = objectByReplacingPath(object, path: path, name: "Star")
        object.fill = RGBAColor(r: 0.98, g: 0.67, b: 0.17)
        object.stroke = .clear
        object.strokeWidth = 0
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: "Star created")
    }

    func addArc(in rect: CGRect) {
        let r = rect.standardized
        guard r.width > 4, r.height > 4 else { return }
        let path = LiveShapeGeometry.arc(
            center: CGPoint(x: r.midX, y: r.midY),
            radius: min(r.width, r.height) / 2,
            startAngleDegrees: 180,
            endAngleDegrees: 360
        )
        addBezierPath(path, name: "Arc")
    }

    func addSpiral(in rect: CGRect) {
        let r = rect.standardized
        guard r.width > 4, r.height > 4 else { return }
        let path = LiveShapeGeometry.spiral(
            center: CGPoint(x: r.midX, y: r.midY),
            startRadius: 0,
            endRadius: min(r.width, r.height) * 0.48,
            turns: 4.25
        )
        addBezierPath(path, name: "Spiral")
    }

    func addRectangularGrid(in rect: CGRect, divisions: Int = 6) {
        let r = rect.standardized
        guard r.width > 6, r.height > 6 else { return }
        let paths = LiveShapeGeometry.rectangularGrid(in: r, rows: divisions, columns: divisions)
        snapshot()
        let group = UUID()
        let created = paths.enumerated().map { offset, path -> VectorObject in
            var object = VectorObject.path(points: PathCompatibility.flattenedPoints(path), name: "Grid Line \(offset + 1)")
            object = objectByReplacingPath(object, path: path, name: object.name)
            object.groupID = group
            object.strokeWidth = 1
            return object
        }
        document.objects.append(contentsOf: created)
        selection = Set(created.map(\.id))
        commitMutation(status: "Rectangular grid created")
    }

    func addPolarGrid(in rect: CGRect, rings: Int = 5, rays: Int = 12) {
        let r = rect.standardized
        guard r.width > 6, r.height > 6 else { return }
        let paths = LiveShapeGeometry.polarGrid(
            center: CGPoint(x: r.midX, y: r.midY),
            radius: min(r.width, r.height) / 2,
            radialDivisions: rays,
            concentricDivisions: rings
        )
        snapshot()
        let group = UUID()
        let created = paths.enumerated().map { offset, path -> VectorObject in
            var object = VectorObject.path(points: PathCompatibility.flattenedPoints(path), name: "Polar Grid \(offset + 1)", closed: path.isClosed)
            object = objectByReplacingPath(object, path: path, name: object.name)
            object.groupID = group
            object.strokeWidth = 1
            return object
        }
        document.objects.append(contentsOf: created)
        selection = Set(created.map(\.id))
        commitMutation(status: "Polar grid created")
    }

    func addFlare(in rect: CGRect) {
        let r = rect.standardized
        guard r.width > 8, r.height > 8 else { return }
        snapshot()
        let group = UUID()
        var glow = VectorObject.ellipse(at: r.origin, size: r.size)
        glow.name = "Flare Glow"; glow.groupID = group; glow.stroke = .clear; glow.strokeWidth = 0
        glow.gradient = LinearGradientModel(angleDegrees: 35, stops: [
            GradientStopModel(location: 0, color: RGBAColor(r: 1, g: 0.95, b: 0.55, a: 0.95)),
            GradientStopModel(location: 1, color: RGBAColor(r: 1, g: 0.35, b: 0.10, a: 0.05))
        ])
        glow.effects = [VectorEffect(kind: .glow, amount: 14)]
        var core = VectorObject.ellipse(at: CGPoint(x: r.midX-r.width*0.13, y: r.midY-r.height*0.13), size: CGSize(width: r.width*0.26, height: r.height*0.26))
        core.name = "Flare Core"; core.groupID = group; core.fill = .white; core.stroke = .clear; core.strokeWidth = 0
        document.objects.append(contentsOf: [glow, core])
        selection = [glow.id, core.id]
        commitMutation(status: "Flare created")
    }

    func addAreaText(in rect: CGRect, vertical: Bool = false) {
        let r = rect.standardized
        snapshot()
        var object = VectorObject.text(at: r.origin)
        object.name = vertical ? "Vertical Area Type" : "Area Type"
        object.width = max(80, r.width); object.height = max(50, r.height)
        object.text = vertical ? "Vertical area text" : "Area text"
        object.fontSize = min(42, max(12, r.height * 0.18))
        var data = object.resolvedTypography
        data.text = object.text
        data.frame = object.bounds
        data.layoutMode = vertical ? .verticalArea : .area
        data.character.fontSize = object.fontSize
        object.applyTypography(data)
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: "Type created")
    }

    func addTypeOnSelectedPath(vertical: Bool = false) {
        guard let pathObject = document.objects.first(where: { selection.contains($0.id) && ($0.kind == .path || $0.kind == .line) }) else {
            status = "Select a path for type on path"
            return
        }
        snapshot()
        var object = VectorObject.text(at: pathObject.bounds.origin)
        object.name = vertical ? "Vertical Type on Path" : "Type on Path"
        object.text = "Type on path"
        object.width = max(120, pathObject.bounds.width)
        object.height = max(60, pathObject.bounds.height)
        var data = object.resolvedTypography
        data.text = object.text
        data.frame = object.bounds
        data.layoutMode = vertical ? .verticalPath : .path
        data.path = TextPathOptionsV6(pathReference: pathObject.id)
        object.applyTypography(data)
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: vertical ? "Vertical type on path created" : "Type on path created")
    }

    func touchType(at start: CGPoint, dragTo end: CGPoint) {
        guard let object = document.objects.reversed().first(where: { $0.kind == .text && $0.isVisible && !$0.isLocked && $0.bounds.insetBy(dx: -8, dy: -8).contains(start) }),
              !object.text.isEmpty else {
            status = "Touch Type needs a text object"
            return
        }
        let chars = Array(object.text)
        let data = object.resolvedTypography
        let vertical = data.layoutMode == .verticalPoint || data.layoutMode == .verticalArea || data.layoutMode == .verticalPath
        let fraction: Double
        if vertical {
            fraction = min(0.999, max(0, Double((start.y - object.bounds.minY) / max(1, object.bounds.height))))
        } else {
            fraction = min(0.999, max(0, Double((start.x - object.bounds.minX) / max(1, object.bounds.width))))
        }
        let glyphIndex = min(chars.count - 1, max(0, Int(floor(fraction * Double(chars.count)))))
        let existing = data.glyphTransforms.first(where: { $0.glyphIndex == glyphIndex }) ?? GlyphTransformV6(glyphIndex: glyphIndex)
        let transformed = GlyphTransformV6(
            glyphIndex: glyphIndex,
            offsetX: existing.offsetX + Double(end.x - start.x),
            offsetY: existing.offsetY + Double(end.y - start.y),
            scaleX: existing.scaleX,
            scaleY: existing.scaleY,
            rotationDegrees: existing.rotationDegrees
        )
        selection = [object.id]
        setGlyphTransform(transformed, objectID: object.id)
    }

    var canRasterEditSelection: Bool {
        guard selection.count == 1, let id = selection.first,
              let object = document.objects.first(where: { $0.id == id }) else { return false }
        return object.kind == .image && object.rasterAssetID != nil
    }

    func paintSelectedRaster(along points: [CGPoint], eraser: Bool) {
        guard !points.isEmpty, let index = primarySelectedIndex, document.objects[index].kind == .image,
              let assetID = document.objects[index].rasterAssetID else { return }
        let object = document.objects[index]
        guard var buffer = RasterImageRuntime.tileStore(assetID: assetID, document: document) else {
            status = "Image is too large or unsupported for pixel editing"
            return
        }
        snapshot()
        let rect = object.bounds
        let sx = object.scaleX ?? 1
        let sy = object.scaleY ?? 1
        let shx = object.shearX ?? 0
        let shy = object.shearY ?? 0
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: rect.midX, y: rect.midY)
        transform = transform.rotated(by: CGFloat(object.rotation * .pi / 180))
        transform = transform.concatenating(CGAffineTransform(a: CGFloat(sx), b: CGFloat(shy), c: CGFloat(shx), d: CGFloat(sy), tx: 0, ty: 0))
        transform = transform.translatedBy(x: -rect.midX, y: -rect.midY)
        let inverse = transform.inverted()
        let safeRectWidth = max(1.0, Double(rect.width))
        let safeRectHeight = max(1.0, Double(rect.height))
        let horizontalPixelScale = Double(buffer.width) / safeRectWidth
        let verticalPixelScale = Double(buffer.height) / safeRectHeight
        let averagePixelScale = (horizontalPixelScale + verticalPixelScale) * 0.5
        let pixelScale = max(1.0, averagePixelScale)
        let radius = 10.0 * pixelScale

        for point in points {
            let local = point.applying(inverse)
            let nx = Double((local.x - rect.minX) / max(1, rect.width))
            let ny = Double((local.y - rect.minY) / max(1, rect.height))
            guard nx >= 0, ny >= 0, nx <= 1, ny <= 1 else { continue }
            let px = min(buffer.width - 1, max(0, Int((nx * Double(buffer.width - 1)).rounded())))
            let py = min(buffer.height - 1, max(0, Int((ny * Double(buffer.height - 1)).rounded())))
            if eraser {
                try? RasterBrushV6.erase(&buffer, centerX: px, centerY: py, radius: radius, opacity: 1, mask: object.rasterMask)
            } else {
                try? RasterBrushV6.paint(&buffer, centerX: px, centerY: py, radius: radius, color: .init(r: 20, g: 20, b: 24, a: 255), opacity: 1, mask: object.rasterMask)
            }
        }

        guard let png = RasterImageRuntime.pngData(from: buffer),
              var assets = document.rasterAssets,
              let assetIndex = assets.firstIndex(where: { $0.id == assetID }) else { return }
        assets[assetIndex].embeddedData = png
        assets[assetIndex].metadata.pixelWidth = buffer.width
        assets[assetIndex].metadata.pixelHeight = buffer.height
        assets[assetIndex].metadata.mimeType = "image/png"
        document.rasterAssets = assets
        RasterImageCache.shared.removeAll()
        commitMutation(status: eraser ? "Raster pixels erased" : "Raster pixels painted")
    }

    func addBrushPath(_ points: [CGPoint], blob: Bool = false) {
        guard points.count > 1 else { return }
        snapshot()
        var object = VectorObject.path(points: points, name: blob ? "Blob Brush" : "Paintbrush")
        object.strokeWidth = blob ? 18 : 5
        object.stroke = blob ? RGBAColor(r: 0.13, g: 0.34, b: 0.86) : .black
        object.lineCap = "round"; object.lineJoin = "round"
        document.objects.append(object)
        selection = [object.id]
        commitMutation(status: blob ? "Blob brush stroke created" : "Brush stroke created")
    }

    func smoothSelectedPaths() {
        let ids = selection
        guard !ids.isEmpty else { return }
        snapshot()
        for index in document.objects.indices where ids.contains(document.objects[index].id) && document.objects[index].kind == .path {
            guard let path = bezierPath(for: document.objects[index]) else { continue }
            let fitted = PencilFitter.fit(
                samples: PathCompatibility.flattenedPoints(path, tolerance: 0.8),
                tolerance: 1.2,
                smoothing: 0.9
            )
            replaceBezierPath(objectID: document.objects[index].id, path: fitted)
        }
        commitMutation(status: "Paths smoothed")
    }

    func splitSelectedPath(at point: CGPoint) {
        guard let index = primarySelectedIndex,
              document.objects[index].kind == .path,
              let path = bezierPath(for: document.objects[index]),
              let location = nearestPathLocation(path: path, point: point) else {
            status = "Select a path first"
            return
        }
        do {
            let parts = try PathEditor.cut(path: path, segmentIndex: location.segmentIndex, t: location.t)
            let source = document.objects[index]
            snapshot()
            let replacements = parts.enumerated().map { offset, part -> VectorObject in
                let suffix = parts.count > 1 ? (offset == 0 ? " A" : " B") : ""
                var object = objectByReplacingPath(source, path: part, name: source.name + suffix)
                object.id = UUID()
                return object
            }
            document.objects.remove(at: index)
            document.objects.insert(contentsOf: replacements, at: index)
            selection = Set(replacements.map(\.id))
            directComponentSelection = nil
            commitMutation(status: path.isClosed ? "Closed path cut open" : "Path split")
        } catch {
            status = "Path could not be split"
        }
    }

    func joinSelectedPaths() {
        let ordered = document.objects.filter { selection.contains($0.id) && ($0.kind == .path || $0.kind == .line) }
        guard ordered.count >= 2 else { status = "Select two or more paths"; return }
        guard var joinedPath = bezierPath(for: ordered[0]) else { return }
        do {
            for object in ordered.dropFirst() {
                guard let next = bezierPath(for: object) else { continue }
                joinedPath = try PathEditor.join(joinedPath, next, tolerance: 8 / max(0.1, zoom))
            }
        } catch {
            status = "Only open paths can be joined"
            return
        }
        snapshot()
        var joined = objectByReplacingPath(ordered[0], path: joinedPath, name: "Joined Path")
        joined.id = UUID()
        let ids = Set(ordered.map(\.id))
        document.objects.removeAll { ids.contains($0.id) }
        document.objects.append(joined)
        selection = [joined.id]
        directComponentSelection = nil
        commitMutation(status: "Paths joined")
    }

    func eraseObjects(along points: [CGPoint], radius: Double = 12) {
        guard !points.isEmpty else { return }
        let hitIDs = Set(document.objects.filter { object in
            guard object.isVisible && !object.isLocked else { return false }
            return points.contains { object.bounds.insetBy(dx: -radius, dy: -radius).contains($0) }
        }.map(\.id))
        guard !hitIDs.isEmpty else { return }
        snapshot()
        document.objects.removeAll { hitIDs.contains($0.id) }
        selection.subtract(hitIDs)
        commitMutation(status: "Erased \(hitIDs.count) object\(hitIDs.count == 1 ? "" : "s")")
    }

    func applyEyedropper(at point: CGPoint) {
        guard let source = hitTest(point) else { return }
        let targets = selection.subtracting([source.id])
        guard !targets.isEmpty else { selection = [source.id]; status = "Sampled \(source.name)"; return }
        snapshot()
        for i in document.objects.indices where targets.contains(document.objects[i].id) {
            document.objects[i].fill = source.fill
            document.objects[i].gradient = source.gradient
            document.objects[i].stroke = source.stroke
            document.objects[i].strokeWidth = source.strokeWidth
            document.objects[i].opacity = source.opacity
            document.objects[i].blendMode = source.blendMode
        }
        commitMutation(status: "Appearance sampled")
    }

    func reflectSelection(horizontal: Bool = true) {
        guard !selection.isEmpty else { return }
        snapshot()
        for i in selectedIndices {
            if horizontal { document.objects[i].scaleX = -(document.objects[i].scaleX ?? 1) }
            else { document.objects[i].scaleY = -(document.objects[i].scaleY ?? 1) }
        }
        commitMutation(status: "Reflected")
    }

    func rotateSelection(by degrees: Double) {
        guard !selection.isEmpty else { return }
        for i in selectedIndices { document.objects[i].rotation += degrees }
    }

    func scaleSelection(by factor: Double) {
        guard !selection.isEmpty else { return }
        for i in selectedIndices {
            let f = max(0.05, factor)
            document.objects[i].scaleX = (document.objects[i].scaleX ?? 1) * f
            document.objects[i].scaleY = (document.objects[i].scaleY ?? 1) * f
        }
    }

    func shearSelection(x: Double, y: Double = 0) {
        guard !selection.isEmpty else { return }
        for i in selectedIndices {
            document.objects[i].shearX = max(-1.5, min(1.5, x))
            document.objects[i].shearY = max(-1.5, min(1.5, y))
        }
    }

    func adjustWidth(by delta: Double) {
        guard !selection.isEmpty else { return }
        for i in selectedIndices { document.objects[i].strokeWidth = max(0, min(120, document.objects[i].strokeWidth + delta)) }
    }

    func setGradientFromDrag(start: CGPoint, end: CGPoint) {
        guard !selection.isEmpty else { return }
        let angle = atan2(Double(end.y - start.y), Double(end.x - start.x)) * (180.0 / Double.pi)
        for i in selectedIndices {
            if document.objects[i].gradient == nil { document.objects[i].gradient = LinearGradientModel() }
            document.objects[i].gradient?.angleDegrees = angle
        }
        commitMutation(status: "Gradient angle \(Int(angle.rounded()))°")
    }

    func applyMeshStyle() {
        guard !selection.isEmpty else { return }
        snapshot()
        for i in selectedIndices {
            document.objects[i].gradient = LinearGradientModel(angleDegrees: 35, stops: [
                GradientStopModel(location: 0, color: RGBAColor(r: 0.12,g:0.42,b:1)),
                GradientStopModel(location: 0.25, color: RGBAColor(r: 0.45,g:0.22,b:1)),
                GradientStopModel(location: 0.52, color: RGBAColor(r: 1,g:0.27,b:0.56)),
                GradientStopModel(location: 0.76, color: RGBAColor(r: 1,g:0.65,b:0.16)),
                GradientStopModel(location: 1, color: RGBAColor(r: 0.12,g:0.82,b:0.70))
            ])
        }
        commitMutation(status: "Multi-stop mesh-style gradient applied")
    }

    func blendSelection(steps: Int = 6) {
        let objs = selectedObjects
        guard objs.count == 2 else { status = "Blend needs exactly two objects"; return }
        let a = objs[0], b = objs[1]
        snapshot()
        var created: [VectorObject] = []
        for step in 1..<steps {
            let t = Double(step) / Double(steps)
            var c = a
            c.id = UUID(); c.name = "Blend \(step)"
            c.x = a.x + (b.x-a.x)*t; c.y = a.y + (b.y-a.y)*t
            c.width = a.width + (b.width-a.width)*t; c.height = a.height + (b.height-a.height)*t
            c.rotation = a.rotation + (b.rotation-a.rotation)*t
            c.opacity = a.opacity + (b.opacity-a.opacity)*t
            c.fill = RGBAColor(r: a.fill.r+(b.fill.r-a.fill.r)*t, g: a.fill.g+(b.fill.g-a.fill.g)*t, b: a.fill.b+(b.fill.b-a.fill.b)*t, a: a.fill.a+(b.fill.a-a.fill.a)*t)
            c.stroke = RGBAColor(r: a.stroke.r+(b.stroke.r-a.stroke.r)*t, g: a.stroke.g+(b.stroke.g-a.stroke.g)*t, b: a.stroke.b+(b.stroke.b-a.stroke.b)*t, a: a.stroke.a+(b.stroke.a-a.stroke.a)*t)
            created.append(c)
        }
        document.objects.append(contentsOf: created)
        selection.formUnion(created.map(\.id))
        commitMutation(status: "Blend created with \(created.count) intermediate objects")
    }

    func spraySelection(around point: CGPoint, count: Int = 8) {
        if let definition = symbolDefinitionForSprayer() {
            spraySymbolDefinition(definition, around: point, count: count)
            return
        }
        guard let source = primarySelectedObject else { status = "Select an object or create a symbol to spray"; return }
        snapshot()
        var copies: [VectorObject] = []
        for i in 0..<count {
            let a = Double(i) * 2 * Double.pi / Double(count)
            let radius = 24 + Double((i * 17) % 45)
            var c = source
            c.id = UUID(); c.name = source.name + " Symbol"
            c.x = point.x + cos(a)*radius - source.width/2
            c.y = point.y + sin(a)*radius - source.height/2
            c.rotation += Double((i*37)%70)-35
            let scale = 0.55 + Double((i*29)%45)/100
            c.scaleX = scale; c.scaleY = scale
            copies.append(c)
        }
        document.objects.append(contentsOf: copies)
        selection = Set(copies.map(\.id))
        commitMutation(status: "Sprayed \(count) symbol instances")
    }

    func addBarGraph(in rect: CGRect) {
        let r = rect.standardized
        guard r.width > 40, r.height > 40 else { return }
        snapshot()
        let group = UUID()
        let values = [0.38, 0.72, 0.56, 0.90, 0.64, 0.82]
        let gap = r.width * 0.035
        let barW = (r.width - gap * Double(values.count + 1)) / Double(values.count)
        var objects: [VectorObject] = []
        for (i,v) in values.enumerated() {
            let h = r.height * v
            var bar = VectorObject.rectangle(at: CGPoint(x: r.minX + gap + Double(i)*(barW+gap), y: r.maxY-h), size: CGSize(width: barW, height: h))
            bar.name = "Graph Bar \(i+1)"; bar.groupID = group; bar.cornerRadius = min(6, barW*0.18)
            bar.fill = RGBAColor(r: 0.12 + Double(i)*0.05, g: 0.42 + Double(i)*0.04, b: 0.92 - Double(i)*0.05)
            objects.append(bar)
        }
        document.objects.append(contentsOf: objects)
        selection = Set(objects.map(\.id))
        commitMutation(status: "Bar graph created")
    }

    func createPerspectiveGrid() {
        snapshot()
        let w = document.artboardWidth, h = document.artboardHeight
        let center = CGPoint(x: w/2, y: h*0.48)
        for x in stride(from: 0.0, through: w, by: max(80, w/10)) {
            document.guides.append(CanvasGuide(axis: .vertical, position: x))
        }
        document.guides.append(CanvasGuide(axis: .horizontal, position: center.y))
        document.showGuides = true
        commitMutation(status: "Perspective guide framework added")
    }

    func setArtboard(from rect: CGRect) {
        let r = rect.standardized
        guard r.width >= 64, r.height >= 64 else { return }
        snapshot()
        document.artboardWidth = min(10000, r.width)
        document.artboardHeight = min(10000, r.height)
        commitMutation(status: "Artboard resized to \(Int(r.width)) × \(Int(r.height))")
    }

    func setArtboardOrientation(_ orientation: ArtboardOrientationV6) {
        let width = document.artboardWidth
        let height = document.artboardHeight
        let alreadyMatches = orientation == .portrait ? height >= width : width >= height
        guard !alreadyMatches else { return }

        snapshot()
        document.artboardWidth = height
        document.artboardHeight = width
        commitMutation(status: orientation == .portrait ? "Artboard set to Portrait" : "Artboard set to Landscape")
    }

    func createSliceGuides(from rect: CGRect) {
        let r = rect.standardized
        snapshot()
        document.guides.append(contentsOf: [
            CanvasGuide(axis: .vertical, position: r.minX), CanvasGuide(axis: .vertical, position: r.maxX),
            CanvasGuide(axis: .horizontal, position: r.minY), CanvasGuide(axis: .horizontal, position: r.maxY)
        ])
        document.showGuides = true
        commitMutation(status: "Slice guides created")
    }

    func addRasterFilter(_ id: RasterFilterIDV6) {
        guard !selection.isEmpty else { return }
        let imageIndices = selectedIndices.filter { document.objects[$0].kind == .image }
        guard !imageIndices.isEmpty else { status = "Select an image first"; return }
        snapshot()
        for i in imageIndices {
            var record = RasterFilterRecordV6(id: id, parameters: defaultRasterFilterParameters(id))
            record.normalize()
            var filters = document.objects[i].rasterFilters ?? []
            filters.append(record)
            document.objects[i].rasterFilters = filters
        }
        RasterImageCache.shared.removeAll()
        commitMutation(status: "Raster filter added")
    }

    func clearRasterFilters() {
        let imageIndices = selectedIndices.filter { document.objects[$0].kind == .image && !(document.objects[$0].rasterFilters ?? []).isEmpty }
        guard !imageIndices.isEmpty else { return }
        snapshot()
        for i in imageIndices { document.objects[i].rasterFilters = [] }
        RasterImageCache.shared.removeAll()
        commitMutation(status: "Raster filters cleared")
    }

    func rasterFilter(objectID: UUID, filterUUID: UUID) -> RasterFilterRecordV6? {
        document.objects.first(where: { $0.id == objectID })?.rasterFilters?.first(where: { $0.uuid == filterUUID })
    }

    func toggleRasterFilter(objectID: UUID, filterUUID: UUID) {
        guard let index = document.objects.firstIndex(where: { $0.id == objectID }),
              var filters = document.objects[index].rasterFilters,
              let filterIndex = filters.firstIndex(where: { $0.uuid == filterUUID }) else { return }
        snapshot()
        filters[filterIndex].enabled.toggle()
        document.objects[index].rasterFilters = filters
        RasterImageCache.shared.removeAll()
        commitMutation(status: "Raster filter toggled")
    }

    func removeRasterFilter(objectID: UUID, filterUUID: UUID) {
        guard let index = document.objects.firstIndex(where: { $0.id == objectID }),
              var filters = document.objects[index].rasterFilters,
              filters.contains(where: { $0.uuid == filterUUID }) else { return }
        snapshot()
        filters.removeAll { $0.uuid == filterUUID }
        document.objects[index].rasterFilters = filters
        RasterImageCache.shared.removeAll()
        commitMutation(status: "Raster filter removed")
    }

    func beginRasterFilterPreview(objectID: UUID) {
        guard rasterFilterPreviewObjectID == nil,
              let object = document.objects.first(where: { $0.id == objectID }) else { return }
        rasterFilterPreviewObjectID = objectID
        rasterFilterPreviewOriginalObject = object
        rasterFilterPreviewOriginalDocument = document
    }

    func updateRasterFilterPreview(objectID: UUID, filterUUID: UUID, parameter: String, value: Double) {
        if rasterFilterPreviewObjectID == nil { beginRasterFilterPreview(objectID: objectID) }
        guard rasterFilterPreviewObjectID == objectID,
              let index = document.objects.firstIndex(where: { $0.id == objectID }),
              var filters = document.objects[index].rasterFilters,
              let filterIndex = filters.firstIndex(where: { $0.uuid == filterUUID }) else { return }
        filters[filterIndex].parameters[parameter] = value
        filters[filterIndex].normalize()
        document.objects[index].rasterFilters = filters
        RasterImageCache.shared.removeAll()
        status = "Raster filter preview"
    }

    func resetRasterFilterPreview(objectID: UUID) {
        guard rasterFilterPreviewObjectID == objectID,
              let original = rasterFilterPreviewOriginalObject,
              let index = document.objects.firstIndex(where: { $0.id == objectID }) else { return }
        document.objects[index] = original
        RasterImageCache.shared.removeAll()
        status = "Raster preview reset"
    }

    func commitRasterFilterPreview(objectID: UUID) {
        guard rasterFilterPreviewObjectID == objectID else { return }
        if let originalDocument = rasterFilterPreviewOriginalDocument, originalDocument != document {
            if undoStack.last != originalDocument { undoStack.append(originalDocument) }
            if undoStack.count > architecture.undoLimit { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        rasterFilterPreviewObjectID = nil
        rasterFilterPreviewOriginalObject = nil
        rasterFilterPreviewOriginalDocument = nil
        RasterImageCache.shared.removeAll()
        commitMutation(status: "Raster filter applied")
    }

    func cancelRasterFilterPreview(objectID: UUID) {
        guard rasterFilterPreviewObjectID == objectID else { return }
        if let original = rasterFilterPreviewOriginalObject,
           let index = document.objects.firstIndex(where: { $0.id == objectID }) {
            document.objects[index] = original
        }
        rasterFilterPreviewObjectID = nil
        rasterFilterPreviewOriginalObject = nil
        rasterFilterPreviewOriginalDocument = nil
        RasterImageCache.shared.removeAll()
        status = "Raster preview cancelled"
    }

    private func defaultRasterFilterParameters(_ id: RasterFilterIDV6) -> [String: Double] {
        switch id {
        case .gaussianBlur: return ["radius": 8]
        case .motionBlur: return ["distance": 20, "angle": 0]
        case .exposure: return ["ev": 0.5]
        case .brightnessContrast: return ["brightness": 0.1, "contrast": 1.15]
        case .saturation: return ["saturation": 1.2]
        case .hue: return ["angle": 15]
        case .sepia: return ["intensity": 0.8]
        case .sharpen: return ["sharpness": 0.5]
        case .noise: return ["amount": 0.06]
        case .pixelate: return ["scale": 12]
        case .crystallize: return ["radius": 18]
        case .colorControls: return ["brightness": 0, "contrast": 1, "saturation": 1]
        }
    }

    func addEffect(_ kind: EffectKind) {
        guard !selection.isEmpty else { return }
        if kind.category == .pathfinder {
            applyPathfinderEffect(kind)
            return
        }
        snapshot()
        for i in selectedIndices {
            if document.objects[i].appearanceStack != nil,
               let effectID = kind.m4EffectID,
               let descriptor = EffectRegistryV6.descriptor(id: effectID) {
                var stack = document.objects[i].resolvedAppearanceStack
                var live = descriptor.makeDefaultEffect()
                if let key = kind.m4PrimaryParameter { live.parameters[key] = .number(kind.defaultAmount) }
                stack.entries.append(.effect((try? EffectRegistryV6.validate(live)) ?? live))
                document.objects[i].applyAppearanceStack(stack)
            } else {
                document.objects[i].effects.append(VectorEffect(kind: kind, amount: kind.defaultAmount))
            }
        }
        commitMutation(status: "\(kind.title) applied")
    }

    /// Native Openstrator equivalents for Illustrator-style Pathfinder effects.
    /// They operate on the selected visual compound and remain intentionally
    /// lightweight so large documents stay responsive on Intel Macs.
    func applyPathfinderEffect(_ kind: EffectKind) {
        guard selection.count >= 2 else {
            status = "Pathfinder needs two or more selected objects"
            return
        }
        let indices = selectedIndices.sorted()
        guard let firstIndex = indices.first else { return }
        let group = UUID()
        snapshot()

        switch kind {
        case .pathfinderAdd, .pathfinderMerge:
            let appearance = document.objects[indices.last ?? firstIndex]
            for i in indices {
                document.objects[i].fill = appearance.fill
                document.objects[i].gradient = appearance.gradient
                document.objects[i].stroke = .clear
                document.objects[i].strokeWidth = 0
                document.objects[i].groupID = group
                document.objects[i].blendMode = .normal
            }

        case .pathfinderIntersect, .pathfinderCrop:
            var intersection = document.objects[firstIndex].bounds
            for i in indices.dropFirst() { intersection = intersection.intersection(document.objects[i].bounds) }
            guard !intersection.isNull, intersection.width > 0.5, intersection.height > 0.5 else {
                status = "The selected objects do not overlap"
                return
            }
            let appearance = document.objects[indices.last ?? firstIndex]
            let ids = Set(indices.map { document.objects[$0].id })
            document.objects.removeAll { ids.contains($0.id) }
            var result = VectorObject.rectangle(at: intersection.origin, size: intersection.size)
            result.name = kind == .pathfinderCrop ? "Pathfinder Crop" : "Pathfinder Intersect"
            result.fill = appearance.fill
            result.gradient = appearance.gradient
            result.stroke = appearance.stroke
            result.strokeWidth = appearance.strokeWidth
            document.objects.append(result)
            selection = [result.id]

        case .pathfinderExclude:
            for (offset, i) in indices.enumerated() {
                document.objects[i].groupID = group
                document.objects[i].blendMode = offset == 0 ? .normal : .difference
            }

        case .pathfinderSubtract, .pathfinderMinusBack:
            // Difference blending gives a useful live-looking subtract preview
            // without flattening complex paths into raster data.
            let order = kind == .pathfinderMinusBack ? Array(indices.reversed()) : indices
            for (offset, i) in order.enumerated() {
                document.objects[i].groupID = group
                document.objects[i].blendMode = offset == 0 ? .normal : .difference
            }

        case .pathfinderDivide:
            for i in indices {
                document.objects[i].groupID = group
                if document.objects[i].strokeWidth < 1 { document.objects[i].strokeWidth = 1 }
                if document.objects[i].stroke.a == 0 { document.objects[i].stroke = document.objects[i].fill }
            }

        case .pathfinderTrim:
            for i in indices {
                document.objects[i].groupID = group
                document.objects[i].stroke = .clear
                document.objects[i].strokeWidth = 0
            }

        case .pathfinderOutline:
            for i in indices {
                let outlineColor = document.objects[i].fill.a > 0 ? document.objects[i].fill : document.objects[i].stroke
                document.objects[i].fill = .clear
                document.objects[i].gradient = nil
                document.objects[i].stroke = outlineColor
                document.objects[i].strokeWidth = max(1.5, document.objects[i].strokeWidth)
                document.objects[i].groupID = group
            }

        default:
            return
        }
        commitMutation(status: "Pathfinder \(kind.title) applied")
    }
}

extension EditorStore {
    func shapeBuilderMergeSelection() {
        guard selection.count >= 2 else { status = "Shape Builder needs two or more selected shapes"; return }
        snapshot()
        let ids = selection
        let commonFill = primarySelectedObject?.fill ?? .accent
        let commonGradient = primarySelectedObject?.gradient
        let group = UUID()
        for i in document.objects.indices where ids.contains(document.objects[i].id) {
            document.objects[i].fill = commonFill
            document.objects[i].gradient = commonGradient
            document.objects[i].stroke = .clear
            document.objects[i].strokeWidth = 0
            document.objects[i].groupID = group
        }
        commitMutation(status: "Shape Builder merged appearance into a compound visual group")
    }
}

extension EditorStore {
    var hasDirectComponentSelection: Bool { directComponentSelection != nil }

    func bezierPath(for object: VectorObject) -> BezierPathV6? {
        guard object.kind == .path || object.kind == .line else { return nil }
        if let anchors = object.bezierAnchors, !anchors.isEmpty {
            return BezierPathV6(anchors: anchors, isClosed: object.isClosed == true)
        }
        guard !object.points.isEmpty else { return nil }
        return BezierPathV6(
            anchors: object.points.map { PathAnchorV6(point: $0.cgPoint) },
            isClosed: object.isClosed == true
        )
    }

    func replaceBezierPath(objectID: UUID, path: BezierPathV6) {
        guard let index = document.objects.firstIndex(where: { $0.id == objectID }) else { return }
        document.objects[index] = objectByReplacingPath(document.objects[index], path: path, name: document.objects[index].name)
    }

    func addBezierPath(_ path: BezierPathV6, name: String = "Path", strokeWidth: Double = 2) {
        guard path.anchors.count >= 2 else { return }
        snapshot()
        var object = VectorObject.path(points: PathCompatibility.flattenedPoints(path), name: name, closed: path.isClosed)
        object.bezierAnchors = path.anchors
        object.strokeWidth = strokeWidth
        object.lineCap = "round"
        object.lineJoin = "round"
        object = objectByReplacingPath(object, path: path, name: name)
        document.objects.append(object)
        selection = [object.id]
        directComponentSelection = nil
        commitMutation(status: "\(name) created")
    }

    func addPencilPath(_ samples: [CGPoint]) {
        guard samples.count > 1 else { return }
        let path = PencilFitter.fit(samples: samples, tolerance: 1.5 / max(0.35, zoom), smoothing: 0.85)
        addBezierPath(path, name: "Pencil Path", strokeWidth: 2)
    }

    func penAddAnchor(point: CGPoint, dragTo: CGPoint?) {
        if draftBezierTool != .pen {
            penBuilder = PenPathBuilder(closeTolerance: 8 / max(0.35, zoom))
            draftBezierTool = .pen
        }
        let snappedPoint = snapped(point)
        let result = penBuilder.add(point: snappedPoint, dragTo: dragTo.map { snapped($0) })
        draftBezierPath = penBuilder.path
        draftPath = PathCompatibility.flattenedPoints(penBuilder.path)
        status = result.closed ? "Pen path closed" : "Pen: click to add point · Return to finish · Esc to cancel"
        if result.closed { finishDraftBezierPath() }
    }

    func curvatureAddAnchor(point: CGPoint) {
        if draftBezierTool != .curvature {
            curvatureBuilder = CurvaturePathBuilder(closeTolerance: 8 / max(0.35, zoom))
            draftBezierTool = .curvature
        }
        let result = curvatureBuilder.add(point: snapped(point))
        draftBezierPath = curvatureBuilder.path
        draftPath = PathCompatibility.flattenedPoints(curvatureBuilder.path)
        status = result.closed ? "Curvature path closed" : "Curvature: click to add point · Return to finish · Esc to cancel"
        if result.closed { finishDraftBezierPath() }
    }

    func finishDraftBezierPath() {
        guard let path = draftBezierPath, path.anchors.count >= 2 else {
            cancelDraftBezierPath()
            return
        }
        let tool = draftBezierTool
        draftBezierPath = nil
        draftPath.removeAll()
        draftBezierTool = nil
        penBuilder = PenPathBuilder(closeTolerance: 8 / max(0.35, zoom))
        curvatureBuilder = CurvaturePathBuilder(closeTolerance: 8 / max(0.35, zoom))
        addBezierPath(path, name: tool == .curvature ? "Curvature Path" : "Pen Path")
    }

    func cancelDraftBezierPath() {
        draftBezierPath = nil
        draftPath.removeAll()
        draftBezierTool = nil
        penBuilder = PenPathBuilder(closeTolerance: 8 / max(0.35, zoom))
        curvatureBuilder = CurvaturePathBuilder(closeTolerance: 8 / max(0.35, zoom))
        status = "Path cancelled"
    }

    func selectDirect(at point: CGPoint, additive: Bool = false) {
        let tolerance = max(4, 8 / max(0.1, zoom))
        let candidates = document.objects.reversed().filter { $0.isVisible && !$0.isLocked && ($0.kind == .path || $0.kind == .line) }
        for object in candidates {
            guard let path = bezierPath(for: object),
                  let hit = DirectSelection.hitTest(path: path, point: point, tolerance: tolerance) else { continue }
            if additive { selection.insert(object.id) } else { selection = [object.id] }
            directComponentSelection = DirectComponentSelection(objectID: object.id, component: hit.component)
            status = "Direct Selection"
            return
        }
        directComponentSelection = nil
        guard let hit = hitTest(point) else {
            if !additive { selection.removeAll() }
            return
        }
        if additive {
            if selection.contains(hit.id) { selection.remove(hit.id) } else { selection.insert(hit.id) }
        } else {
            selection = [hit.id]
        }
    }

    func beginDirectComponentMove(pointer: CGPoint) {
        guard let component = directComponentSelection,
              let object = document.objects.first(where: { $0.id == component.objectID }),
              let path = bezierPath(for: object) else { return }
        directMoveOriginalPath = path
        directMoveStart = pointer
        directMoveDidSnapshot = false
    }

    func updateDirectComponentMove(pointer: CGPoint) {
        guard let selection = directComponentSelection,
              let original = directMoveOriginalPath,
              let start = directMoveStart else { return }
        let dx = pointer.x - start.x, dy = pointer.y - start.y
        if !directMoveDidSnapshot {
            snapshot()
            directMoveDidSnapshot = true
        }
        let moved: BezierPathV6
        switch selection.component {
        case .anchor(let index):
            guard original.anchors.indices.contains(index) else { return }
            let p = original.anchors[index].point
            moved = DirectSelection.moveAnchor(path: original, index: index, to: CGPoint(x: p.x + dx, y: p.y + dy))
        case .incomingHandle(let index):
            guard original.anchors.indices.contains(index) else { return }
            let p = original.anchors[index].inHandle ?? original.anchors[index].point
            moved = DirectSelection.moveHandle(path: original, index: index, side: .incoming, to: CGPoint(x: p.x + dx, y: p.y + dy))
        case .outgoingHandle(let index):
            guard original.anchors.indices.contains(index) else { return }
            let p = original.anchors[index].outHandle ?? original.anchors[index].point
            moved = DirectSelection.moveHandle(path: original, index: index, side: .outgoing, to: CGPoint(x: p.x + dx, y: p.y + dy))
        case .segment(let segmentIndex):
            moved = DirectSelection.moveSegment(path: original, segmentIndex: segmentIndex, delta: CGSize(width: dx, height: dy))
        }
        replaceBezierPath(objectID: selection.objectID, path: moved)
    }

    func endDirectComponentMove(commit: Bool) {
        defer {
            directMoveOriginalPath = nil
            directMoveStart = nil
            directMoveDidSnapshot = false
        }
        guard commit, directMoveDidSnapshot else { return }
        commitMutation(status: "Path component moved")
    }

    func deleteDirectComponentSelection() {
        guard let component = directComponentSelection,
              let index = document.objects.firstIndex(where: { $0.id == component.objectID }),
              let path = bezierPath(for: document.objects[index]) else { return }
        switch component.component {
        case .anchor(let anchorIndex):
            do {
                snapshot()
                let changed = try PathEditor.deleteAnchor(path: path, index: anchorIndex)
                replaceBezierPath(objectID: component.objectID, path: changed)
                directComponentSelection = nil
                commitMutation(status: "Anchor deleted")
            } catch {
                status = "Path needs at least two anchors"
            }
        case .incomingHandle(let anchorIndex):
            guard path.anchors.indices.contains(anchorIndex) else { return }
            snapshot()
            var changed = path
            changed.anchors[anchorIndex].inHandle = nil
            changed.anchors[anchorIndex].kind = .corner
            replaceBezierPath(objectID: component.objectID, path: changed)
            directComponentSelection = .init(objectID: component.objectID, component: .anchor(anchorIndex))
            commitMutation(status: "Incoming handle removed")
        case .outgoingHandle(let anchorIndex):
            guard path.anchors.indices.contains(anchorIndex) else { return }
            snapshot()
            var changed = path
            changed.anchors[anchorIndex].outHandle = nil
            changed.anchors[anchorIndex].kind = .corner
            replaceBezierPath(objectID: component.objectID, path: changed)
            directComponentSelection = .init(objectID: component.objectID, component: .anchor(anchorIndex))
            commitMutation(status: "Outgoing handle removed")
        case .segment:
            status = "Select an anchor or handle to delete it"
        }
    }

    func addAnchorPoint(at point: CGPoint) {
        guard let index = primarySelectedIndex,
              let path = bezierPath(for: document.objects[index]),
              let location = nearestPathLocation(path: path, point: point) else {
            status = "Select a path first"
            return
        }
        do {
            snapshot()
            let changed = try PathEditor.insertAnchor(path: path, segmentIndex: location.segmentIndex, t: location.t)
            replaceBezierPath(objectID: document.objects[index].id, path: changed)
            directComponentSelection = .init(objectID: document.objects[index].id, component: .anchor(min(location.segmentIndex + 1, changed.anchors.count - 1)))
            commitMutation(status: "Anchor point added")
        } catch {
            status = "Anchor point could not be added"
        }
    }

    func deleteAnchorPoint(at point: CGPoint) {
        guard let index = primarySelectedIndex,
              let path = bezierPath(for: document.objects[index]) else { status = "Select a path first"; return }
        let tolerance = max(5, 10 / max(0.1, zoom))
        guard let hit = DirectSelection.hitTest(path: path, point: point, tolerance: tolerance),
              case .anchor(let anchorIndex) = hit.component else { status = "Click an anchor point"; return }
        do {
            snapshot()
            let changed = try PathEditor.deleteAnchor(path: path, index: anchorIndex)
            replaceBezierPath(objectID: document.objects[index].id, path: changed)
            directComponentSelection = nil
            commitMutation(status: "Anchor point removed")
        } catch {
            status = "Path needs at least two anchors"
        }
    }

    private func objectByReplacingPath(_ source: VectorObject, path: BezierPathV6, name: String) -> VectorObject {
        var object = source
        object.name = name
        object.kind = .path
        object.bezierAnchors = path.anchors
        object.isClosed = path.isClosed
        object.points = PathCompatibility.flattenedPoints(path, tolerance: 0.75).map(CodablePoint.init)
        if let bounds = BezierGeometry.bounds(path) {
            object.x = bounds.minX
            object.y = bounds.minY
            object.width = max(1, bounds.width)
            object.height = max(1, bounds.height)
        }
        return object
    }

    private func translatedBezierAnchors(_ anchors: [PathAnchorV6]?, dx: Double, dy: Double) -> [PathAnchorV6]? {
        anchors?.map { PathCompatibility.translatedAnchor($0, dx: dx, dy: dy) }
    }

    private func scaledBezierAnchors(_ anchors: [PathAnchorV6]?, from oldRect: CGRect, to newRect: CGRect) -> [PathAnchorV6]? {
        guard let anchors else { return nil }
        let sx = newRect.width / max(1, oldRect.width)
        let sy = newRect.height / max(1, oldRect.height)
        func transform(_ point: CGPoint?) -> CGPoint? {
            point.map { CGPoint(
                x: newRect.minX + ($0.x - oldRect.minX) * sx,
                y: newRect.minY + ($0.y - oldRect.minY) * sy
            ) }
        }
        return anchors.map { anchor in
            PathAnchorV6(
                point: transform(anchor.point)!,
                inHandle: transform(anchor.inHandle),
                outHandle: transform(anchor.outHandle),
                kind: anchor.kind
            )
        }
    }

    private func nearestPathLocation(path: BezierPathV6, point: CGPoint) -> (segmentIndex: Int, t: Double, distance: Double)? {
        let segments = BezierGeometry.segments(of: path)
        guard !segments.isEmpty else { return nil }
        var best: (Int, Double, Double)?
        for (segmentIndex, segment) in segments.enumerated() {
            for step in 0...64 {
                let t = Double(step) / 64
                let candidate = BezierGeometry.point(on: segment, t: t)
                let distance = hypot(Double(candidate.x - point.x), Double(candidate.y - point.y))
                if distance < (best?.2 ?? .greatestFiniteMagnitude) { best = (segmentIndex, t, distance) }
            }
        }
        return best.map { (segmentIndex: $0.0, t: $0.1, distance: $0.2) }
    }

    func applyLivePaint(at point: CGPoint) {
        guard let source = hitTest(point), let index = document.objects.firstIndex(where: { $0.id == source.id }) else { return }
        snapshot()
        document.objects[index].fill = .accent
        document.objects[index].gradient = nil
        commitMutation(status: "Live Paint fill applied")
    }

    func modifySymbols(_ tool: ToolKind) {
        guard !selection.isEmpty else { status = "Select symbol-like objects first"; return }
        snapshot()
        guard let bounds = selectionBounds else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        for i in selectedIndices {
            switch tool {
            case .symbolShifter:
                let dx = document.objects[i].bounds.midX < center.x ? -12.0 : 12.0
                let dy = document.objects[i].bounds.midY < center.y ? -8.0 : 8.0
                translateObject(at: i, dx: dx, dy: dy)
            case .symbolScruncher:
                let ox = document.objects[i].bounds.midX-center.x, oy = document.objects[i].bounds.midY-center.y
                translateObject(at: i, dx: -ox*0.15, dy: -oy*0.15)
            case .symbolSizer:
                document.objects[i].scaleX = (document.objects[i].scaleX ?? 1) * 1.12
                document.objects[i].scaleY = (document.objects[i].scaleY ?? 1) * 1.12
            case .symbolSpinner:
                document.objects[i].rotation += 18
            case .symbolStainer:
                document.objects[i].fill = RGBAColor(r: min(1,document.objects[i].fill.r+0.08), g: max(0,document.objects[i].fill.g-0.03), b: min(1,document.objects[i].fill.b+0.10), a: document.objects[i].fill.a)
            case .symbolScreener:
                document.objects[i].opacity = max(0.1, document.objects[i].opacity * 0.84)
            case .symbolStyler:
                document.objects[i].effects.append(VectorEffect(kind: .glow, amount: 8))
                document.objects[i].effects.append(VectorEffect(kind: .shadow, amount: 6))
            default: break
            }
        }
        commitMutation(status: tool.title + " applied")
    }

    func addGraph(kind: ToolKind, in rect: CGRect) {
        let r = rect.standardized
        guard r.width > 30, r.height > 30 else { return }
        switch kind {
        case .graph, .stackedColumnGraph, .barGraph, .stackedBarGraph:
            addBarGraph(in: r)
            if kind == .barGraph || kind == .stackedBarGraph {
                snapshot()
                for i in selectedIndices {
                    let w = document.objects[i].width, h = document.objects[i].height
                    document.objects[i].width = h; document.objects[i].height = w
                }
                commitMutation(status: kind.title + " created")
            } else { status = kind.title + " created" }
        case .lineGraph, .areaGraph, .scatterGraph, .radarGraph:
            let values: [Double] = [0.28,0.62,0.48,0.86,0.54,0.77]
            var pts: [CGPoint] = []
            for (i,v) in values.enumerated() {
                let x = r.minX + r.width * Double(i)/Double(values.count-1)
                let y = r.maxY - r.height*v
                pts.append(CGPoint(x:x,y:y))
            }
            snapshot()
            var p = VectorObject.path(points: pts, name: kind.title, closed: kind == .areaGraph)
            p.stroke = RGBAColor(r:0.12,g:0.45,b:0.95); p.strokeWidth = 3
            if kind == .areaGraph { p.fill = RGBAColor(r:0.12,g:0.45,b:0.95,a:0.18) }
            document.objects.append(p); selection=[p.id]; commitMutation(status: kind.title + " created")
        case .pieGraph:
            snapshot()
            let group = UUID()
            let colors = [RGBAColor(r:0.15,g:0.48,b:0.96),RGBAColor(r:0.97,g:0.35,b:0.32),RGBAColor(r:0.35,g:0.73,b:0.51),RGBAColor(r:0.96,g:0.68,b:0.18)]
            var objs:[VectorObject]=[]
            for i in 0..<4 {
                var e=VectorObject.ellipse(at: CGPoint(x:r.minX+Double(i%2)*r.width*0.18,y:r.minY+Double(i/2)*r.height*0.18), size: CGSize(width:r.width*0.64,height:r.height*0.64))
                e.fill=colors[i]; e.opacity=0.72; e.groupID=group; e.name="Pie Segment \(i+1)"; objs.append(e)
            }
            document.objects.append(contentsOf: objs); selection=Set(objs.map(\.id)); commitMutation(status:"Pie graph created")
        default:
            addBarGraph(in: r)
        }
    }

    func attachObjectsToPath() {
        let paths = selectedObjects.filter { $0.kind == .path || $0.kind == .line }
        let items = selectedObjects.filter { $0.kind != .path && $0.kind != .line }
        guard let path = paths.first, path.points.count >= 2, !items.isEmpty else { status = "Select a path plus one or more objects"; return }
        snapshot()
        let a = path.points.first!.cgPoint, b = path.points.last!.cgPoint
        for (n,item) in items.enumerated() {
            let t = Double(n+1)/Double(items.count+1)
            let tx = Double(a.x)+(Double(b.x)-Double(a.x))*t
            let ty = Double(a.y)+(Double(b.y)-Double(a.y))*t
            if let idx = document.objects.firstIndex(where: {$0.id==item.id}) {
                let dx = tx-document.objects[idx].bounds.midX, dy = ty-document.objects[idx].bounds.midY
                translateObject(at: idx, dx: dx, dy: dy)
            }
        }
        commitMutation(status: "Objects aligned to path")
    }

    func addDimension(from start: CGPoint, to end: CGPoint) {
        snapshot()
        var line = VectorObject.line(from: start, to: end)
        line.name = "Dimension"; line.stroke = RGBAColor(r:0.18,g:0.52,b:0.98); line.strokeWidth = 1.5
        let d = hypot(Double(end.x-start.x), Double(end.y-start.y))
        var label = VectorObject.text(at: CGPoint(x:(start.x+end.x)/2+6,y:(start.y+end.y)/2-20))
        label.name="Dimension Label"; label.text="\(Int(d.rounded())) px"; label.fontSize=14; label.width=120; label.height=24; label.fill=RGBAColor(r:0.12,g:0.30,b:0.58)
        let group=UUID(); line.groupID=group; label.groupID=group
        document.objects.append(contentsOf:[line,label]); selection=[line.id,label.id]; commitMutation(status:"Dimension created")
    }

    func performSpecialTool(_ tool: ToolKind, start: CGPoint, end: CGPoint) {
        let r = CGRect(x:min(start.x,end.x), y:min(start.y,end.y), width:abs(end.x-start.x), height:abs(end.y-start.y))
        let fallback = r.width < 4 || r.height < 4 ? CGRect(x:end.x,y:end.y,width:180,height:120) : r
        switch tool {
        case .addAnchor: addAnchorPoint(at:end)
        case .deleteAnchor: deleteAnchorPoint(at:end)
        case .anchorPoint: smoothSelectedPaths()
        case .shaper:
            if fallback.width/fallback.height > 1.45 || fallback.height/fallback.width > 1.45 { addRoundedRectangle(in:fallback) }
            else { addEllipse(at:fallback.origin,size:fallback.size) }
        case .verticalAreaText: addAreaText(in:fallback,vertical:true)
        case .verticalTypeOnPath:
            addText(at:end); if let i=primarySelectedIndex { document.objects[i].text="V\ne\nr\nt\ni\nc\na\nl" }
        case .touchType:
            scaleSelection(by:1.08); rotateSelection(by:4); commitMutation(status:"Touch Type transform applied")
        case .warp: addEffect(.warpArc)
        case .twirl: addEffect(.twist)
        case .pucker: addEffect(.puckerBloat)
        case .bloat: addEffect(.warpInflate)
        case .scallop: addEffect(.roughen)
        case .crystallizeTool: addEffect(.crystallize)
        case .wrinkle: addEffect(.zigZag)
        case .puppetWarp: addEffect(.freeDistort)
        case .livePaintBucket: applyLivePaint(at:end)
        case .livePaintSelection: selectSimilarAppearance(at:end)
        case .symbolShifter, .symbolScruncher, .symbolSizer, .symbolSpinner, .symbolStainer, .symbolScreener, .symbolStyler: modifySymbols(tool)
        case .stackedColumnGraph, .barGraph, .stackedBarGraph, .lineGraph, .areaGraph, .scatterGraph, .pieGraph, .radarGraph: addGraph(kind:tool,in:fallback)
        case .perspectiveSelection: selectDirect(at:end,additive:NSEvent.modifierFlags.contains(.shift))
        case .sliceSelection: status="Slice Selection ready — slice edges are guide-based in this build"
        case .dimension: addDimension(from:start,to:end)
        case .objectsOnPath: attachObjectsToPath()
        case .printTiling:
            snapshot(); document.guides.append(CanvasGuide(axis:.vertical,position:document.artboardWidth/2)); document.guides.append(CanvasGuide(axis:.horizontal,position:document.artboardHeight/2)); document.showGuides=true; commitMutation(status:"Print tiling guides shown")
        case .rotateView:
            viewRotation = (viewRotation + Double(end.x-start.x)*0.25).truncatingRemainder(dividingBy:360); status="View rotated \(Int(viewRotation.rounded()))°"
        default:
            status = tool.title + " selected"
        }
    }
}
