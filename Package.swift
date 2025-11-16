// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VPNBarApp",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "VPNBarApp",
            targets: ["VPNBarApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "VPNBarApp",
            dependencies: [],
            path: "Sources/VPNBarApp"
        )
    ]
)

