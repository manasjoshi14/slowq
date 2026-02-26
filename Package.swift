// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "slowq",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SlowQ", targets: ["SlowQ"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.2.3")
    ],
    targets: [
        .executableTarget(
            name: "SlowQ"
        ),
        .testTarget(
            name: "SlowQTests",
            dependencies: [
                "SlowQ",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
