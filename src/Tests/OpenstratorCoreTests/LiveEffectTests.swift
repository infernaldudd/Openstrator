import XCTest
@testable import OpenstratorCore

final class LiveEffectTests: XCTestCase {
    func testDropShadowDescriptorProvidesTypedDefaults() throws {
        let descriptor = try XCTUnwrap(EffectRegistryV6.descriptor(id: "dropShadow"))
        XCTAssertEqual(descriptor.serializationVersion, 1)
        XCTAssertNotNil(descriptor.parameters["x"])
        XCTAssertNotNil(descriptor.parameters["blur"])
        XCTAssertNotNil(descriptor.parameters["opacity"])
        let effect = descriptor.makeDefaultEffect()
        XCTAssertEqual(effect.effectID, "dropShadow")
        XCTAssertEqual(effect.parameters["opacity"], .number(0.35))
    }

    func testValidationClampsRangesAndRejectsUnknownParameter() throws {
        var effect = EffectRegistryV6.descriptor(id: "gaussianBlur")!.makeDefaultEffect()
        effect.parameters["radius"] = .number(10_000)
        let validated = try EffectRegistryV6.validate(effect)
        XCTAssertEqual(validated.parameters["radius"], .number(250))

        effect.parameters["mystery"] = .number(1)
        XCTAssertThrowsError(try EffectRegistryV6.validate(effect))
    }

    func testLiveEffectCodableRoundTripKeepsStableIDs() throws {
        let id = UUID()
        let effect = LiveEffectV6(id: id, effectID: "motionBlur", enabled: true, parameters: ["distance": .number(24), "angle": .number(45)], serializationVersion: 1)
        let data = try JSONEncoder().encode(effect)
        let decoded = try JSONDecoder().decode(LiveEffectV6.self, from: data)
        XCTAssertEqual(decoded, effect)
        XCTAssertEqual(decoded.id, id)
    }

    func testAppearanceEntryCanCarryLiveEffect() throws {
        let effect = EffectRegistryV6.descriptor(id: "roundCorners")!.makeDefaultEffect()
        let stack = AppearanceStackV6(entries: [.effect(effect)])
        XCTAssertEqual(stack.entries.first?.id, effect.id)
    }

    func testRequiredM4EffectIDsExist() {
        let ids = ["gaussianBlur","motionBlur","dropShadow","outerGlow","innerShadow","innerGlow","roughen","zigZag","puckerBloat","transform","offsetPath","roundCorners","convertRectangle","convertRoundedRectangle","convertEllipse","warp"]
        for id in ids { XCTAssertNotNil(EffectRegistryV6.descriptor(id: id), id) }
    }
}
