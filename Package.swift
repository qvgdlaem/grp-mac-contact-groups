// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GRP",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "GRP", targets: ["GRP"])],
    targets: [
        .executableTarget(name: "GRP")
    ]
)
