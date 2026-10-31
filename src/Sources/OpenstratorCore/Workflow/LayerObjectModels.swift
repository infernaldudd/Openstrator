import Foundation

public enum LayerNodeKindV6: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case artboard
    case layer
    case group
    case object
    case clippingGroup
    case embeddedObject
    case symbolInstance
}

public struct LayerNodeV6: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: LayerNodeKindV6
    public var parentID: UUID?
    public var children: [UUID]
    public var objectID: UUID?
    public var isVisible: Bool
    public var isLocked: Bool
    public var isExpanded: Bool
    public var accent: RGBAColorV6?
    public var clippingObjectID: UUID?
    public var opacityMaskObjectID: UUID?
    public var resourceID: UUID?

    public init(
        id: UUID = UUID(),
        name: String,
        kind: LayerNodeKindV6,
        parentID: UUID? = nil,
        children: [UUID] = [],
        objectID: UUID? = nil,
        isVisible: Bool = true,
        isLocked: Bool = false,
        isExpanded: Bool = true,
        accent: RGBAColorV6? = nil,
        clippingObjectID: UUID? = nil,
        opacityMaskObjectID: UUID? = nil,
        resourceID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.parentID = parentID
        self.children = children
        self.objectID = objectID
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.isExpanded = isExpanded
        self.accent = accent
        self.clippingObjectID = clippingObjectID
        self.opacityMaskObjectID = opacityMaskObjectID
        self.resourceID = resourceID
    }

    public var acceptsChildren: Bool {
        switch kind {
        case .artboard, .layer, .group, .clippingGroup, .embeddedObject:
            return true
        case .object, .symbolInstance:
            return false
        }
    }
}

public enum LayerTreeErrorV6: Error, Equatable, Sendable {
    case duplicateID
    case missingNode
    case missingParent
    case parentRejectsChildren
    case cycle
    case danglingChild
    case inconsistentParent
    case duplicateObjectReference
}

public struct LayerTreeV6: Codable, Equatable, Sendable {
    public var roots: [UUID]
    public var nodes: [UUID: LayerNodeV6]

    public init(roots: [UUID] = [], nodes: [UUID: LayerNodeV6] = [:]) {
        self.roots = roots
        self.nodes = nodes
    }

    public func node(_ id: UUID) -> LayerNodeV6? { nodes[id] }

    public func descendants(of id: UUID) -> [UUID] {
        guard let node = nodes[id] else { return [] }
        var result: [UUID] = []
        var stack = Array(node.children.reversed())
        var visited = Set<UUID>()
        while let next = stack.popLast() {
            guard visited.insert(next).inserted, let child = nodes[next] else { continue }
            result.append(next)
            stack.append(contentsOf: child.children.reversed())
        }
        return result
    }

    public func ancestors(of id: UUID) -> [UUID] {
        var result: [UUID] = []
        var current = nodes[id]?.parentID
        var visited = Set<UUID>()
        while let id = current, visited.insert(id).inserted, let node = nodes[id] {
            result.append(id)
            current = node.parentID
        }
        return result
    }

    public func flattenedDepthFirst() -> [UUID] {
        var result: [UUID] = []
        func visit(_ id: UUID, _ nodes: [UUID: LayerNodeV6], _ visited: inout Set<UUID>, _ out: inout [UUID]) {
            guard visited.insert(id).inserted, let node = nodes[id] else { return }
            out.append(id)
            for child in node.children { visit(child, nodes, &visited, &out) }
        }
        var visited = Set<UUID>()
        for root in roots { visit(root, nodes, &visited, &result) }
        return result
    }

    public func objectOrder() -> [UUID] {
        flattenedDepthFirst().compactMap { nodes[$0]?.objectID }
    }

    public mutating func insert(_ node: LayerNodeV6, parent: UUID?, index: Int) throws {
        guard nodes[node.id] == nil else { throw LayerTreeErrorV6.duplicateID }
        var inserted = node
        inserted.parentID = parent
        if let parent {
            guard var p = nodes[parent] else { throw LayerTreeErrorV6.missingParent }
            guard p.acceptsChildren else { throw LayerTreeErrorV6.parentRejectsChildren }
            nodes[inserted.id] = inserted
            let target = max(0, min(index, p.children.count))
            p.children.insert(inserted.id, at: target)
            nodes[parent] = p
        } else {
            nodes[inserted.id] = inserted
            let target = max(0, min(index, roots.count))
            roots.insert(inserted.id, at: target)
        }
    }

    public mutating func move(_ id: UUID, toParent parent: UUID?, index: Int) throws {
        guard var moving = nodes[id] else { throw LayerTreeErrorV6.missingNode }
        if parent == id { throw LayerTreeErrorV6.cycle }
        if let parent {
            guard let p = nodes[parent] else { throw LayerTreeErrorV6.missingParent }
            guard p.acceptsChildren else { throw LayerTreeErrorV6.parentRejectsChildren }
            if descendants(of: id).contains(parent) { throw LayerTreeErrorV6.cycle }
        }

        if let oldParent = moving.parentID {
            guard var p = nodes[oldParent] else { throw LayerTreeErrorV6.inconsistentParent }
            p.children.removeAll { $0 == id }
            nodes[oldParent] = p
        } else {
            roots.removeAll { $0 == id }
        }

        moving.parentID = parent
        nodes[id] = moving
        if let parent {
            var p = nodes[parent]!
            let target = max(0, min(index, p.children.count))
            p.children.insert(id, at: target)
            nodes[parent] = p
        } else {
            let target = max(0, min(index, roots.count))
            roots.insert(id, at: target)
        }
    }

    @discardableResult
    public mutating func removeSubtree(_ id: UUID) throws -> [UUID: LayerNodeV6] {
        guard let root = nodes[id] else { throw LayerTreeErrorV6.missingNode }
        var removed: [UUID: LayerNodeV6] = [:]
        var stack = [id]
        var visited = Set<UUID>()
        while let next = stack.popLast() {
            guard visited.insert(next).inserted, let node = nodes[next] else { continue }
            removed[next] = node
            stack.append(contentsOf: node.children)
        }
        if let parent = root.parentID {
            guard var p = nodes[parent] else { throw LayerTreeErrorV6.inconsistentParent }
            p.children.removeAll { $0 == id }
            nodes[parent] = p
        } else {
            roots.removeAll { $0 == id }
        }
        for key in removed.keys { nodes.removeValue(forKey: key) }
        return removed
    }

    @discardableResult
    public func validate() throws -> Bool {
        var reachable = Set<UUID>()
        var objectIDs = Set<UUID>()

        func visit(_ id: UUID, expectedParent: UUID?, path: inout Set<UUID>) throws {
            guard let node = nodes[id] else { throw LayerTreeErrorV6.danglingChild }
            guard node.parentID == expectedParent else { throw LayerTreeErrorV6.inconsistentParent }
            guard path.insert(id).inserted else { throw LayerTreeErrorV6.cycle }
            guard reachable.insert(id).inserted else { throw LayerTreeErrorV6.cycle }
            if let objectID = node.objectID, !objectIDs.insert(objectID).inserted {
                throw LayerTreeErrorV6.duplicateObjectReference
            }
            for child in node.children { try visit(child, expectedParent: id, path: &path) }
            path.remove(id)
        }

        for root in roots {
            var path = Set<UUID>()
            try visit(root, expectedParent: nil, path: &path)
        }
        guard reachable.count == nodes.count else { throw LayerTreeErrorV6.inconsistentParent }
        return true
    }
}

public enum ClippingRoleV6: String, Codable, Equatable, Hashable, Sendable {
    case clippingPath
    case content
}

public struct EmbeddedObjectResourceV6: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var originalBounds: CGRect
    public var payloadData: Data
    public var nestedEmbeddedResourceIDs: [UUID]

    public init(id: UUID = UUID(), name: String, originalBounds: CGRect, payloadData: Data, nestedEmbeddedResourceIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.originalBounds = originalBounds
        self.payloadData = payloadData
        self.nestedEmbeddedResourceIDs = nestedEmbeddedResourceIDs
    }
}

public struct LinkedAssetResourceV6: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var displayName: String
    public var sourceURLString: String
    public var originalFilename: String
    public var fallbackRasterAssetID: UUID?
    public var contentFingerprint: String?
    public var modificationDate: Double?

    public init(
        id: UUID = UUID(),
        displayName: String,
        sourceURLString: String,
        originalFilename: String,
        fallbackRasterAssetID: UUID? = nil,
        contentFingerprint: String? = nil,
        modificationDate: Double? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.sourceURLString = sourceURLString
        self.originalFilename = originalFilename
        self.fallbackRasterAssetID = fallbackRasterAssetID
        self.contentFingerprint = contentFingerprint
        self.modificationDate = modificationDate
    }
}

public struct SymbolDefinitionV6: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var originalBounds: CGRect
    public var payloadData: Data

    public init(id: UUID = UUID(), name: String, originalBounds: CGRect, payloadData: Data) {
        self.id = id
        self.name = name
        self.originalBounds = originalBounds
        self.payloadData = payloadData
    }
}

public struct GraphicStyleV6: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var appearance: AppearanceStackV6

    public init(id: UUID = UUID(), name: String, appearance: AppearanceStackV6) {
        self.id = id
        self.name = name
        self.appearance = appearance
    }
}

public struct ResourceLibraryV6: Codable, Equatable, Sendable {
    public var embeddedObjects: [EmbeddedObjectResourceV6]
    public var linkedAssets: [LinkedAssetResourceV6]
    public var symbols: [SymbolDefinitionV6]
    public var graphicStyles: [GraphicStyleV6]

    public init(
        embeddedObjects: [EmbeddedObjectResourceV6] = [],
        linkedAssets: [LinkedAssetResourceV6] = [],
        symbols: [SymbolDefinitionV6] = [],
        graphicStyles: [GraphicStyleV6] = []
    ) {
        self.embeddedObjects = embeddedObjects
        self.linkedAssets = linkedAssets
        self.symbols = symbols
        self.graphicStyles = graphicStyles
    }

    public var hasUniqueResourceIDs: Bool {
        var ids = Set<UUID>()
        for id in embeddedObjects.map(\.id) + linkedAssets.map(\.id) + symbols.map(\.id) + graphicStyles.map(\.id) {
            if !ids.insert(id).inserted { return false }
        }
        return true
    }
}
