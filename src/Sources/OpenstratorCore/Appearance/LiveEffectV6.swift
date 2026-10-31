import Foundation

public enum EffectParameterValueV6: Codable, Equatable, Sendable {
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case color(RGBAColorV6)
    case point(CGPoint)
    case choice(String)

    public var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }
    public var integerValue: Int? {
        if case .integer(let value) = self { return value }
        return nil
    }
    public var boolValue: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }
    public var colorValue: RGBAColorV6? {
        if case .color(let value) = self { return value }
        return nil
    }
    public var choiceValue: String? {
        if case .choice(let value) = self { return value }
        return nil
    }
}

public struct LiveEffectV6: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var effectID: String
    public var enabled: Bool
    public var parameters: [String: EffectParameterValueV6]
    public var serializationVersion: Int

    public init(id: UUID = UUID(), effectID: String, enabled: Bool = true, parameters: [String: EffectParameterValueV6] = [:], serializationVersion: Int = 1) {
        self.id = id
        self.effectID = effectID
        self.enabled = enabled
        self.parameters = parameters
        self.serializationVersion = serializationVersion
    }
}

public enum EffectParameterKindV6: String, Codable, Sendable {
    case number, integer, boolean, color, point, choice
}

public struct EffectParameterDescriptorV6: Codable, Equatable, Sendable {
    public var key: String
    public var label: String
    public var kind: EffectParameterKindV6
    public var defaultValue: EffectParameterValueV6
    public var minimum: Double?
    public var maximum: Double?
    public var choices: [String]

    public init(key: String, label: String, kind: EffectParameterKindV6, defaultValue: EffectParameterValueV6, minimum: Double? = nil, maximum: Double? = nil, choices: [String] = []) {
        self.key = key
        self.label = label
        self.kind = kind
        self.defaultValue = defaultValue
        self.minimum = minimum
        self.maximum = maximum
        self.choices = choices
    }
}

public enum EffectBoundsFamilyV6: String, Codable, Sendable {
    case none, blur, shadow, glow, transformCopies, geometry
}

public struct EffectDescriptorV6: Codable, Equatable, Sendable, Identifiable {
    public var id: String { effectID }
    public var effectID: String
    public var displayName: String
    public var serializationVersion: Int
    public var parameters: [String: EffectParameterDescriptorV6]
    public var boundsFamily: EffectBoundsFamilyV6
    public var vectorExpandable: Bool
    public var requiresRasterExpansion: Bool

    public init(effectID: String, displayName: String, serializationVersion: Int = 1, parameters: [EffectParameterDescriptorV6], boundsFamily: EffectBoundsFamilyV6 = .none, vectorExpandable: Bool = false, requiresRasterExpansion: Bool = false) {
        self.effectID = effectID
        self.displayName = displayName
        self.serializationVersion = serializationVersion
        self.parameters = Dictionary(uniqueKeysWithValues: parameters.map { ($0.key, $0) })
        self.boundsFamily = boundsFamily
        self.vectorExpandable = vectorExpandable
        self.requiresRasterExpansion = requiresRasterExpansion
    }

    public func makeDefaultEffect(id: UUID = UUID()) -> LiveEffectV6 {
        LiveEffectV6(id: id, effectID: effectID, enabled: true, parameters: parameters.mapValues(\.defaultValue), serializationVersion: serializationVersion)
    }
}

public enum EffectValidationErrorV6: Error, Equatable {
    case unknownEffect(String)
    case unknownParameter(effect: String, key: String)
    case typeMismatch(effect: String, key: String)
    case invalidChoice(effect: String, key: String, value: String)
}
