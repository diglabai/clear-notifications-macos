// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClearNotifications",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ClearNotifications", targets: ["ClearNotifications"])
    ],
    targets: [
        .target(name: "ClearNotificationsCore"),
        .executableTarget(
            name: "ClearNotifications",
            dependencies: ["ClearNotificationsCore"]
        ),
        .testTarget(
            name: "ClearNotificationsCoreTests",
            dependencies: ["ClearNotificationsCore"]
        )
    ]
)
