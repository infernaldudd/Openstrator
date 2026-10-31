import XCTest
@testable import OpenstratorCore

final class TextFlowTests: XCTestCase {
    func testAreaFlowPreservesOverflowAcrossFrames() throws {
        let a = TextDataV6(text: "", frame: CGRect(x: 0, y: 0, width: 90, height: 48), layoutMode: .area,
                           character: CharacterStyleV6(fontSize: 12, leading: 14))
        let b = TextDataV6(text: "", frame: CGRect(x: 100, y: 0, width: 90, height: 48), layoutMode: .area,
                           character: CharacterStyleV6(fontSize: 12, leading: 14))
        let text = String(repeating: "A", count: 100)
        let result = TextThreadEngine.flow(text: text, frames: [a, b])
        XCTAssertEqual(result.frames.count, 2)
        XCTAssertEqual(result.frames.map(\.visibleText).joined() + result.overflow, text)
        XCTAssertFalse(result.overflow.isEmpty)
    }

    func testVerticalAreaCapacityUsesRowsAndColumns() {
        let data = TextDataV6(text: "", frame: CGRect(x: 0, y: 0, width: 48, height: 90), layoutMode: .verticalArea,
                              character: CharacterStyleV6(fontSize: 12, leading: 14))
        XCTAssertGreaterThan(TextThreadEngine.capacity(for: data), 10)
    }

    func testThreadChainRejectsCycle() {
        let a = UUID(), b = UUID()
        let byID: [UUID: TextThreadV6] = [
            a: TextThreadV6(previousFrameID: b, nextFrameID: b),
            b: TextThreadV6(previousFrameID: a, nextFrameID: a)
        ]
        XCTAssertThrowsError(try TextThreadEngine.orderedChain(start: a, links: byID)) { error in
            XCTAssertEqual(error as? TextThreadError, .cycle)
        }
    }

    func testThreadChainStopsAtMissingReferenceWithoutLooping() throws {
        let a = UUID(), missing = UUID()
        let chain = try TextThreadEngine.orderedChain(start: a, links: [a: TextThreadV6(nextFrameID: missing)])
        XCTAssertEqual(chain, [a])
    }
}
