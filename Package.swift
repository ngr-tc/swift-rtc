// swift-tools-version: 5.8
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
    // minimal version align with swift-hash
    platforms: [
        .macOS("13.3"),
        .iOS("16.4"),
        .watchOS("9.4"),
        .tvOS("16.4"),
    ],
    products: [
        .library(name: "DataChannel", targets: ["DataChannel"]),
        .library(name: "DTLS", targets: ["DTLS"]),
        .library(name: "RTCP", targets: ["RTCP"]),
        .library(name: "RTP", targets: ["RTP"]),
        .library(name: "SCTP", targets: ["SCTP"]),
        .library(name: "SDP", targets: ["SDP"]),
        .library(name: "Shared", targets: ["Shared"]),
        .library(name: "SRTP", targets: ["SRTP"]),
        .library(name: "STUN", targets: ["STUN"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.4.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-base64.git", from: "1.0.0"),
        .package(url: "https://github.com/karwa/swift-url.git", from: "0.4.1"),
        .package(url: "https://github.com/tayloraswift/swift-hash.git", from: "0.5.0"),
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
                "Shared",
                .product(name: "NIOCore", package: "swift-nio"),
            ]),
        .target(name: "Shared",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio")
            ]),
        .target(name: "SRTP"),
        .target(name: "STUN",
            dependencies: [
                "Shared",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "WebURL", package: "swift-url"),
                .product(name: "CRC", package: "swift-hash"),
                .product(name: "ExtrasBase64", package: "swift-extras-base64"),
            ]),

        // MARK: - Tests
        .testTarget(name: "DataChannelTests", dependencies: ["DataChannel"]),
        .testTarget(name: "DTLSTests", dependencies: ["DTLS"]),
        .testTarget(name: "RTCPTests", dependencies: ["RTCP"]),
        .testTarget(name: "RTPTests", dependencies: ["RTP"]),
        .testTarget(name: "SCTPTests", dependencies: ["SCTP"]),
        .testTarget(name: "SDPTests", dependencies: ["SDP"]),
        .testTarget(name: "SharedTests", dependencies: ["Shared"]),
        .testTarget(name: "SRTPTests", dependencies: ["SRTP"]),
        .testTarget(name: "STUNTests",
            dependencies: [
                "STUN",
                .product(name: "ExtrasBase64", package: "swift-extras-base64"),
            ]),

        // MARK: - Examples
        // https://github.com/ngr-tc/swift-rtc-examples
    ]
)
