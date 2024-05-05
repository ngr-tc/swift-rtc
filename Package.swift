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
