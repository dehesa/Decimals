import Foundation

// MARK: - Static Functionality

extension Decimal64 {
    /// The type used to store both the mantissa and the exponent.
    @usableFromInline internal typealias InternalStorage = Int64
    /// A type that represents the encoded significand of a value.
    public typealias Significand = Int64
    /// A type that can represent any written exponent.
    public typealias Exponent = Int
    
    /// The radix, or base of exponentiation, for a floating-point type.
    @inlinable public static var radix: Int { 10 }
    /// The bit-size of the internal exponent.
    @inlinable public static var exponentBitCount: Int { 9 }
    /// The bit-size of the internal mantissa.
    @inlinable public static var significandBitCount: Int { 55 }
    
    /// The maximum exponent.
    @inlinable public static var greatestExponent: Int { 255 }
    /// The minimum exponent.
    @inlinable public static var leastExponent: Int { -256 }
    /// The decimal that contains the largest possible non-infinite magnitude for the underlying representation.
    @inlinable public static var greatestFiniteMagnitude: Decimal64 { .init(significand: 9_999_999_999_999_999, exponent: Self.greatestExponent) }
    /// The decimal value that represents the smallest possible non-zero value for the underlying representation.
    @inlinable public static var leastNonzeroMagnitude: Decimal64 { .init(significand: 1, exponent: Self.leastExponent) }
    
    /// Bit-mask matching the exponent.
    @usableFromInline internal static var exponentMask: Int64 { .init(bitPattern: 0x1FF) }
    /// Bit-mask matching the sign bit.
    @usableFromInline internal static var signMask: Int64 { .init(bitPattern: 0x8000000000000000) }
}



// MARK: - Internal Type

/// Custom implementation for a decimal type.
///
/// It uses 55 bits for the significand and 9 bits for exponent; both will be stored as twos complement in case of negative numbers.
/// The significand doesn't have to be normalized (although it is better if it is).
///
///     63                                          9 8            0
///     +--------------------------------------------+-----------+
///     |                significand                 |  exponent |
///     +--------------------------------------------+-----------+
///
/// The significand and exponent represent a decimal number given by the following formula:
///
///     number = significand * (10 ^ exponent)
///
public struct Decimal64 {
    /// Internal storage of 64 bytes composed of 55 bit for a significand and 9 bits for the exponent.
    @usableFromInline internal private(set) var _data: InternalStorage = 0
    
    /// Designated initializer passing the exact bytes for the internal storage.
    /// - attention: This initializer just stores the bytes. It doesn't do any validation.
    /// - parameter storage: The bytes representing the decimal number.
    @usableFromInline @_transparent internal init(storage: InternalStorage) {
        self._data = storage
    }
    
    /// Convenience initializer passing the significand and exponent to be stored internally.
    /// - attention: This initializer just stores the bytes. It doesn't do any validation.
    /// - parameter significand: The number to be multiplied by `10^exponent`.
    /// - parameter exponent: The exponent that `10` will be raised to.
    /// - returns: A decimal number returned by the formula: `number = significand * (10 ^ exponent)`.
    @usableFromInline internal init(significand: Significand, exponent: Exponent) {
        let exp = (significand < 0) ? -exponent: exponent
        self.init(storage: (significand << Self.exponentBitCount) | (InternalStorage(exp) & Self.exponentMask))
    }
    
    /// Convenience initializer passing the significand and exponent to be stored internally.
    ///
    /// The decimal number is represented as follows:
    ///
    ///     number = value * (10 ^ exponent)
    ///
    /// - parameter value: The number to be multiplied by `10^exponent`.
    /// - parameter exponent: The exponent that `10` will be raised to.
    /// - returns: A decimal number or `nil` if the given `exponent` and significand represent a number with more than 16 decimal digits.
    @inlinable public init?(_ value: Significand, raisedBy exponent: Exponent) {
        guard Swift.abs(value) < 10_000_000_000_000_000, (exponent >= Self.leastExponent) && (exponent <= Self.greatestExponent) else { return nil }
        self.init(significand: value, exponent: exponent)
    }
    
    /// The significand of the floating-point value.
    @_transparent public var significand: Significand {
        self._data >> Self.exponentBitCount
    }
    
    /// The exponent of the floating-point value.
    @inlinable public var exponent: Exponent {
        // To access the exponent we have to use the absolute value, since the internal storage is a two's complement.
        let absolute = self.isNegative ? -self._data : self._data
        // The left-shift right-shift sequence restores the sign of the exponent
        return .init( ((absolute & Self.exponentMask) << Self.significandBitCount ) >> Self.significandBitCount )
    }
}

// MARK: - Protocols Conformance

extension Decimal64: Equatable {
    @inlinable public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs._data == rhs._data { return true }
        
        var (leftSignificand, rightSifnificand) = (lhs.significand, rhs.significand)
        if leftSignificand == 0 && rightSifnificand == 0 { return true }
        
        let diff = lhs.exponent - rhs.exponent
        if diff > 0 {
            // lhs has a bigger exponent.
            let shift = leftSignificand.shiftLeftTo17(limit: diff)
            if (shift == diff) && (leftSignificand == rightSifnificand) { return true }
        } else if diff < 0 {
            // rhs has a bigger exponent, i.e. smaller significand if it is equal.
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
        
        let ln = lhs.normalized(), rn = rhs.normalized()
        let le = ln.exponent, re = rn.exponent
        
        if le == re {
            return ln.significand < rn.significand
        } else if le < re {
            return !rn.isNegative
        } else {
            return ln.isNegative
        }
    }
    
    @_transparent public static func > (_ lhs: Self, _ rhs: Self) -> Bool {
        rhs < lhs
    }
    
    @_transparent public static func >= (_ lhs: Self, _ rhs: Self) -> Bool{
        !(lhs < rhs)
    }
    
    @_transparent public static func <= (_ left: Self, _ right: Self) -> Bool {
        !(right < left)
    }
}

extension Decimal64: AdditiveArithmetic {
    @_transparent public static var zero: Self {
        .init(storage: 0)
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
        let sign = lsh.isNegative
        
        if sign == rhs.isNegative {
            lsh.subtractFromThis(rhs, sign)
        } else {
            lsh.addToThis(rhs, sign);
        }
    }
}

extension Decimal64: Numeric {
    @_transparent public init?<T>(exactly source: T) where T: BinaryInteger {
        guard source.magnitude < 10_000_000_000_000_000 else { return nil }
        self.init(storage: Int64(truncatingIfNeeded: source) << Self.exponentBitCount)
    }
    
    public var magnitude: Self {
        guard self.isNegative else { return self }
        return .init(storage: -self._data)
    }
    
    @_transparent public static func * (_ lhs: Self, _ rhs: Self) -> Self {
        var result = lhs
        result *= rhs
        return result
    }
    
    public static func *= (_ left: inout Self, _ right: Self) {
        var myExp = left.exponent
        let rightExp = right.exponent
        
        if ( right._data == 0 || left._data == 0 ) {
            left._data = 0
        } else {
            // Calculate new coefficient
            var myHigh = left.significand
            let myLow  = myHigh % Int64.powerOf10.8
            myHigh /= Int64.powerOf10.8
            
            var otherHigh = right.significand
            let otherLow  = otherHigh % Int64.powerOf10.8
            otherHigh /= Int64.powerOf10.8
            
            var newHigh = myHigh * otherHigh
            var newMid  = myHigh * otherLow + myLow * otherHigh
            var myMan = myLow * otherLow
            
            var shift = 0
            
            if (newHigh > 0) {
                // Make high as big as possible.
                shift = 16 - newHigh.shiftLeftTo17Limit16()
                
                if (shift > 8) {
                    newMid /= Int64.tenToThePower(of: shift - 8)
                    myMan /= Int64.tenToThePower(of: shift)
                } else {
                    newMid *= Int64.tenToThePower(of: 8 - shift)
                    myMan /= Int64.tenToThePower(of: shift)
                }
                
                myMan += newHigh + newMid
            } else if ( newMid > 0 ) {
                // Make mid as big as possible.
                shift = 8 - newMid.shiftLeftTo17Limit8()
                myMan /= Int64.tenToThePower(of: shift)
                myMan += newMid
            }
            
            // Calculate new exponent.
            myExp += rightExp + shift;
            
            left.setComponents( myMan, myExp, left.isNegative != right.isNegative )
        }
    }
}

extension Decimal64: SignedNumeric {
    @_transparent public mutating func negate() {
        self._data = -self._data
    }
    
    @_transparent public prefix static func - (operand: Self) -> Self {
        .init(storage: -operand._data)
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
        self.init(storage: value << Self.exponentBitCount)
    }
}

extension Decimal64: ExpressibleByFloatLiteral {
    @_transparent public init(floatLiteral value: Double) {
        // TODO: Find out a way to pass the literal to decimal number.
        self.init(value)!
    }
}

extension Decimal64 /*: FloatingPoint*/ {
    /// The sign of the floating-point value.
    ///
    /// The sign is `.minus` if the value is negative and `.plus` if the value is zero or positive.
    @_transparent public var sign: FloatingPointSign {
        (self.isNegative) ? .minus : .plus
    }
    
    /// Divide the receiving decimal by a given number number.
    ///
    /// It uses the following algorithm:
    ///
    ///     a = r0, f0*r0 = n0*b + r1, f1*r1 = n1*b + r2, ...
    ///
    /// where `fi` are factors (power of 10) to make remainders `ri` as big as possible and `ni` are integers. Then with g a power of 10 to make `n0` as big as possible:
    ///
    ///     a     1              g          g
    ///     - = ---- * ( g*n0 + -- * n1 + ----- * n2 + ... )
    ///     b   f0*g            f1        f1*f2
    ///
    /// - parameter left: Number to be divided.
    /// - parameter right: Divisor.
    public static func /= (_ lhs: inout Self, _ rhs: Self) {
        var myExp = lhs.exponent
        let rightExp = rhs.exponent
        
        var myMan = lhs.significand
        let otherMan = rhs.significand
        
        if otherMan == 0 {
            fatalError()
        } else if ( myMan != 0 ) && ( rhs._data != 1 ) {
            // Calculate new coefficient
            
            // First approach of result.
            // Make numerator as big as possible.
            var mainShift = myMan.shiftLeftTo18()
            
            // Do division.
            var remainderA = myMan % otherMan
            myMan /= otherMan
            
            // Make result as big as possible.
            var shift = myMan.shiftLeftTo18()
            mainShift += shift
            
            while ( remainderA > 0 )
            {
                shift -= remainderA.shiftLeftTo18()
                if ( shift < -17 )
                {
                    break;
                }
                
                // Do division.
                let remainderB = remainderA % otherMan
                remainderA /= otherMan
                
                remainderA.shift(decimalDigits: shift)
                
                if ( remainderA == 0 )
                {
                    break
                }
                
                myMan += remainderA
                
                remainderA = remainderB
            }
            
            // Calculate new exponent.
            myExp -= rightExp + mainShift
            
            lhs.setComponents( myMan, myExp, lhs.isNegative != rhs.isNegative )
        }
    }
    
    @_transparent public static func / (_ lhs: Decimal64, _ rhs: Decimal64) -> Decimal64 {
        var result = lhs
        result /= rhs
        return result
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
    /// - parameter scale: The number of digits a rounded value should have after its decimal point.
    @inlinable public mutating func round(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, scale: Int = 0) {
        let expScale = self.exponent + scale
        
        if expScale < 0 {
            var man = self.significand
            let sig = (self._data < 0)
            
            var remainder: Int64 = 0
            var half: Int64 = 5
            if rule != .towardZero {
                if expScale >= -16  {
                    remainder = man % Int64.tenToThePower(of: -expScale)
                } else if man != 0 {
                    remainder = 1
                }
                
                if ( rule != .awayFromZero ) && ( expScale >= -18 ) {
                    half *= Int64.tenToThePower(of: -expScale - 1)
                }
            }
            
            // first round down
            man.shift(decimalDigits: expScale)
            
            switch rule {
            case .toNearestOrAwayFromZero:
                if ( remainder >= half ) {
                    man += 1
                }
            case .toNearestOrEven:
                if ( ( remainder > half ) || ( ( remainder == half ) && (( man & Int64(1)) != 0) ) ) {
                    man += 1
                }
            case .towardZero: break
            case .awayFromZero:
                if remainder != 0 {
                    man += 1
                }
            case .down:
                if sig && ( remainder != 0 ) {
                    man += 1
                }
            case .up:
                if !sig && (remainder != 0 ) {
                    man += 1
                }
            @unknown default:
                fatalError()
            }
            
            self._data = man << Self.exponentBitCount
            self._data |= Int64( -scale )
            if sig {
                self._data = -self._data
            }
        } else {
            //TODO: should work with negative scale
            fatalError()
        }
    }
    
    /// Rounds the value to an integral value using the specified rounding rule.
    /// - parameter rule: The rounding rule to use.
    /// - parameter scale: The number of digits a rounded value should have after its decimal point.
    @inlinable public func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, scale: Int = 0) -> Self {
        var result = self
        result.round(rule, scale: scale)
        return result
    }
}

// MARK: - Extra Functionality

extension Decimal64 {
    /// The mathematical constant `π`.
    @inlinable public static var pi: Self {
        .init(significand: 3141592653589793, exponent: -15)
    }
    
    /// The mathematical constant `𝝉`.
    @inlinable public static var tau: Self {
        .init(significand: 6283185307179586, exponent: -15)
    }
    
    /// Returns true if the represented decimal is a negative value.
    ///
    /// Zero and positive values return `false`.
    @usableFromInline internal var isNegative: Bool {
        self._data < 0
    }
    
    public mutating func normalize() {
        self._data = self.normalized()._data
    }
    
    public func normalized() -> Self {
        #warning("It doesn't seem to do what is suppose to do")
        var significand = self.significand
        guard significand != 0 else { return Self.zero }
        /// make exp as small as possible (min is -256)
        var exp = self.exponent
        exp -= toMaximumDigits(&significand)
        return .init(significand: significand, exponent: exp)
    }
    
    /// The functions break the number into integral and fractional parts.
    /// After completion, this contains the signed integral part.
    ///
    /// @retval  Decimal64      The unsigned fractional part of this.
    public mutating func decompose() -> Decimal64 {
        var fractionalPart: Decimal64 = self
        
        self.round(.towardZero, scale: 0)
        fractionalPart -= self
        
        if fractionalPart.isNegative {
            fractionalPart._data.negate()
        }
        return fractionalPart
    }
    
    /// Shifts to the left `shift` number of decimal digits and reassign the value to the receiving number.
    public static func <<= (_ lhs: inout Decimal64, _ shift: Int) {
        lhs.setComponents( lhs.significand, lhs.exponent + shift, lhs.isNegative )
    }
    
    /// Shifts to the right `shift` number of decimal digits and reassign the value to the receiving number.
    public static func >>= (_ lhs: inout Decimal64, _ shift: Int) {
        lhs.setComponents( lhs.significand, lhs.exponent - shift, lhs.isNegative )
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
    public init?(_ value: Double) {
        let value = Swift.abs(value)
        let exp = Int(log10( value ) - 15)
        let man = Int64(value / pow( 10.0, Double(exp) ) + 0.5)
        
        let isNegative = value < 0
        let significand: Significand = isNegative ? -man: man
        self.init(significand, raisedBy: exp)
    }

    // keep for rounding functions which may be needed in init
    //TODO: refactor with better handling of negative values
    private mutating func setComponents( _ man: Int64, _ exp: Int = 0, _ negative: Bool = false) {
        var man = man
        var exp = exp
        var negative = negative

        if man < 0 {
            man = -man
            negative = !negative
        }

        if man == 0 {
            self._data = 0
        } else {
            // Round the internal coefficient to a maximum of 16 digits.
            if man >= Int64.powerOf10.16  {
                if man < Int64.powerOf10.17  {
                    man += 5
                    man /= 10
                    exp += 1
                } else if man < Int64.powerOf10.18 {
                    man += 50
                    man /= 100
                    exp += 2
                } else {
                    // Adding 500 may cause an overflow in signed Int64.
                    man += 500
                    man /= 1000
                    exp += 3
                }
            }

            self._data = man << Self.exponentBitCount

            // try denormalization if possible
            if exp > 253 {
                exp -= self._data.shiftLeftTo16() //TODO: numbers with exponent > 253 may be denormalized to much
                self._data |= Int64( exp )
            } else if  exp < -256 {
                self._data.shift(decimalDigits: exp + 256)

                if self._data != 0 {
                    self._data |= -256
                }
            } else if exp != 0 {
                self._data |=  (InternalStorage(exp) & Self.exponentMask )
            }
        }

        // change sign
        if negative {
            self._data = -self._data
        }
    }

    ///  Compute the sum of the absolute values of this and a second Decimal64.
    ///  All signs are ignored !
    ///
    /// @param   right    Summand.
    mutating func addToThis(_ right: Decimal64, _ negative: Bool) {
        var myExp = self.exponent
        var otherExp = right.exponent

        // Calculate new coefficient
        var myMan = self.significand
        var otherMan = right.significand

        if otherMan == 0 {
            // Nothing to do because NumB is 0.
        } else if myExp == otherExp {
            self.setComponents( myMan + otherMan, myExp, negative )
        } else if ( myExp < otherExp - 32 ) || ( myMan == 0 ) {
            // This is too small, therefore sum is completely sign * |NumB|.
            self._data = right._data
            if negative {
                self._data = -self._data
            }
        } else if ( myExp <= otherExp + 32 ) {
            // -32 <= myExp - otherExp <= 32
            if ( myExp < otherExp ) {
                // Make otherExp smaller.
                otherExp -= otherMan.shiftLeftTo17(limit: min( 17, otherExp - myExp ) )
                if ( myExp != otherExp ) {
                    if ( otherExp > myExp + 16 ) {
                        // This is too small, therefore sum is completely sign * |NumB|.
                        self._data = right._data
                        if negative {
                            self._data = -self._data
                        }
                        return
                    }

                    // myExp is still smaller than otherExp, make it bigger.
                    myMan /= Int64.tenToThePower(of: otherExp - myExp)
                    myExp = otherExp
                }
            } else {
                // Make myExp smaller.
                myExp -= myMan.shiftLeftTo17(limit: min( 17, myExp - otherExp ) )
                if ( myExp != otherExp ) {
                    if ( myExp > otherExp + 16 ) {
                        // Nothing to do because NumB is too small
                        return
                    }

                    // otherExp is still smaller than myExp, make it bigger.
                    otherMan /= Int64.tenToThePower(of: myExp - otherExp)
                }
            }

            // Now both exponents are equal.
            self.setComponents( myMan + otherMan, myExp, negative )
        } else {
            // Nothing to do because NumB is too small
            // otherExp < myExp - 32.
        }

    }

    /// Subtract the absolute value of a Decimal64 from the absolute value of this.
    /// The sign is flipped if the result is negative.
    ///
    /// - Parameters:
    ///   - right: Subtrahend
    ///   - negative: flag if ... is negative
    mutating func subtractFromThis(_ right: Decimal64, _ negative: Bool) {
        var myExp = exponent
        var otherExp = right.exponent

        // Calculate new coefficient
        var myMan = significand
        var otherMan = right.significand

        if ( otherMan == 0 ) {
            // Nothing to do because NumB is 0.
        } else if ( myExp == otherExp ) {
            setComponents( myMan - otherMan, myExp, negative );
        } else if ( ( myExp < otherExp - 32 ) || ( myMan == 0 ) ) {
            // This is too small, therefore difference is completely -sign * |NumB|.
            _data = right._data
            if !negative {
                _data = -_data
            }
        } else if ( myExp <= otherExp + 32 ) {
            // -32 <= myExp - otherExp <= 32
            if ( myExp < otherExp ) {
                // Make otherExp smaller.
                otherExp -= otherMan.shiftLeftTo17(limit: min( 17, otherExp - myExp ) );
                if ( myExp != otherExp ) {
                    if ( otherExp > myExp + 16 ) {
                        // This is too small, therefore difference is completely -sign * |NumB|.
                        _data = right._data
                        if !negative {
                            _data = -_data
                        }
                        return
                    }

                    // myExp is still smaller than otherExp, make it bigger.
                    myMan /= Int64.tenToThePower(of: otherExp - myExp)
                    myExp = otherExp;
                }
            } else {
                // Make myExp smaller.
                myExp -= myMan.shiftLeftTo17(limit: min( 17, myExp - otherExp ) );
                if ( myExp != otherExp ) {
                    if ( myExp > otherExp + 16 ) {
                        // Nothing to do because NumB is too small
                        return;
                    }

                    // otherExp is still smaller than myExp, make it bigger.
                    otherMan /= Int64.tenToThePower(of: myExp - otherExp)
                }
            }

            // Now both exponents are equal.
            self.setComponents( myMan - otherMan, myExp, negative );
        } else {
            // Nothing to do because NumB is too small (myExp > otherExp + 32).
        }

    }

    /// If eventually a high-performance swift is available...
    /// a non-throwing swap may be necessary
    ///
    /// - Parameter other: swaps value with the other Decimal
    public mutating func swap(other: inout Decimal64) {
        let temp = other
        other = self
        self = temp
    }

    /// Convert type to an signed integer (64bit)
    ///
    /// - Parameter limit: The maximum value to be returned, otherwise an exception is thrown
    /// - Returns: Self as signed integer
    func toInt( _ limit: Int64 ) -> Int64 {
        var exp = self.exponent

        if ( exp >= -16 ) {
            var man = self.significand
            var shift = 0

            if exp < 0 {
                man /= Int64.tenToThePower(of: -exp)
                exp = 0
            } else  if ( ( exp > 0 ) && ( exp <= 17 ) ) {
                shift = man.shiftLeftTo17(limit: exp)
            }

            if ( ( man > limit ) || ( shift != exp ) ) {
                //FIXME: learn exception handling in swift...
                // throw Decimal64::OverflowExceptionParam( 1, *this, ( exp - shift ) )
                fatalError()
            }

            if self.isNegative {
                return -man
            } else {
                return man
            }
        }

        return 0
    }
}

// MARK: -

extension Decimal64: CustomStringConvertible {
    public var description: String {
        // optimized after Instruments showed that this function used 1/4 of all the time...
        //      var ca: [UInt8] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
        //      return String(cString: toChar(&ca[0]))
        var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        return String(cString: toChar(&data.0))
    }
}

extension Decimal64: TextOutputStreamable {
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        var man = self.significand

        if man == 0 {
            target.write("0")
            return
        } else if man < 0 {
            man = -man
        }

        var exp = exponent
        var end = UnsafeMutablePointer<UInt8>( &data.30 )
        var start = ll2str( man, end )

        if ( exp < 0 ) {
            end -= 1

            // Try to set a decimal point to make exp equal to zero.
            // Strip off trailing zeroes.
            while ( end.pointee == 0x30 ) && ( exp < 0 ) {
                end -= 1
                exp += 1
            }

            if exp < 0 {
                if exp > start - end - 6 {
                    // Add maximal 6 additional chars left from digits to get
                    // 0.nnn, 0.0nnn, 0.00nnn, 0.000nnn, 0.0000nnn or 0.00000nnn.
                    // The result may have more than 16 digits.
                    while start - end > exp {
                        start -= 1
                        start.pointee = 0x30 // 0
                    }
                }

                let dotPos = ( end - start ) + exp + 1;
                // exp < 0 therefore start + dotPos <= end.
                if dotPos > 0 {
                    memmove( start + dotPos + 1, start + dotPos, 1 - exp )
                    start[ dotPos ] = 0x2E // .
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

                    exp = 1 - dotPos

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
                    _ = ll2str( Int64(exp), end )
                }
            }
            else {
                end += 1
            }
        }
        else if exp + end - start > 16 {
            end -= 1

            exp += end - start //TODO: will it work on 64bit?

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
            _ = ll2str( Int64(exp), end )
        }
        else {
            while exp > 0 {
                end.pointee = 0x30 // 0
                end += 1
                exp -= 1
            }
        }

        if self.isNegative {
            start -= 1
            start.pointee = 0x2D // -
        }

        end.pointee = 0
        target._writeASCII(UnsafeBufferPointer<UInt8>(start: start, count: end - start))
    }
}

extension Decimal64: ExpressibleByStringLiteral {
    /// Reads an Decimal from a string input in the format
    /// ["+"|"-"]? Optional sign
    /// "0".."9"*  any number of digits as integer part
    /// ["." "0".."9"*]? optional a dot with any number of digits as fraction
    /// [("E"|"e") "0".."9"*]? optional an e with any number of digits as exponent
    ///
    /// - Parameter value: the input string
    public init(stringLiteral value: String) {
        self.init(value)!
    }

    public init?(_ value: String) {
        func isDigit( _ c: Character? ) -> Bool {
            return c != nil && c! >= "0" && c! <= "9"
        }

        var iter = value.makeIterator()
        var c = iter.next()

        while c == " " {
            c = iter.next()
        }

//        print(c ?? "END")

        // Check sign
        let sig = ( c == "-" )
        if c == "-"  || c == "+" {
            c = iter.next()
        }

        while c != nil && c! == "0" {
            c = iter.next()
        }

        var man: Int64 = 0
        var exp: Int = 0
        var dig: Int = 0

        // check integer part
        while isDigit(c) && (dig < 18) {
            dig += 1
            man *= 10
            man += Int64(c!.asciiValue! - 48)
            c = iter.next()
        }

        // maybe we have more digits for our precision
        while isDigit(c) {
            exp += 1
            c = iter.next()
        }

        // check fraction part
        if c != nil && c! == "." {
            c = iter.next()

            if man == 0 {
                while c != nil && c! == "0" {
                    exp -= 1
                    c = iter.next()
                }
            }

            while isDigit(c) && (dig < 18) {
                dig += 1
                exp -= 1
                man *= 10
                man += Int64(c!.asciiValue! - 48)
                c = iter.next()
            }

            // maybe we have more digits -> just ignore
            while isDigit(c) {
                c = iter.next()
            }
        }

        if sig {
            man = -man
        }

        if (c != nil) && ((c! == "e") || (c! == "E")) {
            c = iter.next()
            dig = 0
            var e = 0
            var expSign = 1

            if (c != nil) && ((c! == "-") || (c! == "+")) {
                expSign = (c! == "-") ? -1 : 1
                c = iter.next()
            }

            while c != nil && c! == "0" {
                c = iter.next()
            }

            while isDigit(c) && (dig < 3) {
                dig += 1
                e *= 10
                e += Int(c!.asciiValue!) - 48
                c = iter.next()
            }

            exp += e * expSign

            if isDigit(c) {
                while isDigit(c) {
                    c = iter.next()
                }
                return nil
            }
        }
//        print (c ?? "END")
        self.init(man, raisedBy: exp)
    }
}



// MARK: helper functions on Int64

/// Internal helper function to shift a number to the left until
/// it fills 16 digits.
///
/// - Parameters:
///   - num: The number to process, must not have more than 18 digits
/// - Returns: count of shifted digits
func toMaximumDigits( _ num: inout Int64 ) -> Int {
    if num == 0 {
        return 0
    }
    var n = abs(num)
    var result = 0
    // num will overflow if pushed left, just shift to 16 digits

    if n < Int64.powerOf10.8 {
        if n < Int64.powerOf10.4 {
            result = 12
            n &*= Int64.powerOf10.12
        } else {
            result = 8
            n &*= Int64.powerOf10.8
        }
    }
    else {
        if n < Int64.powerOf10.12 {
            result = 4
            n &*= Int64.powerOf10.4
        }
    }

    if n < Int64.powerOf10.14 {
        if n < Int64.powerOf10.13 {
            result &+= 3
            n &*= 1000
        } else {
            result &+= 2
            n &*= 100
        }
    } else if n < Int64.powerOf10.15 {
        result &+= 1
        n &*= 10
    }

    num = (num < 0) ? -n: n
    return result
}

//converting to String
extension Decimal64 {
    /// This function converts number to decimal and produces the string.
    /// It returns  a pointer to the beginning of the string. No leading
    /// zeros are produced, and no terminating null is produced.
    /// The low-order digit of the result always occupies memory position end-1.
    /// The behavior is undefined if number is negative. A single zero digit is
    /// produced if number is 0.
    ///
    /// - Parameters:
    ///   - x: The number.
    ///   - end: Pointer to the end of the buffer.
    /// - Returns: Pointer to beginning of the string.
    private func ll2str(_ x: Int64, _ end: UnsafeMutableRawPointer ) -> UnsafeMutablePointer<UInt8> {
        var x = x
        var end = end

        while x >= 10000 {
            let y = Int(x % 10000)
            x /= 10000
            end -= 4
            memcpy(end, Self.int64LookUp.Pointer + y * 4, 4)
        }

        var dig = 1
        if x >= 100 {
            if x >= 1000 {
                dig = 4
            } else {
                dig = 3
            }
        } else if x >= 10 {
            dig = 2
        }
        end -= dig

        memcpy(end, Self.int64LookUp.Pointer + Int(x) * 4 + 4 - dig, dig)

        return UnsafeMutablePointer<UInt8>.init(OpaquePointer( end))
    }

    // possibly not the fastest swift way. but for now the easiest way to port some c++ code
    private func strcpy( _ buffer: UnsafeMutablePointer<UInt8>, _ content: String ) -> UnsafeMutablePointer<UInt8> {
        var pos = buffer

        for c in content.utf8 {
            pos.pointee = c
            pos += 1
        }
        return buffer
    }

    func toChar( _ buffer: UnsafeMutablePointer<UInt8> ) -> UnsafeMutablePointer<UInt8> {
        var man = significand

        if man == 0 {
            return strcpy( buffer, "0" )
        } else if man < 0 {
            man = -man
        }

        var exp = exponent
        var end = buffer.advanced(by: 30)
        var start = ll2str( man, end )

        if ( exp < 0 ) {
            end -= 1

            // Try to set a decimal point to make exp equal to zero.
            // Strip off trailing zeroes.
            while ( end.pointee == 0x30 ) && ( exp < 0 ) {
                end -= 1
                exp += 1
            }

            if exp < 0 {
                if exp > start - end - 6 {
                    // Add maximal 6 additional chars left from digits to get
                    // 0.nnn, 0.0nnn, 0.00nnn, 0.000nnn, 0.0000nnn or 0.00000nnn.
                    // The result may have more than 16 digits.
                    while start - end > exp {
                        start -= 1
                        start.pointee = 0x30 // 0
                    }
                }

                let dotPos = ( end - start ) + exp + 1;
                // exp < 0 therefore start + dotPos <= end.
                if dotPos > 0 {
                    memmove( start + dotPos + 1, start + dotPos, 1 - exp )
                    start[ dotPos ] = 0x2E // .
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

                    exp = 1 - dotPos

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
                    _ = ll2str( Int64(exp), end )
                }
            }
            else {
                end += 1
            }
        }
        else if exp + end - start > 16 {
            end -= 1

            exp += end - start //TODO: will it work on 64bit?

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
            _ = ll2str( Int64(exp), end )
        }
        else {
            while exp > 0 {
                end.pointee = 0x30 // 0
                end += 1
                exp -= 1
            }
        }

        if self.isNegative {
            start -= 1
            start.pointee = 0x2D // -
        }

        end.pointee = 0

        return start
    }


    struct LookUpTable {
        var Pointer: UnsafeMutableRawPointer

        init() {
            Pointer = UnsafeMutableRawPointer.allocate( byteCount: 40000, alignment: 8 )
            var fill = Pointer
            for i in 0...9999 {
                var val = i
                fill.storeBytes(of: UInt8(val / 1000) + 48, as: UInt8.self)
                val %= 1000
                fill += 1
                fill.storeBytes(of: UInt8(val / 100) + 48, as: UInt8.self)
                val %= 100
                fill += 1
                fill.storeBytes(of: UInt8(val / 10) + 48, as: UInt8.self)
                val %= 10
                fill += 1
                fill.storeBytes(of: UInt8(val) + 48, as: UInt8.self)
                fill += 1
            }
        }
    }

    static let int64LookUp = LookUpTable()
}
