import Decimals
import XCTest

/// Tests decimal number regular cases.
final class DecimalFP64Test: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
}

extension DecimalFP64Test {
    /// Test `Double` conversion.
    func testDouble() {
        let numbers: [Double] = [3.14, -3.14, 0.0, .infinity, -.infinity, .nan, .signalingNaN]
        let results: [DecimalFP64] = ["3.14", "-3.14", .zero, .infinity, -.infinity, .nan, .signalingNaN]
        XCTAssertEqual(numbers.map { DecimalFP64($0) }, results)
    }
}
