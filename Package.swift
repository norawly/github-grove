// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Grove",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Grove", targets: ["Grove"]),
               .executable(name: "GroveChecks", targets: ["GroveChecks"])],
    targets: [
        .target(name: "GroveCore"),
        .executableTarget(name: "Grove", dependencies: ["GroveCore"]),
        .executableTarget(name: "GroveChecks", dependencies: ["GroveCore"], path: "Tests/GroveCoreTests")
    ]
)
