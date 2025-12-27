// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VPNBarApp",
    defaultLocalization: "en",
    // Note: Minimum version is macOS 12, but some features require macOS 13+ (e.g., SMAppService)
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "VPNBarApp",
            targets: ["VPNBarApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    targets: [
        .executableTarget(
            name: "VPNBarApp",
            dependencies: [],
            path: "Sources/VPNBarApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "VPNBarAppTests",
            dependencies: [
                "VPNBarApp",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/VPNBarAppTests"
        ),
        .testTarget(
            name: "VPNBarAppIntegrationTests",
            dependencies: ["VPNBarApp"],
            path: "Tests/VPNBarAppIntegrationTests"
        )
    ]
)

