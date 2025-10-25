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
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "OutLoud",
            dependencies: [
                "Starscream",
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "OutLoud/OutLoud"
        )
    ]
)
