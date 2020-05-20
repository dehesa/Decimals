/// Constants TenPow<x> = 10^X
let TenPow0: Int64  =                         1
let TenPow1: Int64  =                        10
let TenPow2: Int64  =                       100
let TenPow3: Int64  =                     1_000
let TenPow4: Int64  =                    10_000
let TenPow5: Int64  =                   100_000
let TenPow6: Int64  =                 1_000_000
let TenPow7: Int64  =                10_000_000
let TenPow8: Int64  =               100_000_000
let TenPow9: Int64  =             1_000_000_000
let TenPow10: Int64 =            10_000_000_000
let TenPow11: Int64 =           100_000_000_000
let TenPow12: Int64 =         1_000_000_000_000
let TenPow13: Int64 =        10_000_000_000_000
let TenPow14: Int64 =       100_000_000_000_000
let TenPow15: Int64 =     1_000_000_000_000_000
let TenPow16: Int64 =    10_000_000_000_000_000
let TenPow17: Int64 =   100_000_000_000_000_000
let TenPow18: Int64 = 1_000_000_000_000_000_000

/// For faster access to power of tens
let PowerOf10: [Int64] = [TenPow0, TenPow1, TenPow2, TenPow3, TenPow4, TenPow5, TenPow6, TenPow7, TenPow8, TenPow9, TenPow10, TenPow11, TenPow12, TenPow13, TenPow14, TenPow15, TenPow16, TenPow17, TenPow18]

/// This methods calculate num * 10^shift.
///
/// - Parameters:
///   - num: The number to process, must not have more than 18 digits.
///   - shift: Number of decimal digits to shift, must not be larger than +16.
func shiftDigits( _ num: inout Int64, _ shift: Int ) {
    if  shift < -17 {
        num = 0
    } else if shift < 0 {
        num /= PowerOf10[ -shift ]
    } else {
        num *= PowerOf10[ shift ]
    }
}

/// Internal helper function to shift a number to the left
/// until it fills 16 digits.
///
/// - Parameters:  numIn       The number to process, must not
///                     have more than 18 digits.
///
/// - Returns: number of shifted digits.
func int64_shiftLeftTo16( _ num: inout Int64 ) -> Int {
    var ret = 0
    
    if num < TenPow8 {
        if num < TenPow4 {
            ret = 12
            num *= TenPow12
        } else {
            ret = 8
            num *= TenPow8
        }
    } else {
        if num < TenPow12 {
            ret = 4
            num *= TenPow4
        }
    }
    
    if num < TenPow15 {
        if num < TenPow13 {
            ret += 3
            num *= 1000
        } else if num < TenPow14 {
            ret += 2
            num *= 100
        } else {
            ret += 1
            num *= 10
        }
    }
    
    return ret
}


/// Internal helper function to shift a number to the left
/// until it fills 18 digits.
///
/// - Parameter num: The number to process, must not have more than 18 digits.
/// - Returns: number of shifted digits.
func int64_shiftLeftTo18( _ num: inout Int64 ) -> Int {
    var ret = 0
    
    if num < TenPow8 {
        if num < TenPow4 {
            ret = 14
            num *= TenPow14
        } else {
            ret = 10
            num *= TenPow10
        }
    }
    else {
        if num < TenPow12 {
            ret = 6
            num *= TenPow6
        } else if ( num < TenPow16 ) {
            ret = 2
            num *= 100
        }
    }
    
    if num < TenPow17 {
        if num < TenPow15 {
            ret += 3
            num *= 1000
        } else if num < TenPow16 {
            ret += 2
            num *= 100
        } else {
            ret += 1
            num *= 10
        }
    }
    
    return ret
}

/// Internal helper function to shift a number to the left until it fills 17 digits or number of shifted digits reaches limit (whatever comes first).
/// - parameter num: The number to process, must not have more than 18 digits.
/// - parameter limit: Maximum number of decimal digits to shift, must not be larger than 17.
/// - returns: count of shifted digits.
func int64_shiftLeftTo17orLim(_ num: inout Int64, _ limit: Int) -> Int {
    if num < PowerOf10[17 - limit] {
        // num will not overflow if pushed left
        num *= PowerOf10[ limit ]
        
        return limit
    }
    
    var result = 0
    
    // num will overflow if pushed left, just shift to 17 digits
    if num < TenPow8 {
        if num < TenPow4 {
            result = 13
            num *= TenPow13
        } else {
            result = 9
            num *= TenPow9
        }
    }
    else {
        if num < TenPow12 {
            result = 5
            num *= TenPow5
        } else if num < TenPow16 {
            result = 1
            num *= 10
        }
    }
    
    if num < TenPow16 {
        if num < TenPow14 {
            result += 3
            num *= 1000
        } else if num < TenPow15 {
            result += 2
            num *= 100
        } else {
            result += 1
            num *= 10
        }
    }
    
    return result
}

/// Internal helper function to shift a number to the left until
/// it fills 17 digits or number of shifted digits reaches 16.
/// (whatever comes first)
/// Same as int64_shiftLeftTo17_16( in, 16 ) but faster.
///
/// - Parameters:  numIn       The number to process, must not have
///                     more than 18 digits.
///
/// - Returns: number of shifted digits.
func int64_shiftLeftTo17_16( _ num: inout Int64 ) -> Int {
    var ret = 0
    
    if num < TenPow8 {
        if num < TenPow4 {
            ret = 13
            num *= TenPow13
        } else {
            ret = 9
            num *= TenPow9
        }
    } else {
        if num < TenPow12 {
            ret = 5
            num *= TenPow5
        } else if num < TenPow16 {
            ret = 1
            num *= 10
        }
    }
    
    if num < TenPow16 {
        if num < TenPow14 {
            ret += 3
            num *= 1000
        } else if num < TenPow15 {
            ret += 2
            num *= 100
        } else {
            ret += 1
            num *= 10
        }
    }
    
    return ret
}


/// Internal helper function to shift a number to the left until
/// it fills 17 digits or number of shifted digits reaches 8.
/// (whatever comes first)
/// Same as int64_shiftLeftTo17_16( in, 8 ) but faster.
///
/// - Parameters:  numIn       The number to process, must not have
///                     more than 18 digits.
///
/// - Returns: number of shifted digits.
func int64_shiftLeftTo17_8( _ num: inout Int64 ) -> Int {
    var ret = 0
    
    if num < TenPow8 {
        ret = 8
        num *= TenPow8
    } else {
        if num < TenPow12 {
            ret = 5
            num *= TenPow5
        } else if num < TenPow16 {
            ret = 1
            num *= 10
        }
        
        if num < TenPow16 {
            if num < TenPow14 {
                ret += 3
                num *= 1000
            } else if num < TenPow15 {
                ret += 2
                num *= 100
            } else {
                ret += 1
                num *= 10
            }
        }
    }
    
    return ret
}
