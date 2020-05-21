import Decimals
import XCTest

final class Decimal64Test: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
}

extension Decimal64Test {
    func testPi() {
        let hardcoded = Decimal64("3.141592653589793")
        let generated = Decimal64.pi
        XCTAssertEqual(hardcoded, generated)
    }
}

extension BinaryInteger {
    fileprivate var binaryDescription: String {
        var binaryString = ""
        var internalNumber = self
        var counter = 0
        
        for _ in (1...self.bitWidth) {
            binaryString.insert(contentsOf: "\(internalNumber & 1)", at: binaryString.startIndex)
            internalNumber >>= 1
            counter += 1
            if counter % 4 == 0 {
                binaryString.insert(contentsOf: " ", at: binaryString.startIndex)
            }
        }
        
        return binaryString
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
