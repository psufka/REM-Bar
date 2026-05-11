// swift-tools-version: 5.9
import Foundation
import PackageDescription

let commandLineToolsFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let commandLineToolsDeveloperLib = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let testingFrameworkSettings: [SwiftSetting] = FileManager.default.fileExists(atPath: "\(commandLineToolsFrameworks)/Testing.framework")
    ? [.unsafeFlags(["-F", commandLineToolsFrameworks])]
    : []
let swiftTestingSettings = testingFrameworkSettings + [
    .enableExperimentalFeature("SwiftTesting"),
]
let testingFrameworkLinkerSettings: [LinkerSetting] = FileManager.default.fileExists(atPath: "\(commandLineToolsFrameworks)/Testing.framework")
    ? [.unsafeFlags([
        "-F", commandLineToolsFrameworks,
        "-framework", "Testing",
        "-Xlinker", "-rpath", "-Xlinker", commandLineToolsFrameworks,
        "-Xlinker", "-rpath", "-Xlinker", commandLineToolsDeveloperLib,
    ])]
    : []

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
            ],
            swiftSettings: swiftTestingSettings,
            linkerSettings: testingFrameworkLinkerSettings),
        .testTarget(
            name: "RemBarTests",
            dependencies: ["REMBar"],
            path: "Tests/RemBarTests",
            swiftSettings: swiftTestingSettings,
            linkerSettings: testingFrameworkLinkerSettings),
    ])
