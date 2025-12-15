// swift-tools-version: 6.0
// Swift Package definition for LTATApp (macOS 13+).

import PackageDescription

let package = Package(
    name: "LTATApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LTATApp", targets: ["LTATApp"])
    ],
    dependencies: [
        // YAML parsing for config files.
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .executableTarget(
            name: "LTATApp",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/LTATApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
