// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "bzpad-tui",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../EisenhowerCore"),
        .package(url: "https://github.com/migueldeicaza/TermKit", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "bzpad-tui",
            dependencies: [
                .product(name: "EisenhowerCore", package: "EisenhowerCore"),
                .product(name: "TermKit", package: "TermKit"),
            ],
            path: "Sources/bzpad-tui",
            // Swift 5 mode: avoids strict-concurrency friction with TermKit's
            // callback-based API while still running on the main thread.
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
