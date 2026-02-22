// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InputAutoSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "InputAutoSwitcher", targets: ["InputAutoSwitcher"])
    ],
    targets: [
        .executableTarget(
            name: "InputAutoSwitcher",
            path: "Sources"
        )
    ]
)

