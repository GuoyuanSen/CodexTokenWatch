// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexTokenWatch",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexTokenWatch", targets: ["CodexTokenWatch"])],
    targets: [.executableTarget(name: "CodexTokenWatch")]
)
