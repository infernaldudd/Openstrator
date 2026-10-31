import Foundation

public struct NodeSubtree: Equatable, Sendable {
    public var rootID: NodeID
    public var nodes: [NodeID: DocumentNode]
    public init(rootID: NodeID, nodes: [NodeID: DocumentNode]) { self.rootID=rootID; self.nodes=nodes }
}

public struct CanvasSettingsV6: Codable, Equatable, Sendable {
    public var grid: GridSettingsV6
    public init(grid: GridSettingsV6) { self.grid=grid }
}

public enum DocumentMutation: Equatable, Sendable {
    case insert(parent: NodeID, index: Int, subtree: NodeSubtree)
    case remove(parent: NodeID, index: Int, subtree: NodeSubtree)
    case replaceNode(before: DocumentNode, after: DocumentNode)
    case setTransform(id: NodeID, before: NodeTransform, after: NodeTransform)
    case replaceCanvas(before: CanvasSettingsV6, after: CanvasSettingsV6)
}

public struct DocumentCommand: Equatable, Sendable {
    public var label: String
    public var forward: [DocumentMutation]
    public var inverse: [DocumentMutation]
    public var coalescingKey: String?
    public init(label: String, forward: [DocumentMutation], inverse: [DocumentMutation], coalescingKey: String? = nil) {
        self.label=label; self.forward=forward; self.inverse=inverse; self.coalescingKey=coalescingKey
    }

    public static func setTransform(id: NodeID, from: NodeTransform, to: NodeTransform, coalescingKey: String? = nil) -> DocumentCommand {
        .init(label: "Transform", forward: [.setTransform(id: id, before: from, after: to)], inverse: [.setTransform(id: id, before: to, after: from)], coalescingKey: coalescingKey)
    }

    public static func insert(subtree: NodeSubtree, parent: NodeID, index: Int) -> DocumentCommand {
        .init(label: "Insert", forward: [.insert(parent: parent, index: index, subtree: subtree)], inverse: [.remove(parent: parent, index: index, subtree: subtree)])
    }

    public static func remove(subtree: NodeSubtree, parent: NodeID, index: Int) -> DocumentCommand {
        .init(label: "Delete", forward: [.remove(parent: parent, index: index, subtree: subtree)], inverse: [.insert(parent: parent, index: index, subtree: subtree)])
    }
}

extension DocumentMutation {
    func apply(to document: inout DocumentV6) throws {
        switch self {
        case let .insert(parent, index, subtree):
            guard let root = subtree.nodes[subtree.rootID] else { throw DocumentTreeError.missingNode }
            for (id, node) in subtree.nodes where id != subtree.rootID { document.nodes[id] = node }
            try document.insert(root, parent: parent, index: index)
        case let .remove(_, _, subtree):
            _ = try document.removeSubtree(id: subtree.rootID)
        case let .replaceNode(_, after):
            try document.replaceNode(after)
        case let .setTransform(id, _, after):
            guard var node = document.node(id: id) else { throw DocumentTreeError.missingNode }
            node.transform = after
            try document.replaceNode(node)
        case let .replaceCanvas(_, after):
            document.grid = after.grid
        }
    }
}
