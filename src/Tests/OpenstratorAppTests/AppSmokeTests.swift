#if os(macOS)
import XCTest
@testable import Openstrator

final class AppSmokeTests: XCTestCase {
    func testAppTargetLoads() {
        XCTAssertTrue(true)
    }
}
#endif
