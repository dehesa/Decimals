import Foundation

/// Custom implementation for a decimal type.
///
/// It uses 55 bits for the significand and 9 bits for exponent (both are two's complement).
///
///      63                                         9 8         0
///     +--------------------------------------------+-----------+
///     |                significand                 |  exponent |
///     +--------------------------------------------+-----------+
///
/// The significand and exponent represent a decimal number given by the following formula:
///
///     number = significand * (10 ^ exponent)
///
/// This decimal number implementation has some interesting quirks:
/// - It doesn't express the concept of Infinite or NaN (it will simply crash on invalid operations, such as dividing by zero).
/// - Only 16 decimal digits may be expressed (i.e. `1234567890123456` or `123456.7890123456` or `123456789012345.6`, etc).
public struct Decimal64 {
    /// The type used to store both the mantissa and the exponent.
    @usableFromInline internal typealias InternalStorage = Int64
    /// Internal storage of 64 bytes composed of 55 bit for a significand and 9 bits for the exponent.
    @usableFromInline internal private(set) var _data: InternalStorage
    
    /// Designated initializer passing the exact bytes for the internal storage.
    /// - attention: This initializer just stores the bytes. It doesn't do any validation.
    /// - parameter bitPattern: The bytes representing the decimal number.
    @usableFromInline @_transparent internal init(bitPattern: InternalStorage) {
        self._data = bitPattern
    }
}

extension Decimal64: Equatable {
    public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs._data == rhs._data { return true }
        
        var (leftSignificand, rightSifnificand) = (lhs.significand, rhs.significand)
        if (leftSignificand == 0) && (rightSifnificand == 0) { return true }
        
        let diff = lhs.exponent &- rhs.exponent
        // lhs has a greater exponent than rhs.
        if diff > 0 {
            let shift = leftSignificand.shiftLeftTo17(limit: diff)
            if (shift == diff) && (leftSignificand == rightSifnificand) { return true }
        // lhs has a lesser exponent than rhs.
        } else if diff < 0 {
            let limit = -diff
            let shift = rightSifnificand.shiftLeftTo17(limit: limit)
            if (shift == limit) && (rightSifnificand == leftSignificand) { return true }
        }
        
        // If the exponents are equal, lhs._data == rhs.data should have been equal to zero.
        return false
    }
}

extension Decimal64: Hashable {
    @_transparent public func hash(into hasher: inout Hasher) {
        hasher.combine(self.normalized())
    }
}

extension Decimal64: Comparable {
    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs._data == rhs._data { return false }
        
        let (leftNormal, rightNormal) = (lhs.normalized(), rhs.normalized())
        let (leftExponent, rightExponent) = (leftNormal.exponent, rightNormal.exponent)
        
        if leftExponent == rightExponent {
            return leftNormal.significand < rightNormal.significand
        } else if leftExponent < rightExponent {
            return !rightNormal.isNegative
        } else {
            return leftNormal.isNegative
        }
    }
    
    @_transparent public static func > (_ lhs: Self, _ rhs: Self) -> Bool {
        rhs < lhs
    }
    
    @_transparent public static func >= (_ lhs: Self, _ rhs: Self) -> Bool{
        !(lhs < rhs)
    }
    
    @_transparent public static func <= (_ lhs: Self, _ rhs: Self) -> Bool {
        !(rhs < lhs)
    }
}

extension Decimal64: AdditiveArithmetic {
    @_transparent public static var zero: Self {
        .init(bitPattern: 0)
    }
    
    @_transparent public static func + (_ lhs: Self, _ rhs: Self) -> Self {
        var result = lhs
        result += rhs
        return result
    }
    
    @_transparent public static func - (_ lhs: Self, _ rhs: Self) -> Self {
        var result = lhs
        result -= rhs
        return result
    }
    
    public static func += (_ lhs: inout Self, _ rhs: Self) {
        let sign = lhs.isNegative
        
        if sign == rhs.isNegative {
            lhs.addToThis(rhs, sign)
        } else {
            lhs.subtractFromThis(rhs, sign)
        }
    }
    
    public static func -=(_ lsh: inout Self, _ rhs: Self) {
        let leftSign = lsh.isNegative
        
        if leftSign == rhs.isNegative {
            lsh.subtractFromThis(rhs, leftSign)
        } else {
            lsh.addToThis(rhs, leftSign);
        }
    }
}

extension Decimal64: Numeric {
    @inlinable @_transparent public init?<T>(exactly source: T) where T: BinaryInteger {
        guard source.magnitude < 10_000_000_000_000_000 else { return nil }
        self.init(bitPattern: Int64(truncatingIfNeeded: source) << Self.exponentBitCount)
    }
    
    @_transparent public var magnitude: Self {
        guard self.isNegative else { return self }
        return .init(significand: -self.significand, exponent: self.exponent)
    }
    
    @_transparent public static func * (_ lhs: Self, _ rhs: Self) -> Self {
        var result = lhs
        result *= rhs
        return result
    }
    
    public static func *= (_ lhs: inout Self, _ rhs: Self) {
        guard !lhs.isZero && !rhs.isZero else { lhs = .zero; return }
        
        // Calculate new coefficient.
        var myHigh = lhs.significand
        let myLow  = myHigh % Int64.powerOf10.8
        myHigh /= Int64.powerOf10.8
        
        var otherHigh = rhs.significand
        let otherLow  = otherHigh % Int64.powerOf10.8
        otherHigh /= Int64.powerOf10.8
        
        var newHigh = myHigh &* otherHigh
        var newMid  = myHigh &* otherLow &+ myLow &* otherHigh
        var significand = myLow &* otherLow
        
        var shift = 0
        
        if (newHigh > 0) {
            // Make high as big as possible.
            shift = 16 &- newHigh.shiftLeftTo17Limit16()
            
            if (shift > 8) {
                newMid /= Int64.tenToThePower(of: shift - 8)
                significand /= Int64.tenToThePower(of: shift)
            } else {
                newMid &*= Int64.tenToThePower(of: 8 - shift)
                significand /= Int64.tenToThePower(of: shift)
            }
            
            significand += newHigh &+ newMid
        } else if newMid > 0 {
            // Make mid as big as possible.
            shift = 8 &- newMid.shiftLeftTo17Limit8()
            significand /= Int64.tenToThePower(of: shift)
            significand &+= newMid
        }
        
        // Calculate new exponent.
        let exponent = lhs.exponent &+ (rhs.exponent &+ shift)
        
        #warning("I commented setComponents")
//        lhs.setComponents(significand, exponent, lhs.isNegative != rhs.isNegative)
        lhs = .init(significand: significand, exponent: exponent)
    }
}

extension Decimal64: SignedNumeric {
    @_transparent public mutating func negate() {
        self = .init(significand: -self.significand, exponent: self.exponent)
    }
    
    @_transparent public prefix static func - (operand: Self) -> Self {
        .init(significand: -operand.significand, exponent: operand.exponent)
    }
}

extension Decimal64: Strideable {
    @_transparent public func advanced(by n: Self) -> Self {
        self + n
    }
    
    @_transparent public func distance(to other: Self) -> Self {
        other - self
    }
}

extension Decimal64: ExpressibleByIntegerLiteral {
    @_transparent public init(integerLiteral value: Int64) {
        precondition(Swift.abs(value) < 10_000_000_000_000_000)
        self.init(bitPattern: value << Self.exponentBitCount)
    }
}

extension Decimal64: ExpressibleByFloatLiteral {
    @_transparent public init(floatLiteral value: Double) {
        self.init(value)! // TODO: Figure out an exact conversion.
    }
}

extension Decimal64: ExpressibleByStringLiteral {
    @_transparent public init(stringLiteral value: String) {
        self.init(value)!
    }
}

extension Decimal64 /*: FloatingPoint*/ {
    @_transparent public var isZero: Bool {
        self.significand == 0
    }
    
    @_transparent public var sign: FloatingPointSign {
        (self.isNegative) ? .minus : .plus
    }
    
    @_transparent public var significand: Significand {
        self._data >> Self.exponentBitCount
    }
    
    public static var greatestFiniteMagnitude: Self {
        .init(significand: 9_999_999_999_999_999, exponent: Self.greatestExponent)
    }
    
    public static var leastNonzeroMagnitude: Self {
        .init(significand: 1, exponent: Self.leastExponent)
    }
    
    @_transparent public static var pi: Self {
        .init(significand: 3141592653589793, exponent: -15)
    }
    
    @_transparent public static var radix: Int {
        10
    }
    
    @_transparent public static func / (_ lhs: Decimal64, _ rhs: Decimal64) -> Decimal64 {
        var result = lhs
        result /= rhs
        return result
    }
    
    // It uses the following algorithm: `a = r0, f0*r0 = n0*b + r1, f1*r1 = n1*b + r2, ...` where `fi` are factors (power of 10) to make remainders `ri` as big as possible and `ni` are integers. Then with g a power of 10 to make `n0` as big as possible:
    //     a     1              g          g
    //     - = ---- * ( g*n0 + -- * n1 + ----- * n2 + ... )
    //     b   f0*g            f1        f1*f2
    public static func /= (_ lhs: inout Self, _ rhs: Self) {
        var myExp = lhs.exponent
        let rightExp = rhs.exponent
        
        var myMan = lhs.significand
        let otherMan = rhs.significand
        
        if otherMan == 0 {
            // TODO: Look out
            fatalError()
        } else if (myMan != 0) && (rhs._data != 1) {
            // Calculate new coefficient
            
            // First approach of result. Make numerator as big as possible.
            var mainShift = myMan.shiftLeftTo18()
            
            // Do division.
            var remainderA = myMan % otherMan
            myMan /= otherMan
            
            // Make result as big as possible.
            var shift = myMan.shiftLeftTo18()
            mainShift &+= shift
            
            while remainderA > 0 {
                shift &-= remainderA.shiftLeftTo18()
                if shift < -17 { break }
                
                // Do division.
                let remainderB = remainderA % otherMan
                remainderA /= otherMan
                
                remainderA.shift(decimalDigits: shift)
                
                if remainderA == 0 { break }
                myMan &+= remainderA
                
                remainderA = remainderB
            }
            
            // Calculate new exponent.
            myExp &-= rightExp &+ mainShift
            
            lhs.setComponents(myMan, myExp, lhs.isNegative != rhs.isNegative)
        }
    }
}

extension Decimal64: LosslessStringConvertible, CustomStringConvertible {
    // Creates a decimal number from the given string (if possible). The input in the format is:
    //
    //     [`+`|`-`]? `0`..`9`* [`.` `0`..`9`*]? [(`E`|`e`) `0`..`9`*]?
    //
    // 1. Optional sign.
    // 2. Any number of digits as integer part.
    // 3. Optional a dot with any number of digits as fraction
    // 4. Optional an e with any number of digits as exponent
    public init?(_ value: String) {
        func isDigit(_ c: Character?) -> Bool { c != nil && c! >= "0" && c! <= "9" }
        
        var iterator = value.makeIterator()
        var c: Character?
        
        // Ignore whitespaces.
        repeat {
            c = iterator.next()
        } while c == " "
        
        // 1. Check sign
        let isNegative = c == "-"
        if isNegative || c == "+" {
            c = iterator.next()
        }
        
        // Ignore leading zeros.
        while c != nil && c! == "0" {
            c = iterator.next()
        }
        
        var significand: Int64 = 0
        var exponent: Int = 0
        var numDigits: Int = 0
        
        // check integer part
        while isDigit(c) && (numDigits < 18) {
            numDigits += 1
            significand *= 10
            significand += Int64(c!.asciiValue! - 48)
            c = iterator.next()
        }
        
        // maybe we have more digits for our precision
        while isDigit(c) {
            exponent += 1
            c = iterator.next()
        }
        
        // check fraction part
        if c != nil && c! == "." {
            c = iterator.next()
            
            if significand == 0 {
                while c != nil && c! == "0" {
                    exponent -= 1
                    c = iterator.next()
                }
            }
            
            while isDigit(c) && (numDigits < 18) {
                numDigits += 1
                exponent -= 1
                significand *= 10
                significand += Int64(c!.asciiValue! - 48)
                c = iterator.next()
            }
            
            // maybe we have more digits -> just ignore
            while isDigit(c) {
                c = iterator.next()
            }
        }
        
        if isNegative {
            significand = -significand
        }
        
        if (c != nil) && ((c! == "e") || (c! == "E")) {
            c = iterator.next()
            numDigits = 0
            var e = 0
            var expSign = 1
            
            if (c != nil) && ((c! == "-") || (c! == "+")) {
                expSign = (c! == "-") ? -1 : 1
                c = iterator.next()
            }
            
            while c != nil && c! == "0" {
                c = iterator.next()
            }
            
            while isDigit(c) && (numDigits < 3) {
                numDigits += 1
                e *= 10
                e += Int(c!.asciiValue!) - 48
                c = iterator.next()
            }
            
            exponent += e * expSign
            
            if isDigit(c) {
                while isDigit(c) {
                    c = iterator.next()
                }
                return nil
            }
        }
        
        self.init(significand, power: exponent)
    }
    
    public var description: String {
        var significand = self.significand
        
        if significand == 0 {
            return "0"
        } else if significand < 0 {
            significand = -significand
        }
        
        var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
                  ) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        return withUnsafeMutablePointer(to: &data.0) {
            var exp = self.exponent
            var end = $0.advanced(by: 30)
            var start = significand.toString(end: end)
            
            if exp < 0 {
                end -= 1
                
                // Try to set a decimal point to make exp equal to zero.
                // Strip off trailing zeroes.
                while (end.pointee == 0x30) && (exp < 0) {
                    end -= 1
                    exp &+= 1
                }
                
                if exp < 0 {
                    if exp > start - end &- 6 {
                        // Add maximal 6 additional chars left from digits to get 0.nnn, 0.0nnn, 0.00nnn, 0.000nnn, 0.0000nnn or 0.00000nnn.
                        // The result may have more than 16 digits.
                        while start - end > exp {
                            start -= 1
                            start.pointee = 0x30 // 0
                        }
                    }
                    
                    let dotPos = (end - start) &+ exp &+ 1;
                    // exp < 0 therefore start + dotPos <= end.
                    if dotPos > 0 {
                        memmove(start + dotPos + 1, start + dotPos, 1 &- exp)
                        start[dotPos] = 0x2E // .
                        exp = 0
                        end += 2
                    }
                    else {
                        if end != start {
                            let startMinusOne = start.advanced(by: -1)
                            startMinusOne.pointee = start.pointee
                            start.pointee = 0x2E // .
                            start -= 1
                        }
                        
                        exp = 1 &- dotPos
                        
                        end += 1
                        end.pointee = 0x45 // E
                        end += 1
                        end.pointee = 0x2D // -
                        
                        end += 2
                        if exp >= 10 {
                            end += 1
                        }
                        if exp >= 100 {
                            end += 1
                        }
                        _ = Int64(exp).toString(end: end)
                    }
                }
                else {
                    end += 1
                }
            }
            else if exp + end - start > 16 {
                end -= 1
                
                exp &+= end - start //TODO: will it work on 64bit?
                
                while  end.pointee == 0x30 { // 0
                    end -= 1
                }
                
                if end != start {
                    let startMinusOne = start.advanced(by: -1)
                    startMinusOne.pointee = start.pointee
                    start.pointee = 0x2E // .
                    start -= 1
                }
                end += 1
                end.pointee = 0x45 // E
                end += 1
                end.pointee = 0x2B // +
                
                end += 2
                if exp >= 10 {
                    end += 1
                }
                if exp >= 100 {
                    end += 1
                }
                _ = Int64(exp).toString(end: end)
            }
            else {
                while exp > 0 {
                    end.pointee = 0x30 // 0
                    end += 1
                    exp &-= 1
                }
            }
            
            if self.isNegative {
                start -= 1
                start.pointee = 0x2D // -
            }
            
            end.pointee = 0
            
            return String(cString: start)
        }
    }
}

extension Decimal64: TextOutputStreamable {
    public func write<Target>(to target: inout Target) where Target: TextOutputStream {
        var significand = self.significand
        
        if significand == 0 {
            return target.write("0")
        } else if significand < 0 {
            significand = -significand
        }
        
        var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
                  ) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        var exp = self.exponent
        withUnsafeMutablePointer(to: &data.30) {
            var end = $0
            var start = significand.toString(end: end)
            
            if exp < 0 {
                end -= 1
                
                // Try to set a decimal point to make exp equal to zero.
                // Strip off trailing zeroes.
                while (end.pointee == 0x30) && (exp < 0) {
                    end -= 1
                    exp &+= 1
                }
                
                if exp < 0 {
                    if exp > start - end &- 6 {
                        // Add maximal 6 additional chars left from digits to get
                        // 0.nnn, 0.0nnn, 0.00nnn, 0.000nnn, 0.0000nnn or 0.00000nnn.
                        // The result may have more than 16 digits.
                        while start - end > exp {
                            start -= 1
                            start.pointee = 0x30 // 0
                        }
                    }
                    
                    let dotPos = (end - start) &+ exp &+ 1;
                    // exp < 0 therefore start + dotPos <= end.
                    if dotPos > 0 {
                        memmove(start + dotPos + 1, start + dotPos, 1 &- exp)
                        start[dotPos] = 0x2E // .
                        exp = 0
                        end += 2
                    } else {
                        if end != start {
                            let startMinusOne = start.advanced(by: -1)
                            startMinusOne.pointee = start.pointee
                            start.pointee = 0x2E // .
                            start -= 1
                        }
                        
                        exp = 1 &- dotPos
                        
                        end += 1
                        end.pointee = 0x45 // E
                        end += 1
                        end.pointee = 0x2D // -
                        
                        end += 2
                        if exp >= 10 {
                            end += 1
                        }
                        
                        if exp >= 100 {
                            end += 1
                        }
                        _ = Int64(exp).toString(end: end)
                    }
                } else {
                    end += 1
                }
            } else if exp + end - start > 16 {
                end -= 1
                
                exp &+= end - start //TODO: will it work on 64bit?
                
                while  end.pointee == 0x30 { // 0
                    end -= 1
                }
                
                if end != start {
                    let startMinusOne = start.advanced(by: -1)
                    startMinusOne.pointee = start.pointee
                    start.pointee = 0x2E // .
                    start -= 1
                }
                
                end += 1
                end.pointee = 0x45 // E
                end += 1
                end.pointee = 0x2B // +
                
                end += 2
                if exp >= 10 {
                    end += 1
                }
                
                if exp >= 100 {
                    end += 1
                }
                _ = Int64(exp).toString(end: end)
            } else {
                while exp > 0 {
                    end.pointee = 0x30 // 0
                    end += 1
                    exp &-= 1
                }
            }
            
            if self.isNegative {
                start -= 1
                start.pointee = 0x2D // -
            }
            
            end.pointee = 0
            target._writeASCII(.init(start: start, count: end - start))
        }
    }
}


// MARK: -

extension Decimal64 {
    /// A type that represents the encoded significand of a value.
    public typealias Significand = Int64
    /// A type that can represent any written exponent.
    public typealias Exponent = Int
    
    /// Convenience initializer passing the significand and exponent to be stored internally.
    /// - attention: This initializer just stores the bytes. It doesn't do any validation.
    /// - parameter significand: The number to be multiplied by `10^exponent`.
    /// - parameter exponent: The exponent that `10` will be raised to.
    /// - returns: A decimal number returned by the formula: `number = significand * (10 ^ exponent)`.
    @usableFromInline @_transparent internal init(significand: Significand, exponent: Exponent) {
        self.init(bitPattern: (significand << Self.exponentBitCount) | (InternalStorage(exponent) & Self.exponentMask))
    }
    
    /// Convenience initializer passing the significand and exponent to be stored internally.
    ///
    /// The decimal number is represented as follows:
    ///
    ///     number = value * (10 ^ exponent)
    ///
    /// For example `10.53` and `-1.7344` can be initialized with the following code:
    ///
    ///     let first  = Decimal64(  1053, power: -2)
    ///     let second = Decimal64(-17344, power: -4)
    ///
    /// - parameter value: The number to be multiplied by `10^exponent`.
    /// - parameter exponent: The exponent that `10` will be raised to.
    /// - returns: A decimal number or `nil` if the given `exponent` and significand represent a number with more than 16 decimal digits.
    public init?(_ value: Significand, power exponent: Exponent) {
        guard Swift.abs(value) < 10_000_000_000_000_000, (exponent >= Self.leastExponent) && (exponent <= Self.greatestExponent) else { return nil }
        self.init(significand: value, exponent: exponent)
    }
    
    public init?(_ value: Double) {
        guard value.isFinite else { return nil }
        
        if value.isZero {
            self = .zero
        } else {
            let val = Swift.abs(value)
            let exp = Int(log10(val) - 15)
            let man = Int64(val / pow(10.0, Double(exp)) + 0.5)
            let significand: Significand = (value < 0) ? -man: man
            self.init(significand, power: exp)
        }
    }
    
    /// The number of bits used to represent the type’s exponent.
    @_transparent public static var exponentBitCount: Int {
        9
    }
    /// The available number of fractional significand bits.
    @_transparent public static var significandBitCount: Int {
        55
    }
    /// The maximum exponent. The formula is: `(2 ^ exponentBitCount) / 2 - 1`.
    @_transparent private static var greatestExponent: Int {
        255
    }
    /// The minimum exponent. The formula is: `-(2 ^ exponentBitCount) / 2`
    @_transparent private static var leastExponent: Int {
        -256
    }
    /// Bit-mask matching the exponent.
    @usableFromInline @_transparent internal static var exponentMask: InternalStorage {
        .init(bitPattern: 0b1_1111_1111)
    }
    
    /// The exponent of the floating-point value.
    @_transparent public var exponent: Exponent {
        .init((self._data << Self.significandBitCount) >> Self.significandBitCount)
    }
    
    @_transparent public static var tau: Self {
        .init(significand: 6283185307179586, exponent: -15)
    }
    
    /// Returns true if the represented decimal is a negative value.
    ///
    /// Zero and positive values return `false`.
    @usableFromInline @_transparent internal var isNegative: Bool {
        self._data < 0
    }
    
    /// Rounds the value to an integral value using the specified rounding rule.
    ///
    /// The following example rounds a value using four different rounding rules:
    ///
    ///     // Equivalent to the C 'round' function:
    ///     var w: Decimal64 = 6.5
    ///     w.round(.toNearestOrAwayFromZero)
    ///     // w == 7
    ///
    ///     // Equivalent to the C 'trunc' function:
    ///     var x: Decimal64 = 6.5
    ///     x.round(.towardZero)
    ///     // x == 6
    ///
    ///     // Equivalent to the C 'ceil' function:
    ///     var y: Decimal64 = 6.5
    ///     y.round(.up)
    ///     // y == 7
    ///
    ///     // Equivalent to the C 'floor' function:
    ///     var z: Decimal64 = 6.5
    ///     z.round(.down)
    ///     // z == 6
    ///
    /// - parameter rule: The rounding rule to use.
    /// - parameter scale: The number of digits a rounded value should have after its decimal point. It must be zero or a positive number; otherwise, the program will crash.
    public mutating func round(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, scale: Int = 0) {
        self._data = self.rounded(rule, scale: scale)._data
    }
    
    /// Rounds the value to an integral value using the specified rounding rule.
    /// - parameter rule: The rounding rule to use.
    /// - parameter scale: The number of digits a rounded value should have after its decimal point.  It must be zero or a positive number; otherwise, the program will crash.
    public func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, scale: Int = 0) -> Self {
        precondition(scale >= 0)
        
        let exponent = self.exponent
        let shift = -(exponent + scale)
        guard shift > 0 else { return self }
        
        var significand = self.significand
        let divisor = Int64.tenToThePower(of: shift)
        let remainder = significand % divisor
        significand /= divisor
        
        switch rule {
        case .towardZero:
            break
        case .up:
            guard remainder > 0 else { break }
            significand &+= 1
        case .down:
            guard remainder < 0 else { break }
            significand &-= 1
        case .awayFromZero:
            if remainder > 0 { significand &+= 1 } else
            if remainder < 0 { significand &-= 1 }
        case .toNearestOrAwayFromZero:
            guard abs(remainder) >= (divisor / 2) else { break }
            if remainder > 0 { significand &+= 1 } else
            if remainder < 0 { significand &-= 1 }
        case .toNearestOrEven:
            let (rem, half) = (abs(remainder), divisor / 2)
            guard (rem > half) || ((rem == half) && ((significand & 1) != 0)) else { break }
            if remainder > 0 { significand &+= 1 } else
            if remainder < 0 { significand &-= 1 }
        @unknown default:
            fatalError()
        }
        return .init(significand: significand, exponent: -scale)
    }
    
    @_transparent public mutating func normalize() {
        self._data = self.normalized()._data
    }
    
    // Makes the significand number as large as possible while at the same time making the exponent to have the smallest possible value (min is -256).
    public func normalized() -> Self {
        var significand = self.significand
        guard significand != 0 else { return Self.zero }
        #warning("Is this working?")
        var exponent = self.exponent
        exponent -= significand.toMaximumDigits()
        return .init(significand: significand, exponent: exponent)
    }
    
    /// The functions break the number into the integral and the fractional parts.
    /// - attention: The integral part have sign information; therefore, negative number will still contain the negative sign.
    /// - returns: Tuple containing the _whole_/integral and _decimal_/fractional part.
    public func decomposed() -> (integral: Decimal64, fractional: Decimal64) {
        let integral = self.rounded(.towardZero, scale: 0)
        var fractional = self - integral
        
        if fractional.isNegative {
            fractional._data.negate()
        }
        return (integral, fractional)
    }
    
    /// Shifts to the left `shift` number of decimal digits and reassign the value to the receiving number.
    public static func <<= (_ lhs: inout Decimal64, _ shift: Int) {
        lhs.setComponents(lhs.significand, lhs.exponent &+ shift, false)
    }
    
    /// Shifts to the right `shift` number of decimal digits and reassign the value to the receiving number.
    public static func >>= (_ lhs: inout Decimal64, _ shift: Int) {
        lhs.setComponents(lhs.significand, lhs.exponent &- shift, false)
    }
    
    /// Shifts to the left `shift` number of decimal digits.
    @_transparent public static func << (_ lhs: Decimal64, _ rhs: Int) -> Decimal64 {
        var result = lhs
        result <<= rhs
        return result
    }
    
    /// Shifts to the right `shift` number of decimal digits.
    @_transparent public static func >> (_ lhs: Decimal64, _ rhs: Int) -> Decimal64 {
        var result = lhs
        result >>= rhs
        return result
    }
}

extension Decimal64 {
    private mutating func setComponents(_ man: Int64, _ exp: Int = 0, _ negate: Bool = false) {
        var man = man, exp = exp, negate = negate

        if man < 0 {
            man = -man
            negate = !negate
        }

        if man == 0 {
            self._data = 0
        } else {
            // Round the internal coefficient to a maximum of 16 digits.
            if man >= Int64.powerOf10.16  {
                if man < Int64.powerOf10.17  {
                    man &+= 5
                    man /= 10
                    exp &+= 1
                } else if man < Int64.powerOf10.18 {
                    man &+= 50
                    man /= 100
                    exp &+= 2
                } else {
                    // Adding 500 may cause an overflow in signed Int64.
                    man += 500
                    man /= 1000
                    exp &+= 3
                }
            }

            self._data = man << Self.exponentBitCount

            // try denormalization if possible
            if exp > 253 {
                exp &-= self._data.shiftLeftTo16() //TODO: numbers with exponent > 253 may be denormalized to much
                self._data |= Int64(exp)
            } else if  exp < -256 {
                self._data.shift(decimalDigits: exp &+ 256)

                if self._data != 0 {
                    self._data |= -256
                }
            } else if exp != 0 {
                self._data |=  (InternalStorage(exp) & Self.exponentMask)
            }
        }

        // change sign
        if negate {
            self._data = -self._data
        }
    }

    /// Compute the sum of the absolute values of the receiving number and a second decimal number.
    /// - attention: All signs are ignored!
    /// - parameter right: Summand.
    private mutating func addToThis(_ right: Decimal64, _ negative: Bool) {
        var myExp = self.exponent
        var otherExp = right.exponent

        // Calculate new coefficient
        var myMan = self.significand
        var otherMan = right.significand

        if otherMan == 0 {
            // Nothing to do because NumB is 0.
        } else if myExp == otherExp {
            self.setComponents(myMan &+ otherMan, myExp, negative)
        } else if (myExp < otherExp &- 32) || (myMan == 0) {
            // This is too small, therefore sum is completely sign * |NumB|.
            self._data = right._data
            if negative {
                self._data = -self._data
            }
        } else if myExp <= otherExp &+ 32 {
            // -32 <= myExp - otherExp <= 32
            if myExp < otherExp {
                // Make otherExp smaller.
                otherExp &-= otherMan.shiftLeftTo17(limit: min(17, otherExp &- myExp))
                if myExp != otherExp {
                    if otherExp > myExp &+ 16 {
                        // This is too small, therefore sum is completely sign * |NumB|.
                        self._data = right._data
                        if negative {
                            self._data = -self._data
                        }
                        return
                    }

                    // myExp is still smaller than otherExp, make it bigger.
                    myMan /= Int64.tenToThePower(of: otherExp &- myExp)
                    myExp = otherExp
                }
            } else {
                // Make myExp smaller.
                myExp &-= myMan.shiftLeftTo17(limit: min(17, myExp &- otherExp))
                if myExp != otherExp {
                    if myExp > otherExp &+ 16 {
                        // Nothing to do because NumB is too small
                        return
                    }

                    // otherExp is still smaller than myExp, make it bigger.
                    otherMan /= Int64.tenToThePower(of: myExp &- otherExp)
                }
            }

            // Now both exponents are equal.
            self.setComponents(myMan &+ otherMan, myExp, negative)
        } else {
            // Nothing to do because NumB is too small
            // otherExp < myExp - 32.
        }

    }

    /// Subtract the absolute value of a `Decimal64` from the absolute value of the receiving number.
    ///
    /// The sign is flipped if the result is negative.
    /// - parameter right: Subtrahend
    /// - parameter negative: flag if ... is negative
    private mutating func subtractFromThis(_ right: Decimal64, _ negative: Bool) {
        var myExp = self.exponent
        var otherExp = right.exponent

        // Calculate new coefficient
        var myMan = self.significand
        var otherMan = right.significand

        if otherMan == 0 {
            // Nothing to do because NumB is 0.
        } else if myExp == otherExp {
            setComponents(myMan &- otherMan, myExp, negative);
        } else if ((myExp < otherExp &- 32) || (myMan == 0)) {
            // This is too small, therefore difference is completely -sign * |NumB|.
            self._data = right._data
            if !negative {
                self._data = -_data
            }
        } else if myExp <= otherExp &+ 32 {
            // -32 <= myExp - otherExp <= 32
            if myExp < otherExp {
                // Make otherExp smaller.
                otherExp &-= otherMan.shiftLeftTo17(limit: min(17, otherExp &- myExp));
                if myExp != otherExp {
                    if otherExp > myExp &+ 16 {
                        // This is too small, therefore difference is completely -sign * |NumB|.
                        self._data = right._data
                        if !negative {
                            self._data = -_data
                        }
                        return
                    }

                    // myExp is still smaller than otherExp, make it bigger.
                    myMan /= Int64.tenToThePower(of: otherExp &- myExp)
                    myExp = otherExp
                }
            } else {
                // Make myExp smaller.
                myExp &-= myMan.shiftLeftTo17(limit: min(17, myExp &- otherExp))
                if myExp != otherExp {
                    if myExp > otherExp + 16 {
                        // Nothing to do because NumB is too small
                        return
                    }

                    // otherExp is still smaller than myExp, make it bigger.
                    otherMan /= Int64.tenToThePower(of: myExp &- otherExp)
                }
            }

            // Now both exponents are equal.
            self.setComponents(myMan &- otherMan, myExp, negative)
        } else {
            // Nothing to do because NumB is too small (myExp > otherExp + 32).
        }
    }
}
