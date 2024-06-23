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
    // minimal version align with swift-crypto
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(name: "DataChannel", targets: ["DataChannel"]),
        .library(name: "DTLS", targets: ["DTLS"]),
        .library(name: "RTC", targets: ["RTC"]),
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
    ],
    targets: [
        // MARK: - Targets
        .target(name: "DataChannel"),
        .target(name: "DTLS",
            dependencies: [
                "Shared",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
            ]),
        .target(
            name: "RTC",
            dependencies: [
                "RTP",
                "SDP",
                "STUN",
            ]
        ),
        .target(name: "RTCP",
            dependencies: [
                "Shared",
                .product(name: "NIOCore", package: "swift-nio"),
            ]),
        .target(name: "RTP",
            dependencies: [
                "Shared",
                .product(name: "NIOCore", package: "swift-nio"),
            ]),
        .target(name: "SCTP"),
        .target(
            name: "SDP",
            dependencies: [
                "Shared",
                .product(name: "NIOCore", package: "swift-nio"),
            ]),
        .target(name: "Shared",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
            ]),
        .target(name: "SRTP",
            dependencies: [
                "RTCP",
                "RTP",
                "Shared",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
            ]),
        .target(name: "STUN",
            dependencies: [
                "Shared",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]),

        // MARK: - Tests
        .testTarget(name: "DataChannelTests", dependencies: ["DataChannel"]),
        .testTarget(name: "DTLSTests", dependencies: ["DTLS"]),
        .testTarget(name: "RTCPTests", dependencies: ["RTCP"]),
        .testTarget(name: "RTPTests", dependencies: ["RTP"]),
        .testTarget(name: "SCTPTests", dependencies: ["SCTP"]),
        .testTarget(name: "SDPTests", dependencies: ["SDP"]),
        .testTarget(name: "SharedTests", dependencies: ["Shared"]),
        .testTarget(name: "SRTPTests", dependencies: ["SRTP", "RTP"]),
        .testTarget(name: "STUNTests", dependencies: ["STUN", "Shared"]),

        // MARK: - Examples
        // https://github.com/ngr-tc/swift-rtc-examples
    ]
)
