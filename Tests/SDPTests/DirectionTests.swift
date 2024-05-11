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
import XCTest
import SDP

final class DirectionTests: XCTestCase {
    func testNewDirection() throws {
        let passingTests = [
            ("sendrecv", Direction.sendrecv),
            ("sendonly", Direction.sendonly),
            ("recvonly", Direction.recvonly),
            ("inactive", Direction.inactive),
        ]

        let failingTests = ["", "notadirection"]

        for (s, d) in passingTests {
            let dir = Direction(rawValue: s)
            XCTAssertEqual(d, dir)
        }
        for s in failingTests {
            let dir = Direction(rawValue: s)
            XCTAssertEqual(nil, dir)
        }
    }

    func testDirectionString() throws {
        let tests = [
            (Direction.sendrecv, "sendrecv"),
            (Direction.sendonly, "sendonly"),
            (Direction.recvonly, "recvonly"),
            (Direction.inactive, "inactive"),
        ]

        for (d, s) in tests {
            XCTAssertEqual(s, d.rawValue)
        }
    }
}
