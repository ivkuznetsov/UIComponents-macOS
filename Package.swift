// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UIComponents",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(name: "UIComponents", targets: ["UIComponents"])
    ],
    dependencies: [
        .package(url: "https://github.com/ivkuznetsov/CommonUtils.git", branch: "main")
    ],
    targets: [
        .target(name: "UIComponents",
                dependencies: ["CommonUtils"],
                resources: [.copy("Resources/NoObjectsView.xib"),
                            .copy("Resources/FooterLoadingView.xib"),
                            .copy("Resources/LoadingView.xib"),
                            .copy("Resources/LoadingPanel.xib"),
                            .copy("Resources/FailedView.xib"),
                            .copy("Resources/AlertBarView.xib")]),
    ]
)
