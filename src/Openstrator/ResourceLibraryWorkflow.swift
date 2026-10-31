import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OpenstratorCore

@MainActor
extension EditorStore {
    func saveGraphicStyleFromSelection() {
        guard let object = primarySelectedObject else { status = "Select artwork to save a Graphic Style"; return }
        snapshot()
        var library = document.resourceLibrary ?? ResourceLibraryV6()
        let style = GraphicStyleV6(name: "Graphic Style \(library.graphicStyles.count + 1)", appearance: object.resolvedAppearanceStack)
        library.graphicStyles.append(style)
        document.resourceLibrary = library
        commitMutation(status: "Graphic Style saved")
    }

    func applyGraphicStyle(_ id: UUID) {
        guard let style = document.resourceLibrary?.graphicStyles.first(where: { $0.id == id }), !selection.isEmpty else { return }
        snapshot()
        for index in selectedIndices {
            document.objects[index].applyAppearanceStack(style.appearance)
            document.objects[index].graphicStyleID = style.id
        }
        commitMutation(status: "Graphic Style applied")
    }

    func removeGraphicStyle(_ id: UUID) {
        guard var library = document.resourceLibrary else { return }
        snapshot()
        library.graphicStyles.removeAll { $0.id == id }
        document.resourceLibrary = library
        for index in document.objects.indices where document.objects[index].graphicStyleID == id { document.objects[index].graphicStyleID = nil }
        commitMutation(status: "Graphic Style removed")
    }

    func selectObjectsUsingEmbeddedResource(_ id: UUID) {
        selection = Set(document.objects.filter { $0.embeddedObjectID == id }.map(\.id))
        revealSelectionInLayers()
    }

    func removeEmbeddedResource(_ id: UUID) {
        guard !document.objects.contains(where: { $0.embeddedObjectID == id }),
              !(document.resourceLibrary?.embeddedObjects.contains(where: { $0.nestedEmbeddedResourceIDs.contains(id) }) ?? false),
              var library = document.resourceLibrary else {
            status = "Embedded Object resource is still in use"
            return
        }
        snapshot()
        library.embeddedObjects.removeAll { $0.id == id }
        document.resourceLibrary = library
        commitMutation(status: "Embedded Object resource removed")
    }

    func selectObjectsUsingLinkedAsset(_ id: UUID) {
        selection = Set(document.objects.filter { $0.linkedAssetID == id }.map(\.id))
        revealSelectionInLayers()
    }

    func selectObjectsUsingSymbol(_ id: UUID) {
        selection = Set(document.objects.filter { $0.symbolDefinitionID == id }.map(\.id))
        revealSelectionInLayers()
    }

    func exportResourceLibrary() {
        guard let library = document.resourceLibrary else { status = "Resource library is empty"; return }
        let panel = NSSavePanel()
        panel.title = "Export Openstrator Resource Library"
        panel.nameFieldStringValue = "Openstrator Resources.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(library).write(to: url, options: .atomic)
            status = "Resource library exported"
        } catch { status = "Resource export failed: \(error.localizedDescription)" }
    }

    func importResourceLibrary() {
        let panel = NSOpenPanel()
        panel.title = "Import Openstrator Resource Library"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let incoming = try JSONDecoder().decode(ResourceLibraryV6.self, from: Data(contentsOf: url))
            guard incoming.hasUniqueResourceIDs else { status = "Resource library has duplicate IDs"; return }
            snapshot()
            mergeResourceLibrary(incoming)
            commitMutation(status: "Resource library imported")
        } catch { status = "Resource import failed: \(error.localizedDescription)" }
    }
}

@MainActor
struct ResourceLibraryPanel: View {
    @EnvironmentObject var store: EditorStore

    private var library: ResourceLibraryV6 { store.document.resourceLibrary ?? ResourceLibraryV6() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Resources", systemImage: "books.vertical")
                    .font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Button { store.importResourceLibrary() } label: { Image(systemName: "square.and.arrow.down") }.buttonStyle(.plain).help("Import resource library")
                Button { store.exportResourceLibrary() } label: { Image(systemName: "square.and.arrow.up") }.buttonStyle(.plain).help("Export resource library")
            }

            resourceHeader("Embedded Objects", count: library.embeddedObjects.count)
            ForEach(library.embeddedObjects) { resource in
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox").foregroundStyle(.secondary)
                    Text(resource.name).lineLimit(1)
                    Spacer()
                    Button { store.selectObjectsUsingEmbeddedResource(resource.id) } label: { Image(systemName: "scope") }.buttonStyle(.plain)
                    Button(role: .destructive) { store.removeEmbeddedResource(resource.id) } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                }.font(.caption)
            }

            resourceHeader("Links", count: library.linkedAssets.count)
            ForEach(library.linkedAssets) { link in
                let state = store.linkedAssetState(link.id)
                HStack(spacing: 6) {
                    Image(systemName: state.symbol).foregroundStyle(state == .missing ? Color.red : Color(nsColor: .secondaryLabelColor))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(link.displayName).lineLimit(1)
                        Text(state.title).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { store.refreshLinkedAsset(link.id) } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).disabled(state == .missing)
                    Button { store.relinkLinkedAsset(link.id) } label: { Image(systemName: "link.badge.plus") }.buttonStyle(.plain)
                    Button { store.embedLinkedAsset(link.id) } label: { Image(systemName: "square.and.arrow.down") }.buttonStyle(.plain)
                }.font(.caption)
                .contentShape(Rectangle())
                .onTapGesture { store.selectObjectsUsingLinkedAsset(link.id) }
            }

            resourceHeader("Symbols", count: library.symbols.count)
            ForEach(library.symbols) { symbol in
                HStack(spacing: 6) {
                    Image(systemName: "seal").foregroundStyle(.secondary)
                    Text(symbol.name).lineLimit(1)
                    Spacer()
                    Button { store.placeSymbol(symbol.id) } label: { Image(systemName: "plus") }.buttonStyle(.plain).help("Place instance")
                    Button { store.selectObjectsUsingSymbol(symbol.id) } label: { Image(systemName: "scope") }.buttonStyle(.plain)
                    Button(role: .destructive) { store.removeSymbolDefinition(symbol.id) } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                }.font(.caption)
            }

            HStack {
                resourceHeader("Graphic Styles", count: library.graphicStyles.count)
                Spacer()
                Button { store.saveGraphicStyleFromSelection() } label: { Image(systemName: "plus") }.buttonStyle(.plain).help("Save style from selection")
            }
            ForEach(library.graphicStyles) { style in
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette").foregroundStyle(.secondary)
                    Text(style.name).lineLimit(1)
                    Spacer()
                    Button("Apply") { store.applyGraphicStyle(style.id) }.buttonStyle(.borderless).disabled(store.selection.isEmpty)
                    Button(role: .destructive) { store.removeGraphicStyle(style.id) } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                }.font(.caption)
            }
        }
    }

    private func resourceHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 5) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text("\(count)").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
        }
    }
}
