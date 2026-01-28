// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "macsnap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacSnap", targets: ["MacSnap"]),
        .executable(name: "macsnap-cli", targets: ["macsnap-cli"]),
        .library(name: "MacSnapCore", targets: ["MacSnapCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0")
    ],
    targets: [
        // Shared core library with capture engine, config, and hotkey management
        .target(
            name: "MacSnapCore",
            dependencies: [],
            path: "Sources/MacSnapCore"
        ),

        // Menu bar application
        .executableTarget(
            name: "MacSnap",
            dependencies: ["MacSnapCore"],
            path: "Sources/MacSnap",
            resources: [
                .process("Resources")
            ]
        ),

        // Command-line interface
        .executableTarget(
            name: "macsnap-cli",
            dependencies: [
                "MacSnapCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/macsnap-cli"
        ),

        // Tests
        .testTarget(
            name: "MacSnapTests",
            dependencies: ["MacSnapCore"],
            path: "Tests/MacSnapTests"
        )
    ]
)
