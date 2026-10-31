import SwiftUI
import OpenstratorCore

enum SymbolRuntime {
    static func payload(definitionID: UUID, document: OpenDocument) -> (SymbolDefinitionV6, EmbeddedObjectPayloadV6)? {
        guard let definition = document.resourceLibrary?.symbols.first(where: { $0.id == definitionID }),
              let payload = try? JSONDecoder().decode(EmbeddedObjectPayloadV6.self, from: definition.payloadData) else { return nil }
        return (definition, payload)
    }

    static func draw(proxy: VectorObject, definitionID: UUID, document: OpenDocument, context: inout GraphicsContext, depth: Int) {
        guard depth < EmbeddedObjectRuntime.recursionLimit,
              let (definition, payload) = payload(definitionID: definitionID, document: document) else {
            context.stroke(Path(proxy.bounds), with: .color(.secondary.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            context.draw(Text("Missing Symbol").font(.system(size: 11)).foregroundColor(.secondary), at: CGPoint(x: proxy.bounds.midX, y: proxy.bounds.midY))
            return
        }
        let original = definition.originalBounds
        guard original.width > 0, original.height > 0 else { return }
        let sx = proxy.bounds.width / original.width, sy = proxy.bounds.height / original.height
        context.drawLayer { layer in
            layer.opacity = proxy.opacity
            layer.translateBy(x: proxy.bounds.midX, y: proxy.bounds.midY)
            if proxy.rotation != 0 { layer.rotate(by: .degrees(proxy.rotation)) }
            let psx = proxy.scaleX ?? 1, psy = proxy.scaleY ?? 1, shx = proxy.shearX ?? 0, shy = proxy.shearY ?? 0
            if psx != 1 || psy != 1 || shx != 0 || shy != 0 { layer.concatenate(CGAffineTransform(a: psx, b: shy, c: shx, d: psy, tx: 0, ty: 0)) }
            layer.translateBy(x: -proxy.bounds.width / 2, y: -proxy.bounds.height / 2)
            layer.scaleBy(x: sx, y: sy)
            layer.translateBy(x: -original.minX, y: -original.minY)
            for child in payload.objects where child.isVisible {
                VectorCanvasRenderer.draw(child, document: document, context: &layer, embeddedDepth: depth + 1)
            }
        }
    }
}

@MainActor
extension EditorStore {
    func createSymbolFromSelection() {
        let objects = selectedObjects
        guard !objects.isEmpty, let bounds = selectionBounds,
              let data = try? JSONEncoder().encode(EmbeddedObjectPayloadV6(objects: objects)) else {
            status = "Select artwork to create a symbol"
            return
        }
        snapshot()
        let definition = SymbolDefinitionV6(name: objects.count == 1 ? objects[0].name : "Symbol", originalBounds: bounds, payloadData: data)
        var library = document.resourceLibrary ?? ResourceLibraryV6()
        library.symbols.append(definition)
        document.resourceLibrary = library

        let doomed = Set(objects.map(\.id))
        document.objects.removeAll { doomed.contains($0.id) }
        let instance = makeSymbolInstance(definition, at: CGPoint(x: bounds.minX, y: bounds.minY), size: bounds.size)
        document.objects.append(instance)
        selection = [instance.id]
        commitMutation(status: "Symbol created")
    }

    func placeSymbol(_ definitionID: UUID) {
        guard let definition = document.resourceLibrary?.symbols.first(where: { $0.id == definitionID }) else { return }
        snapshot()
        let size = definition.originalBounds.size
        let origin = CGPoint(x: document.artboardWidth / 2 - size.width / 2, y: document.artboardHeight / 2 - size.height / 2)
        let instance = makeSymbolInstance(definition, at: origin, size: size)
        document.objects.append(instance)
        selection = [instance.id]
        commitMutation(status: "Symbol instance placed")
    }

    func replaceSymbolDefinitionFromSelection() {
        let instances = selectedObjects.filter { $0.symbolDefinitionID != nil }
        let replacements = selectedObjects.filter { $0.symbolDefinitionID == nil }
        guard instances.count == 1, let definitionID = instances[0].symbolDefinitionID, !replacements.isEmpty else {
            status = "Select one symbol instance plus replacement artwork"
            return
        }
        let bounds = replacements.dropFirst().reduce(replacements[0].bounds) { $0.union($1.bounds) }
        guard let data = try? JSONEncoder().encode(EmbeddedObjectPayloadV6(objects: replacements)),
              var library = document.resourceLibrary,
              let index = library.symbols.firstIndex(where: { $0.id == definitionID }) else { return }
        snapshot()
        library.symbols[index].payloadData = data
        library.symbols[index].originalBounds = bounds
        document.resourceLibrary = library
        let replacementIDs = Set(replacements.map(\.id))
        document.objects.removeAll { replacementIDs.contains($0.id) }
        selection = [instances[0].id]
        commitMutation(status: "Symbol definition updated")
    }

    func detachSelectedSymbolInstances() {
        let instances = selectedObjects.filter { $0.symbolDefinitionID != nil }
        guard !instances.isEmpty else { status = "Select a symbol instance"; return }
        snapshot()
        var detached: [VectorObject] = []
        let instanceIDs = Set(instances.map(\.id))
        for instance in instances {
            guard let definitionID = instance.symbolDefinitionID,
                  let (definition, payload) = SymbolRuntime.payload(definitionID: definitionID, document: document) else { continue }
            for var child in payload.objects {
                child.id = UUID()
                child.layerNodeID = nil
                child = transformedPreservedChild(child, from: definition.originalBounds, into: instance)
                detached.append(child)
            }
        }
        guard !detached.isEmpty else { status = "Symbol definition unavailable"; return }
        document.objects.removeAll { instanceIDs.contains($0.id) }
        document.objects.append(contentsOf: detached)
        selection = Set(detached.map(\.id))
        commitMutation(status: "Symbol instance detached")
    }

    func removeSymbolDefinition(_ id: UUID) {
        guard var library = document.resourceLibrary else { return }
        let inUse = document.objects.contains { $0.symbolDefinitionID == id }
        guard !inUse else { status = "Detach symbol instances before deleting the definition"; return }
        snapshot()
        library.symbols.removeAll { $0.id == id }
        document.resourceLibrary = library
        commitMutation(status: "Symbol definition removed")
    }

    func symbolDefinitionForSprayer() -> SymbolDefinitionV6? {
        if let id = primarySelectedObject?.symbolDefinitionID,
           let definition = document.resourceLibrary?.symbols.first(where: { $0.id == id }) { return definition }
        return document.resourceLibrary?.symbols.first
    }

    func spraySymbolDefinition(_ definition: SymbolDefinitionV6, around point: CGPoint, count: Int = 8) {
        snapshot()
        var copies: [VectorObject] = []
        let baseSize = definition.originalBounds.size
        for i in 0..<count {
            let angle = Double(i) * 2 * Double.pi / Double(count)
            let radius = 24 + Double((i * 17) % 45)
            let scale = 0.55 + Double((i * 29) % 45) / 100
            var instance = makeSymbolInstance(definition, at: CGPoint(x: point.x + cos(angle) * radius - baseSize.width / 2, y: point.y + sin(angle) * radius - baseSize.height / 2), size: baseSize)
            instance.rotation = Double((i * 37) % 70) - 35
            instance.scaleX = scale; instance.scaleY = scale
            copies.append(instance)
        }
        document.objects.append(contentsOf: copies)
        selection = Set(copies.map(\.id))
        commitMutation(status: "Sprayed \(count) symbol instances")
    }

    private func makeSymbolInstance(_ definition: SymbolDefinitionV6, at origin: CGPoint, size: CGSize) -> VectorObject {
        var instance = VectorObject(name: definition.name + " Instance", kind: .image, x: origin.x, y: origin.y, width: max(1, size.width), height: max(1, size.height), fill: .clear, stroke: .clear, strokeWidth: 0)
        instance.symbolDefinitionID = definition.id
        return instance
    }
}
