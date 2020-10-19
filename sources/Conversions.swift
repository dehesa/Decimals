extension BinaryInteger {
    /// Creates a new instance with the representable value that’s closest to the given integer
    @inlinable public init(clamping source: Decimal64) {
        let exponent = source.exponent
        let result = (exponent < 0) ? source.significand / Int64.tenToThePower(of: -exponent)
                                    : source.significand * Int64.tenToThePower(of: exponent)
        self.init(clamping: result)
    }
}

extension FloatingPoint {
    /// Creates a new instance from the given value, rounded to the closest possible representation.
    public init(_ value: Decimal64) {
        let (significand, exponent) = (Self(value.significand), value.exponent)
        
        if exponent >= .zero {
//            precondition(exponent < 19)
            let multiplier = Self(Int64.tenToThePower(of: exponent))
            self = significand * multiplier
        } else {
//            precondition(exponent > -19)
            let divisor = Self(Int64.tenToThePower(of: -exponent))
            self = significand / divisor
        }
    }
}
