// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MuseNative",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MuseDesktop", targets: ["MuseDesktop"]),
        .executable(name: "MuseDiagnostics", targets: ["MuseDiagnostics"]),
        .executable(name: "MuseCoreTests", targets: ["MuseCoreTests"])
    ],
    targets: [
        .target(name: "MuseCore"),
        .executableTarget(name: "MuseDesktop", dependencies: ["MuseCore"],
            resources: [.copy("Resources/MuseLogo.svg")]),
        .executableTarget(name: "MuseDiagnostics", dependencies: ["MuseCore"]),
        .executableTarget(name: "MuseCoreTests", dependencies: ["MuseCore"], path: "Tests/MuseCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
