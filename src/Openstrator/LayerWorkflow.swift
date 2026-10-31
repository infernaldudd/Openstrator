import SwiftUI
import AppKit
import OpenstratorCore

struct LayerRowEntry: Identifiable {
    let node: LayerNodeV6
    let depth: Int
    var id: UUID { node.id }
}

@MainActor
extension EditorStore {
    var layerRows: [LayerRowEntry] {
        guard let tree = document.layerTree else { return [] }
        var rows: [LayerRowEntry] = []
        var visited = Set<UUID>()
        func append(_ id: UUID, depth: Int) {
            guard visited.insert(id).inserted, let node = tree.nodes[id] else { return }
            rows.append(.init(node: node, depth: depth))
            guard node.isExpanded else { return }
            // Last object is top-most in the canvas, so present siblings top-first in the panel.
            for child in node.children.reversed() { append(child, depth: depth + 1) }
        }
        for root in tree.roots.reversed() { append(root, depth: 0) }
        return rows
    }

    func ensureM6LayerTree() {
        if document.layerTree == nil {
            bootstrapM6LayerTree()
        } else {
            reconcileM6LayerTree()
        }
        if document.resourceLibrary == nil { document.resourceLibrary = ResourceLibraryV6() }
    }

    func reconcileM6LayerTree() {
        guard var tree = document.layerTree else { bootstrapM6LayerTree(); return }
        let objectIDs = Set(document.objects.map(\.id))

        // Drop object nodes whose shell object was deleted. Container nodes are preserved.
        for (id, node) in tree.nodes where node.objectID != nil && !objectIDs.contains(node.objectID!) {
            _ = try? tree.removeSubtree(id)
        }

        let artboardID: UUID
        if let existing = tree.roots.compactMap({ tree.nodes[$0] }).first(where: { $0.kind == .artboard })?.id {
            artboardID = existing
        } else {
            let artboard = LayerNodeV6(name: "Artboard 1", kind: .artboard, accent: RGBAColorV6(r: 0.15, g: 0.49, b: 0.98))
            try? tree.insert(artboard, parent: nil, index: tree.roots.count)
            artboardID = artboard.id
        }

        // Ensure every shell object has exactly one object node.
        for index in document.objects.indices {
            var object = document.objects[index]
            var nodeID = object.layerNodeID
            if nodeID == nil || tree.nodes[nodeID!] == nil {
                if let existing = tree.nodes.values.first(where: { $0.objectID == object.id }) {
                    nodeID = existing.id
                } else {
                    let kind: LayerNodeKindV6 = object.embeddedObjectID != nil ? .embeddedObject : (object.symbolDefinitionID != nil ? .symbolInstance : .object)
                    let node = LayerNodeV6(name: object.name, kind: kind, objectID: object.id, isVisible: object.isVisible, isLocked: object.isLocked)
                    try? tree.insert(node, parent: artboardID, index: tree.nodes[artboardID]?.children.count ?? 0)
                    nodeID = node.id
                }
                object.layerNodeID = nodeID
                document.objects[index] = object
            }
            guard let nodeID, var node = tree.nodes[nodeID] else { continue }
            node.name = object.name
            node.objectID = object.id
            node.isVisible = object.isVisible
            node.isLocked = object.isLocked
            if object.embeddedObjectID != nil { node.kind = .embeddedObject; node.resourceID = object.embeddedObjectID }
            else if object.symbolDefinitionID != nil { node.kind = .symbolInstance; node.resourceID = object.symbolDefinitionID }
            else if node.kind == .embeddedObject || node.kind == .symbolInstance { node.kind = .object; node.resourceID = nil }
            node.clippingObjectID = object.clippingRole == .clippingPath ? object.id : node.clippingObjectID
            node.opacityMaskObjectID = object.opacityMaskObjectID
            tree.nodes[nodeID] = node
        }

        // Remove empty grouping containers, but never artboards/layers.
        let emptyContainers = tree.nodes.values.filter {
            ($0.kind == .group || $0.kind == .clippingGroup) && $0.children.isEmpty && $0.objectID == nil
        }.map(\.id)
        for id in emptyContainers { _ = try? tree.removeSubtree(id) }

        // A malformed optional M6 tree must never make a document unusable.
        if (try? tree.validate()) != true {
            document.layerTree = nil
            bootstrapM6LayerTree()
            return
        }
        document.layerTree = tree
    }

    private func bootstrapM6LayerTree() {
        var tree = LayerTreeV6()
        let artboard = LayerNodeV6(name: "Artboard 1", kind: .artboard, accent: RGBAColorV6(r: 0.15, g: 0.49, b: 0.98))
        try? tree.insert(artboard, parent: nil, index: 0)
        var legacyGroups: [UUID: UUID] = [:]

        for index in document.objects.indices {
            var object = document.objects[index]
            let parentID: UUID
            if let legacy = object.groupID {
                if let existing = legacyGroups[legacy] {
                    parentID = existing
                } else {
                    let group = LayerNodeV6(id: legacy, name: "Group", kind: .group)
                    try? tree.insert(group, parent: artboard.id, index: tree.nodes[artboard.id]?.children.count ?? 0)
                    legacyGroups[legacy] = group.id
                    parentID = group.id
                }
            } else {
                parentID = artboard.id
            }
            let kind: LayerNodeKindV6 = object.embeddedObjectID != nil ? .embeddedObject : (object.symbolDefinitionID != nil ? .symbolInstance : .object)
            let node = LayerNodeV6(name: object.name, kind: kind, objectID: object.id, isVisible: object.isVisible, isLocked: object.isLocked, resourceID: object.embeddedObjectID ?? object.symbolDefinitionID)
            try? tree.insert(node, parent: parentID, index: tree.nodes[parentID]?.children.count ?? 0)
            object.layerNodeID = node.id
            document.objects[index] = object
        }
        document.layerTree = tree
        if document.resourceLibrary == nil { document.resourceLibrary = ResourceLibraryV6() }
    }

    func selectLayerNode(_ id: UUID, additive: Bool = false) {
        guard let tree = document.layerTree, let node = tree.nodes[id] else { return }
        let objectIDs: Set<UUID>
        if let objectID = node.objectID {
            objectIDs = [objectID]
        } else {
            objectIDs = Set(([id] + tree.descendants(of: id)).compactMap { tree.nodes[$0]?.objectID })
        }
        if additive { selection.formSymmetricDifference(objectIDs) }
        else { selection = objectIDs }
    }

    func revealSelectionInLayers() {
        guard var tree = document.layerTree else { return }
        for object in document.objects where selection.contains(object.id) {
            guard let nodeID = object.layerNodeID else { continue }
            for ancestor in tree.ancestors(of: nodeID) {
                guard var node = tree.nodes[ancestor] else { continue }
                node.isExpanded = true
                tree.nodes[ancestor] = node
            }
        }
        document.layerTree = tree
        status = selection.isEmpty ? "Select artwork to locate" : "Located selection in Layers"
    }

    func toggleLayerExpansion(_ id: UUID) {
        guard var tree = document.layerTree, var node = tree.nodes[id], !node.children.isEmpty else { return }
        node.isExpanded.toggle(); tree.nodes[id] = node; document.layerTree = tree
    }

    func renameLayerNode(_ id: UUID, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, var tree = document.layerTree, var node = tree.nodes[id] else { return }
        snapshot()
        node.name = clean; tree.nodes[id] = node
        if let objectID = node.objectID, let index = document.objects.firstIndex(where: { $0.id == objectID }) {
            document.objects[index].name = clean
        }
        document.layerTree = tree
        commitMutation(status: "Layer renamed")
    }

    func toggleLayerVisibility(_ id: UUID) {
        guard var tree = document.layerTree, var node = tree.nodes[id] else { return }
        snapshot()
        let value = !node.isVisible
        let ids = [id] + tree.descendants(of: id)
        for nodeID in ids {
            guard var child = tree.nodes[nodeID] else { continue }
            child.isVisible = value; tree.nodes[nodeID] = child
            if let objectID = child.objectID, let index = document.objects.firstIndex(where: { $0.id == objectID }) {
                document.objects[index].isVisible = value
            }
        }
        document.layerTree = tree
        commitMutation(status: value ? "Layer shown" : "Layer hidden")
    }

    func toggleLayerLock(_ id: UUID) {
        guard var tree = document.layerTree, let node = tree.nodes[id] else { return }
        snapshot()
        let value = !node.isLocked
        let ids = [id] + tree.descendants(of: id)
        for nodeID in ids {
            guard var child = tree.nodes[nodeID] else { continue }
            child.isLocked = value; tree.nodes[nodeID] = child
            if let objectID = child.objectID, let index = document.objects.firstIndex(where: { $0.id == objectID }) {
                document.objects[index].isLocked = value
            }
        }
        document.layerTree = tree
        commitMutation(status: value ? "Layer locked" : "Layer unlocked")
    }

    func cycleLayerAccent(_ id: UUID) {
        guard var tree = document.layerTree, var node = tree.nodes[id] else { return }
        let palette = [
            RGBAColorV6(r: 0.15, g: 0.49, b: 0.98),
            RGBAColorV6(r: 0.94, g: 0.33, b: 0.32),
            RGBAColorV6(r: 0.22, g: 0.72, b: 0.45),
            RGBAColorV6(r: 0.67, g: 0.39, b: 0.96),
            RGBAColorV6(r: 0.96, g: 0.64, b: 0.18),
        ]
        let current = node.accent
        let nextIndex = current.flatMap { value in palette.firstIndex(of: value).map { ($0 + 1) % palette.count } } ?? 0
        node.accent = palette[nextIndex]
        tree.nodes[id] = node
        document.layerTree = tree
        commitMutation(status: "Layer color changed")
    }

    func groupSelectionM6() {
        guard selection.count > 1 else { status = "Select at least two objects to group"; return }
        ensureM6LayerTree()
        guard var tree = document.layerTree else { return }
        let selectedNodes = document.objects.compactMap { selection.contains($0.id) ? $0.layerNodeID : nil }
        guard selectedNodes.count > 1 else { return }
        snapshot()

        let artboardID = tree.roots.compactMap { tree.nodes[$0] }.first(where: { $0.kind == .artboard })?.id
        let commonParent = tree.nodes[selectedNodes[0]]?.parentID
        let parent = selectedNodes.allSatisfy { tree.nodes[$0]?.parentID == commonParent } ? commonParent : artboardID
        guard let parent else { return }
        let siblingOrder = tree.nodes[parent]?.children ?? []
        let firstIndex = selectedNodes.compactMap { siblingOrder.firstIndex(of: $0) }.min() ?? siblingOrder.count
        let group = LayerNodeV6(name: "Group", kind: .group)
        try? tree.insert(group, parent: parent, index: firstIndex)
        let ordered = selectedNodes.sorted { (siblingOrder.firstIndex(of: $0) ?? Int.max) < (siblingOrder.firstIndex(of: $1) ?? Int.max) }
        for (offset, nodeID) in ordered.enumerated() { try? tree.move(nodeID, toParent: group.id, index: offset) }
        for index in selectedIndices where document.objects[index].groupID == nil { document.objects[index].groupID = group.id }
        document.layerTree = tree
        syncDocumentObjectOrderFromLayerTree()
        commitMutation(status: "Grouped")
    }

    func ungroupSelectionM6() {
        ensureM6LayerTree()
        guard var tree = document.layerTree else { return }
        let selectedNodeIDs = Set(document.objects.compactMap { selection.contains($0.id) ? $0.layerNodeID : nil })
        let groupIDs = Set(selectedNodeIDs.compactMap { tree.nodes[$0]?.parentID }.filter { tree.nodes[$0]?.kind == .group })
        guard !groupIDs.isEmpty else { return }
        snapshot()
        for groupID in groupIDs {
            guard let group = tree.nodes[groupID], let parent = group.parentID else { continue }
            let parentIndex = tree.nodes[parent]?.children.firstIndex(of: groupID) ?? 0
            let children = group.children
            for (offset, childID) in children.enumerated() { try? tree.move(childID, toParent: parent, index: parentIndex + offset) }
            _ = try? tree.removeSubtree(groupID)
        }
        for index in selectedIndices { document.objects[index].groupID = nil }
        document.layerTree = tree
        syncDocumentObjectOrderFromLayerTree()
        commitMutation(status: "Ungrouped")
    }

    func moveLayerNode(_ id: UUID, direction: Int) {
        guard var tree = document.layerTree, let node = tree.nodes[id] else { return }
        let siblings = node.parentID.flatMap { tree.nodes[$0]?.children } ?? tree.roots
        guard let index = siblings.firstIndex(of: id) else { return }
        let target = index + direction
        guard siblings.indices.contains(target) else { return }
        snapshot()
        try? tree.move(id, toParent: node.parentID, index: target)
        document.layerTree = tree
        syncDocumentObjectOrderFromLayerTree()
        commitMutation(status: "Layer order changed")
    }

    @discardableResult
    func dropLayerNodeStrings(_ values: [String], on targetID: UUID) -> Bool {
        guard let raw = values.first, let movingID = UUID(uuidString: raw), movingID != targetID,
              var tree = document.layerTree, let target = tree.nodes[targetID], tree.nodes[movingID] != nil else { return false }
        snapshot()
        do {
            if target.acceptsChildren {
                try tree.move(movingID, toParent: targetID, index: target.children.count)
            } else {
                let parent = target.parentID
                let siblings = parent.flatMap { tree.nodes[$0]?.children } ?? tree.roots
                let index = siblings.firstIndex(of: targetID) ?? siblings.count
                try tree.move(movingID, toParent: parent, index: index)
            }
            document.layerTree = tree
            syncDocumentObjectOrderFromLayerTree()
            commitMutation(status: "Layer moved")
            return true
        } catch {
            // Undo snapshot was only needed for a successful tree mutation.
            undo()
            status = "Layer move rejected"
            return false
        }
    }

    func syncDocumentObjectOrderFromLayerTree() {
        guard let tree = document.layerTree else { return }
        let byID = Dictionary(uniqueKeysWithValues: document.objects.map { ($0.id, $0) })
        var ordered = tree.objectOrder().compactMap { byID[$0] }
        let included = Set(ordered.map(\.id))
        ordered.append(contentsOf: document.objects.filter { !included.contains($0.id) })
        document.objects = ordered
    }
}

@MainActor
struct LayerTreeRowView: View {
    @EnvironmentObject var store: EditorStore
    let entry: LayerRowEntry
    @State private var draftName: String

    init(entry: LayerRowEntry) {
        self.entry = entry
        _draftName = State(initialValue: entry.node.name)
    }

    var body: some View {
        let node = entry.node
        HStack(spacing: 6) {
            Color.clear.frame(width: CGFloat(entry.depth) * 12, height: 1)

            if !node.children.isEmpty {
                Button { store.toggleLayerExpansion(node.id) } label: {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 11)
                }.buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 11, height: 11)
            }

            Button { store.toggleLayerVisibility(node.id) } label: {
                Image(systemName: node.isVisible ? "eye" : "eye.slash").frame(width: 15)
            }.buttonStyle(.plain)

            Button { store.toggleLayerLock(node.id) } label: {
                Image(systemName: node.isLocked ? "lock.fill" : "lock.open").frame(width: 15)
            }.buttonStyle(.plain)

            Button { store.cycleLayerAccent(node.id) } label: {
                Circle().fill(accentColor(node.accent)).frame(width: 8, height: 8)
            }
            .buttonStyle(.plain)
            .help("Cycle layer color")

            LayerThumbnailView(node: node)
                .environmentObject(store)

            TextField("Layer name", text: $draftName)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .onSubmit { store.renameLayerNode(node.id, to: draftName) }
                .onChange(of: node.name) { value in draftName = value }

            Spacer(minLength: 4)

            VStack(spacing: 0) {
                Button { store.moveLayerNode(node.id, direction: 1) } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(.plain)
                Button { store.moveLayerNode(node.id, direction: -1) } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.plain)
            }
            .font(.system(size: 8, weight: .bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(selectionBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { store.selectLayerNode(node.id, additive: NSEvent.modifierFlags.contains(.shift)) }
        .draggable(node.id.uuidString)
        .dropDestination(for: String.self) { values, _ in store.dropLayerNodeStrings(values, on: node.id) }
        .contextMenu {
            Button(node.isVisible ? "Hide" : "Show") { store.toggleLayerVisibility(node.id) }
            Button(node.isLocked ? "Unlock" : "Lock") { store.toggleLayerLock(node.id) }
            if node.kind == .group { Button("Ungroup Selected Contents") { store.ungroupSelection() } }
        }
    }

    private var selectionBackground: Color {
        let objectIDs: Set<UUID>
        if let id = entry.node.objectID { objectIDs = [id] }
        else if let tree = store.document.layerTree {
            objectIDs = Set(([entry.node.id] + tree.descendants(of: entry.node.id)).compactMap { tree.nodes[$0]?.objectID })
        } else { objectIDs = [] }
        return !objectIDs.isEmpty && objectIDs.isSubset(of: store.selection) ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.025)
    }

    private func accentColor(_ value: RGBAColorV6?) -> Color {
        let value = value ?? RGBAColorV6(r: 0.15, g: 0.49, b: 0.98)
        return Color(red: value.r, green: value.g, blue: value.b, opacity: value.a)
    }

    private func symbol(_ kind: LayerNodeKindV6) -> String {
        switch kind {
        case .artboard: return "rectangle.on.rectangle"
        case .layer: return "square.3.layers.3d"
        case .group: return "folder"
        case .object: return "square"
        case .clippingGroup: return "crop"
        case .embeddedObject: return "shippingbox"
        case .symbolInstance: return "seal"
        }
    }
}
