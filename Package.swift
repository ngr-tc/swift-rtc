// swift-tools-version: 5.9
//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftRTC open source project
//
// Copyright (c) 2024 ngRTC and the SwiftRTC project authors
// Licensed under MIT License
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftRTC project authors
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "swift-rtc",
    products: [
        .library(name: "DataChannel", targets: ["DataChannel"]),
        .library(name: "DTLS", targets: ["DTLS"]),
        .library(name: "RTCP", targets: ["RTCP"]),
        .library(name: "RTP", targets: ["RTP"]),
        .library(name: "SCTP", targets: ["SCTP"]),
        .library(name: "SDP", targets: ["SDP"]),
        .library(name: "SRTP", targets: ["SRTP"]),
        .library(name: "STUN", targets: ["STUN"]),
        .library(name: "Utils", targets: ["Utils"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-base64.git", from: "1.0.0"),
        .package(url: "https://github.com/karwa/swift-url", .upToNextMinor(from: "0.4.1")),
        .package(url: "https://github.com/tayloraswift/swift-hash.git", from: "0.5.0")
    ],
    targets: [
        // MARK: - Targets
        .target(name: "DataChannel"),
        .target(name: "DTLS"),
        .target(name: "RTCP"),
        .target(name: "RTP"),
        .target(name: "SCTP"),
        .target(
            name: "SDP",
            dependencies: [
                "Utils",
                .product(name: "NIOCore", package: "swift-nio")
            ]),
        .target(name: "SRTP"),
        .target(name: "STUN",
            dependencies: [
                "Utils",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "WebURL", package: "swift-url"),
                .product(name: "CRC", package: "swift-hash")
            ]),
        .target(name: "Utils",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio")
            ]),

        // MARK: - Tests
        .testTarget(name: "DataChannelTests", dependencies: ["DataChannel"]),
        .testTarget(name: "DTLSTests", dependencies: ["DTLS"]),
        .testTarget(name: "RTCPTests", dependencies: ["RTCP"]),
        .testTarget(name: "RTPTests", dependencies: ["RTP"]),
        .testTarget(name: "SCTPTests", dependencies: ["SCTP"]),
        .testTarget(name: "SDPTests", dependencies: ["SDP"]),
        .testTarget(name: "SRTPTests", dependencies: ["SRTP"]),
        .testTarget(name: "STUNTests", 
            dependencies: [
                "STUN",
                .product(name: "ExtrasBase64", package: "swift-extras-base64")
            ]),
        .testTarget(name: "UtilsTests", dependencies: ["Utils"]),

        // MARK: - Examples
    ]
)
