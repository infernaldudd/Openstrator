import XCTest
@testable import OpenstratorCore

final class AppearanceMigrationTests: XCTestCase {
    func testLegacyFillGradientStrokeAndDashBecomeOrderedStack() {
        let legacy = AppearanceV6(
            fill: RGBAColorV6(r: 1, g: 0, b: 0),
            gradient: LinearGradientV6(angleDegrees: 45, stops: [GradientStopV6(location: 0, color: .white), GradientStopV6(location: 1, color: .black)]),
            stroke: StrokeV6(color: .black, width: 5, dash: [4,2], cap: "round", join: "bevel"),
            effects: []
        )
        let stack = AppearanceMigrationV6.stack(from: legacy, opacity: 0.8, blendMode: .multiply)
        XCTAssertEqual(stack.opacity, 0.8)
        XCTAssertEqual(stack.blendMode, .multiply)
        XCTAssertEqual(stack.entries.count, 2)
        guard case .fill(let fill) = stack.entries[0] else { return XCTFail("fill first") }
        guard case .linearGradient = fill.paint else { return XCTFail("gradient preserved") }
        guard case .stroke(let stroke) = stack.entries[1] else { return XCTFail("stroke second") }
        XCTAssertEqual(stroke.width, 5)
        XCTAssertEqual(stroke.dash, [4,2])
        XCTAssertEqual(stroke.cap, "round")
        XCTAssertEqual(stroke.join, "bevel")
    }

    func testLegacyEffectsPreserveOrderAndEnabledState() {
        let legacy = AppearanceV6(fill: .white, effects: [
            LegacyEffectV6(kind: "gaussianBlur", amount: 12, enabled: true),
            LegacyEffectV6(kind: "shadow", amount: 7, enabled: false)
        ])
        let stack = AppearanceMigrationV6.stack(from: legacy)
        let effects = stack.entries.compactMap { entry -> LiveEffectV6? in
            if case .effect(let effect) = entry { return effect }
            return nil
        }
        XCTAssertEqual(effects.map(\.effectID), ["gaussianBlur","dropShadow"])
        XCTAssertEqual(effects.map(\.enabled), [true,false])
        XCTAssertEqual(effects[0].parameters["radius"], .number(12))
    }
}
