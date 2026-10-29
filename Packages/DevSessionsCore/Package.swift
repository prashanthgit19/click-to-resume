// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DevSessionsCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DevSessionsCore", targets: ["DevSessionsCore"])
    ],
    targets: [
        .target(name: "DevSessionsCore"),
        .executableTarget(
            name: "DevSessionsCoreChecks",
            dependencies: ["DevSessionsCore"]
        )
    ]
)
