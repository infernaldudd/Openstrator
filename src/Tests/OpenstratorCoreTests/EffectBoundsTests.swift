import XCTest
@testable import OpenstratorCore

final class EffectBoundsTests: XCTestCase {
    private let rect = CGRect(x: 10, y: 20, width: 100, height: 60)

    func testBlurInflatesAllSidesWithoutChangingInput() {
        var effect = EffectRegistryV6.descriptor(id: "gaussianBlur")!.makeDefaultEffect()
        effect.parameters["radius"] = .number(10)
        let stack = AppearanceStackV6(entries: [.effect(effect)])
        let result = EffectBoundsV6.visualBounds(geometricBounds: rect, appearance: stack)
        XCTAssertEqual(result, rect.insetBy(dx: -20, dy: -20))
        XCTAssertEqual(rect, CGRect(x: 10, y: 20, width: 100, height: 60))
    }

    func testShadowIncludesSignedOffsetAndBlur() {
        var effect = EffectRegistryV6.descriptor(id: "dropShadow")!.makeDefaultEffect()
        effect.parameters["x"] = .number(-12)
        effect.parameters["y"] = .number(8)
        effect.parameters["blur"] = .number(5)
        let result = EffectBoundsV6.visualBounds(geometricBounds: rect, appearance: AppearanceStackV6(entries: [.effect(effect)]))
        let shadow = rect.offsetBy(dx: -12, dy: 8).insetBy(dx: -10, dy: -10)
        XCTAssertEqual(result, rect.union(shadow))
    }

    func testGlowInflatesSymmetricallyAndDisabledEffectAddsNothing() {
        var glow = EffectRegistryV6.descriptor(id: "outerGlow")!.makeDefaultEffect()
        glow.parameters["blur"] = .number(7)
        XCTAssertEqual(EffectBoundsV6.visualBounds(geometricBounds: rect, appearance: .init(entries: [.effect(glow)])), rect.insetBy(dx: -14, dy: -14))
        glow.enabled = false
        XCTAssertEqual(EffectBoundsV6.visualBounds(geometricBounds: rect, appearance: .init(entries: [.effect(glow)])), rect)
    }

    func testTransformCopiesUnionSuccessiveTranslations() {
        var effect = EffectRegistryV6.descriptor(id: "transform")!.makeDefaultEffect()
        effect.parameters["x"] = .number(20)
        effect.parameters["y"] = .number(-5)
        effect.parameters["copies"] = .integer(2)
        let result = EffectBoundsV6.visualBounds(geometricBounds: rect, appearance: .init(entries: [.effect(effect)]))
        XCTAssertEqual(result, rect.union(rect.offsetBy(dx: 20, dy: -5)).union(rect.offsetBy(dx: 40, dy: -10)))
    }
}
