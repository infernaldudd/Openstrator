import Foundation

public enum V5MigrationError: Error { case unsupportedObjectKind(String), invalidDocument }

public enum V5Migrator {
    public static func decodeAndMigrate(_ data: Data) throws -> DocumentV6 {
        try migrate(JSONDecoder().decode(LegacyDocumentV5.self, from: data))
    }

    public static func migrate(_ legacy: LegacyDocumentV5) throws -> DocumentV6 {
        var doc = DocumentV6.empty(width: legacy.artboardWidth, height: legacy.artboardHeight)
        doc.name = legacy.name
        doc.grid = GridSettingsV6(spacing: legacy.gridSpacing, isVisible: legacy.showGrid, snapEnabled: legacy.snapToGrid)
        doc.showGuides = legacy.showGuides
        if var art = doc.node(id: doc.activeArtboardID), case let .artboard(data) = art.payload {
            art.payload = .artboard(ArtboardData(rect: data.rect, background: convert(legacy.background)))
            try doc.replaceNode(art)
        }

        var insertedGroups: [UUID: NodeID] = [:]
        var topIndex = 0
        for legacyObject in legacy.objects {
            let node = try convert(legacyObject)
            if let gid = legacyObject.groupID {
                let groupID: NodeID
                if let existing = insertedGroups[gid] {
                    groupID = existing
                } else {
                    var group = DocumentNode.group(name: "Group")
                    group.legacyGroupKey = gid
                    try doc.insert(group, parent: doc.activeArtboardID, index: topIndex)
                    insertedGroups[gid] = group.id
                    groupID = group.id
                    topIndex += 1
                }
                let childIndex = doc.node(id: groupID)?.children.count ?? 0
                try doc.insert(node, parent: groupID, index: childIndex)
            } else {
                try doc.insert(node, parent: doc.activeArtboardID, index: topIndex)
                topIndex += 1
            }
        }

        for guide in legacy.guides {
            let node = DocumentNode(name: "Guide", payload: .guide(GuideData(axis: guide.axis, position: guide.position)))
            try doc.insert(node, parent: doc.rootID, index: doc.rootChildren.count)
        }
        return doc
    }

    private static func convert(_ c: LegacyColorV5) -> RGBAColorV6 { .init(r: c.r, g: c.g, b: c.b, a: c.a) }
    private static func convert(_ o: LegacyObjectV5) throws -> DocumentNode {
        let fill = convert(o.fill)
        let gradient = o.gradient.map { g in LinearGradientV6(angleDegrees: g.angleDegrees, stops: g.stops.map { .init(location: $0.location, color: convert($0.color)) }) }
        let stroke = StrokeV6(color: convert(o.stroke), width: o.strokeWidth, dash: o.strokeDash ?? [], cap: o.lineCap ?? "butt", join: o.lineJoin ?? "miter")
        let effects = o.effects.map { LegacyEffectV6(kind: $0.kind, amount: $0.amount, enabled: $0.enabled, boundsInflation: inflation(kind: $0.kind, amount: $0.amount)) }
        let appearance = AppearanceV6(fill: fill, gradient: gradient, stroke: stroke, effects: effects)
        let blend = BlendModeV6(rawValue: o.blendMode) ?? .normal
        let centerX = o.x + o.width / 2
        let centerY = o.y + o.height / 2
        let transform = NodeTransform(translationX: centerX, translationY: centerY, rotationDegrees: o.rotation, scaleX: o.scaleX ?? 1, scaleY: o.scaleY ?? 1, shearX: o.shearX ?? 0, shearY: o.shearY ?? 0)
        let localRect = CGRect(x: -max(0, o.width) / 2, y: -max(0, o.height) / 2, width: max(0, o.width), height: max(0, o.height))
        let payload: NodePayload
        switch o.kind {
        case "rectangle": payload = .rectangle(LiveRectData(rect: localRect, cornerRadius: o.cornerRadius))
        case "ellipse": payload = .ellipse(LiveEllipseData(rect: localRect))
        case "polygon": payload = .polygon(LivePolygonData(rect: localRect, sides: 6))
        case "text": payload = .text(TextDataM1(text: o.text, frame: localRect, fontSize: o.fontSize, fontWeight: o.fontWeight))
        case "line":
            let anchors = legacyPathAnchors(o, centerX: centerX, centerY: centerY)
            payload = .line(PathData(anchors: anchors, isClosed: false))
        case "path":
            let anchors = legacyPathAnchors(o, centerX: centerX, centerY: centerY)
            payload = .path(PathData(anchors: anchors, isClosed: o.isClosed ?? false))
        default: throw V5MigrationError.unsupportedObjectKind(o.kind)
        }
        return DocumentNode(id: NodeID(o.id), name: o.name, isVisible: o.isVisible, isLocked: o.isLocked, transform: transform, opacity: o.opacity, blendMode: blend, appearance: appearance, payload: payload)
    }

    private static func legacyPathAnchors(_ o: LegacyObjectV5, centerX: Double, centerY: Double) -> [PathAnchorV6] {
        if let anchors = o.bezierAnchors, !anchors.isEmpty {
            return anchors.map { PathCompatibility.translatedAnchor($0, dx: -centerX, dy: -centerY) }
        }
        return o.points.map { PathAnchorV6(point: CGPoint(x: $0.x - centerX, y: $0.y - centerY)) }
    }

    private static func inflation(kind: String, amount: Double) -> Double {
        switch kind {
        case "shadow", "glow", "innerShadow", "innerGlow", "blur", "gaussianBlur", "radialBlur", "zoomBlur", "smartBlur", "motionBlur", "feather": return max(0, abs(amount) * 2 + 4)
        case "offset", "offsetPath", "roughen", "zigZag": return max(0, abs(amount) + 2)
        default: return 0
        }
    }
}
