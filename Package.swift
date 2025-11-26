// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Jarvis", targets: ["Jarvis"])
    ],
    dependencies: [
        // No external dependencies for now to keep it self-contained.
        // We will use native APIs for everything.
    ],
    targets: [
        .executableTarget(
            name: "Jarvis",
            dependencies: [],
            path: "JarvisApp/Sources",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
