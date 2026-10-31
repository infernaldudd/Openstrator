import Foundation

public enum AppearanceMigrationV6 {
    public static func stack(from legacy: AppearanceV6, opacity: Double = 1, blendMode: BlendModeV6 = .normal) -> AppearanceStackV6 {
        var entries: [AppearanceEntryV6] = []
        let fillPaint: AppearancePaintV6 = legacy.gradient.map(AppearancePaintV6.linearGradient) ?? .color(legacy.fill)
        entries.append(.fill(FillAppearanceV6(paint: fillPaint)))
        if legacy.stroke.width > 0 || legacy.stroke.color.a > 0 {
            entries.append(.stroke(StrokeAppearanceV6(
                paint: .color(legacy.stroke.color),
                width: legacy.stroke.width,
                dash: legacy.stroke.dash,
                cap: legacy.stroke.cap,
                join: legacy.stroke.join
            )))
        }
        for legacyEffect in legacy.effects {
            if let effect = liveEffect(from: legacyEffect) { entries.append(.effect(effect)) }
        }
        return AppearanceStackV6(entries: entries, opacity: opacity, blendMode: blendMode)
    }

    public static func liveEffect(from legacy: LegacyEffectV6) -> LiveEffectV6? {
        let id: String
        let key: String?
        switch legacy.kind {
        case "blur", "gaussianBlur": id = "gaussianBlur"; key = "radius"
        case "motionBlur": id = "motionBlur"; key = "distance"
        case "shadow", "dropShadow": id = "dropShadow"; key = "blur"
        case "glow", "outerGlow": id = "outerGlow"; key = "blur"
        case "innerShadow": id = "innerShadow"; key = "blur"
        case "innerGlow": id = "innerGlow"; key = "blur"
        case "roughen": id = "roughen"; key = "size"
        case "zigZag": id = "zigZag"; key = "size"
        case "puckerBloat": id = "puckerBloat"; key = "amount"
        case "offsetPath": id = "offsetPath"; key = "offset"
        case "roundCorners": id = "roundCorners"; key = "radius"
        case "convertRectangle": id = "convertRectangle"; key = nil
        case "convertRoundedRectangle": id = "convertRoundedRectangle"; key = "radius"
        case "convertEllipse": id = "convertEllipse"; key = nil
        case "warpArc", "warpArch", "warpBulge", "warpFlag", "warpFish", "warpInflate", "warpRise", "warpSqueeze", "warpWave":
            id = "warp"; key = "bend"
        default: return nil
        }
        guard let descriptor = EffectRegistryV6.descriptor(id: id) else { return nil }
        var effect = descriptor.makeDefaultEffect()
        effect.enabled = legacy.enabled
        if let key { effect.parameters[key] = .number(legacy.amount) }
        return try? EffectRegistryV6.validate(effect)
    }
}
