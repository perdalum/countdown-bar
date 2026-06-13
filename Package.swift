// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CountdownBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CountdownBar", targets: ["CountdownBar"])
    ],
    targets: [
        .executableTarget(name: "CountdownBar")
    ]
)
