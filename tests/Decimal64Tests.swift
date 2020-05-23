import Decimals
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
}

//extension Decimal64Test {
//    var s = ""
//
//    func testtoMaxDigits() {
//        // This is an example of a functional test case.
//        // Use XCTAssert and related functions to verify your tests produce the correct results.
//        var a: Int64 = 1
//        for _ in 1...16 {
//            var b = a
//            _ = toMaximumDigits(&b)
//            XCTAssert(b.description.count == 16)
//            a *= 10
//        }
//    }
//
//    func testCompareLess() {
//        // This is an example of a functional test case.
//        // Use XCTAssert and related functions to verify your tests produce the correct results.
//        let a = Decimal64(10, withExponent: -1 )!
//        let b = Decimal64(90, withExponent: -2 )!
//        XCTAssert(a > b)
//        let c = Decimal64( -12345245245253, withExponent: 20 )!
//        let d = Decimal64( 123, withExponent: 10 )!
//        XCTAssert(c < d)
//    }
//
//    func testCompareEqual() {
//        // This is an example of a functional test case.
//        // Use XCTAssert and related functions to verify your tests produce the correct results.
//        let a = Decimal64(10, withExponent: -1 )!
//        let b = Decimal64(100, withExponent: -2 )!
//        XCTAssert(a == b)
//    }
//
//    func testPerformanceDouble() {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//            for i in 1...10 {
//                s = testDouble(start: Double(Double(i)/10))
//            }
//        }
//    }
//
//    func testPerformanceDecimal() {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//            for i in 1...10 {
//                s = testDecimal(start: Decimal(Double(i)/10))
//            }
//        }
//    }
//
//    func testPerformanceDecimalFP64() {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//            for i in 1...10 {
//                s = testDecimalFP64(start: DecimalFP64(Double(i)/10))
//            }
//        }
//    }
//
//    func testPerformanceDecimal64() {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//            for i in 1...10 {
//                s = testDecimal64(start: Decimal64(Double(i)/10)!)
//            }
//        }
//    }
//
//    func testPerformanceDecimalFP64Template() {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//            for i in 1...10 {
//                s = templTest(start: DecimalFP64(Double(i)/10))
//            }
//        }
//    }
//
//    func testPerformanceDoubleTemplate() {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//            for i in 1...10 {
//                s = templTest(start: Double(Double(i)/10))
//            }
//        }
//    }
//}
