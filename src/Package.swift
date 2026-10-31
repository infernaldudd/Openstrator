// swift-tools-version: 5.9
import PackageDescription

#if os(macOS)
let targets: [Target] = [
    .target(name: "OpenstratorCore", path: "Sources/OpenstratorCore"),
    .executableTarget(name: "OpenstratorCoreSelfTest", dependencies: ["OpenstratorCore"], path: "Sources/OpenstratorCoreSelfTest"),
    .executableTarget(
        name: "Openstrator",
        dependencies: ["OpenstratorCore"],
        path: "Openstrator",
        exclude: ["Assets.xcassets", "Info.plist"],
        swiftSettings: [.define("OPENSTRATOR_INTEL")]
    ),
    .testTarget(name: "OpenstratorCoreTests", dependencies: ["OpenstratorCore"], path: "Tests/OpenstratorCoreTests"),
    .testTarget(name: "OpenstratorAppTests", dependencies: ["Openstrator", "OpenstratorCore"], path: "Tests/OpenstratorAppTests")
]
let products: [Product] = [
    .executable(name: "Openstrator", targets: ["Openstrator"]),
    .executable(name: "OpenstratorCoreSelfTest", targets: ["OpenstratorCoreSelfTest"]),
    .library(name: "OpenstratorCore", targets: ["OpenstratorCore"])
]
#else
let targets: [Target] = [
    .target(name: "OpenstratorCore", path: "Sources/OpenstratorCore"),
    .executableTarget(name: "OpenstratorCoreSelfTest", dependencies: ["OpenstratorCore"], path: "Sources/OpenstratorCoreSelfTest"),
    .testTarget(name: "OpenstratorCoreTests", dependencies: ["OpenstratorCore"], path: "Tests/OpenstratorCoreTests")
]
let products: [Product] = [.library(name: "OpenstratorCore", targets: ["OpenstratorCore"]), .executable(name: "OpenstratorCoreSelfTest", targets: ["OpenstratorCoreSelfTest"])]
#endif

let package = Package(
    name: "Openstrator",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
