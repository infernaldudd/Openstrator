import Foundation

public struct ExpandedAppearancePieceV6: Equatable, Sendable {
    public var sourceEntryID: UUID
    public var entry: AppearanceEntryV6
    public var copyIndex: Int
    public var translationX: Double
    public var translationY: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotationDegrees: Double
    public var geometryEffects: [LiveEffectV6]

    public init(sourceEntryID: UUID, entry: AppearanceEntryV6, copyIndex: Int, translationX: Double = 0, translationY: Double = 0, scaleX: Double = 1, scaleY: Double = 1, rotationDegrees: Double = 0, geometryEffects: [LiveEffectV6] = []) {
        self.sourceEntryID = sourceEntryID
        self.entry = entry
        self.copyIndex = copyIndex
        self.translationX = translationX
        self.translationY = translationY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotationDegrees = rotationDegrees
        self.geometryEffects = geometryEffects
    }
}

public struct ExpandAppearanceResultV6: Equatable, Sendable {
    public var pieces: [ExpandedAppearancePieceV6]
    public var requiresRasterExpansion: Bool
    public var blockingEffectIDs: [String]

    public init(pieces: [ExpandedAppearancePieceV6], requiresRasterExpansion: Bool, blockingEffectIDs: [String]) {
        self.pieces = pieces
        self.requiresRasterExpansion = requiresRasterExpansion
        self.blockingEffectIDs = blockingEffectIDs
    }
}

public enum ExpandAppearanceV6 {
    public static func expand(appearance: AppearanceStackV6) -> ExpandAppearanceResultV6 {
        let enabledEffects = appearance.entries.compactMap { entry -> LiveEffectV6? in
            guard case .effect(let effect) = entry, effect.enabled else { return nil }
            return effect
        }
        let blocking = enabledEffects.compactMap { effect -> String? in
            guard EffectRegistryV6.descriptor(id: effect.effectID)?.requiresRasterExpansion == true else { return nil }
            return effect.effectID
        }
        let vectorEffects = enabledEffects.filter { EffectRegistryV6.descriptor(id: $0.effectID)?.vectorExpandable == true && $0.effectID != "transform" }
        let transform = enabledEffects.last(where: { $0.effectID == "transform" })
        let copies = max(0, transform?.parameters["copies"]?.integerValue ?? 0)
        let instanceCount = copies + 1

        var pieces: [ExpandedAppearancePieceV6] = []
        for entry in appearance.entries {
            guard entry.enabled else { continue }
            switch entry {
            case .fill, .stroke:
                for copyIndex in 0..<instanceCount {
                    let multiplier = Double(copyIndex)
                    pieces.append(ExpandedAppearancePieceV6(
                        sourceEntryID: entry.id,
                        entry: entry,
                        copyIndex: copyIndex,
                        translationX: (transform?.parameters["x"]?.numberValue ?? 0) * multiplier,
                        translationY: (transform?.parameters["y"]?.numberValue ?? 0) * multiplier,
                        scaleX: pow(max(0.01, transform?.parameters["scaleX"]?.numberValue ?? 1), multiplier),
                        scaleY: pow(max(0.01, transform?.parameters["scaleY"]?.numberValue ?? 1), multiplier),
                        rotationDegrees: (transform?.parameters["rotation"]?.numberValue ?? 0) * multiplier,
                        geometryEffects: vectorEffects
                    ))
                }
            case .effect:
                continue
            }
        }
        return ExpandAppearanceResultV6(pieces: pieces, requiresRasterExpansion: !blocking.isEmpty, blockingEffectIDs: blocking)
    }
}
