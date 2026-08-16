// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ProjectBar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "ProjectBar", targets: ["ProjectBar"]),
        .library(name: "ProjectBarCore", targets: ["ProjectBarCore"]),
    ],
    targets: [
        .target(
            name: "ProjectBarCore",
            path: "Sources/ProjectBarCore"),
        .executableTarget(
            name: "ProjectBar",
            dependencies: ["ProjectBarCore"],
            path: "Sources/ProjectBar"),
        .testTarget(
            name: "ProjectBarCoreTests",
            dependencies: ["ProjectBarCore"],
            path: "Tests/ProjectBarCoreTests"),
        .testTarget(
            name: "ProjectBarTests",
            dependencies: ["ProjectBar"],
            path: "Tests/ProjectBarTests"),
    ])
