import Foundation

public struct NodeID: Hashable, Codable, Sendable {
    public var rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public struct NodeTransform: Codable, Equatable, Sendable {
    public var translationX: Double; public var translationY: Double; public var rotationDegrees: Double
    public var scaleX: Double; public var scaleY: Double; public var shearX: Double; public var shearY: Double
    public init(translationX: Double, translationY: Double, rotationDegrees: Double, scaleX: Double, scaleY: Double, shearX: Double, shearY: Double) {
        self.translationX=translationX; self.translationY=translationY; self.rotationDegrees=rotationDegrees; self.scaleX=scaleX; self.scaleY=scaleY; self.shearX=shearX; self.shearY=shearY
    }
    public static let identity = NodeTransform(translationX: 0, translationY: 0, rotationDegrees: 0, scaleX: 1, scaleY: 1, shearX: 0, shearY: 0)
    public static func translation(x: Double, y: Double) -> NodeTransform { .init(translationX: x, translationY: y, rotationDegrees: 0, scaleX: 1, scaleY: 1, shearX: 0, shearY: 0) }
}

public struct ArtboardData: Codable, Equatable, Sendable { public var rect: CGRect; public var background: RGBAColorV6; public init(rect: CGRect, background: RGBAColorV6) { self.rect=rect; self.background=background } }
public struct LiveRectData: Codable, Equatable, Sendable { public var rect: CGRect; public var cornerRadius: Double; public init(rect: CGRect, cornerRadius: Double=0) { self.rect=rect; self.cornerRadius=cornerRadius } }
public struct LiveEllipseData: Codable, Equatable, Sendable { public var rect: CGRect; public init(rect: CGRect) { self.rect=rect } }
public struct LivePolygonData: Codable, Equatable, Sendable { public var rect: CGRect; public var sides: Int; public init(rect: CGRect, sides: Int=6) { self.rect=rect; self.sides=sides } }
public typealias PathAnchorM1 = PathAnchorV6
public typealias PathData = BezierPathV6
public struct GuideData: Codable, Equatable, Sendable { public var axis: String; public var position: Double; public init(axis: String, position: Double) { self.axis=axis; self.position=position } }
public struct GridSettingsV6: Codable, Equatable, Sendable { public var spacing: Double; public var isVisible: Bool; public var snapEnabled: Bool; public init(spacing: Double=24, isVisible: Bool=true, snapEnabled: Bool=false) { self.spacing=spacing; self.isVisible=isVisible; self.snapEnabled=snapEnabled } }

public enum NodePayload: Codable, Equatable, Sendable {
    case root, group
    case artboard(ArtboardData), rectangle(LiveRectData), ellipse(LiveEllipseData), polygon(LivePolygonData)
    case line(PathData), path(PathData), text(TextDataM1), image(RasterImageDataV6), guide(GuideData)
}

public struct DocumentNode: Codable, Equatable, Identifiable, Sendable {
    public var id: NodeID; public var name: String; public var isVisible: Bool; public var isLocked: Bool
    public var transform: NodeTransform; public var opacity: Double; public var blendMode: BlendModeV6
    public var appearance: AppearanceV6; public var payload: NodePayload; public var children: [NodeID]; public var legacyGroupKey: UUID?
    public init(id: NodeID = NodeID(), name: String, isVisible: Bool=true, isLocked: Bool=false, transform: NodeTransform = .identity, opacity: Double=1, blendMode: BlendModeV6 = .normal, appearance: AppearanceV6 = AppearanceV6(), payload: NodePayload, children: [NodeID]=[], legacyGroupKey: UUID?=nil) {
        self.id=id; self.name=name; self.isVisible=isVisible; self.isLocked=isLocked; self.transform=transform; self.opacity=opacity; self.blendMode=blendMode; self.appearance=appearance; self.payload=payload; self.children=children; self.legacyGroupKey=legacyGroupKey
    }
    public static func group(name: String) -> DocumentNode { .init(name: name, payload: .group) }
    public static func rectangle(name: String, rect: CGRect) -> DocumentNode { .init(name: name, appearance: AppearanceV6(fill: RGBAColorV6(r:0.15,g:0.48,b:0.96)), payload: .rectangle(.init(rect: rect))) }
    public static func ellipse(name: String, rect: CGRect) -> DocumentNode { .init(name: name, appearance: AppearanceV6(fill: RGBAColorV6(r:0.98,g:0.33,b:0.35)), payload: .ellipse(.init(rect: rect))) }
    public static func text(name: String, text: String, frame: CGRect) -> DocumentNode { .init(name: name, appearance: AppearanceV6(fill: .black), payload: .text(.init(text: text, frame: frame))) }
}

public enum DocumentTreeError: Error, Equatable { case missingParent, duplicateID, cycle, rootRemoval, missingNode }

public struct DocumentV6: Codable, Equatable, Sendable {
    public var formatVersion: Int = 6
    public var name: String
    public var nodes: [NodeID: DocumentNode]
    public var rootID: NodeID
    public var activeArtboardID: NodeID
    public var grid: GridSettingsV6
    public var showGuides: Bool

    public static func empty(width: Double, height: Double) -> DocumentV6 {
        let root = DocumentNode(name: "Document", payload: .root)
        let art = DocumentNode(name: "Artboard 1", payload: .artboard(.init(rect: CGRect(x: 0, y: 0, width: width, height: height), background: .white)))
        var r = root; r.children = [art.id]
        return DocumentV6(name: "Untitled", nodes: [r.id:r, art.id:art], rootID:r.id, activeArtboardID:art.id, grid: .init(), showGuides:true)
    }
    public var rootChildren: [NodeID] { nodes[rootID]?.children ?? [] }
    public var artworkChildren: [NodeID] { nodes[activeArtboardID]?.children ?? [] }
    public var artboardSize: CGSize {
        guard let n = nodes[activeArtboardID], case let .artboard(a) = n.payload else { return .zero }
        return a.rect.size
    }
    public var guides: [DocumentNode] { nodes.values.filter { if case .guide = $0.payload { return true }; return false } }
    public func node(id: NodeID) -> DocumentNode? { nodes[id] }
    public func parent(of id: NodeID) -> NodeID? { nodes.first(where: { $0.value.children.contains(id) })?.key }
    public mutating func insert(_ node: DocumentNode, parent: NodeID, index: Int) throws {
        guard nodes[parent] != nil else { throw DocumentTreeError.missingParent }
        guard nodes[node.id] == nil else { throw DocumentTreeError.duplicateID }
        if node.children.contains(parent) { throw DocumentTreeError.cycle }
        nodes[node.id] = node
        var p = nodes[parent]!; p.children.insert(node.id, at: max(0, min(index, p.children.count))); nodes[parent] = p
    }
    @discardableResult public mutating func removeSubtree(id: NodeID) throws -> [NodeID: DocumentNode] {
        guard id != rootID else { throw DocumentTreeError.rootRemoval }
        guard let node = nodes[id] else { throw DocumentTreeError.missingNode }
        var removed: [NodeID:DocumentNode] = [:]
        func collect(_ nid: NodeID, _ source: [NodeID:DocumentNode], _ out: inout [NodeID:DocumentNode]) { if let n=source[nid] { out[nid]=n; for c in n.children { collect(c, source, &out) } } }
        collect(id, nodes, &removed)
        if let pid = parent(of: id), var p = nodes[pid] { p.children.removeAll{$0==id}; nodes[pid]=p }
        for key in removed.keys { nodes.removeValue(forKey:key) }
        _ = node
        return removed
    }
    public mutating func replaceNode(_ node: DocumentNode) throws { guard nodes[node.id] != nil else { throw DocumentTreeError.missingNode }; nodes[node.id]=node }
}
