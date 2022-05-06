// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftOktaPackage",
    platforms: [
        .macOS(.v10_14), .iOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftOktaPackage",
            targets: ["SwiftOktaPackage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/okta/okta-oidc-ios.git", from: "3.11.1"),
        .package(url: "https://github.com/okta/okta-auth-swift.git", from: "2.4.3"),
        .package(url: "https://github.com/okta/okta-ios-jwt.git", from: "2.3.4")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwiftOktaPackage",
            dependencies: [.product(name: "OktaAuthNative", package: "okta-auth-swift"),
                           .product(name: "OktaOidc", package: "okta-oidc-ios"),
                           .product(name: "OktaJWT", package: "okta-ios-jwt")]),
        .testTarget(
            name: "SwiftOktaPackageTests",
            dependencies: ["SwiftOktaPackage"]),
    ]
)
