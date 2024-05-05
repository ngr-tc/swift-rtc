// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "swift-rtc",
    products: [
        .library(name: "rtc", targets: ["rtc"]),
        .library(name: "sdp", targets: ["sdp"]),
    ],
    targets: [
        // MARK: - Targets
        .target(name: "rtc"),
        .target(name: "sdp"),
        
        // MARK: - Tests
        .testTarget(name: "rtcTests", dependencies: ["rtc"]),
        .testTarget(name: "sdpTests", dependencies: ["sdp"]),
        
        // MARK: - Examples
    ]
)
