// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EisenhowerCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "EisenhowerCore", targets: ["EisenhowerCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "EisenhowerCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/EisenhowerCore"
        ),
        .testTarget(
            name: "EisenhowerCoreTests",
            dependencies: ["EisenhowerCore"],
            path: "Tests/EisenhowerCoreTests"
        ),
    ]
)
