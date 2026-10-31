import Foundation

public struct RGBAColorV6: Codable, Equatable, Sendable {
    public var r: Double; public var g: Double; public var b: Double; public var a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1) { self.r=r; self.g=g; self.b=b; self.a=a }
    public static let clear = RGBAColorV6(r: 0, g: 0, b: 0, a: 0)
    public static let black = RGBAColorV6(r: 0, g: 0, b: 0, a: 1)
    public static let white = RGBAColorV6(r: 1, g: 1, b: 1, a: 1)
}

public enum BlendModeV6: String, Codable, Equatable, Sendable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn
    case softLight, hardLight, difference, exclusion, hue, saturation, color, luminosity
}

public struct GradientStopV6: Codable, Equatable, Sendable {
    public var location: Double; public var color: RGBAColorV6
    public init(location: Double, color: RGBAColorV6) { self.location=location; self.color=color }
}

public struct LinearGradientV6: Codable, Equatable, Sendable {
    public var angleDegrees: Double; public var stops: [GradientStopV6]
    public init(angleDegrees: Double, stops: [GradientStopV6]) { self.angleDegrees=angleDegrees; self.stops=stops }
}

public struct StrokeV6: Codable, Equatable, Sendable {
    public var color: RGBAColorV6; public var width: Double; public var dash: [Double]; public var cap: String; public var join: String
    public init(color: RGBAColorV6 = .clear, width: Double = 0, dash: [Double] = [], cap: String = "butt", join: String = "miter") {
        self.color=color; self.width=width; self.dash=dash; self.cap=cap; self.join=join
    }
}

public struct LegacyEffectV6: Codable, Equatable, Sendable {
    public var kind: String; public var amount: Double; public var enabled: Bool; public var boundsInflation: Double
    public init(kind: String, amount: Double, enabled: Bool = true, boundsInflation: Double = 0) {
        self.kind=kind; self.amount=amount; self.enabled=enabled; self.boundsInflation=boundsInflation
    }
}

public struct AppearanceV6: Codable, Equatable, Sendable {
    public var fill: RGBAColorV6; public var gradient: LinearGradientV6?; public var stroke: StrokeV6; public var effects: [LegacyEffectV6]
    public init(fill: RGBAColorV6 = .clear, gradient: LinearGradientV6? = nil, stroke: StrokeV6 = StrokeV6(), effects: [LegacyEffectV6] = []) {
        self.fill=fill; self.gradient=gradient; self.stroke=stroke; self.effects=effects
    }
}
