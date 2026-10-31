import SwiftUI
import OpenstratorCore

@MainActor
extension EditorStore {
    func makeClippingGroup() {
        let indices = selectedIndices.sorted()
        guard indices.count >= 2, let clipIndex = indices.last else {
            status = "Select a clipping path above at least one object"
            return
        }
        ensureM6LayerTree()
        snapshot()
        let groupID = UUID()
        let clipID = document.objects[clipIndex].id
        for index in indices {
            document.objects[index].clippingGroupID = groupID
            document.objects[index].clippingRole = index == clipIndex ? .clippingPath : .content
            document.objects[index].groupID = groupID
        }

        if var tree = document.layerTree {
            let selectedNodes = indices.compactMap { document.objects[$0].layerNodeID }
            let first = selectedNodes.first
            let commonParent = first.flatMap { tree.nodes[$0]?.parentID }
            let parent = commonParent ?? tree.roots.compactMap { tree.nodes[$0] }.first(where: { $0.kind == .artboard })?.id
            if let parent {
                let siblings = tree.nodes[parent]?.children ?? []
                let insertion = selectedNodes.compactMap { siblings.firstIndex(of: $0) }.min() ?? siblings.count
                let group = LayerNodeV6(id: groupID, name: "Clipping Group", kind: .clippingGroup, clippingObjectID: clipID)
                try? tree.insert(group, parent: parent, index: insertion)
                let ordered = selectedNodes.sorted { (siblings.firstIndex(of: $0) ?? Int.max) < (siblings.firstIndex(of: $1) ?? Int.max) }
                for (offset, nodeID) in ordered.enumerated() { try? tree.move(nodeID, toParent: group.id, index: offset) }
            }
            document.layerTree = tree
        }
        syncDocumentObjectOrderFromLayerTree()
        commitMutation(status: "Clipping group created")
    }

    func releaseClippingGroup() {
        let groupIDs = Set(selectedObjects.compactMap(\.clippingGroupID))
        guard !groupIDs.isEmpty else { status = "Select artwork in a clipping group"; return }
        snapshot()
        for index in document.objects.indices where groupIDs.contains(document.objects[index].clippingGroupID) {
            document.objects[index].clippingGroupID = nil
            document.objects[index].clippingRole = nil
            if let legacyGroupID = document.objects[index].groupID, groupIDs.contains(legacyGroupID) { document.objects[index].groupID = nil }
        }
        if var tree = document.layerTree {
            let containers = tree.nodes.values.filter { $0.kind == .clippingGroup && groupIDs.contains($0.id) }
            for group in containers {
                guard let parent = group.parentID else { continue }
                let insertion = tree.nodes[parent]?.children.firstIndex(of: group.id) ?? 0
                for (offset, child) in group.children.enumerated() { try? tree.move(child, toParent: parent, index: insertion + offset) }
                _ = try? tree.removeSubtree(group.id)
            }
            document.layerTree = tree
        }
        commitMutation(status: "Clipping group released")
    }

    func makeOpacityMask() {
        let indices = selectedIndices.sorted()
        guard indices.count == 2 else { status = "Select exactly two objects: artwork then mask on top"; return }
        let targetIndex = indices[0]
        let maskIndex = indices[1]
        snapshot()
        let maskID = document.objects[maskIndex].id
        document.objects[targetIndex].opacityMaskObjectID = maskID
        document.objects[targetIndex].opacityMaskInverted = false
        // The mask remains an editable layer but is not painted as ordinary artwork while attached.
        document.objects[maskIndex].isVisible = false
        if var tree = document.layerTree, let targetNodeID = document.objects[targetIndex].layerNodeID, var targetNode = tree.nodes[targetNodeID] {
            targetNode.opacityMaskObjectID = maskID
            tree.nodes[targetNodeID] = targetNode
            if let maskNodeID = document.objects[maskIndex].layerNodeID, var maskNode = tree.nodes[maskNodeID] {
                maskNode.isVisible = false
                tree.nodes[maskNodeID] = maskNode
            }
            document.layerTree = tree
        }
        selection = [document.objects[targetIndex].id]
        commitMutation(status: "Opacity mask created")
    }

    func releaseOpacityMask() {
        let targetIDs = Set(selectedObjects.filter { $0.opacityMaskObjectID != nil }.map(\.id))
        guard !targetIDs.isEmpty else { status = "Select masked artwork"; return }
        snapshot()
        var releasedMaskIDs = Set<UUID>()
        for index in document.objects.indices where targetIDs.contains(document.objects[index].id) {
            if let maskID = document.objects[index].opacityMaskObjectID { releasedMaskIDs.insert(maskID) }
            document.objects[index].opacityMaskObjectID = nil
            document.objects[index].opacityMaskInverted = nil
        }
        for index in document.objects.indices where releasedMaskIDs.contains(document.objects[index].id) {
            document.objects[index].isVisible = true
        }
        if var tree = document.layerTree {
            for id in tree.nodes.keys {
                guard var node = tree.nodes[id] else { continue }
                if targetIDs.contains(node.objectID ?? UUID()) { node.opacityMaskObjectID = nil }
                if releasedMaskIDs.contains(node.objectID ?? UUID()) { node.isVisible = true }
                tree.nodes[id] = node
            }
            document.layerTree = tree
        }
        commitMutation(status: "Opacity mask released")
    }

    func toggleOpacityMaskInversion() {
        let indices = selectedIndices.filter { document.objects[$0].opacityMaskObjectID != nil }
        guard !indices.isEmpty else { status = "Select masked artwork"; return }
        snapshot()
        for index in indices { document.objects[index].opacityMaskInverted = !(document.objects[index].opacityMaskInverted ?? false) }
        commitMutation(status: "Opacity mask inversion changed")
    }
}

enum CompositedDocumentRenderer {
    static func draw(document: OpenDocument, context: inout GraphicsContext) {
        let maskSourceIDs = Set(document.objects.compactMap(\.opacityMaskObjectID))
        var renderedClipGroups = Set<UUID>()

        for object in document.objects {
            guard object.isVisible || maskSourceIDs.contains(object.id) else { continue }
            if maskSourceIDs.contains(object.id) { continue }

            if let groupID = object.clippingGroupID {
                guard renderedClipGroups.insert(groupID).inserted else { continue }
                let members = document.objects.filter { $0.clippingGroupID == groupID }
                guard let clip = members.last(where: { $0.clippingRole == .clippingPath }),
                      let clipPath = VectorCanvasRenderer.clippingPath(for: clip) else {
                    for member in members where member.clippingRole != .clippingPath && member.isVisible {
                        drawWithOpacityMask(member, document: document, context: &context)
                    }
                    continue
                }
                context.drawLayer { layer in
                    layer.clip(to: clipPath)
                    for member in members where member.clippingRole == .content && member.isVisible {
                        drawWithOpacityMask(member, document: document, context: &layer)
                    }
                }
                continue
            }

            drawWithOpacityMask(object, document: document, context: &context)
        }
    }

    private static func drawWithOpacityMask(_ object: VectorObject, document: OpenDocument, context: inout GraphicsContext) {
        guard let maskID = object.opacityMaskObjectID,
              let mask = document.objects.first(where: { $0.id == maskID }) else {
            VectorCanvasRenderer.draw(object, document: document, context: &context)
            return
        }
        context.drawLayer { layer in
            VectorCanvasRenderer.draw(object, document: document, context: &layer)
            layer.drawLayer { maskLayer in
                maskLayer.blendMode = object.opacityMaskInverted == true ? .destinationOut : .destinationIn
                var visibleMask = mask
                visibleMask.isVisible = true
                visibleMask.opacity = max(0, min(1, mask.opacity))
                VectorCanvasRenderer.draw(visibleMask, document: document, context: &maskLayer)
            }
        }
    }
}
