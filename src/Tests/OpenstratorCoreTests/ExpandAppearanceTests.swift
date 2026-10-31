import XCTest
@testable import OpenstratorCore

final class ExpandAppearanceTests: XCTestCase {
    func testTwoFillsAndTwoStrokesPreserveStackOrdering() throws {
        let f1 = FillAppearanceV6(id: UUID(), paint: .color(.white))
        let s1 = StrokeAppearanceV6(id: UUID(), paint: .color(.black), width: 2)
        let f2 = FillAppearanceV6(id: UUID(), paint: .color(.black))
        let s2 = StrokeAppearanceV6(id: UUID(), paint: .color(.white), width: 5)
        let stack = AppearanceStackV6(entries: [.fill(f1), .stroke(s1), .fill(f2), .stroke(s2)])
        let result = ExpandAppearanceV6.expand(appearance: stack)
        XCTAssertFalse(result.requiresRasterExpansion)
        XCTAssertEqual(result.pieces.map(\.sourceEntryID), [f1.id, s1.id, f2.id, s2.id])
        XCTAssertEqual(result.pieces.map(\.copyIndex), [0,0,0,0])
    }

    func testTransformCopiesExpandEveryPaintEntry() throws {
        let fill = FillAppearanceV6(id: UUID(), paint: .color(.white))
        var transform = EffectRegistryV6.descriptor(id: "transform")!.makeDefaultEffect()
        transform.parameters["x"] = .number(10)
        transform.parameters["copies"] = .integer(2)
        let result = ExpandAppearanceV6.expand(appearance: .init(entries: [.fill(fill), .effect(transform)]))
        XCTAssertEqual(result.pieces.count, 3)
        XCTAssertEqual(result.pieces.map(\.copyIndex), [0,1,2])
        XCTAssertEqual(result.pieces.map(\.sourceEntryID), [fill.id,fill.id,fill.id])
        XCTAssertEqual(result.pieces[2].translationX, 20)
    }

    func testRasterDependentEffectBlocksVectorExpansion() {
        let fill = FillAppearanceV6(paint: .color(.white))
        let blur = EffectRegistryV6.descriptor(id: "gaussianBlur")!.makeDefaultEffect()
        let result = ExpandAppearanceV6.expand(appearance: .init(entries: [.fill(fill), .effect(blur)]))
        XCTAssertTrue(result.requiresRasterExpansion)
        XCTAssertEqual(result.blockingEffectIDs, ["gaussianBlur"])
    }
}
