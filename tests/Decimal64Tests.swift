@testable import Decimals
import XCTest

/// Tests decimal number regular cases.
final class Decimal64Test: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
}

extension Decimal64Test {
    /// Tests the π and 𝝉 math constants.
    func testMathConstants() {
        let hardcodedπ = Decimal64("3.141592653589793")
        let generatedπ = Decimal64.pi
        XCTAssertEqual(hardcodedπ, generatedπ)
        
        let hardcoded𝝉 = Decimal64("6.283185307179586")
        let generated𝝉 = Decimal64.tau
        XCTAssertEqual(hardcoded𝝉, generated𝝉)
    }
    
    /// Test `Double` conversion.
    func testDouble() {
        let numbers: [Double] = [3.14, -3.14, 0.0, .infinity, -.infinity, .nan]
        let results: [Decimal64?] = ["3.14", "-3.14", .zero, nil, nil, nil]
        XCTAssertEqual(numbers.map(Decimal64.init), results)
    }
    
    /// Test the comparable functions.
    func testSorting() {
        let doubles = (0..<1_000).map { _ in ceil(Double.random(in: -1000...1000) * 10_000) / 10_000 }
        let decimals = doubles.map { Decimal64(String($0))! }
        XCTAssertEqual(doubles.sorted().map { Decimal64($0)! }, decimals.sorted())
    }
    
    /// Test the `round()` functionality.
    func testRound() {
        let numbers: [Decimal64]   =  ["-5.6", "-5.5", "-5.4", "-5", "0", "5", "5.4", "5.5", "5.6", "6.5", "6.666"]
        let dict: [FloatingPointRoundingRule:[Decimal64]] = [
            .up:                      [  "-5",   "-5",   "-5", "-5", "0", "5",   "6",   "6",   "6",   "7",    "7"],
            .down:                    [  "-6",   "-6",   "-6", "-5", "0", "5",   "5",   "5",   "5",   "6",    "6"],
            .towardZero:              [  "-5",   "-5",   "-5", "-5", "0", "5",   "5",   "5",   "5",   "6",    "6"],
            .awayFromZero:            [  "-6",   "-6",   "-6", "-5", "0", "5",   "6",   "6",   "6",   "7",    "7"],
            .toNearestOrAwayFromZero: [  "-6",   "-6",   "-5", "-5", "0", "5",   "5",   "6",   "6",   "7",    "7"],
            .toNearestOrEven:         [  "-6",   "-6",   "-5", "-5", "0", "5",   "5",   "6",   "6",   "6",    "7"]
        ]
        
        for (rule, results) in dict {
            XCTAssertEqual(numbers.map { $0.rounded(rule, scale: 0) }, results)
        }
        
        let decimal: Decimal64 = "736.3067895123"
        XCTAssertEqual(decimal.rounded(.toNearestOrEven, scale: 7), "736.3067895")
    }
    
    /// Test the `decomposed()` functionality.
    func testDecompose() {
        let numbers: [Decimal64] = ["3.14", "-3.14", .zero]
        let results: [(integral: Decimal64, fractional: Decimal64)] = [(3, "0.14"), (-3, "0.14"), (0, 0)]
        
        for (input, output) in zip(numbers, results) {
            let d = input.decomposed()
            XCTAssertEqual(d.integral, output.integral)
            XCTAssertEqual(d.fractional, output.fractional)
        }
    }
}
