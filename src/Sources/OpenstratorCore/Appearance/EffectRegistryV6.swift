import Foundation

public enum EffectRegistryV6 {
    private static func number(_ key: String, _ label: String, _ defaultValue: Double, _ range: ClosedRange<Double>) -> EffectParameterDescriptorV6 {
        .init(key: key, label: label, kind: .number, defaultValue: .number(defaultValue), minimum: range.lowerBound, maximum: range.upperBound)
    }
    private static func integer(_ key: String, _ label: String, _ defaultValue: Int, _ range: ClosedRange<Double>) -> EffectParameterDescriptorV6 {
        .init(key: key, label: label, kind: .integer, defaultValue: .integer(defaultValue), minimum: range.lowerBound, maximum: range.upperBound)
    }
    private static func boolean(_ key: String, _ label: String, _ defaultValue: Bool) -> EffectParameterDescriptorV6 {
        .init(key: key, label: label, kind: .boolean, defaultValue: .boolean(defaultValue))
    }
    private static func color(_ key: String, _ label: String, _ value: RGBAColorV6) -> EffectParameterDescriptorV6 {
        .init(key: key, label: label, kind: .color, defaultValue: .color(value))
    }
    private static func choice(_ key: String, _ label: String, _ value: String, _ choices: [String]) -> EffectParameterDescriptorV6 {
        .init(key: key, label: label, kind: .choice, defaultValue: .choice(value), choices: choices)
    }

    public static let descriptors: [EffectDescriptorV6] = [
        .init(effectID: "gaussianBlur", displayName: "Gaussian Blur", parameters: [number("radius","Radius",4,0...250)], boundsFamily: .blur, requiresRasterExpansion: true),
        .init(effectID: "motionBlur", displayName: "Motion Blur", parameters: [number("distance","Distance",12,0...500), number("angle","Angle",0,-180...180)], boundsFamily: .blur, requiresRasterExpansion: true),
        .init(effectID: "dropShadow", displayName: "Drop Shadow", parameters: [number("x","X Offset",4,-500...500), number("y","Y Offset",4,-500...500), number("blur","Blur",8,0...250), number("opacity","Opacity",0.35,0...1), color("color","Color",.black), choice("blendMode","Blend Mode","multiply",["normal","multiply","screen","overlay"])], boundsFamily: .shadow, requiresRasterExpansion: true),
        .init(effectID: "outerGlow", displayName: "Outer Glow", parameters: [number("blur","Blur",10,0...250), number("opacity","Opacity",0.5,0...1), color("color","Color",.white), choice("blendMode","Blend Mode","screen",["normal","multiply","screen","overlay"])], boundsFamily: .glow, requiresRasterExpansion: true),
        .init(effectID: "innerShadow", displayName: "Inner Shadow", parameters: [number("x","X Offset",3,-500...500), number("y","Y Offset",3,-500...500), number("blur","Blur",6,0...250), number("opacity","Opacity",0.35,0...1), color("color","Color",.black)], requiresRasterExpansion: true),
        .init(effectID: "innerGlow", displayName: "Inner Glow", parameters: [number("blur","Blur",8,0...250), number("opacity","Opacity",0.4,0...1), color("color","Color",.white)], requiresRasterExpansion: true),
        .init(effectID: "roughen", displayName: "Roughen", parameters: [number("size","Size",4,0...100), integer("detail","Detail",8,1...100), boolean("relative","Relative",true), choice("points","Points","smooth",["smooth","corner"])], boundsFamily: .geometry),
        .init(effectID: "zigZag", displayName: "Zig Zag", parameters: [number("size","Size",5,0...100), integer("ridges","Ridges",8,1...100), choice("points","Points","smooth",["smooth","corner"])], boundsFamily: .geometry),
        .init(effectID: "puckerBloat", displayName: "Pucker & Bloat", parameters: [number("amount","Amount",0,-1...1)], boundsFamily: .geometry),
        .init(effectID: "transform", displayName: "Transform", parameters: [number("x","Move X",0,-5000...5000), number("y","Move Y",0,-5000...5000), number("scaleX","Scale X",1,0.01...100), number("scaleY","Scale Y",1,0.01...100), number("rotation","Rotation",0,-360...360), integer("copies","Copies",0,0...100), choice("origin","Origin","center",["center","topLeft","topRight","bottomLeft","bottomRight"])], boundsFamily: .transformCopies, vectorExpandable: true),
        .init(effectID: "offsetPath", displayName: "Offset Path", parameters: [number("offset","Offset",4,-1000...1000), choice("join","Join","miter",["miter","round","bevel"]), number("miterLimit","Miter Limit",10,1...100)], boundsFamily: .geometry, vectorExpandable: true),
        .init(effectID: "roundCorners", displayName: "Round Corners", parameters: [number("radius","Radius",8,0...1000)], boundsFamily: .geometry, vectorExpandable: true),
        .init(effectID: "convertRectangle", displayName: "Convert to Rectangle", parameters: [], boundsFamily: .geometry, vectorExpandable: true),
        .init(effectID: "convertRoundedRectangle", displayName: "Convert to Rounded Rectangle", parameters: [number("radius","Radius",12,0...1000)], boundsFamily: .geometry, vectorExpandable: true),
        .init(effectID: "convertEllipse", displayName: "Convert to Ellipse", parameters: [], boundsFamily: .geometry, vectorExpandable: true),
        .init(effectID: "warp", displayName: "Warp", parameters: [choice("style","Style","arc",["arc","arch","bulge","flag","fish","inflate","rise","squeeze","wave"]), number("bend","Bend",0.25,-1...1), number("horizontalDistortion","Horizontal Distortion",0,-1...1), number("verticalDistortion","Vertical Distortion",0,-1...1)], boundsFamily: .geometry)
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.effectID, $0) })

    public static func descriptor(id: String) -> EffectDescriptorV6? { byID[id] }

    public static func validate(_ effect: LiveEffectV6) throws -> LiveEffectV6 {
        guard let descriptor = descriptor(id: effect.effectID) else { throw EffectValidationErrorV6.unknownEffect(effect.effectID) }
        var result = effect
        result.serializationVersion = descriptor.serializationVersion
        for key in effect.parameters.keys where descriptor.parameters[key] == nil {
            throw EffectValidationErrorV6.unknownParameter(effect: effect.effectID, key: key)
        }
        for (key, parameter) in descriptor.parameters {
            var value = result.parameters[key] ?? parameter.defaultValue
            switch (parameter.kind, value) {
            case (.number, .number(let raw)):
                let safe = raw.isFinite ? raw : (parameter.defaultValue.numberValue ?? 0)
                value = .number(min(parameter.maximum ?? safe, max(parameter.minimum ?? safe, safe)))
            case (.integer, .integer(let raw)):
                let clamped = min(Int(parameter.maximum ?? Double(raw)), max(Int(parameter.minimum ?? Double(raw)), raw))
                value = .integer(clamped)
            case (.boolean, .boolean), (.color, .color), (.point, .point):
                break
            case (.choice, .choice(let raw)):
                guard parameter.choices.isEmpty || parameter.choices.contains(raw) else { throw EffectValidationErrorV6.invalidChoice(effect: effect.effectID, key: key, value: raw) }
            default:
                throw EffectValidationErrorV6.typeMismatch(effect: effect.effectID, key: key)
            }
            result.parameters[key] = value
        }
        return result
    }
}
