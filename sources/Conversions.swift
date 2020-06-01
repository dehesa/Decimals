import Foundation

extension BinaryInteger {
    /// Creates a new instance with the representable value that’s closest to the given integer
    public init(clamping source: Decimal64) {
        self.init(clamping: source.rounded(.towardZero, scale: 0).significand)
    }
}

extension Float {
    /// Creates a new instance from the given value, rounded to the closest possible representation.
    public init(_ value: Decimal64) {
        let (significand, exponent) = (Float(value.significand), value.exponent)
        
        if exponent >= .zero {
            let multiplier = pow(10.0, Float(exponent))
            self = significand * multiplier
        } else {
            let divisor = pow(10.0, Float(-exponent))
            self = Float(significand) / divisor
        }
    }
}

extension Double {
    /// Creates a new instance from the given value, rounded to the closest possible representation.
    public init(_ value: Decimal64) {
        let (significand, exponent) = (Double(value.significand), value.exponent)

        if exponent >= .zero {
            let multiplier = pow(10.0, Double(exponent))
            self = significand * multiplier
        } else {
            let divisor = pow(10.0, Double(-exponent))
            self = Double(significand) / divisor
        }
    }
}
