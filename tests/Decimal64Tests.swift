@testable import Decimals
import XCTest

/// Tests decimal number regular cases.
final class Decimal64Test: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
}

extension Decimal64Test {
    /// Test the string initializer works on certain cases.
    func testInitializers() {
        let results: [String] = ["-3.333", "-1", "-0.5", "-0.1", "0", "0.1", "0.5", "1", "3.333"]
        
        let floatLiterals: [Decimal64] = [-3.333, -1, -0.5, -0.1, 0, 0.1, 0.5, 1, 3.333]
        XCTAssertEqual(floatLiterals.map { $0.description }, results)
        
        let stringLiterals: [Decimal64] = results.map { Decimal64(stringLiteral: $0) }
        XCTAssertEqual(stringLiterals.map { $0.description }, results)
        
        let specific: [Decimal64] = [Decimal64(-3333, raisedBy: -3)!, Decimal64(-1, raisedBy: 0)!, Decimal64(-5, raisedBy: -1)!, Decimal64(-1, raisedBy: -1)!, .zero, Decimal64(1, raisedBy: -1)!, Decimal64(5, raisedBy: -1)!, Decimal64(1, raisedBy: 0)!, Decimal64(3333, raisedBy: -3)!]
        XCTAssertEqual(specific.map { $0.description }, results)
    }
    
    /// Tests the π and 𝝉 math constants.
    func testMathConstants() {
        let hardcodedπ = Decimal64("3.141592653589793")
        let generatedπ = Decimal64.pi
        XCTAssertEqual(hardcodedπ, generatedπ)
        
        let hardcoded𝝉 = Decimal64("6.283185307179586")
        let generated𝝉 = Decimal64.tau
        XCTAssertEqual(hardcoded𝝉, generated𝝉)
    }
}

extension Decimal64Test {
    /// Test the negation operator.
//    func testNegate() {
//        let input: [String] = [(-Decimal64.pi).description, "-3.333", "-1", "-0.5", "-0.1", "0", "0.1", "0.5", "1", "3.333", Decimal64.tau.description]
//        let output: [String] = input.map {
//            var result = $0
//            if $0.hasPrefix("-") {
//                result.removeFirst()
//            } else {
//                result.insert("-", at: result.startIndex)
//            }
//            return result
//        }
//        
//        print(input)
//        print(input.map { Decimal64($0)! })
//        print(input.map { -(Decimal64($0)!) })
//    }
    
    func testSum() {
        let left: [Decimal64] = [-.pi, "-10", "-3.14", .zero, "10"]
        print(left.map { $0 + 2 })
    }
    
//    func testDecimalShifting() {
//        let first: Decimal64 = 1
//        print("\(first): \(first._data.binary)")
//        print("\tsignificand: \(first.significand)")
//        print("\texponent:    \(first.exponent)")
//        print("\top: \(first >> 1)")
//
//        let second: Decimal64 = -10
//        print("\(second): \(second._data.binary)")
//        print("\tsignificand: \(second.significand)")
//        print("\texponent:    \(second.exponent)")
//        print("\top: \(second >> 1)")
//
//        let numbers: [Decimal64] = [.pi, -.tau, .zero, "-10", "10"]
//        print(numbers)
//        print(numbers.map { $0 >> 1 })
//    }
}

extension Decimal64Test {
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
