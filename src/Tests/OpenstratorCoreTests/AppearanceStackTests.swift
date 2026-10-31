import XCTest
@testable import OpenstratorCore

final class AppearanceStackTests: XCTestCase {
    func testOrderedEntriesPreserveIDsAndOrderThroughCodable() throws {
        let fill = FillAppearanceV6(id: UUID(), paint: .color(.white))
        let stroke = StrokeAppearanceV6(id: UUID(), paint: .color(.black), width: 3)
        let stack = AppearanceStackV6(entries: [.stroke(stroke), .fill(fill)], opacity: 0.7, blendMode: .multiply)
        let data = try JSONEncoder().encode(stack)
        let decoded = try JSONDecoder().decode(AppearanceStackV6.self, from: data)
        XCTAssertEqual(decoded, stack)
        XCTAssertEqual(decoded.entries.map(\.id), [stroke.id, fill.id])
    }

    func testMultipleAndZeroFillsAndStrokesAreLegal() {
        let empty = AppearanceStackV6(entries: [])
        XCTAssertTrue(empty.entries.isEmpty)
        let stack = AppearanceStackV6(entries: [
            .fill(FillAppearanceV6(paint: .color(.white))),
            .fill(FillAppearanceV6(paint: .color(.black))),
            .stroke(StrokeAppearanceV6(paint: .color(.white), width: 1)),
            .stroke(StrokeAppearanceV6(paint: .color(.black), width: 5))
        ])
        XCTAssertEqual(stack.entries.count, 4)
    }

    func testOpacityNormalizesToUnitInterval() {
        var high = AppearanceStackV6(entries: [], opacity: 4)
        high.normalize()
        XCTAssertEqual(high.opacity, 1)
        var low = AppearanceStackV6(entries: [], opacity: -2)
        low.normalize()
        XCTAssertEqual(low.opacity, 0)
    }
}
