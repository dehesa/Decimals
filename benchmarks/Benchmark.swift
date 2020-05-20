import Decimals
import Foundation

internal enum Benchmark {
    /// Benchmark for `Double` (64-bit) operations `+`, `*`, `/`, and conversion to `String`.
    /// - parameter start: The starting value for the calculations.
    /// - returns: A string result of the numbers (to compare results and to make sure that the string conversion is not optimized away)
    static func double(start: Double) -> String  {
        var s = start
        s /= Double(10) // my value in sec
        s /= Double(60) // my value in min
        var ret: String = ""
        for _ in 0...9999 {
            
            let ppm: Double = 9.9
            
            let net = s * ppm
            let taxrate = Double(19) / Double(100)
            let tax = net * taxrate
            let gross = net + tax
            
            ret = "\(s), net: \(net), tax: \(tax), gross: \(gross)"
            //        ret = s.description + ", net: " + net.description + ", tax: " + tax.description + ", gross: " + gross.description
            s += 1.1
        }
        return ret
    }
}

extension Benchmark {
    /// Benchmark for Foundation's `Decimal` (160-bit) operations `+`, `*`, `/`, and conversion to `String`.
    /// - parameter start: The starting value for the calculations.
    /// - returns: A string result of the numbers (to compare results and to make sure that the string conversion is not optimized away)
    static func decimal(start: Decimal) -> String  {
        var s = start
        s /= Decimal(10) // my value in sec
        s /= Decimal(60) // my value in min
        var ret: String = ""
        for _ in 0...9999 {
            
            let ppm: Decimal = 9.9
            
            let net = s * ppm
            let taxrate = Decimal(19) / Decimal(100)
            let tax = net * taxrate
            let gross = net + tax
            
            ret = "\(s), net: \(net), tax: \(tax), gross: \(gross)"
            s += 1.1
        }
        return ret
    }
}

extension Benchmark {
    /// Benchmark for `DecimalFP64` (64-bit) operations `+`, `*`, `/`, and conversion to `String`.
    /// - parameter start: The starting value for the calculations.
    /// - returns: A string result of the numbers (to compare results and to make sure that the string conversion is not optimized away)
    static func decimalFP64(start: DecimalFP64) -> String  {
        var s = start
        s /= DecimalFP64(10) // my value in sec
        s /= DecimalFP64(60) // my value in min
        var ret: String = ""
        for _ in 0...9999 {
            
            let ppm: DecimalFP64 = 9.9
            
            let net = s * ppm
            let taxrate = DecimalFP64(19) / DecimalFP64(100)
            let tax = net * taxrate
            let gross = net + tax
            
            ret = "\(s), net: \(net), tax: \(tax), gross: \(gross)"
            s += 1.1
        }
        return ret
    }
}

extension Benchmark {
    /// Benchmark for `Decimal` (64-bit) operations `+`, `*`, `/`, and conversion to `String`.
    /// - parameter start: The starting value for the calculations.
    /// - returns: A string result of the numbers (to compare results and to make sure that the string conversion is not optimized away)
    static func decimal64(start: Decimal64) -> String  {
        var s = start
        s /= Decimal64(10) // my value in sec
        s /= Decimal64(60) // my value in min
        var ret: String = ""
        for _ in 0...9999 {
            
            let ppm: Decimal64 = 9.9
            
            let net = s * ppm
            let taxrate = Decimal64(19) / Decimal64(100)
            let tax = net * taxrate
            let gross = net + tax
            
            ret = "\(s), net: \(net), tax: \(tax), gross: \(gross)"
            s += 1.1
        }
        return ret
    }
}

extension Benchmark {
    /// Benchmark for types conforming to `FloatingPoint` operations `+`, `*`, `/`, and conversion to `String`.
    ///
    /// The template version (only useful for Double and DecimalFP64, slower by ~40% than non template version)
    /// - parameter start: The starting value for the calculations.
    /// - returns: A string result of the numbers (to compare results and to make sure that the string conversion is not optimized away)
    static func genericFloatingPoint<T>(start: T) -> String where T:FloatingPoint, T:ExpressibleByFloatLiteral  {
        var s = start
        s /= T(10) // my value in sec
        s /= T(60) // my value in min
        var ret: String = ""
        for _ in 0...9999 {
            
            let ppm: T = 9.9
            
            let net = s * ppm
            let taxrate = T(19) / T(100)
            let tax = net * taxrate
            let gross = net + tax
            
            ret = "\(s), net: \(net), tax: \(tax), gross: \(gross)"
            s += 1.1
        }
        return ret
    }
}
