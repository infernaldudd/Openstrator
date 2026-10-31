import XCTest
@testable import OpenstratorCore

final class CoreSmokeTests: XCTestCase {
    func testCoreExposesV6FormatVersion() {
        XCTAssertEqual(OpenstratorCoreInfo.documentFormatVersion, 6)
    }
}
