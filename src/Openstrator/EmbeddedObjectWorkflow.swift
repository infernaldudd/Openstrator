import SwiftUI
import AppKit
import OpenstratorCore

struct EmbeddedObjectPayloadV6: Codable, Equatable {
    var objects: [VectorObject]
}

enum EmbeddedObjectRuntime {
    static let recursionLimit = 8

    static func payload(resourceID: UUID, document: OpenDocument) -> (EmbeddedObjectResourceV6, EmbeddedObjectPayloadV6)? {
        guard let resource = document.resourceLibrary?.embeddedObjects.first(where: { $0.id == resourceID }),
              let payload = try? JSONDecoder().decode(EmbeddedObjectPayloadV6.self, from: resource.payloadData) else { return nil }
        return (resource, payload)
    }

    static func draw(proxy: VectorObject, resourceID: UUID, document: OpenDocument, context: inout GraphicsContext, depth: Int) {
        guard depth < recursionLimit, let (resource, payload) = payload(resourceID: resourceID, document: document) else {
            drawPlaceholder(proxy.bounds, text: depth >= recursionLimit ? "Embedded recursion limit" : "Missing embedded object", context: &context)
            return
        }
        let original = resource.originalBounds
        guard original.width > 0, original.height > 0 else { return }
        let sx = proxy.bounds.width / original.width
        let sy = proxy.bounds.height / original.height
        context.drawLayer { layer in
            layer.opacity = proxy.opacity
            layer.translateBy(x: proxy.bounds.midX, y: proxy.bounds.midY)
            if proxy.rotation != 0 { layer.rotate(by: .degrees(proxy.rotation)) }
            let psx = proxy.scaleX ?? 1, psy = proxy.scaleY ?? 1, shx = proxy.shearX ?? 0, shy = proxy.shearY ?? 0
            if psx != 1 || psy != 1 || shx != 0 || shy != 0 {
                layer.concatenate(CGAffineTransform(a: psx, b: shy, c: shx, d: psy, tx: 0, ty: 0))
            }
            layer.translateBy(x: -proxy.bounds.width / 2, y: -proxy.bounds.height / 2)
            layer.scaleBy(x: sx, y: sy)
            layer.translateBy(x: -original.minX, y: -original.minY)
            for child in payload.objects where child.isVisible {
                VectorCanvasRenderer.draw(child, document: document, context: &layer, embeddedDepth: depth + 1)
            }
        }
    }

    private static func drawPlaceholder(_ rect: CGRect, text: String, context: inout GraphicsContext) {
        context.stroke(Path(rect), with: .color(.secondary.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        context.draw(Text(text).font(.system(size: 11)).foregroundColor(.secondary), at: CGPoint(x: rect.midX, y: rect.midY))
    }
}

@MainActor
extension EditorStore {
    func convertSelectionToEmbeddedObject() {
        let objects = selectedObjects
        guard !objects.isEmpty, let bounds = selectionBounds else { status = "Select artwork to embed"; return }
        guard let payloadData = try? JSONEncoder().encode(EmbeddedObjectPayloadV6(objects: objects)) else { status = "Could not preserve selected artwork"; return }
        ensureM6LayerTree()
        snapshot()

        let nested = Array(Set(objects.compactMap(\.embeddedObjectID)))
        let resource = EmbeddedObjectResourceV6(
            name: objects.count == 1 ? objects[0].name : "Embedded Object",
            originalBounds: bounds,
            payloadData: payloadData,
            nestedEmbeddedResourceIDs: nested
        )
        var library = document.resourceLibrary ?? ResourceLibraryV6()
        library.embeddedObjects.append(resource)
        document.resourceLibrary = library

        let doomed = Set(objects.map(\.id))
        var proxy = VectorObject(
            name: resource.name,
            kind: .image,
            x: bounds.minX,
            y: bounds.minY,
            width: max(1, bounds.width),
            height: max(1, bounds.height),
            fill: .clear,
            stroke: .clear,
            strokeWidth: 0
        )
        proxy.embeddedObjectID = resource.id

        var targetParent: UUID?
        var targetIndex = 0
        if var tree = document.layerTree {
            let nodeIDs = objects.compactMap(\.layerNodeID)
            let parents = Set(nodeIDs.compactMap { tree.nodes[$0]?.parentID })
            targetParent = parents.count == 1 ? parents.first : tree.roots.compactMap { tree.nodes[$0] }.first(where: { $0.kind == .artboard })?.id
            if let targetParent {
                let siblings = tree.nodes[targetParent]?.children ?? []
                targetIndex = nodeIDs.compactMap { siblings.firstIndex(of: $0) }.min() ?? siblings.count
            }
            for nodeID in nodeIDs { _ = try? tree.removeSubtree(nodeID) }
            if let targetParent {
                let node = LayerNodeV6(name: proxy.name, kind: .embeddedObject, objectID: proxy.id, resourceID: resource.id)
                try? tree.insert(node, parent: targetParent, index: targetIndex)
                proxy.layerNodeID = node.id
            }
            document.layerTree = tree
        }

        document.objects.removeAll { doomed.contains($0.id) }
        document.objects.append(proxy)
        selection = [proxy.id]
        syncDocumentObjectOrderFromLayerTree()
        commitMutation(status: "Converted to Embedded Object")
    }

    func expandSelectedEmbeddedObjects() {
        let proxies = selectedObjects.filter { $0.embeddedObjectID != nil }
        guard !proxies.isEmpty else { status = "Select an Embedded Object"; return }
        snapshot()
        var expanded: [VectorObject] = []
        let proxyIDs = Set(proxies.map(\.id))
        for proxy in proxies {
            guard let resourceID = proxy.embeddedObjectID,
                  let (resource, payload) = EmbeddedObjectRuntime.payload(resourceID: resourceID, document: document) else { continue }
            for var child in payload.objects {
                child.id = UUID()
                child.layerNodeID = nil
                child = transformedPreservedChild(child, from: resource.originalBounds, into: proxy)
                expanded.append(child)
            }
        }
        guard !expanded.isEmpty else { status = "Embedded contents unavailable"; return }
        document.objects.removeAll { proxyIDs.contains($0.id) }
        document.objects.append(contentsOf: expanded)
        selection = Set(expanded.map(\.id))
        commitMutation(status: "Expanded Embedded Object")
    }

    func replaceEmbeddedContentsFromSelection() {
        let embedded = selectedObjects.filter { $0.embeddedObjectID != nil }
        let replacements = selectedObjects.filter { $0.embeddedObjectID == nil }
        guard embedded.count == 1, !replacements.isEmpty,
              let resourceID = embedded[0].embeddedObjectID else {
            status = "Select one Embedded Object plus replacement artwork"
            return
        }
        let bounds = replacements.dropFirst().reduce(replacements[0].bounds) { $0.union($1.bounds) }
        guard let data = try? JSONEncoder().encode(EmbeddedObjectPayloadV6(objects: replacements)) else { return }
        snapshot()
        var library = document.resourceLibrary ?? ResourceLibraryV6()
        guard let index = library.embeddedObjects.firstIndex(where: { $0.id == resourceID }) else { return }
        library.embeddedObjects[index].payloadData = data
        library.embeddedObjects[index].originalBounds = bounds
        library.embeddedObjects[index].nestedEmbeddedResourceIDs = Array(Set(replacements.compactMap(\.embeddedObjectID)))
        document.resourceLibrary = library
        let replacementIDs = Set(replacements.map(\.id))
        document.objects.removeAll { replacementIDs.contains($0.id) }
        selection = [embedded[0].id]
        commitMutation(status: "Embedded contents replaced")
    }

    func openSelectedEmbeddedObject() {
        guard let proxy = selectedObjects.first(where: { $0.embeddedObjectID != nil }),
              let resourceID = proxy.embeddedObjectID,
              let (resource, payload) = EmbeddedObjectRuntime.payload(resourceID: resourceID, document: document) else {
            status = "Select an Embedded Object"
            return
        }
        EmbeddedObjectWindowManager.shared.open(parent: self, resource: resource, payload: payload)
    }

    func applyEmbeddedEditor(resourceID: UUID, childDocument: OpenDocument) {
        guard !childDocument.objects.isEmpty else { status = "Embedded contents cannot be empty"; return }
        let bounds = childDocument.objects.dropFirst().reduce(childDocument.objects[0].bounds) { $0.union($1.bounds) }
        guard let data = try? JSONEncoder().encode(EmbeddedObjectPayloadV6(objects: childDocument.objects)) else { return }
        snapshot()
        var library = document.resourceLibrary ?? ResourceLibraryV6()
        guard let index = library.embeddedObjects.firstIndex(where: { $0.id == resourceID }) else { return }
        library.embeddedObjects[index].payloadData = data
        library.embeddedObjects[index].originalBounds = bounds
        library.embeddedObjects[index].nestedEmbeddedResourceIDs = Array(Set(childDocument.objects.compactMap(\.embeddedObjectID)))
        // Resources created while editing nested contents are merged by identity.
        if let childLibrary = childDocument.resourceLibrary {
            mergeResources(from: childLibrary, into: &library, excludingEmbeddedID: resourceID)
        }
        document.resourceLibrary = library
        mergeRasterAssets(from: childDocument)
        commitMutation(status: "Embedded contents updated")
    }

    private func mergeRasterAssets(from childDocument: OpenDocument) {
        let existing = Set((document.rasterAssets ?? []).map(\.id))
        let missing = (childDocument.rasterAssets ?? []).filter { !existing.contains($0.id) }
        guard !missing.isEmpty else { return }
        var assets = document.rasterAssets ?? []
        assets.append(contentsOf: missing)
        document.rasterAssets = assets
    }

    func mergeResourceLibrary(_ source: ResourceLibraryV6) {
        var target = document.resourceLibrary ?? ResourceLibraryV6()
        mergeResources(from: source, into: &target, excludingEmbeddedID: nil)
        document.resourceLibrary = target
    }

    private func mergeResources(from source: ResourceLibraryV6, into target: inout ResourceLibraryV6, excludingEmbeddedID: UUID?) {
        let embeddedIDs = Set(target.embeddedObjects.map(\.id))
        target.embeddedObjects.append(contentsOf: source.embeddedObjects.filter { $0.id != excludingEmbeddedID && !embeddedIDs.contains($0.id) })
        let linkIDs = Set(target.linkedAssets.map(\.id))
        target.linkedAssets.append(contentsOf: source.linkedAssets.filter { !linkIDs.contains($0.id) })
        let symbolIDs = Set(target.symbols.map(\.id))
        target.symbols.append(contentsOf: source.symbols.filter { !symbolIDs.contains($0.id) })
        let styleIDs = Set(target.graphicStyles.map(\.id))
        target.graphicStyles.append(contentsOf: source.graphicStyles.filter { !styleIDs.contains($0.id) })
    }

    func transformedPreservedChild(_ source: VectorObject, from original: CGRect, into proxy: VectorObject) -> VectorObject {
        var object = source
        let sx = proxy.bounds.width / max(0.0001, original.width)
        let sy = proxy.bounds.height / max(0.0001, original.height)
        let radians = proxy.rotation * .pi / 180
        let center = CGPoint(x: proxy.bounds.midX, y: proxy.bounds.midY)

        func map(_ point: CGPoint) -> CGPoint {
            var p = CGPoint(
                x: proxy.bounds.minX + (point.x - original.minX) * sx,
                y: proxy.bounds.minY + (point.y - original.minY) * sy
            )
            if proxy.rotation != 0 {
                let dx = p.x - center.x, dy = p.y - center.y
                p = CGPoint(x: center.x + dx * cos(radians) - dy * sin(radians), y: center.y + dx * sin(radians) + dy * cos(radians))
            }
            return p
        }

        let corners = [
            CGPoint(x: source.bounds.minX, y: source.bounds.minY), CGPoint(x: source.bounds.maxX, y: source.bounds.minY),
            CGPoint(x: source.bounds.maxX, y: source.bounds.maxY), CGPoint(x: source.bounds.minX, y: source.bounds.maxY),
        ].map(map)
        let minX = corners.map(\.x).min() ?? proxy.x, maxX = corners.map(\.x).max() ?? proxy.x + 1
        let minY = corners.map(\.y).min() ?? proxy.y, maxY = corners.map(\.y).max() ?? proxy.y + 1
        object.x = minX; object.y = minY; object.width = max(1, maxX - minX); object.height = max(1, maxY - minY)
        object.rotation += proxy.rotation
        object.opacity *= proxy.opacity
        object.scaleX = (object.scaleX ?? 1) * (proxy.scaleX ?? 1)
        object.scaleY = (object.scaleY ?? 1) * (proxy.scaleY ?? 1)
        object.shearX = (object.shearX ?? 0) + (proxy.shearX ?? 0)
        object.shearY = (object.shearY ?? 0) + (proxy.shearY ?? 0)
        object.points = object.points.map { CodablePoint(map($0.cgPoint)) }
        if let anchors = object.bezierAnchors {
            object.bezierAnchors = anchors.map { anchor in
                PathAnchorV6(point: map(anchor.point), inHandle: anchor.inHandle.map(map), outHandle: anchor.outHandle.map(map), kind: anchor.kind)
            }
        }
        if object.kind == .text {
            var typography = object.resolvedTypography
            typography.frame = object.bounds
            object.applyTypography(typography)
        }
        return object
    }
}

@MainActor
private final class EmbeddedObjectWindowManager {
    static let shared = EmbeddedObjectWindowManager()
    private var windows: [UUID: NSWindow] = [:]

    func open(parent: EditorStore, resource: EmbeddedObjectResourceV6, payload: EmbeddedObjectPayloadV6) {
        if let existing = windows[resource.id] { existing.makeKeyAndOrderFront(nil); return }
        let child = EditorStore()
        var doc = OpenDocument()
        doc.name = resource.name
        doc.artboardWidth = max(320, resource.originalBounds.maxX + 64)
        doc.artboardHeight = max(240, resource.originalBounds.maxY + 64)
        doc.objects = payload.objects
        doc.rasterAssets = parent.document.rasterAssets
        doc.resourceLibrary = parent.document.resourceLibrary
        child.document = doc
        child.selection.removeAll()
        child.ensureM6LayerTree()

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Embedded Object — \(resource.name)"
        window.center()
        window.contentView = NSHostingView(rootView: EmbeddedObjectEditorHost(
            store: child,
            onApply: { [weak parent] in parent?.applyEmbeddedEditor(resourceID: resource.id, childDocument: child.document) },
            onClose: { [weak self, weak window] in window?.close(); self?.windows.removeValue(forKey: resource.id) }
        ))
        windows[resource.id] = window
        window.makeKeyAndOrderFront(nil)
    }
}

private struct EmbeddedObjectEditorHost: View {
    @ObservedObject var store: EditorStore
    var onApply: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RootEditorView().environmentObject(store)
            Divider()
            HStack {
                Text("Editing preserved Embedded Object contents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Close", action: onClose)
                Button("Apply to Parent") { onApply() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(10)
        }
    }
}
