import Foundation

public struct LegacyColorV5: Codable, Equatable, Sendable {
    public var r: Double; public var g: Double; public var b: Double; public var a: Double
}
public struct LegacyPointV5: Codable, Equatable, Sendable { public var x: Double; public var y: Double }
public struct LegacyGradientStopV5: Codable, Equatable, Sendable { public var id: UUID?; public var location: Double; public var color: LegacyColorV5 }
public struct LegacyGradientV5: Codable, Equatable, Sendable { public var angleDegrees: Double; public var stops: [LegacyGradientStopV5] }
public struct LegacyEffectV5: Codable, Equatable, Sendable { public var id: UUID?; public var kind: String; public var amount: Double; public var enabled: Bool }
public struct LegacyGuideV5: Codable, Equatable, Sendable { public var id: UUID?; public var axis: String; public var position: Double }

public struct LegacyObjectV5: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: String
    public var x: Double; public var y: Double; public var width: Double; public var height: Double
    public var rotation: Double
    public var opacity: Double
    public var fill: LegacyColorV5
    public var gradient: LegacyGradientV5?
    public var stroke: LegacyColorV5
    public var strokeWidth: Double
    public var cornerRadius: Double
    public var blendMode: String
    public var text: String
    public var fontSize: Double
    public var fontWeight: Double
    public var points: [LegacyPointV5]
    public var bezierAnchors: [PathAnchorV6]?
    public var effects: [LegacyEffectV5]
    public var isVisible: Bool
    public var isLocked: Bool
    public var groupID: UUID?
    public var isClosed: Bool?
    public var scaleX: Double?
    public var scaleY: Double?
    public var shearX: Double?
    public var shearY: Double?
    public var strokeDash: [Double]?
    public var lineCap: String?
    public var lineJoin: String?
}

public struct LegacyDocumentV5: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var name: String
    public var artboardWidth: Double
    public var artboardHeight: Double
    public var background: LegacyColorV5
    public var objects: [LegacyObjectV5]
    public var guides: [LegacyGuideV5]
    public var gridSpacing: Double
    public var showGrid: Bool
    public var snapToGrid: Bool
    public var showGuides: Bool
}
