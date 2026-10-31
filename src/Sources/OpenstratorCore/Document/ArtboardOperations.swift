import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public enum ArtboardOrientationV6: String, Codable, Equatable, Sendable {
    case portrait
    case landscape
}

public enum ArtboardError: Error, Equatable {
    case notArtboard
    case cannotRemoveFinalArtboard
    case missingArtboard
}

public extension DocumentV6 {
    var artboardIDs: [NodeID] {
        rootChildren.filter { id in
            guard let node=nodes[id] else { return false }
            if case .artboard = node.payload { return true }
            return false
        }
    }

    @discardableResult
    mutating func addArtboard(rect: CGRect, name: String? = nil, background: RGBAColorV6 = .white, makeActive: Bool = false) throws -> NodeID {
        let art=DocumentNode(name:name ?? "Artboard \(artboardIDs.count + 1)",payload:.artboard(.init(rect:rect.standardized,background:background)))
        let rootIndex=(nodes[rootID]?.children.firstIndex(where:{ id in
            guard let n=nodes[id] else{return false}; if case .guide=n.payload{return true}; return false
        })) ?? (nodes[rootID]?.children.count ?? 0)
        try insert(art,parent:rootID,index:rootIndex)
        if makeActive { activeArtboardID=art.id }
        return art.id
    }

    @discardableResult
    mutating func duplicateArtboard(id: NodeID, offset: CGSize = CGSize(width: 40, height: 40), makeActive: Bool = false) throws -> NodeID {
        guard let original=nodes[id], case let .artboard(data)=original.payload else { throw ArtboardError.notArtboard }
        let newID=NodeID()
        var clone=original
        clone.id=newID
        clone.name=nextCopyName(original.name)
        clone.payload = .artboard(.init(rect:data.rect.offsetBy(dx:offset.width,dy:offset.height),background:data.background))
        clone.children=[]

        let parentIndex=(nodes[rootID]?.children.firstIndex(of:id) ?? max(0,(nodes[rootID]?.children.count ?? 1)-1)) + 1
        try insert(clone,parent:rootID,index:parentIndex)
        for child in original.children {
            let subtree=try cloneSubtreeForArtboard(sourceID:child,offset:offset,offsetRoot:true)
            try insertClonedSubtree(subtree,parent:newID,index:nodes[newID]?.children.count ?? 0)
        }
        if makeActive { activeArtboardID=newID }
        return newID
    }

    mutating func removeArtboard(id: NodeID) throws {
        guard artboardIDs.contains(id) else { throw ArtboardError.notArtboard }
        guard artboardIDs.count > 1 else { throw ArtboardError.cannotRemoveFinalArtboard }
        _ = try removeSubtree(id:id)
        if activeArtboardID == id {
            guard let replacement=artboardIDs.first else { throw ArtboardError.missingArtboard }
            activeArtboardID=replacement
        }
    }

    mutating func setActiveArtboard(_ id: NodeID) throws {
        guard artboardIDs.contains(id) else { throw ArtboardError.notArtboard }
        activeArtboardID=id
    }

    mutating func setArtboardOrientation(_ orientation: ArtboardOrientationV6, id: NodeID) throws {
        guard var node = nodes[id], case let .artboard(data) = node.payload else { throw ArtboardError.notArtboard }
        let rect = data.rect.standardized
        let alreadyMatches = orientation == .portrait ? rect.height >= rect.width : rect.width >= rect.height
        guard !alreadyMatches else { return }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let swapped = CGRect(
            x: center.x - rect.height / 2,
            y: center.y - rect.width / 2,
            width: rect.height,
            height: rect.width
        )
        node.payload = .artboard(.init(rect: swapped, background: data.background))
        nodes[id] = node
    }

    private func nextCopyName(_ name: String) -> String { name + " copy" }

    private func cloneSubtreeForArtboard(sourceID: NodeID, offset: CGSize, offsetRoot: Bool) throws -> NodeSubtree {
        guard let original=nodes[sourceID] else { throw DocumentTreeError.missingNode }
        let newID=NodeID()
        var clone=original
        clone.id=newID
        clone.children=[]
        if offsetRoot {
            clone.transform.translationX += Double(offset.width)
            clone.transform.translationY += Double(offset.height)
        }
        var collected:[NodeID:DocumentNode]=[newID:clone]
        var childIDs:[NodeID]=[]
        for child in original.children {
            let childSubtree=try cloneSubtreeForArtboard(sourceID:child,offset:offset,offsetRoot:false)
            childIDs.append(childSubtree.rootID)
            for (k,v) in childSubtree.nodes { collected[k]=v }
        }
        collected[newID]?.children=childIDs
        return NodeSubtree(rootID:newID,nodes:collected)
    }

    private mutating func insertClonedSubtree(_ subtree: NodeSubtree, parent: NodeID, index: Int) throws {
        guard let rootNode=subtree.nodes[subtree.rootID] else { throw DocumentTreeError.missingNode }
        var rootCopy=rootNode
        rootCopy.children=[]
        try insert(rootCopy,parent:parent,index:index)
        func addChildren(_ sourceID: NodeID, _ targetParent: NodeID, _ all: [NodeID:DocumentNode], _ doc: inout DocumentV6) throws {
            guard let source=all[sourceID] else{return}
            for (idx,childID) in source.children.enumerated() {
                guard let child=all[childID] else{continue}
                var copy=child; copy.children=[]
                try doc.insert(copy,parent:targetParent,index:idx)
                try addChildren(childID,childID,all,&doc)
            }
        }
        try addChildren(subtree.rootID,subtree.rootID,subtree.nodes,&self)
    }
}
