import Decimals
import XCTest

/// Tests decimal number regular cases.
final class ConversionTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
}

extension ConversionTests {
    /// Tests conversion from `Decimal64` to integer values.
    func testIntegerConversion() {
        let decimals: [Decimal64]  = ["-876", "-123.5678201", "-0.1", "0", "0.7", "1", "32578.5678"]
        let signedResult: [Int]    = [-876, -123, 0, 0, 0, 1, 32578]
        let unsignedResult: [UInt] = [0, 0, 0, 0, 0, 1, 32578]
        XCTAssertEqual(decimals.map { Int(clamping: $0) }, signedResult)
        XCTAssertEqual(decimals.map { UInt(clamping: $0) }, unsignedResult)
    }
    
    /// Tests conversion from `Decimal64` to binary floating-point values.
    func testFloatingPointConversion() {
        let decimals: [Decimal64] = ["-876", "-123.5678201", "-0.1", "0", "0.7", "1", "32578.5678"]
        let doubles: [Double]     = [-876, -123.5678201, -0.1, 0, 0.7, 1, 32578.5678]
        XCTAssertEqual(decimals.map { Double($0) }, doubles)
        XCTAssertEqual(doubles.map { Decimal64($0) }, decimals)
    }
    
    /// Test `Double` conversion.
    func testDoubleConversion() {
        let numbers: [Double] = [3.14, -3.14, 0.0, .infinity, -.infinity, .nan]
        let results: [Decimal64?] = ["3.14", "-3.14", .zero, nil, nil, nil]
        XCTAssertEqual(numbers.map(Decimal64.init), results)
    }
}
