import Foundation

extension BinaryInteger {
    /// Creates a new instance with the representable value that’s closest to the given integer
    public init(clamping source: Decimal64) {
        self.init(clamping: source.rounded(.towardZero, scale: 0).significand)
    }
}

extension BinaryFloatingPoint {
    /// Creates a new instance from the given value, rounded to the closest possible representation.
    public init(_ value: Decimal64) {
//        // Not accurate enough.
//        let magnitude = value.magnitude
//        self.init(magnitude.significand)
//
//        let multiplier = Self.init(pow(10, Double(magnitude.exponent)))
//        self *= multiplier
        
        // TODO: Find out a better function.
        self.init(Double(value.description)!)
    }
}
