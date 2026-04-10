// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenFlow",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ScreenFlowCore", targets: ["ScreenFlowCore"]),
        .executable(name: "ScreenFlow", targets: ["ScreenFlowApp"]),
        .executable(name: "screenflowctl", targets: ["screenflowctl"]),
    ],
    targets: [
        .target(
            name: "ScreenFlowCore",
            path: "Sources/ScreenFlowCore"
        ),
        .executableTarget(
            name: "ScreenFlowApp",
            dependencies: ["ScreenFlowCore"],
            path: "Sources/ScreenFlowApp",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "screenflowctl",
            dependencies: ["ScreenFlowCore"],
            path: "Sources/screenflowctl"
        ),
        .testTarget(
            name: "ScreenFlowCoreTests",
            dependencies: ["ScreenFlowCore"],
            path: "Tests/ScreenFlowCoreTests"
        ),
    ]
)
