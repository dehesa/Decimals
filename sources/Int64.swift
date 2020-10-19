import Foundation

internal extension Int64 {
    /// Cache for the first 18 values of 10 to the power of n (for performance purposes).
     @usableFromInline static let powerOf10 = (
                                1 as Int64, // 0
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
    @_transparent @usableFromInline static func tenToThePower(of exponent: Int) -> Int64 {
        withUnsafeBytes(of: Self.powerOf10) {
            $0.baseAddress.unsafelyUnwrapped.assumingMemoryBound(to: Int64.self)[exponent]
        }
    }
}

internal extension Int64 {
    /// Calculates `num * 10^shift`.
    /// - attention: The receiving integer, must not have more than 18 decimal digits.
    /// - parameter shift: Number of decimal digits to shift, must not be larger than +16.
    @_transparent mutating func shift(decimalDigits shift: Int) {
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
    @_transparent mutating func shiftLeftTo16() -> Int {
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
    mutating func shiftLeftTo17(limit: Int) -> Int {
        // If the receiving number is less than 10^boundary, the number won't overflow if pushed to the left a `limit` number of times.
        if self < Int64.tenToThePower(of: 17 - limit) {
            self *= Int64.tenToThePower(of: limit)
            return limit
        }
        
        // Otherwise, the receiving number will overflow if pushed left; therefore, just shift to 17 decimal digits.
        var shift = 0
        
        if self < Int64.powerOf10.8 {
            if self < Int64.powerOf10.4 {
                shift = 13
                self *= Int64.powerOf10.13
            } else {
                shift = 9
                self *= Int64.powerOf10.9
            }
        } else {
            if self < Int64.powerOf10.12 {
                shift = 5
                self *= Int64.powerOf10.5
            } else if self < Int64.powerOf10.16 {
                shift = 1
                self *= 10
            }
        }
        
        if self < Int64.powerOf10.16 {
            if self < Int64.powerOf10.14 {
                shift += 3
                self *= 1000
            } else if self < Int64.powerOf10.15 {
                shift += 2
                self *= 100
            } else {
                shift += 1
                self *= 10
            }
        }
        
        return shift
    }
    
    /// Shifts the receiving number to the left until it fills 17 decimal digits or number of shifted decimal digits reaches 16 (whatever comes first).
    ///
    /// Same as `Int64.shiftLeftTo17(limit:)` but faster.
    /// - attention: The receiving integer must not have more than 18 digits.
    /// - returns: The number of shifted decimal digits.
    @_transparent mutating func shiftLeftTo17Limit16() -> Int {
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
    @_transparent mutating func shiftLeftTo17Limit8() -> Int {
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
    mutating func shiftLeftTo18() -> Int {
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
    
    /// Shifts a positive non-zero number to the left until it fills 16 decimal digits.
    /// - precondition: The receiving integer should be greater than zero.
    /// - attention: The receiving number must not have more than 18 decimal digits
    /// - returns: Count of shifted digits.
    mutating func absoluteNormalization() -> Int {
        assert(self > 0)
        
        var shift: Int = 0
        // self will overflow if pushed left, just shift to 16 digits

        if self < Int64.powerOf10.8 {
            if self < Int64.powerOf10.4 {
                shift = 12
                self &*= Int64.powerOf10.12
            } else {
                shift = 8
                self &*= Int64.powerOf10.8
            }
        } else {
            if self < Int64.powerOf10.12 {
                shift = 4
                self &*= Int64.powerOf10.4
            }
        }

        if self < Int64.powerOf10.14 {
            if self < Int64.powerOf10.13 {
                shift &+= 3
                self &*= 1000
            } else {
                shift &+= 2
                self &*= 100
            }
        } else if self < Int64.powerOf10.15 {
            shift &+= 1
            self &*= 10
        }

        return shift
    }
}

/// MARK: -

internal extension Int64 {
    /// 40k bytes
    static let lookUpTable: UnsafeMutableRawPointer = {
        var result = UnsafeMutableRawPointer.allocate(byteCount: 40_000, alignment: 8)
        var fill = result
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
        return result
    }()
    
    /// Converts number to decimal and produces the string.
    ///
    /// The low-order digit of the result always occupies memory position `end-1`.
    /// - attention: The behavior is undefined if number is negative. A single zero digit is produced if number is 0.
    /// - parameter end: Pointer to the end of the buffer.
    /// - returns: Pointer to the beginning of the string. No leading zeros are produced, and no terminating null is produced.
    func toString(end: UnsafeMutableRawPointer) -> UnsafeMutablePointer<UInt8> {
        var x = self
        var result = end
        
        while x >= 10000 {
            let y = Int(x % 10000)
            x /= 10000
            result -= 4
            memcpy(result, Int64.lookUpTable + y * 4, 4)
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
        result -= dig
        
        memcpy(result, Int64.lookUpTable + Int(x) * 4 + 4 - dig, dig)
        return .init(OpaquePointer(result))
    }
}
