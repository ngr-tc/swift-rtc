import Shared
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

@testable import STUN

final class UriTests: XCTestCase {
    func testParseUri() throws {
        let tests = [
            (
                "default",
                "stun:example.org",
                Uri(
                    scheme: SchemeType.stun,
                    host: "example.org",
                    port: 3478
                ),
                "stun:example.org:3478"
            ),
            (
                "secure",
                "stuns:example.org",
                Uri(
                    scheme: SchemeType.stuns,
                    host: "example.org",
                    port: 5349
                ),
                "stuns:example.org:5349"
            ),
            (
                "with port",
                "stun:example.org:8000",
                Uri(
                    scheme: SchemeType.stun,
                    host: "example.org",
                    port: 8000
                ),
                "stun:example.org:8000"
            ),
            (
                "ipv6 address",
                "stun:[::1]:123",
                Uri(
                    scheme: SchemeType.stun,
                    host: "::1",
                    port: 123
                ),
                "stun:[::1]:123"
            ),
        ]

        for (_, input, output, expected_str) in tests {
            let out = try Uri.parseUri(input)
            XCTAssertEqual(out, output)
            XCTAssertEqual(out.description, expected_str)
        }

        //"MustFail"
        do {
            let tests = [
                ("hierarchical", "stun://example.org"),
                ("bad scheme", "tcp:example.org"),
                ("invalid uri scheme", "stun_s:test"),
            ]
            for (name, input) in tests {
                do {
                    let _ = try Uri.parseUri(input)
                    XCTAssertTrue(false, "\(name) should fail, but did not")
                } catch {
                    XCTAssertTrue(true, "realm attribute should be found")
                }
            }
        }
    }
}
