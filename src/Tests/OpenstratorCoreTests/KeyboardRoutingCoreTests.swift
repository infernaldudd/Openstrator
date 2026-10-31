import XCTest
@testable import OpenstratorCore

final class KeyboardRoutingCoreTests: XCTestCase {
    func testDeleteIsHandledOnlyWhenCanvasOwnsItAndThereIsSelection() {
        XCTAssertTrue(CanvasKeyRouting.shouldHandleDelete(keyCode: 51, hasSelection: true, textEditingActive: false))
        XCTAssertTrue(CanvasKeyRouting.shouldHandleDelete(keyCode: 117, hasSelection: true, textEditingActive: false))
        XCTAssertFalse(CanvasKeyRouting.shouldHandleDelete(keyCode: 51, hasSelection: false, textEditingActive: false))
        XCTAssertFalse(CanvasKeyRouting.shouldHandleDelete(keyCode: 51, hasSelection: true, textEditingActive: true))
    }
}
