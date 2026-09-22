// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ParkFighter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ParkFighter",
            path: "Sources/ParkFighter",
            swiftSettings: [.unsafeFlags(["-Ounchecked"], .when(configuration: .release))],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Vision"),
                .linkedFramework("CoreImage"),
            ]
        )
    ]
)
