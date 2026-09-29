// swift-tools-version:5.9
// Builds and tests the UI-free core (models, exercise library, training engine, animation data) on any
// platform, including Linux CI. The iOS app itself is built from project.yml with XcodeGen.
import PackageDescription

let package = Package(
    name: "MomentumCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "Momentum", targets: ["Momentum"])],
    targets: [
        .target(
            name: "Momentum",
            path: "Momentum",
            exclude: [
                "App", "Views", "Store", "Health", "Assets.xcassets",
                "Design/FigureView.swift", "Design/Theme.swift", "Design/Components.swift"
            ],
            sources: ["Models", "Engine", "Design/MotionData.swift"]
        ),
        .executableTarget(
            name: "EngineSim",
            dependencies: ["Momentum"],
            path: "Tools/EngineSim"
        ),
        .testTarget(
            name: "MomentumTests",
            dependencies: ["Momentum"],
            path: "MomentumTests"
        )
    ]
)
