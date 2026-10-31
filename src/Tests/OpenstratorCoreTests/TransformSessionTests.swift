import XCTest
@testable import OpenstratorCore

final class TransformSessionTests: XCTestCase {
    let id = NodeID(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)

    func testMoveUsesOriginalSnapshotInsteadOfAccumulatingDeltas() {
        let session = MoveSession(startPointer: CGPoint(x: 10, y: 10), originals: [id: .identity])
        let a = session.transforms(currentPointer: CGPoint(x: 20, y: 10))
        let b = session.transforms(currentPointer: CGPoint(x: 35, y: 10))
        XCTAssertEqual(a[id]?.translationX, 10)
        XCTAssertEqual(b[id]?.translationX, 25)
    }

    func testResizeModifierSemantics() {
        let originals = [id: NodeTransform.identity]
        let s = ResizeSession(originalBounds: CGRect(x: 100, y: 100, width: 200, height: 100), originals: originals, handle: .bottomRight, startPointer: CGPoint(x: 300, y: 200))
        let plain = s.result(pointerDocumentPoint: CGPoint(x: 400, y: 260), modifiers: [])
        XCTAssertEqual(plain.bounds.width, 300, accuracy: 0.001)
        XCTAssertEqual(plain.bounds.height, 160, accuracy: 0.001)

        let shift = s.result(pointerDocumentPoint: CGPoint(x: 400, y: 260), modifiers: [.preserveAspect])
        XCTAssertEqual(shift.bounds.width, 300, accuracy: 0.001)
        XCTAssertEqual(shift.bounds.height, 150, accuracy: 0.001)

        let option = s.result(pointerDocumentPoint: CGPoint(x: 400, y: 260), modifiers: [.fromCenter])
        XCTAssertEqual(option.bounds.midX, 200, accuracy: 0.001)
        XCTAssertEqual(option.bounds.midY, 150, accuracy: 0.001)

        let both = s.result(pointerDocumentPoint: CGPoint(x: 400, y: 260), modifiers: [.preserveAspect, .fromCenter])
        XCTAssertEqual(both.bounds.midX, 200, accuracy: 0.001)
        XCTAssertEqual(both.bounds.midY, 150, accuracy: 0.001)
        XCTAssertEqual(both.bounds.width / both.bounds.height, 2, accuracy: 0.001)
    }

    func testCrossingOppositeCornerNormalizesAndClampsMinimum() {
        let s = ResizeSession(originalBounds: CGRect(x: 100, y: 100, width: 200, height: 100), originals: [id:.identity], handle: .bottomRight, startPointer: CGPoint(x: 300, y: 200))
        let r = s.result(pointerDocumentPoint: CGPoint(x: 99, y: 99), modifiers: [])
        XCTAssertGreaterThanOrEqual(r.bounds.width, 4)
        XCTAssertGreaterThanOrEqual(r.bounds.height, 4)
        XCTAssertTrue(r.bounds.width.isFinite && r.bounds.height.isFinite)
    }
}
