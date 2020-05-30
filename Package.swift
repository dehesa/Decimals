// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Decimals",
    products: [
        .library(name: "Decimals", targets: ["Decimals"]),
        .executable(name: "DecimalsBenchmarks", targets: ["DecimalsBenchmarks"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Decimals", dependencies: [], path: "sources"),
        .target(name: "DecimalsBenchmarks", dependencies: ["Decimals"], path: "benchmarks"),
        .testTarget(name: "DecimalsTests", dependencies: ["Decimals"], path: "tests"),
    ]
)
