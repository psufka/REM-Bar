// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "REM-Bar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "REM-Bar", targets: ["REMBar"]),
        .library(name: "OuraKit", targets: ["OuraKit"]),
        .executable(name: "RemBarMCP", targets: ["RemBarMCP"]),
    ],
    targets: [
        .executableTarget(
            name: "REMBar",
            dependencies: ["OuraKit"],
            path: "Sources/REM-Bar",
            resources: [
                .process("Resources"),
            ]),
        .target(
            name: "OuraKit",
            path: "Sources/OuraKit"),
        .executableTarget(
            name: "RemBarMCP",
            dependencies: ["OuraKit"],
            path: "Sources/RemBarMCP"),
        .testTarget(
            name: "OuraKitTests",
            dependencies: ["OuraKit"],
            path: "Tests/OuraKitTests",
            resources: [
                .copy("Fixtures"),
            ]),
        .testTarget(
            name: "RemBarTests",
            dependencies: ["REMBar"],
            path: "Tests/RemBarTests"),
    ])
