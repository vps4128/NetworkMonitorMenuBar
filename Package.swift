// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetworkMonitorMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "NetworkMonitorMenuBar",
            targets: ["NetworkMonitorMenuBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NetworkMonitorMenuBar",
            path: "Sources"
        )
    ]
)
