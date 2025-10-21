// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OutLoud",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "OutLoud",
            targets: ["OutLoud"])
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "OutLoud",
            dependencies: ["Starscream"],
            path: "OutLoud/OutLoud"
        )
    ]
)
