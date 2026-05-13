// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StylometrySanitizer",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "StylometrySanitizer", targets: ["StylometrySanitizer"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "StylometrySanitizer",
            path: ".",
            sources: ["App.swift", "ContentView.swift", "LLMService.swift", "SelectionNeutralizer.swift"]
        )
    ]
)