// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MiniPNG",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MiniPNG", targets: ["MiniPNG"])
    ],
    targets: [
        .executableTarget(
            name: "MiniPNG",
            path: "Sources",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
