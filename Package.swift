// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NearbyInteractionPermissions",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "NearbyInteractionPermissions",
            targets: ["NearbyInteractionPermissions"]),
    ],
    targets: [
        .target(
            name: "NearbyInteractionPermissions"),

    ]
)
