import Decimals
import Foundation

var (start, stop, result) = (DispatchTime.now(), DispatchTime.now(), String())
print()

// 1. Test Swift `Double`.
start = DispatchTime.now()
for i in 1...100 {
    result = Benchmark.double(start: Double(Double(i)/10))
}
stop = DispatchTime.now()
print("Swift.Double:             ", stop.uptimeNanoseconds - start.uptimeNanoseconds)

// 2. Test Foundation's `Decimal`.
start = DispatchTime.now()
for i in 1...100 {
    result = Benchmark.decimal(start: Decimal(Double(i)/10))
}
stop = DispatchTime.now()
print("Foundation.Decimal:       ", stop.uptimeNanoseconds - start.uptimeNanoseconds)

// 3. Test `DecimalFP64`.
start = DispatchTime.now()
for i in 1...100 {
    result = Benchmark.decimalFP64(start: DecimalFP64(Double(i)/10))
}
stop = DispatchTime.now()
print("Decimals.DecimalFP64:     ", stop.uptimeNanoseconds - start.uptimeNanoseconds)

// 4. Test `Decimal64`.
start = DispatchTime.now()
for i in 1...100 {
    result = Benchmark.decimal64(start: Decimal64(Double(i)/10)!)
}
stop = DispatchTime.now()
print("Decimals.Decimal64:       ", stop.uptimeNanoseconds - start.uptimeNanoseconds)

print()

// 5. Test generic Swift `Double` math.
start = DispatchTime.now()
for i in 1...100 {
    result = Benchmark.genericFloatingPoint(start: Double(Double(i)/10))
}
stop = DispatchTime.now()
print("Swift.Double (G):         ", stop.uptimeNanoseconds - start.uptimeNanoseconds)

// 6. Test generic `DecimalFP64` math.
start = DispatchTime.now()
for i in 1...100 {
    result = Benchmark.genericFloatingPoint(start: DecimalFP64(Double(i)/10))
}
stop = DispatchTime.now()
print("Decimals.DecimalFP64 (G): ", stop.uptimeNanoseconds - start.uptimeNanoseconds)

print()
