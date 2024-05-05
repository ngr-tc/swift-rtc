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
        .library(name: "RTCP", targets: ["RTCP"]),
        .library(name: "RTP", targets: ["RTP"]),
        .library(name: "SCTP", targets: ["SCTP"]),
        .library(name: "SDP", targets: ["SDP"]),
        .library(name: "SRTP", targets: ["SRTP"]),
        .library(name: "STUN", targets: ["STUN"]),
        .library(name: "Utils", targets: ["Utils"]),
    ],
    targets: [
        // MARK: - Targets
        .target(name: "DataChannel"),
        .target(name: "DTLS"),
        .target(name: "RTCP"),
        .target(name: "RTP"),
        .target(name: "SCTP"),
        .target(name: "SDP", dependencies: ["Utils"]),
        .target(name: "SRTP"),
        .target(name: "STUN"),
        .target(name: "Utils"),

        // MARK: - Tests
        .testTarget(name: "DataChannelTests", dependencies: ["DataChannel"]),
        .testTarget(name: "DTLSTests", dependencies: ["DTLS"]),
        .testTarget(name: "RTCPTests", dependencies: ["RTCP"]),
        .testTarget(name: "RTPTests", dependencies: ["RTP"]),
        .testTarget(name: "SCTPTests", dependencies: ["SCTP"]),
        .testTarget(name: "SDPTests", dependencies: ["SDP"]),
        .testTarget(name: "SRTPTests", dependencies: ["SRTP"]),
        .testTarget(name: "STUNTests", dependencies: ["STUN"]),
        .testTarget(name: "UtilsTests", dependencies: ["Utils"]),

        // MARK: - Examples
    ]
)
