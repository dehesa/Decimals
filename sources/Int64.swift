internal extension Int64 {
    /// Cache for the first 18 values of 10 to the power of n (for performance purposes).
    static let powerOf10 = (    1 as Int64, // 0
                               10 as Int64, // 1
                              100 as Int64, // 2
                            1_000 as Int64, // 3
                           10_000 as Int64, // 4
                          100_000 as Int64, // 5
                        1_000_000 as Int64, // 6
                       10_000_000 as Int64, // 7
                      100_000_000 as Int64, // 8
                    1_000_000_000 as Int64, // 9
                   10_000_000_000 as Int64, // 10
                  100_000_000_000 as Int64, // 11
                1_000_000_000_000 as Int64, // 12
               10_000_000_000_000 as Int64, // 13
              100_000_000_000_000 as Int64, // 14
            1_000_000_000_000_000 as Int64, // 15
           10_000_000_000_000_000 as Int64, // 16
          100_000_000_000_000_000 as Int64, // 17
        1_000_000_000_000_000_000 as Int64  // 18
    )

    /// Returns the result of `10^exponent`.
    @_transparent static func tenToThePower(of exponent: Int) -> Int64 {
        withUnsafeBytes(of: Self.powerOf10) {
            $0.baseAddress!.assumingMemoryBound(to: Int64.self)[exponent]
        }
    }
}

internal extension Int64 {
    /// Calculates `num * 10^shift`.
    /// - attention: The receiving integer, must not have more than 18 decimal digits.
    /// - parameter shift: Number of decimal digits to shift, must not be larger than +16.
    @usableFromInline mutating func shift(decimalDigits shift: Int) {
        if shift < -17 {
            self = 0
        } else if shift < 0 {
            self /= Int64.tenToThePower(of: -shift)
        } else {
            self *= Int64.tenToThePower(of: shift)
        }
    }
    
    /// Shifts the receiving number to the left until it fills 16 decimal digits.
    /// - attention: The receiving integer must not have more than 18 decimal digits.
    /// - returns: The number of shifted digits.
    @usableFromInline mutating func shiftLeftTo16() -> Int {
        var result = 0
        
        if self < Int64.powerOf10.8 {
            if self < Int64.powerOf10.4 {
                result = 12
                self *= Int64.powerOf10.12
            } else {
                result = 8
                self *= Int64.powerOf10.8
            }
        } else {
            if self < Int64.powerOf10.12 {
                result = 4
                self *= Int64.powerOf10.4
            }
        }
        
        if self < Int64.powerOf10.15 {
            if self < Int64.powerOf10.13 {
                result += 3
                self *= 1000
            } else if self < Int64.powerOf10.14 {
                result += 2
                self *= 100
            } else {
                result += 1
                self *= 10
            }
        }
        
        return result
    }
    
    /// Shifts the receiving number to the left until it fills 17 decimal digits or the number of shifted digits reaches the limit (whatever comes first).
    /// - attention: The receiving integer must not have more than 18 decimal digits.
    /// - parameter limit: Maximum number of decimal digits to shift, must not be larger than 17.
    /// - returns: Count of shifted digits.
    @usableFromInline mutating func shiftLeftTo17(limit: Int) -> Int {
        if self < Int64.tenToThePower(of:17 - limit) {
            // num will not overflow if pushed left
            self *= Int64.tenToThePower(of: limit)
            return limit
        }
        
        var result = 0
        
        // num will overflow if pushed left, just shift to 17 digits
        if self < Int64.powerOf10.8 {
            if self < Int64.powerOf10.4 {
                result = 13
                self *= Int64.powerOf10.13
            } else {
                result = 9
                self *= Int64.powerOf10.9
            }
        } else {
            if self < Int64.powerOf10.12 {
                result = 5
                self *= Int64.powerOf10.5
            } else if self < Int64.powerOf10.16 {
                result = 1
                self *= 10
            }
        }
        
        if self < Int64.powerOf10.16 {
            if self < Int64.powerOf10.14 {
                result += 3
                self *= 1000
            } else if self < Int64.powerOf10.15 {
                result += 2
                self *= 100
            } else {
                result += 1
                self *= 10
            }
        }
        
        return result
    }
    
    /// Shifts the receiving number to the left until it fills 17 decimal digits or number of shifted decimal digits reaches 16 (whatever comes first).
    ///
    /// Same as `Int64.shiftLeftTo17(limit:)` but faster.
    /// - attention: The receiving integer must not have more than 18 digits.
    /// - returns: The number of shifted decimal digits.
    @usableFromInline mutating func shiftLeftTo17Limit16() -> Int {
        var result = 0
        
        if self < Int64.powerOf10.8 {
            if self < Int64.powerOf10.4 {
                result = 13
                self *= Int64.powerOf10.13
            } else {
                result = 9
                self *= Int64.powerOf10.9
            }
        } else {
            if self < Int64.powerOf10.12 {
                result = 5
                self *= Int64.powerOf10.5
            } else if self < Int64.powerOf10.16 {
                result = 1
                self *= 10
            }
        }
        
        if self < Int64.powerOf10.16 {
            if self < Int64.powerOf10.14 {
                result += 3
                self *= 1000
            } else if self < Int64.powerOf10.15 {
                result += 2
                self *= 100
            } else {
                result += 1
                self *= 10
            }
        }
        
        return result
    }
    
    /// Shifts the receiving number to the left until it fills 17 decimal digits or number of shifted digits reaches 8 (whatever comes first).
    ///
    /// Same as `Int64.shiftLeftTo17(limit:)` but faster.
    /// - attention: The receiving integer must not have more than 18 digits.
    /// - returns: The number of shifted digits.
    @usableFromInline mutating func shiftLeftTo17Limit8() -> Int {
        var result = 0
        
        if self < Int64.powerOf10.8 {
            result = 8
            self *= Int64.powerOf10.8
        } else {
            if self < Int64.powerOf10.12 {
                result = 5
                self *= Int64.powerOf10.5
            } else if self < Int64.powerOf10.16 {
                result = 1
                self *= 10
            }
            
            if self < Int64.powerOf10.16 {
                if self < Int64.powerOf10.14 {
                    result += 3
                    self *= 1000
                } else if self < Int64.powerOf10.15 {
                    result += 2
                    self *= 100
                } else {
                    result += 1
                    self *= 10
                }
            }
        }
        
        return result
    }
    
    /// Shifts the receiving number to the left until it fills 18 decimal digits.
    /// - attention: The number to process, must not have more than 18 decimal digits.
    /// - returns: The number of shifted digits.
    @usableFromInline mutating func shiftLeftTo18() -> Int {
        var result = 0
        
        if self < Int64.powerOf10.8 {
            if self < Int64.powerOf10.4 {
                result = 14
                self *= Int64.powerOf10.14
            } else {
                result = 10
                self *= Int64.powerOf10.10
            }
        } else {
            if self < Int64.powerOf10.12 {
                result = 6
                self *= Int64.powerOf10.6
            } else if ( self < Int64.powerOf10.16 ) {
                result = 2
                self *= 100
            }
        }
        
        if self < Int64.powerOf10.17 {
            if self < Int64.powerOf10.15 {
                result += 3
                self *= 1000
            } else if self < Int64.powerOf10.16 {
                result += 2
                self *= 100
            } else {
                result += 1
                self *= 10
            }
        }
        
        return result
    }
}
