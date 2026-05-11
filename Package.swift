// swift-tools-version: 5.9
import Foundation
import PackageDescription

let xcodeMacOSXDeveloper = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer"
let xcodeMacOSXFrameworks = "\(xcodeMacOSXDeveloper)/Library/Frameworks"
let xcodeMacOSXSwiftModules = "\(xcodeMacOSXDeveloper)/usr/lib"
let xcodeSharedFrameworks = "/Applications/Xcode.app/Contents/SharedFrameworks"
let xctestSettings: [SwiftSetting] = FileManager.default.fileExists(atPath: "\(xcodeMacOSXFrameworks)/XCTest.framework")
    ? [.unsafeFlags(["-F", xcodeMacOSXFrameworks, "-I", xcodeMacOSXSwiftModules])]
    : []
let xctestLinkerSettings: [LinkerSetting] = FileManager.default.fileExists(atPath: "\(xcodeMacOSXFrameworks)/XCTest.framework")
    ? [.unsafeFlags([
        "-F", xcodeMacOSXFrameworks,
        "-L", xcodeMacOSXSwiftModules,
        "-framework", "XCTest",
        "-lXCTestSwiftSupport",
        "-Xlinker", "-rpath", "-Xlinker", xcodeMacOSXFrameworks,
        "-Xlinker", "-rpath", "-Xlinker", xcodeMacOSXSwiftModules,
        "-Xlinker", "-rpath", "-Xlinker", xcodeSharedFrameworks,
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
            swiftSettings: xctestSettings,
            linkerSettings: xctestLinkerSettings),
        .testTarget(
            name: "RemBarTests",
            dependencies: ["REMBar"],
            path: "Tests/RemBarTests",
            swiftSettings: xctestSettings,
            linkerSettings: xctestLinkerSettings),
    ])
