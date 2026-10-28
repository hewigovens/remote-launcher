// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RemoteLauncher",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "RemoteLauncher", targets: ["ScreenSharingLauncher"])],
    targets: [
        .executableTarget(name: "ScreenSharingLauncher"),
        .testTarget(name: "ScreenSharingLauncherTests", dependencies: ["ScreenSharingLauncher"]),
    ]
)
