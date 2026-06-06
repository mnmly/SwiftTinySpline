// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftTinySpline",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "TinySpline", targets: ["TinySpline"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
    ],
    targets: [
        // Vendored tinyspline C/C++ sources (upstream v0.6.0).
        // Compiled as a static library; tsReal defaults to `double`.
        .target(
            name: "CTinySpline",
            cSettings: [
                .headerSearchPath("include"),
            ],
            cxxSettings: [
                .headerSearchPath("include"),
            ]
        ),
        // Idiomatic Swift wrapper built on top of the C++ API via C++ interop.
        .target(
            name: "TinySpline",
            dependencies: ["CTinySpline"],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]
        ),
        .testTarget(
            name: "TinySplineTests",
            dependencies: ["TinySpline"],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
