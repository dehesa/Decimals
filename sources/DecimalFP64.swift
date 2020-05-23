import Foundation

/// Struct to represent decimal floating point 64 bit numbers.
///
/// This class represents floating point numbers having a 54 bit coefficient, a sign bit and a 9 bit exponent. The coefficient range from bit 0 to 53, the sign bit is bit 54 and the exponent range from bit 55 to 63. The accuracy of this representation is 16 decimal digits.
///
/// It was designed after ideas from C++ code modelled after the "General Decimal Arithmetic Specification" [Version 1.11 from 2003-02-21](http://www2.hursley.ibm.com/decimal/decarith.pdf) which has moved to a [new site](http://speleotrove.com/decimal/decarith.pdf).
public struct DecimalFP64 {
    /// The type used to store both the mantissa and the exponent.
    @usableFromInline internal typealias InternalStorage = Int64
    /// Internal storage of 64 bytes composed.
    @usableFromInline internal private(set) var _data: InternalStorage = 0
}

// MARK: -

extension DecimalFP64: Equatable {
    ///  Compare two decimal numbers.
    /// - parameter left: Number to compare.
    /// - parameter right: Number to compare.
    /// - returns: `true` if both are equal ( A == B ), `false` both differ ( A != B ).
    public static func == (_ left: Self, _ right: Self) -> Bool {
        var leftMan = left.getMantissa()
        var rightMan = right.getMantissa()
        
        var result = false
        // Same as left.getSign() == right.getSign() but faster.
        if ((left._data & signMask) == (right._data & signMask)) {
            var leftExp = left.getExponent()
            var rightExp = right.getExponent()
            
            if ((leftExp == rightExp) || (leftMan == 0) || (rightMan == 0)) {
                result = ( leftMan == rightMan );
            } else if ((leftExp > rightExp - 18) && (leftExp < rightExp)) {
                // Try to make rightExp smaller to make it equal to leftExp.
                rightExp -= rightMan.shiftLeftTo17(limit: rightExp - leftExp)
                
                if ( leftExp == rightExp ) {
                    result = ( leftMan == rightMan );
                }
            } else if ((leftExp < rightExp + 18) && (leftExp > rightExp)) {
                // Try to make leftExp smaller to make it equal to rightExp.
                leftExp -= leftMan.shiftLeftTo17(limit: leftExp - rightExp )
                
                if (leftExp == rightExp) {
                    result = ( leftMan == rightMan );
                }
            } else {
                // The exponents differ more than +-17,
                // therefore the numbers can never be equal.
            }
        } else {
            // A >= 0 and B <= 0 or A <= 0 and B >= 0.
            result = ( leftMan == 0 ) && ( rightMan == 0 );
        }
        
        return result;
    }
}

extension DecimalFP64: Comparable {
    ///  Compare two decimal numbers.
    /// - parameters left: Number to compare.
    /// - parameters right: Number to compare.
    /// - returns: `true`  A is smaller than B ( A < B), `false` if A is bigger or equal to B (A >= B ).
    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        var result = false
        let leftSign = lhs.getSign()
        let rightSign = rhs.getSign()
        
        if leftSign && !rightSign {
            // A <= 0 and B >= 0.
            result = (lhs.getMantissa() != 0) || (rhs.getMantissa() != 0)
        } else if !leftSign && rightSign {
            // A >= 0 and B <= 0.
            result = false
        } else {
            // Both are either positive or negative or 0.
            var leftMan = lhs.getMantissa()
            var rightMan = rhs.getMantissa()
            
            var leftExp = lhs.getExponent()
            var rightExp = rhs.getExponent()
            
            // Lets assume both are positive.
            if ((leftExp == rightExp) || (leftMan == 0) || (rightMan == 0)) {
                result = ( leftMan < rightMan );
            } else if ( rightExp >= leftExp + 18 ) {
                // A > B > 0.
                result = true
            } else if ( rightExp > leftExp - 18 ) {
                // -18 < rightExp - leftExp < 18 and A,B > 0.
                if (leftExp < rightExp) {
                    // Try to make rightExp smaller to make it equal to leftExp.
                    rightExp -= rightMan.shiftLeftTo17(limit: rightExp - leftExp)
                    
                    // If rightExp is greater than leftExp then rightMan > Int64.powerOf10.16 > leftMan.
                    result = true;
                } else {
                    // Try to make leftExp smaller to make it equal to rightExp.
                    leftExp -= leftMan.shiftLeftTo17(limit: leftExp - rightExp)
                    
                    // If leftExp is greater than rightExp then leftMan > Int64.powerOf10.16 > rightMan.
                }
                
                if (leftExp == rightExp) {
                    result = ( leftMan < rightMan );
                }
            } else {
                // rightExp <= leftExp - 18 and A,B > 0. => A > B, therefore false.
            }
            
            // If both are negative and not equal then ret = ! ret.
            if leftSign {
                if result {
                    result = false;
                } else {
                    result = ( leftExp != rightExp ) || ( leftMan != rightMan );
                }
            }
        }
        
        return result;
    }
    
    @_transparent public static func > (_ lhs: Self, _ rhs: Self) -> Bool {
        rhs < lhs
    }
    
    @_transparent public static func >= (_ lsh: Self, _ rhs: Self) -> Bool {
        !(lsh < rhs)
    }
    
    @_transparent public static func <= (_ lsh: Self, _ rhs: Self) -> Bool {
        !(rhs < lsh)
    }
}

extension DecimalFP64: AdditiveArithmetic {
    @_transparent public static var zero: Self {
        .init(0)
    }
    
    public static func + (_ lsh: Self, _ rhs: Self) -> Self {
        var result = lsh
        result += rhs
        return result
    }
    
    public static func - (_ lhs: Self, _ rhs: Self) -> Self {
        var result = lhs
        result -= rhs
        return result
    }
    
    //  Add a number to the receiving decimal number.
    //    |a| < |b|          |a| > |b|
    //  a+b | + | -        a+b | + | -
    //  ----+---+---       ----+---+---
    //   +  |+a+|+s-        +  |+a+|+s+
    //  ----+---+---       ----+---+---
    //   -  |-s+|-a-        -  |-s-|-a-
    public static func += (_ lhs: inout Self, _ rhs: Self) {
        let sign = lhs.getSign()
        
        if sign == rhs.getSign() {
            lhs.addToThis( rhs, sign )
        }
        else {
            lhs.subtractFromThis( rhs, sign )
        }
    }
    
    //  Subtract a number from this.
    //     |a| < |b|          |a| > |b|
    //     a-b | + | -        a-b | + | -
    //     ----+---+---       ----+---+---
    //     +  |+s-|+a+        +  |+s+|+a+
    //     ----+---+---       ----+---+---
    //     -  |-a-|-s+        -  |-a-|-s-
    public static func -= (_ lhs: inout Self, _ rhs: Self) {
        let sign = lhs.getSign()
        
        if  sign == rhs.getSign() {
            lhs.subtractFromThis( rhs, sign )
        } else {
            lhs.addToThis( rhs, sign );
        }
    }
}

extension DecimalFP64: Numeric {
    @_transparent public init?<Source>(exactly source: Source) where Source: BinaryInteger {
        fatalError()
    }
    
    public var magnitude: Self {
        Self.abs(self)
    }
    
    @_transparent public static func * (_ lhs: Self, _ rhs: Self) -> Self {
        var result = lhs
        result *= rhs
        return result
    }
    
    // Multiply receiving number by a number.
    //
    //     newExp = aExp + bExp + shift
    //     newMan = ah*bh * 10^(16-shift) + (ah*bl + al*bh) * 10^(8-shift) +
    //              al*bl * 10^-shift
    //
    // shift is a unique integer so that newMan fits into 54 bits with the highest accuracy.
    public static func *=(_ lhs: inout Self, _ rhs: Self) {
        var myExp = lhs.getExponent()
        let rightExp = rhs.getExponent()
        
        // equivalent to ( !isNumber() || !right.isNumber() ) but faster
        if (myExp > 253 || rightExp > 253) {
            // Infinity is reached if one or both of the exp are 254
            if (( myExp <= 254 ) && ( rightExp <= 254 )) {
                let flipSign = lhs.getSign() != rhs.getSign()
                lhs.setInfinity()
                
                if ( flipSign ) {
                    lhs.minus();
                }
            } else { // NaN is set if both exp are greater than 254
                lhs.setNaN();
            }
        } else if ( rhs._data == 0 || lhs._data == 0 ) {
            lhs._data = 0
        } else {
            // Calculate new coefficient
            var myHigh = lhs.getMantissa()
            let myLow  = myHigh % Int64.powerOf10.8
            myHigh /= Int64.powerOf10.8
            
            var otherHigh = rhs.getMantissa()
            let otherLow  = otherHigh % Int64.powerOf10.8
            otherHigh /= Int64.powerOf10.8
            
            var newHigh = myHigh * otherHigh
            var newMid  = myHigh * otherLow + myLow * otherHigh
            var myMan = myLow * otherLow
            
            var shift = 0
            
            if ( newHigh > 0 ) {
                // Make high as big as possible.
                shift = 16 - newHigh.shiftLeftTo17Limit16()
                
                if ( shift > 8 )
                {
                    newMid /= Int64.tenToThePower(of: shift - 8)
                    myMan /= Int64.tenToThePower(of: shift)
                }
                else
                {
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
            
            lhs.setComponents( myMan, myExp, lhs.getSign() != rhs.getSign() )
        }
    }
}

extension DecimalFP64: SignedNumeric {
    public mutating func negate() {
        self._data ^= Self.signMask
    }
    
    public static prefix func - (_ operand: Self) -> Self {
        var result = operand
        result.minus()
        return result
    }
}

extension DecimalFP64: Strideable {
    public func distance(to other: Self) -> Self {
        other - self
    }
    
    public func advanced(by n: Self) -> Self {
        self + n
    }
}

extension DecimalFP64: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self.init(value)
    }
}

extension DecimalFP64: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

//extension DecimalFP64: ExpressibleByStringLiteral {
//    public init(stringLiteral value: StringLiteralType) {
//        fatalError()
//    }
//}

extension DecimalFP64: FloatingPoint {
    public typealias Exponent = Int
    
    public init(_ value: Int) {
        self.init(value, 0)
    }
    
    public init<Source>(_ value: Source) where Source: BinaryInteger {
        fatalError()
    }
    
    public init(sign: FloatingPointSign, exponent: Self.Exponent, significand: Self) {
        self.setComponents(significand.getMantissa(), exponent + significand.getExponent(), sign == .minus )
    }
    
    public init(signOf: Self, magnitudeOf: Self) {
        self.setComponents(magnitudeOf.getMantissa(), magnitudeOf.getExponent(), signOf.getSign())
    }
    
    public var exponent: Exponent {
        self.getExponent()
    }
    
    public var floatingPointClass: FloatingPointClassification {
        if self.isNaN { // we don't have .signalingNaN
            return .quietNaN
        }
        
        if self.getSign() {
            if self.isInfinity() { return .negativeInfinity }
            if self.isZero { return .negativeZero }
            if self.isNormal { return .negativeNormal }
            return .negativeSubnormal
        }
        
        if isInfinity() {
            return .positiveInfinity
        }
        
        if isZero {
            return .positiveZero
        }
        
        if isNormal {
            return .positiveNormal
        }
        
        return .positiveSubnormal
    }
    
    public var isCanonical: Bool {
        true //FIXME: for now I just don't care
    }
    
    public var isFinite: Bool {
        assertionFailure("not yet implemented")
        return true
    }
    
    public var isInfinite: Bool {
        assertionFailure("not yet implemented")
        return false
    }
    
    public var isNaN: Bool {
        self.isQuiteNaN() || self.isSignalingNaN
    }
    
    public var isNormal: Bool {
        assertionFailure("not yet implemented")
        return true
    }
    
    public var isSignalingNaN: Bool {
        false
    }
    
    public var isSubnormal: Bool {
        assertionFailure("not yet implemented")
        return false
    }
    
    public var isZero: Bool {
        self == 0.0
    }
    
    public var nextDown: Self {
        assertionFailure("not implemented")
        return self
    }
    
    public var nextUp: Self {
        assertionFailure("not implemented")
        return self
    }
    
    public var sign: FloatingPointSign {
        self.getSign() ? .minus : .plus
    }
    
    public var significand: Self {
        Self(self.getMantissa())
    }
    
    public var ulp: Self {
        var result = self
        result.setComponents(1, result.getExponent(), result.getSign() ) //TODO: Check if correct don't know if normalization is necessary
        return result
    }
    
    public static var greatestFiniteMagnitude: Self {
        Self(Int64(9_999_999_999_999_999), 255, false) //TODO: Check Exponent
    }
    
    public static var infinity: Self {
        var this: Self = 0
        this.setInfinity()
        return this
    }
    
    public static var leastNonzeroMagnitude: Self {
        Self(Int64(1), -256, false) //TODO: Check exponent
    }
    
    public static var leastNormalMagnitude: Self {
        Self(Int64(1_000_000_000_000_000), -256, false) //TODO: Check exponent
    }
    
    public static var nan: Self {
        var this: Self = 0
        this.setNaN()
        return this
    }
    
    public static var pi: Self {
        Self(Double.pi)
    }
    
    @_transparent public static var radix: Int {
        10
    }
    
    public static var signalingNaN: Self {
        //TODO: what?
        Self.nan
    }
    
    public static var ulpOfOne: Self {
        Self(1.000000000000001) - Self(1)
    }
    
    public mutating func addProduct(_ lhs: Self, _ rhs: Self) {
        assertionFailure("not implemented yet")
    }
    
    public func addingProduct(_ lhs: Self, _ rhs: Self) -> Self {
        assertionFailure("not implemented yet")
        return self
    }
    
    public mutating func formRemainder(dividingBy other: Self) {
        assertionFailure("not implemented yet")
    }
    
    public mutating func formSquareRoot() {
        assertionFailure("not implemented yet")
    }
    
    public mutating func formTruncatingRemainder(dividingBy other: Self) {
        assertionFailure("not implemented yet")
    }
    
    public func isEqual(to other: Self) -> Bool {
        self == other
    }
    
    public func isLess(than other: Self) -> Bool {
        return self < other
    }
    
    public func isLessThanOrEqualTo(_ other: Self) -> Bool {
        return self < other || self == other
    }
    
    public func isTotallyOrdered(belowOrEqualTo other: Self) -> Bool {
        return isLessThanOrEqualTo(other) //TODO: ???
    }
    
    public func remainder(dividingBy other: Self) -> Self {
        assertionFailure("not implemented yet")
        return self
    }
    
    public mutating func round(_ rule: FloatingPointRoundingRule) {
        self.round(0, rule)
    }
    
    public func rounded(_ rule: FloatingPointRoundingRule) -> Self {
        var result = self
        result.round(rule)
        return result
    }
    
    public func squareRoot() -> Self {
        assertionFailure("not implemented yet")
        return self
    }
    
    public func truncatingRemainder(dividingBy other: Self) -> Self {
        assertionFailure("not implemented yet")
        return self
    }
    
    public static func minimum(_ x: Self, _ y: Self) -> Self {
        assertionFailure("not implemented yet")
        return x
    }
    
    public static func minimumMagnitude(_ x: Self, _ y: Self) -> Self {
        assertionFailure("not implemented yet")
        return x
    }
    
    public static func maximum(_ x: Self, _ y: Self) -> Self {
        assertionFailure("not implemented yet")
        return x
    }
    
    public static func maximumMagnitude(_ x: Self, _ y: Self) -> Self {
        assertionFailure("not implemented yet")
        return x
    }
    
    public static func / (_ left: Self, _ right: Self) -> Self {
        var result = left
        result /= right
        return result
    }
    
    //  Using the following algorithm: `a = r0, f0*r0 = n0*b + r1, f1*r1 = n1*b + r2, ...` where fi are factors (power of 10) to make remainders ri as big as possible and ni are integers. Then with g a power of 10 to make n0 as big as possible:
    //
    //      a     1              g          g
    //      - = ---- * ( g*n0 + -- * n1 + ----- * n2 + ... )
    //      b   f0*g            f1        f1*f2
    public static func /= (_ left: inout Self, _ right: Self) {
        var myExp = left.getExponent()
        let rightExp = right.getExponent()
        
        var myMan = left.getMantissa()
        let otherMan = right.getMantissa()
        
        // equivalent to ( !isNumber() || !right.isNumber() ) but faster
        if ((myExp > 253) || (rightExp > 253)) {
            if ( ( myExp == 254 ) && ( rightExp <= 254 ) ) {
                let flipSign = (left.getSign() != right.getSign());
                left.setInfinity()
                
                if ( flipSign ){
                    left.minus();
                }
            } else if ( ( myExp <= 253 ) && ( rightExp == 254 ) ) {
                left._data = 0
            } else {
                left.setNaN();
            }
        } else if ( otherMan == 0 ) {
            let sign = left.getSign();
            left.setInfinity()
            
            if sign {
                left.minus()
            }
        } else if ( myMan != 0 ) && ( right._data != 1 ) {
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
            
            while ( remainderA > 0 ) {
                shift -= remainderA.shiftLeftTo18()
                if (shift < -17) { break }
                
                // Do division.
                let remainderB = remainderA % otherMan
                remainderA /= otherMan
                
                remainderA.shift(decimalDigits: shift)
                
                if (remainderA == 0) { break }
                
                myMan += remainderA
                
                remainderA = remainderB
            }
            
            // Calculate new exponent.
            myExp -= rightExp + mainShift
            
            left.setComponents( myMan, myExp, left.getSign() != right.getSign() )
        }
    }
}

extension DecimalFP64: CustomStringConvertible {
    public var description: String {
        var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
                  ) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        return String(cString: toChar(&data.0))
    }
}

extension DecimalFP64: TextOutputStreamable {
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
                  ) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)

        guard !self.isNaN else { return target.write("NaN") }

        guard !self.isInfinity() else {
            if self.getSign() {
                return target.write("-Inf")
            } else {
                return target.write("Inf")
            }
        }

        let man = self.getMantissa()
        guard man != 0 else { return target.write("0") }

        var exp = self.getExponent();
        withUnsafeMutablePointer(to: &data.30) {
            var end = $0
            var start = man.toString(end: end)
            
            if (exp < 0) {
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
                    } else {
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
                        _ = Int64(exp).toString(end: end)
                    }
                } else {
                    end += 1
                }
            } else if exp + end - start > 16 {
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
                _ = Int64(exp).toString(end: end)
            } else {
                while exp > 0 {
                    end.pointee = 0x30 // 0
                    end += 1
                    exp -= 1
                }
            }
            
            if self.getSign() {
                start -= 1
                start.pointee = 0x2D // -
            }
            
            end.pointee = 0
            target._writeASCII(UnsafeBufferPointer<UInt8>(start: start, count: end - start))
        }
    }
}

// MARK: -

extension DecimalFP64 {
    public init(_ value: Int8) {
        self.init(value, 0)
    }
    
    public init(_ value: Int8 , _ exponent: Exponent = 0) {
        self.init(Int64(value), exponent)
    }
    
    public init(_ value: UInt8) {
        self.init(value, 0)
    }
    
    public init(_ value: UInt8, _ exponent: Exponent = 0) {
        self.init(Int64(value), exponent)
    }
    
    public init(_ value: Int16) {
        self.init(value, 0)
    }
    
    public init(_ value: Int16, _ exponent: Exponent = 0) {
        self.init(Int64(value), exponent)
    }
    
    public init(_ value: UInt16) {
        self.init(value, 0)
    }
    
    public init(_ value: UInt16, _ exponent: Exponent = 0) {
        self.init(Int64(value), exponent)
    }
    
    public init(_ value: Int32) {
        self.init(value, 0)
    }
    
    public init(_ value: Int32, _ exponent: Exponent = 0) {
        self.init(Int64(value), exponent)
    }
    
    public init(_ value: UInt32) {
        self.init(value, 0)
    }
    
    public init(_ value: UInt32, _ exponent: Exponent = 0) {
        self.init( Int64(value), exponent )
    }
    
    public init(_ value: Int64) {
        self.init(value, 0)
    }
    
    public init(_ value: UInt64) {
        self.init(value, 0)
    }
    
    public init(_ value: UInt) {
        self.init(value, 0)
    }
    
    public init(_ value: Int, _ exponent: Exponent = 0) {
        self.init(Int64(value), exponent)
    }
    
    public init(_ value: UInt, _ exponent: Exponent = 0) {
        self.init(Int64(value), exponent)
    }
    
    public init( _ mantissa: Int64, _ exponent: Int = 0, _ negative: Bool = false) {
        self.setComponents(mantissa, exponent, negative)
    }
    
    public init(_ mantissa: UInt64, _ exponent: Int = 0, _ negative: Bool = false) {
        self.setComponents(Int64(mantissa), exponent, negative) // will overflow if greater >Int64.max
    }
    
    public init(_ value: Double) {
        var isNegative = false
        var value = value
        
        if (value < 0) {
            isNegative = true
            value = -value
        }
        
        let exp = Int( log10( value ) - 15 )
        let man = Int64( value / pow( 10.0, Self.FloatLiteralType( exp ) ) + 0.5 )
        
        self.setComponents( man, exp, isNegative )
    }
    
    /// Bit-mask matching the exponent.
    @usableFromInline @_transparent internal static var exponentMask: InternalStorage { .init(bitPattern: 0xFF80000000000000) }
    /// Bit-mask matching the significand.
    @_transparent private static var significandMask: InternalStorage { .init(bitPattern: 0x003FFFFFFFFFFFFF) }
    /// Bit-mask matching the sign.
    @_transparent private static var signMask: InternalStorage { .init(bitPattern: 0x0040000000000000) }
    /// Number of coefficient + sign bits.
    @_transparent private static var exponentShift: InternalStorage { 55 }
    
    public func negated() -> Self {
        var left = self
        left.negate()
        return left
    }
    
    /// Round a decimal number according to the given digits and rounding method.
    /// - parameter scale:  The number of digits right from the decimal point.
    /// - parameter method: The rounding method.
    /// - returns: The rounded number.
    mutating func round(_ scale: Int, _ method: FloatingPointRoundingRule) {
        let expScale = self.getExponent() + scale
        
        //TODO: should work with negative scale
        if expScale < 0 {
            var man = self.getMantissa()
            let sig = self._data & Self.signMask
            
            var remainder: Int64 = 0
            var half: Int64 = 5
            if method != .towardZero {
                if expScale >= -16  {
                    remainder = man % Int64.tenToThePower(of: -expScale)
                } else if man != 0 {
                    remainder = 1
                }
                if (method != .awayFromZero) && (expScale >= -18) {
                    half *= Int64.tenToThePower(of: -expScale - 1)
                }
            }
            
            // first round down
            man.shift(decimalDigits: expScale)
            
            switch method {
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
                if sig != 0 && remainder != 0 {
                    man += 1
                }
            case .up:
                if sig == 0 && remainder != 0 {
                    man += 1
                }
            @unknown default:
                fatalError()
            }
            
            self._data = man
            self._data |= sig
            self._data |= Int64( -scale ) << Self.exponentShift
        }
    }
    
    // Arithmetical operations (see GDA specification) they all return *this
    static func round(_ op: Self, _ exp: Int = 0, _ method: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Self {
        var result = op
        result.round(exp, method)
        return result
    }
    
    func isQuiteNaN() -> Bool {
        return self._data == 0x7F80000000000000
    }
    
    func getSign() -> Bool {
        (self._data & Self.signMask) != 0
    }
    
    /// Return the exponent (incl. NaN, Inf)
    func getExponent() -> Int {
        Int(self._data >> Self.exponentShift)
    }
    
    // Return the positive mantissa
    func getMantissa() -> Int64 {
        self._data & Self.significandMask
    }
    
    /// This methods sets the internal represantation according to the
    /// parameters coefficient, exponent and sign.
    /// The result is never Not-a-Number(NaN) but can be
    /// +/- infinity if the exponent is to large or zero if the exponent is
    /// to small
    ///
    /// - Parameters:
    ///   - mantissa: coefficient of result
    ///   - exponent: exponent of result valid range is -256 to +253
    ///   - negative: Sign of the result (-0 is valid and distinct from +0 (but compares equal))
    mutating func setComponents( _ mantissa: Int64, _ exponent: Int = 0, _ negative: Bool = false) {
        var mantissa = mantissa
        var exponent = exponent
        var negative = negative
        // exponent  255 is NaN (we don't care about sign from NaN)
        // exponent  254 is +/- infinity
        
        if  mantissa < 0 {
            mantissa = -mantissa
            negative = !negative
        }
        
        if  mantissa == 0 {
            self._data = 0
        }
        else
        {
            // Round the internal coefficient to a maximum of 16 digits.
            if mantissa >= Int64.powerOf10.16  {
                if mantissa < Int64.powerOf10.17  {
                    mantissa += 5
                    mantissa /= 10
                    exponent += 1
                }
                else if mantissa < Int64.powerOf10.18 {
                    mantissa += 50
                    mantissa /= 100
                    exponent += 2
                }
                else {
                    // Adding 500 may cause an overflow in signed Int64.
                    mantissa += 500
                    mantissa /= 1000
                    exponent += 3
                }
            }
            
            self._data = mantissa
            
            // try denormalization if possible
            if exponent > 253 {
                exponent -= self._data.shiftLeftTo16() //TODO: numbers with exponent > 253 may be denormalized to much
                
                if exponent > 253 {
                    self.setInfinity()
                }
                else {
                    self._data |= Int64( exponent ) << Self.exponentShift
                }
            }
            else if  exponent < -256 {
                self._data.shift(decimalDigits: exponent + 256)
                
                if self._data != 0 {
                    self._data |= -256 << Self.exponentShift
                }
            }
            else if exponent != 0 {
                self._data |= Int64(exponent) << Self.exponentShift
            }
        }
        
        // change sign
        if negative {
            self._data |= Self.signMask
        }
    }
    
    // Arithmetical operations (see GDA specification) they all return *this
    /// The result is non-negative
    mutating func abs() {
        self._data &= ~Self.signMask
    }
    static func abs(_ op: Self) -> Self {
        var result = op
        result.abs()
        return result
    }
    
    /// The functions break the number into integral and fractional parts.
    ///
    /// After completion, this contains the signed integral part.
    /// - returns: The unsigned fractional part of this.
    mutating func decompose() -> Self {
        var fracPart = self
        self.round(0, .towardZero)
        fracPart -= self
        fracPart.abs()
        return fracPart
    }
    
    mutating func minus() {
        self._data ^= Self.signMask
    }
    
    mutating func setSign(_ negative: Bool) {
        if negative {
            self._data |= Self.signMask
        } else {
            self._data &= ~Self.signMask
        }
    }
    
    ///  Compute the sum of the absolute values of this and a second receiving number.
    ///
    ///  All signs are ignored!
    /// - parameter right: Summand.
    mutating func addToThis(_ right: Self, _ negative: Bool) {
        var myExp = self.getExponent()
        var otherExp = right.getExponent()
        
        if (myExp > 253) || (otherExp > 253) { // equivalent to ( !isNumber() || !right.isNumber() ) but faster
            if ( ( myExp <= 254 ) && ( otherExp <= 254 ) ) {
                self.setInfinity()
                
                if negative {
                    self.minus()
                }
            } else {
                self.setNaN()
            }
        } else {
            // Calculate new coefficient
            var myMan = self.getMantissa()
            var otherMan = right.getMantissa()
            
            if otherMan == 0 {
                // Nothing to do because NumB is 0.
            } else if myExp == otherExp {
                self.setComponents( myMan + otherMan, myExp, negative )
            } else if ( myExp < otherExp - 32 ) || ( myMan == 0 ) {
                // This is too small, therefore sum is completely sign * |NumB|.
                self._data = right._data
                self.setSign( negative )
            } else if ( myExp <= otherExp + 32 ) {
                // -32 <= myExp - otherExp <= 32
                if ( myExp < otherExp ) {
                    // Make otherExp smaller.
                    otherExp -= otherMan.shiftLeftTo17(limit: min( 17, otherExp - myExp ))
                    if ( myExp != otherExp ) {
                        if ( otherExp > myExp + 16 ) {
                            // This is too small, therefore sum is completely sign * |NumB|.
                            self._data = right._data
                            return self.setSign(negative)
                        }
                        
                        // myExp is still smaller than otherExp, make it bigger.
                        myMan /= Int64.tenToThePower(of: otherExp - myExp)
                        myExp = otherExp
                    }
                } else {
                    // Make myExp smaller.
                    myExp -= myMan.shiftLeftTo17(limit: min( 17, myExp - otherExp ))
                    if (myExp != otherExp) {
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
    }
    
    /// Subtract the absolute value of a decimal number from the absolute value of this.
    ///
    /// The sign is flipped if the result is negative.
    /// - parameter right: Subtrahend.
    /// - parameter negative:flag if ... is negative.
    mutating func subtractFromThis(_ right: Self, _ negative: Bool) {
        var myExp = self.getExponent();
        var otherExp = right.getExponent();
        
        // equivalent to ( !isNumber() || !right.isNumber() ) but faster
        if (myExp > 253 || otherExp > 253) {
            if ( ( myExp == 254 ) && ( otherExp <= 254 ) ) {
                // Nothing to do
            } else if ( ( myExp <= 253 ) && ( otherExp == 254 ) ) {
                self.setInfinity();
                
                if negative {
                    self.minus();
                }
            } else {
                self.setNaN();
            }
        } else {
            // Calculate new coefficient
            var myMan = self.getMantissa()
            var otherMan = right.getMantissa()
            
            if ( otherMan == 0 ) {
                // Nothing to do because NumB is 0.
            } else if ( myExp == otherExp ) {
                self.setComponents( myMan - otherMan, myExp, negative );
            } else if (( myExp < otherExp - 32 ) || ( myMan == 0 )) {
                // This is too small, therefore difference is completely -sign * |NumB|.
                self._data = right._data
                self.setSign( !negative )
            } else if ( myExp <= otherExp + 32 ) {
                // -32 <= myExp - otherExp <= 32
                if (myExp < otherExp) {
                    // Make otherExp smaller.
                    otherExp -= otherMan.shiftLeftTo17(limit: min( 17, otherExp - myExp ))
                    if (myExp != otherExp) {
                        if (otherExp > myExp + 16) {
                            // This is too small, therefore difference is completely -sign * |NumB|.
                            self._data = right._data
                            return self.setSign(!negative)
                        }
                        
                        // myExp is still smaller than otherExp, make it bigger.
                        myMan /= Int64.tenToThePower(of: otherExp - myExp)
                        myExp = otherExp;
                    }
                } else {
                    // Make myExp smaller.
                    myExp -= myMan.shiftLeftTo17(limit: min( 17, myExp - otherExp ))
                    if (myExp != otherExp) {
                        if (myExp > otherExp + 16) {
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
    }
    
    /// if sometime a high-performance swift is available... maybe a non-throwing swap is necessary.
    /// - parameter other: the other value that will be exchanged with self.
    mutating func swap(other: inout Self) {
        let temp = other
        other = self
        self = temp
    }
    
    // TBD which is... methods are necessary
    func isNegative() -> Bool {
        (self._data & Self.signMask) == Self.signMask
    }
    
    func isInfinity() -> Bool {
        self._data & Self.exponentMask == 0x7F00000000000000
    }
    
    mutating func setNaN() {
        self._data = 0x7F80000000000000
    } //TODO: keep sign and coefficient
    
    mutating func setInfinity() {
        self._data = 0x7F3FFFFFFFFFFFFF
    } // Infinity is greater than any valid number.
    
    /// Convert type to an signed integer (64bit).
    /// - parameter limit: The maximum value to be returned, otherwise an exception is thrown.
    /// - returns: Self as signed integer.
    func toInt(_ limit: Int64) -> Int64 {
        var exp = self.getExponent()
        
        if ( exp >= -16 ) {
            var man = self.getMantissa()
            var shift = 0
            
            if exp < 0 {
                man /= Int64.tenToThePower(of: -exp)
                exp = 0
            } else if ((exp > 0) && (exp <= 17)) {
                shift = man.shiftLeftTo17(limit: exp)
            }
            
            if ((man > limit) || (shift != exp)) {
                //FIXME: learn exception handling in swift...
                // throw DecimalFP64::OverflowExceptionParam( 1, *this, ( exp - shift ) )
                fatalError()
            }
            
            if self.getSign() {
                return -man
            } else {
                return man
            }
        }
        
        return 0
    }
    
    /// Assignment decimal shift left
    /// - parameter shift: Number of decimal digits to shift to the left.
    /// - Returns:  Receiving number * 10^shift
    public static func <<= (_ left: inout Self, _ shift: Int) {
        left.setComponents(left.getMantissa(), left.getExponent() + shift, left.getSign())
    }
    
    /// Assignment decimal shift right.
    /// - parameter shift: Number of decimal digits to shift to the right.
    /// - returns:  Receiving number / 10^shift
    public static func >>= (_ left: inout Self, _ shift: Int ) {
        left.setComponents(left.getMantissa(), left.getExponent() - shift, left.getSign())
    }
    
    public static func <<(_ left: Self, _ right: Int ) -> Self {
        var result = left
        result <<= right
        return result
    }
    
    public static func >>(_ left: Self, _ right: Int) -> Self {
        var result = left
        result >>= right
        return result
    }
    
    // possibly not the fastest swift way. but for now the easiest way to port some c++ code
    private func strcpy(_ content: String, to buffer: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<UInt8> {
        var pos = buffer

        for c in content.utf8 {
            pos.pointee = c
            pos += 1
        }
        return buffer
    }

    func toChar( _ buffer: UnsafeMutablePointer<UInt8> ) -> UnsafeMutablePointer<UInt8> {
        if self.isNaN { return strcpy("NaN", to: buffer) }

        if self.isInfinity() {
            if self.getSign() {
                return self.strcpy("-Inf", to: buffer)
            } else {
                return self.strcpy("Inf", to: buffer)
            }
        }

        let man = self.getMantissa()

        if man == 0 { return self.strcpy("0", to: buffer) }

        var exp = self.getExponent()
        var end = buffer.advanced(by: 30)
        var start = man.toString(end: end)

        if exp < 0 {
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
                } else {
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
                    _ = Int64(exp).toString(end: end)
                }
            } else {
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
            _ = Int64(exp).toString(end: end)
        } else {
            while exp > 0 {
                end.pointee = 0x30 // 0
                end += 1
                exp -= 1
            }
        }

        if self.getSign() {
            start -= 1
            start.pointee = 0x2D // -
        }

        end.pointee = 0

        return start
    }
}
