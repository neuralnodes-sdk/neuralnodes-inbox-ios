// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "NeuralNodesInbox",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NeuralNodesInbox",
            targets: ["NeuralNodesInbox"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ably/ably-cocoa", from: "1.2.0"),
        .package(url: "https://github.com/pusher/pusher-websocket-swift", from: "10.0.0")
    ],
    targets: [
        .target(
            name: "NeuralNodesInbox",
            dependencies: [
                .product(name: "Ably", package: "ably-cocoa"),
                .product(name: "PusherSwift", package: "pusher-websocket-swift")
            ])
    ]
)
