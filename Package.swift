// swift-tools-version: 5.10
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
        .library(name: "RTC", targets: ["RTC"]),
        .library(name: "RTCP", targets: ["RTCP"]),
        .library(name: "RTP", targets: ["RTP"]),
        .library(name: "SCTP", targets: ["SCTP"]),
        .library(name: "SDP", targets: ["SDP"]),
        .library(name: "SRTP", targets: ["SRTP"]),
        .library(name: "STUN", targets: ["STUN"]),
    ],
    targets: [
        // MARK: - Targets
        .target(name: "DataChannel"),
        .target(name: "DTLS"),
        .target(name: "RTC"),
        .target(name: "RTCP"),
        .target(name: "RTP"),
        .target(name: "SCTP"),
        .target(name: "SDP"),
        .target(name: "SRTP"),
        .target(name: "STUN"),

        // MARK: - Tests
        .testTarget(name: "DataChannelTests", dependencies: ["DataChannel"]),
        .testTarget(name: "DTLSTests", dependencies: ["DTLS"]),
        .testTarget(name: "RTCTests", dependencies: ["RTC"]),
        .testTarget(name: "RTCPTests", dependencies: ["RTCP"]),
        .testTarget(name: "RTPTests", dependencies: ["RTP"]),
        .testTarget(name: "SCTPTests", dependencies: ["SCTP"]),
        .testTarget(name: "SDPTests", dependencies: ["SDP"]),
        .testTarget(name: "SRTPTests", dependencies: ["SRTP"]),
        .testTarget(name: "STUNTests", dependencies: ["STUN"]),

        // MARK: - Examples
    ]
)
