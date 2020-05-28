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
    @usableFromInline @_transparent internal init(unsafeSignificand significand: Significand, exponent: Exponent) {
        self.init(bitPattern: (significand << Self.exponentBitCount) | (InternalStorage(exponent) & Self.exponentMask))
    }
    
    @_transparent public var significand: Significand {
        self._data >> Self.exponentBitCount
    }
    
    /// The exponent of the floating-point value.
    @_transparent public var exponent: Exponent {
        // The double shift makes the `Exponent` to keep the sign.
        .init((self._data << Self.significandBitCount) >> Self.significandBitCount)
    }
    
    /// The available number of fractional significand bits.
    @_transparent public static var significandBitCount: Int { 55 }
    /// The number of bits used to represent the type’s exponent.
    @_transparent public static var exponentBitCount: Int { 9 }
    /// The maximum exponent. The formula is: `(2 ^ exponentBitCount) / 2 - 1`.
    @_transparent private static var greatestExponent: Int { 255 }
    /// The minimum exponent. The formula is: `-(2 ^ exponentBitCount) / 2`
    @_transparent private static var leastExponent: Int { -256 }
    /// Bit-mask matching the exponent.
    @usableFromInline @_transparent internal static var exponentMask: InternalStorage { .init(bitPattern: 0b1_1111_1111) }
}

// MARK: -

extension Decimal64: Equatable {
    public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        var (leftSignificand, rightSignificand) = (lhs.significand, rhs.significand)
        guard leftSignificand != 0 else { return rightSignificand == 0 }
        
        let diff = lhs.exponent &- rhs.exponent
        if diff > 0 { // lhs has a greater exponent than rhs.
            let shift = leftSignificand.shiftLeftTo17(limit: diff)
            guard shift == diff else { return false }
        } else if diff < 0 { // lhs has a lesser exponent than rhs.
            let shift = rightSignificand.shiftLeftTo17(limit: -diff)
            guard shift == -diff else { return false }
        }
        
        return leftSignificand == rightSignificand
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
        .init(bitPattern: .zero)
    }
    
    public static func + (_ lhs: Self, _ rhs: Self) -> Self {
        var rightSignificand = rhs.significand
        // If the right significand is 0, there is nothing to do.
        guard rightSignificand != .zero else { return lhs }
        
        var (leftExponent, rightExponent) = (lhs.exponent, rhs.exponent)
        var leftSignificand = lhs.significand
        
        // If exponents are the same, just add the significands.
        if leftExponent == rightExponent {
            return .init(roundingSignificand: leftSignificand &+ rightSignificand, exponent: leftExponent)
        // If the left decimal number is too small, only the right number matters.
        } else if (leftSignificand == .zero) || (leftExponent < rightExponent &- 32) {
            return rhs
        // If (leftExponent - rightExponent) ∈ [-32, 32], then the numbers can be added.
        } else if leftExponent <= rightExponent &+ 32 {
            // If `rightExponent` is bigger than `leftExponent`, make `rightExponent` smaller.
            if leftExponent < rightExponent {
                rightExponent &-= rightSignificand.shiftLeftTo17(limit: min(17, rightExponent &- leftExponent))
                // If after the shift, the exponents are still not the same...
                if leftExponent != rightExponent {
                    // ...and the `rightExponent` is much bigger than the `leftExponent`, ignore the left number.
                    if rightExponent > leftExponent &+ 16 {
                        return rhs
                    // ..`leftExponent` is still smaller than `rightExponent`, make it bigger.
                    } else {
                        leftSignificand /= Int64.tenToThePower(of: rightExponent &- leftExponent)
                        leftExponent = rightExponent
                    }
                }
            // If `leftExponent` is bigger than `rightExponent`, make `leftExponent` smaller.
            } else {
                leftExponent &-= leftSignificand.shiftLeftTo17(limit: min(17, leftExponent &- rightExponent))
                // If after the shift, the exponents are still not the same...
                if leftExponent != rightExponent {
                    // ..and the `leftExponent` is much bigger than the `rightExponent`, ignore the right number.
                    if leftExponent > rightExponent &+ 16 {
                        return lhs
                    // ..`rightExponent` is still smaller than `leftExponent`, make it bigger.
                    } else {
                        rightSignificand /= Int64.tenToThePower(of: leftExponent &- rightExponent)
                    }
                }
            }
            // Now both exponents are equal.
            return .init(roundingSignificand: leftSignificand &+ rightSignificand, exponent: leftExponent)
        // If the right number is too small, only the left number matters.
        } else { return lhs }
    }
    
    public static func - (_ lhs: Self, _ rhs: Self) -> Self {
        var rightSignificand = rhs.significand
        // If the right significand is 0, there is nothing to do.
        guard rightSignificand != .zero else { return lhs }
        
        var (leftExponent, rightExponent) = (lhs.exponent, rhs.exponent)
        var leftSignificand = lhs.significand
        
        // If exponents are the same, just remove the right significand from the left significand.
        if leftExponent == rightExponent {
            return .init(roundingSignificand: leftSignificand &- rightSignificand, exponent: leftExponent)
        // If the left decimal number is too small, only the right number matters.
        } else if (leftSignificand == .zero) || (leftExponent < rightExponent &- 32) {
            return .init(unsafeSignificand: -rightSignificand, exponent: rightExponent)
        // If (leftExponent - rightExponent) ∈ [-32, 32], then the numbers can be subtracted.
        } else if leftExponent <= rightExponent &+ 32 {
            // If `rightExponent` is bigger than `leftExponent`, make `rightExponent` smaller.
            if leftExponent < rightExponent {
                rightExponent &-= rightSignificand.shiftLeftTo17(limit: min(17, rightExponent &- leftExponent));
                // If after the shift, the exponents are still not the same...
                if leftExponent != rightExponent {
                    // ...and the `rightExponent` is much bigger than the `leftExponent`, ignore the left number.
                    if rightExponent > leftExponent &+ 16 {
                        // This is too small, therefore difference is completely -sign * |NumB|.
                        return .init(unsafeSignificand: -rightSignificand, exponent: rightExponent)
                    // ..`leftExponent` is still smaller than `rightExponent`, make it bigger.
                    } else {
                        leftSignificand /= Int64.tenToThePower(of: rightExponent &- leftExponent)
                        leftExponent = rightExponent
                    }
                }
            // If `leftExponent` is bigger than `rightExponent`, make `leftExponent` smaller.
            } else {
                leftExponent &-= leftSignificand.shiftLeftTo17(limit: min(17, leftExponent &- rightExponent))
                // If after the shift, the exponents are still not the same...
                if leftExponent != rightExponent {
                    // ..and the `leftExponent` is much bigger than the `rightExponent`, ignore the right number.
                    if leftExponent > rightExponent &+ 16 {
                        return lhs
                    // ..`rightExponent` is still smaller than `leftExponent`, make it bigger.
                    } else {
                        rightSignificand /= Int64.tenToThePower(of: leftExponent &- rightExponent)
                    }
                }
            }
            
            // Now both exponents are equal.
            return .init(roundingSignificand: leftSignificand &- rightSignificand, exponent: leftExponent)
        // If the right number is too small, only the left number matters.
        } else { return lhs }
    }
    
    @_transparent public static func += (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs + rhs
    }

    @_transparent public static func -= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs - rhs
    }
}

extension Decimal64: Numeric {
    @inlinable @_transparent public init?<T>(exactly source: T) where T: BinaryInteger {
        guard source.magnitude < 10_000_000_000_000_000 else { return nil }
        self.init(bitPattern: Int64(truncatingIfNeeded: source) << Self.exponentBitCount)
    }
    
    @_transparent public var magnitude: Self {
        guard self.isNegative else { return self }
        return .init(unsafeSignificand: -self.significand, exponent: self.exponent)
    }
    
    public static func * (_ lhs: Self, _ rhs: Self) -> Self {
        var (leftHigh, rightHigh) = (lhs.significand, rhs.significand)
        if (leftHigh == .zero) || (rightHigh == .zero) { return .zero }
        
        let (leftNegative, rightNegative) = (leftHigh < .zero, rightHigh < .zero)
        if leftNegative { leftHigh.negate() }
        if rightNegative { rightHigh.negate() }
        
        let (leftLow, rightLow) = (leftHigh % Int64.powerOf10.8, rightHigh % Int64.powerOf10.8)
        leftHigh /= Int64.powerOf10.8
        rightHigh /= Int64.powerOf10.8
        
        var (high, mid) = (leftHigh * rightHigh, leftHigh * rightLow &+ leftLow * rightHigh)
        var significand = leftLow * rightLow
        let shift: Int
        
        if high > 0 {
            // Make high as big as possible.
            shift = 16 &- high.shiftLeftTo17Limit16()
            
            if shift > 8 {
                mid /= Int64.tenToThePower(of: shift &- 8)
                significand /= Int64.tenToThePower(of: shift)
            } else {
                mid *= Int64.tenToThePower(of: 8 &- shift)
                significand /= Int64.tenToThePower(of: shift)
            }
            
            significand &+= high &+ mid
        } else if mid > 0 {
            // Make mid as big as possible.
            shift = 8 &- mid.shiftLeftTo17Limit8()
            significand /= Int64.tenToThePower(of: shift)
            significand &+= mid
        } else {
            shift = 0
        }
        
        let exponent = lhs.exponent &+ (rhs.exponent &+ shift)
        if leftNegative != rightNegative { significand.negate() }
        return .init(roundingSignificand: significand, exponent: exponent)
    }
    
    @_transparent public static func *= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs * rhs
    }
}

extension Decimal64: SignedNumeric {
    @_transparent public mutating func negate() {
        self = .init(unsafeSignificand: -self.significand, exponent: self.exponent)
    }
    
    @_transparent public prefix static func - (operand: Self) -> Self {
        .init(unsafeSignificand: -operand.significand, exponent: operand.exponent)
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
    public static var greatestFiniteMagnitude: Self {
        .init(unsafeSignificand: 9_999_999_999_999_999, exponent: Self.greatestExponent)
    }
    
    public static var leastNonzeroMagnitude: Self {
        .init(unsafeSignificand: 1, exponent: Self.leastExponent)
    }
    
    @_transparent public static var pi: Self {
        .init(unsafeSignificand: 3141592653589793, exponent: -15)
    }
    
    @_transparent public static var tau: Self {
        .init(unsafeSignificand: 6283185307179586, exponent: -15)
    }
    
    @_transparent public static var radix: Int {
        10
    }
    
    @_transparent public var isZero: Bool {
        self.significand == .zero
    }
    
    @_transparent public var sign: FloatingPointSign {
        (self.isNegative) ? .minus : .plus
    }
    
    // It uses the following algorithm: `a = r0, f0*r0 = n0*b + r1, f1*r1 = n1*b + r2, ...` where `fi` are factors (power of 10) to make remainders `ri` as big as possible and `ni` are integers. Then with g a power of 10 to make `n0` as big as possible:
    //     a     1              g          g
    //     - = ---- * ( g*n0 + -- * n1 + ----- * n2 + ... )
    //     b   f0*g            f1        f1*f2
    //
    public static func / (_ lhs: Decimal64, _ rhs: Decimal64) -> Decimal64 {
        let rightSignificand = rhs.significand
        precondition(rightSignificand != .zero)
        
        let leftSignificand = lhs.significand
        let (leftNegative, rightNegative) = (leftSignificand < .zero, rightSignificand < .zero)
        
        var significand = leftSignificand
        if leftNegative { significand.negate() }
        let divisor = rightNegative ? -rightSignificand : rightSignificand
        let (leftExponent, rightExponent) = (lhs.exponent, rhs.exponent)
        
        // Make numerator as big as possible.
        var mainShift = significand.shiftLeftTo18()
        // Do division.
        var remainderA = significand % divisor
        significand /= divisor
        // Make result as big as possible.
        var shift = significand.shiftLeftTo18()
        mainShift &+= shift
        
        while remainderA > 0 {
            shift &-= remainderA.shiftLeftTo18()
            if shift < -17 { break }
            
            let remainderB = remainderA % divisor
            remainderA /= divisor
            
            remainderA.shift(decimalDigits: shift)
            
            if remainderA == 0 { break }
            significand &+= remainderA
            
            remainderA = remainderB
        }
        
        // Calculate new exponent.
        let exponent = leftExponent &- (rightExponent &+ mainShift)
        if leftNegative != rightNegative { significand.negate() }
        return .init(roundingSignificand: significand, exponent: exponent)
    }
    
    @_transparent public static func /= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs / rhs
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
            numDigits &+= 1
            significand *= 10
            significand &+= Int64(c!.asciiValue! &- 48)
            c = iterator.next()
        }
        
        // maybe we have more digits for our precision
        while isDigit(c) {
            exponent &+= 1
            c = iterator.next()
        }
        
        // check fraction part
        if c != nil && c! == "." {
            c = iterator.next()
            
            if significand == 0 {
                while c != nil && c! == "0" {
                    exponent &-= 1
                    c = iterator.next()
                }
            }
            
            while isDigit(c) && (numDigits < 18) {
                numDigits &+= 1
                exponent &-= 1
                significand *= 10
                significand &+= Int64(c!.asciiValue! &- 48)
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
                numDigits &+= 1
                e *= 10
                e &+= Int(c!.asciiValue!) &- 48
                c = iterator.next()
            }
            
            exponent &+= e * expSign
            
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
        self.init(unsafeSignificand: value, exponent: exponent)
    }
    
    /// Creates a new decimal number with the representable value that's closest to the given integer.
    public init<I>(clamping source: I) where I:BinaryInteger {
        let value: Significand
        if source > 10_000_000_000_000_000 {
            value = 10_000_000_000_000_000
        } else if source < -10_000_000_000_000_000 {
            value = -10_000_000_000_000_000
        } else {
            value = Significand(source)
        }
        self.init(bitPattern: value << Self.exponentBitCount)
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
    @_transparent public mutating func round(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, scale: Int = 0) {
        self = self.rounded(rule, scale: scale)
    }
    
    /// Rounds the value to an integral value using the specified rounding rule.
    /// - parameter rule: The rounding rule to use.
    /// - parameter scale: The number of digits a rounded value should have after its decimal point.  It must be zero or a positive number; otherwise, the program will crash.
    public func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, scale: Int = 0) -> Self {
        precondition(scale >= 0)
        
        let exponent = self.exponent
        let shift = -(exponent &+ scale)
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
        return .init(unsafeSignificand: significand, exponent: -scale)
    }
    
    @_transparent public mutating func normalize() {
        self = self.normalized()
    }
    
    /// Makes the significand number as large as possible while making the exponent the smallest possible value (min is -256).
    public func normalized() -> Self {
        var significand = self.significand
        guard significand != 0 else { return Self.zero }
        
        var exponent = self.exponent
        exponent &-= significand.toMaximumDigits()
        return .init(unsafeSignificand: significand, exponent: exponent)
    }
    
    /// The functions break the number into the integral and the fractional parts.
    /// - attention: The integral part have sign information; therefore, negative number will still contain the negative sign.
    /// - returns: Tuple containing the _whole_/integral and _decimal_/fractional part.
    @_transparent public func decomposed() -> (integral: Decimal64, fractional: Decimal64) {
        let integral = self.rounded(.towardZero, scale: 0)
        let fractional = (self - integral).magnitude
        return (integral, fractional)
    }
    
    /// Shifts to the left `shift` number of decimal digits.
    public static func << (_ lhs: Decimal64, _ shift: Int) -> Decimal64 {
        .init(roundingSignificand: lhs.significand, exponent: lhs.exponent &+ shift)
    }
    
    /// Shifts to the right `shift` number of decimal digits.
    public static func >> (_ lhs: Decimal64, _ shift: Int) -> Decimal64 {
        .init(roundingSignificand: lhs.significand, exponent: lhs.exponent &- shift)
    }
    
    /// Shifts to the left `shift` number of decimal digits and reassign the value to the receiving number.
    @_transparent public static func <<= (_ lhs: inout Decimal64, _ shift: Int) {
        lhs = lhs << shift
    }
    
    /// Shifts to the right `shift` number of decimal digits and reassign the value to the receiving number.
    @_transparent public static func >>= (_ lhs: inout Decimal64, _ shift: Int) {
        lhs = lhs >> shift
    }
}

extension Decimal64 {
    /// Initializer rounding the overflowing components.
    private init(roundingSignificand significand: Significand, exponent: Exponent) {
        guard significand != .zero else { self = .zero; return }
        
        var (absolute, exponent) = (significand, exponent)
        if significand < .zero { absolute.negate() }
        
        // Round the internal coefficient to a maximum of 16 digits.
        if absolute >= Int64.powerOf10.16  {
            if absolute < Int64.powerOf10.17  {
                absolute &+= 5
                absolute /= 10
                exponent &+= 1
            } else if absolute < Int64.powerOf10.18 {
                absolute &+= 50
                absolute /= 100
                exponent &+= 2
            } else {
                // Adding 500 may cause an overflow in signed Int64.
                absolute += 500
                absolute /= 1000
                exponent &+= 3
            }
        }
        
        // Try denormalization if possible
        // TODO: Improve performance.
        if exponent > 253 {
            absolute <<= Self.exponentBitCount
            exponent &-= absolute.shiftLeftTo16() //TODO: numbers with exponent > 253 may be denormalized to much
            absolute >>= Self.exponentBitCount
        } else if exponent < -256 {
            absolute <<= Self.exponentBitCount
            absolute.shift(decimalDigits: exponent &+ 256)
            if absolute != .zero { absolute |= -256 }
            absolute >>= Self.exponentBitCount
        }
        
        if significand < .zero { absolute.negate() }
        self.init(unsafeSignificand: absolute, exponent: exponent)
    }
}
