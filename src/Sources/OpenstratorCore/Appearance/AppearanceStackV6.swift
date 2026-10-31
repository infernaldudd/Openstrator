import Foundation

public enum AppearancePaintV6: Codable, Equatable, Sendable {
    case color(RGBAColorV6)
    case linearGradient(LinearGradientV6)
}

public struct FillAppearanceV6: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var enabled: Bool
    public var opacity: Double
    public var blendMode: BlendModeV6
    public var paint: AppearancePaintV6

    public init(id: UUID = UUID(), enabled: Bool = true, opacity: Double = 1, blendMode: BlendModeV6 = .normal, paint: AppearancePaintV6) {
        self.id = id
        self.enabled = enabled
        self.opacity = opacity
        self.blendMode = blendMode
        self.paint = paint
        normalize()
    }

    public mutating func normalize() {
        opacity = min(1, max(0, opacity.isFinite ? opacity : 1))
    }
}

public struct StrokeAppearanceV6: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var enabled: Bool
    public var opacity: Double
    public var blendMode: BlendModeV6
    public var paint: AppearancePaintV6
    public var width: Double
    public var dash: [Double]
    public var cap: String
    public var join: String
    public var miterLimit: Double

    public init(id: UUID = UUID(), enabled: Bool = true, opacity: Double = 1, blendMode: BlendModeV6 = .normal, paint: AppearancePaintV6, width: Double = 1, dash: [Double] = [], cap: String = "butt", join: String = "miter", miterLimit: Double = 10) {
        self.id = id
        self.enabled = enabled
        self.opacity = opacity
        self.blendMode = blendMode
        self.paint = paint
        self.width = width
        self.dash = dash
        self.cap = cap
        self.join = join
        self.miterLimit = miterLimit
        normalize()
    }

    public mutating func normalize() {
        opacity = min(1, max(0, opacity.isFinite ? opacity : 1))
        width = max(0, width.isFinite ? width : 0)
        miterLimit = max(1, miterLimit.isFinite ? miterLimit : 10)
        dash = dash.map { max(0, $0.isFinite ? $0 : 0) }
    }
}

public enum AppearanceEntryV6: Codable, Equatable, Sendable, Identifiable {
    case fill(FillAppearanceV6)
    case stroke(StrokeAppearanceV6)
    case effect(LiveEffectV6)

    public var id: UUID {
        switch self {
        case .fill(let value): return value.id
        case .stroke(let value): return value.id
        case .effect(let value): return value.id
        }
    }

    public var enabled: Bool {
        switch self {
        case .fill(let value): return value.enabled
        case .stroke(let value): return value.enabled
        case .effect(let value): return value.enabled
        }
    }
}

public struct AppearanceStackV6: Codable, Equatable, Sendable {
    public var entries: [AppearanceEntryV6]
    public var opacity: Double
    public var blendMode: BlendModeV6
    public var isolation: Bool

    public init(entries: [AppearanceEntryV6] = [], opacity: Double = 1, blendMode: BlendModeV6 = .normal, isolation: Bool = false) {
        self.entries = entries
        self.opacity = opacity
        self.blendMode = blendMode
        self.isolation = isolation
        normalize()
    }

    public mutating func normalize() {
        opacity = min(1, max(0, opacity.isFinite ? opacity : 1))
        for index in entries.indices {
            switch entries[index] {
            case .fill(var fill):
                fill.normalize(); entries[index] = .fill(fill)
            case .stroke(var stroke):
                stroke.normalize(); entries[index] = .stroke(stroke)
            case .effect(let effect):
                if let validated = try? EffectRegistryV6.validate(effect) { entries[index] = .effect(validated) }
            }
        }
    }
}
