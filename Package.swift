// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ShizenNative",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/pvieito/PythonKit.git", from: "0.3.1")
    ],
    targets: [
        .executableTarget(
            name: "ShizenNative",
            dependencies: ["PythonKit"],
            path: "Sources"
        )
    ]
)
