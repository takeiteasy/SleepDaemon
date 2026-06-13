// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SleepDaemon",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "sleepd", targets: ["sleepd"]),
        .executable(name: "sleepctl", targets: ["sleepctl"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2")
    ],
    targets: [
        .target(
            name: "SleepDaemonCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "sleepd",
            dependencies: ["SleepDaemonCore"]
        ),
        .executableTarget(
            name: "sleepctl",
            dependencies: [
                "SleepDaemonCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "SleepDaemonCoreTests",
            dependencies: ["SleepDaemonCore"]
        )
    ]
)
