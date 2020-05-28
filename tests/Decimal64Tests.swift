import Decimals
import XCTest

/// Tests decimal number regular cases.
final class Decimal64Test: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = true
    }
}

extension Decimal64Test {
    /// Tests the lowest-level public initializer.
    func testLowLevelInitializers() {
        let results: [String] = ["-3.333", "-1", "-0.5", "-0.1", "0", "0.1", "0.5", "1", "3.333"]
        let input = [
            Decimal64(-3333, power: -3)!, Decimal64(-1, power: 0)!, Decimal64(-5, power: -1)!, Decimal64(-1, power: -1)!, .zero,
            Decimal64(1, power: -1)!, Decimal64(5, power: -1)!, Decimal64(1, power: 0)!, Decimal64(3333, power: -3)!
        ]
        XCTAssertEqual(input.map { $0.description }, results)
    }
    
    /// Tests the string initializer works on certain cases.
    func testLiteralInitializers() {
        let results: [String] = ["-3.333", "-1", "-0.5", "-0.1", "0", "0.1", "0.5", "1", "3.333"]
        
        let floatLiterals: [Decimal64] = [-3.333, -1, -0.5, -0.1, 0, 0.1, 0.5, 1, 3.333]
        XCTAssertEqual(floatLiterals.map { $0.description }, results)
        
        let stringLiterals: [Decimal64] = results.map { Decimal64(stringLiteral: $0) }
        XCTAssertEqual(stringLiterals.map { $0.description }, results)
    }
    
    /// Tests the zero, π and, 𝝉 math constants.
    func testMathConstants() {
        let zeros: [Decimal64] = [.zero, "0", -0.0, Decimal64(0, power: 5)!, Decimal64(0, power: -5)!]
        XCTAssertTrue(zeros.allSatisfy { $0.isZero })
        XCTAssertTrue(zeros.allSatisfy { $0 == .zero })
        
        let hardcodedπ = Decimal64("3.141592653589793")
        let generatedπ = Decimal64.pi
        XCTAssertEqual(hardcodedπ, generatedπ)

        let hardcoded𝝉 = Decimal64("6.283185307179586")
        let generated𝝉 = Decimal64.tau
        XCTAssertEqual(hardcoded𝝉, generated𝝉)
    }
}

extension Decimal64Test {
    /// Tests the equality operations.
    func testEquality() {
        let result: [Decimal64] = ["-3.333", "-1", "-0.5", "-0.1", "0", "0.1", "0.5", "1", "3.333"]
        let left = [
            Decimal64(-3333, power: -3)!, Decimal64(-1, power: 0)!, Decimal64(-5, power: -1)!, Decimal64(-1, power: -1)!, .zero,
            Decimal64(1, power: -1)!, Decimal64(5, power: -1)!, Decimal64(1, power: 0)!, Decimal64(3333, power: -3)!
        ]
        XCTAssertEqual(left, result)
        
        let right = [
            Decimal64(-33330, power: -4)!, Decimal64(-100, power: -2)!, Decimal64(-5000, power: -4)!, Decimal64(-10, power: -2)!, Decimal64(0, power: 10)!,
            Decimal64(100, power: -3)!, Decimal64(50, power: -2)!, Decimal64(10, power: -1)!, Decimal64(333300, power: -5)!
        ]
        XCTAssertEqual(right, result)
        XCTAssertEqual(left, right)
        
        let leftTau = Decimal64(6283185307179580, power: -15)!
        let rightTau = Decimal64(628318530717958, power: -14)!
        XCTAssertEqual(leftTau, rightTau)
    }
    
    /// Tests the _less-than_ operator.
    func testComparable() {
        let left:  [Decimal64] = ["-3.333", "-1",  "-0.5", "-0.1", "0", "0.1", "0.5", "1", "3.333"]
        let right: [Decimal64] = ["+3.333", "-1", "-0.51",    "0", "0",  "-7", "789", "1", "3.3333"]
        let lessComparison: [Bool] = [true, false,  false,   true, false, false, true, false, true]
        XCTAssertEqual(zip(left, right).map { $0 < $1 }, lessComparison)
    }
    
    /// Tests the `AdditiveArithmetic` protocol conformance.
    func testAdditiveArithmetic() {
        let input: [Decimal64] = [-.pi, "-10", "-3.14", .zero, "10", .tau]
        XCTAssertEqual(input.map { $0 + 2 }, ["-1.141592653589793", -8, "-1.14", 2, 12, "8.283185307179586"] as [Decimal64])
        XCTAssertEqual(input.map { $0 - 2 }, ["-5.141592653589793", -12, "-5.14", -2, 8, "4.283185307179586"] as [Decimal64])
        XCTAssertEqual(input.map { $0 + $0 }, ["-6.283185307179586", -20, "-6.28", 0, 20, "12.56637061435917"] as [Decimal64])
        XCTAssertEqual(input.map { $0 - $0 }, input.map { _ in .zero })
    }
    
    /// Tests the multiplication operator.
    func testMultiplication() {
        let left:  [Decimal64] = ["-3.333",     "-1",  "-0.5", "-0.1", 0,  "0.1",   "0.5", 1,     "3.333", .pi]
        let right: [Decimal64] = ["+3.333",     "-1", "-0.51",      0, 0,   "-7",   "789", 1,    "3.3333",  -2]
        let result: [Decimal64] = ["-11.108889", "1", "0.255",      0, 0, "-0.7", "394.5", 1, "11.1098889", "-6.283185307179586"]
        XCTAssertEqual(zip(left, right).map { $0 * $1 }, result)
    }
    
    /// Tests the division operator.
    func testDivision() {
        let left:  [Decimal64] = ["-3.333", "-1", "-0.5", "-0.1", "0.1", "0.5", 1, "3.333", .pi]
        XCTAssertEqual(left.map { $0 / $0 }, Array(repeating: 1, count: left.count))
        XCTAssertEqual(Decimal64.tau / Decimal64.pi, 2)
        XCTAssertEqual(Decimal64(integerLiteral: -8) / 2, Decimal64(integerLiteral: -4))
    }
    
    /// Tests the negation operator.
    func testNegation() {
        let inputStrings: [String] = [(-Decimal64.pi).description, "-3.333", "-1", "-0.5", "-0.1", "0", "0.1", "0.5", "1", "3.333", Decimal64.tau.description]
        let outputStrings: [String] = inputStrings.map {
            var result = $0
            if $0.hasPrefix("-") {
                result.removeFirst()
            } else if $0 != "0" {
                result.insert("-", at: result.startIndex)
            }
            return result
        }

        let input = inputStrings.map { Decimal64($0)! }
        XCTAssertEqual(input.map { $0.description }, inputStrings)
        
        let output = outputStrings.map { Decimal64($0)! }
        XCTAssertEqual(output.map { $0.description }, outputStrings)
        
        XCTAssertEqual(input.map { -$0 }, output)
        XCTAssertEqual(input.map { $0 * -1 }, output)
    }
    
    /// Tests the decimal shifting operators.
    func testDecimalShifting() {
        let numbers: [Decimal64] = [.pi, -.tau, .zero, "-10", "10"]
        
        let rightResult: [Decimal64] = ["0.00003141592653589793", "-0.00006283185307179586", 0, "-0.0001", "0.0001"]
        XCTAssertEqual(numbers.map { $0 >> 5 }, rightResult)
        
        let leftResult: [Decimal64] = ["3141.592653589793", "-6283.185307179586", 0, -10000, 10000]
        XCTAssertEqual(numbers.map { $0 << 3 }, leftResult)
    }

    /// Tests the comparable functions.
    func testSorting() {
        let doubles = (0..<1_000).map { _ in ceil(Double.random(in: -1000...1000) * 10_000) / 10_000 }
        let decimals = doubles.map { Decimal64(String($0))! }
        XCTAssertEqual(doubles.sorted().map { Decimal64($0)! }, decimals.sorted())
    }
    
    /// Tests the `round()` functionality.
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
    
    /// Tests the `decomposed()` functionality.
    func testDecompose() {
        let numbers: [Decimal64] = ["3.14", "-3.14", .zero]
        let results: [(integral: Decimal64, fractional: Decimal64)] = [(3, "0.14"), (-3, "0.14"), (0, 0)]
        
        for (input, output) in zip(numbers, results) {
            let d = input.decomposed()
            XCTAssertEqual(d.integral, output.integral)
            XCTAssertEqual(d.fractional, output.fractional)
        }
    }
    
    func testSomething() {
        print(Decimal64.tau)
        print(Decimal64.tau << 2)
        print(Decimal64.tau >> 2)
    }
}
