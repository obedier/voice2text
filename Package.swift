// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceDictate",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/Defaults", from: "7.1.0")
    ],
    targets: [
        .executableTarget(
            name: "VoiceDictate",
            dependencies: ["Defaults"],
            path: "src/VoiceDictate/Sources"
        )
    ]
) 