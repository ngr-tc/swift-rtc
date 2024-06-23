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

@testable import Shared

final class UrlTests: XCTestCase {
    func testParseUrlSuccess() throws {
        let tests: [(String, String, SchemeType, Bool, String, UInt16, ProtoType)] = [
            (
                "stun:google.de",
                "stun:google.de:3478",
                SchemeType.stun,
                false,
                "google.de",
                3478,
                ProtoType.udp
            ),
            (
                "stun:google.de:1234",
                "stun:google.de:1234",
                SchemeType.stun,
                false,
                "google.de",
                1234,
                ProtoType.udp
            ),
            (
                "stuns:google.de",
                "stuns:google.de:5349",
                SchemeType.stuns,
                true,
                "google.de",
                5349,
                ProtoType.tcp
            ),
            (
                "stun:[::1]:123",
                "stun:[::1]:123",
                SchemeType.stun,
                false,
                "::1",
                123,
                ProtoType.udp
            ),
            (
                "stun:[::1]",
                "stun:[::1]:3478",
                SchemeType.stun,
                false,
                "::1",
                3478,
                ProtoType.udp
            ),
            (
                "stun:192.0.0.1:123",
                "stun:192.0.0.1:123",
                SchemeType.stun,
                false,
                "192.0.0.1",
                123,
                ProtoType.udp
            ),
            (
                "stun:192.0.0.1",
                "stun:192.0.0.1:3478",
                SchemeType.stun,
                false,
                "192.0.0.1",
                3478,
                ProtoType.udp
            ),
            (
                "turn:google.de",
                "turn:google.de:3478?transport=udp",
                SchemeType.turn,
                false,
                "google.de",
                3478,
                ProtoType.udp
            ),
            (
                "turns:google.de",
                "turns:google.de:5349?transport=tcp",
                SchemeType.turns,
                true,
                "google.de",
                5349,
                ProtoType.tcp
            ),
            (
                "turn:google.de?transport=udp",
                "turn:google.de:3478?transport=udp",
                SchemeType.turn,
                false,
                "google.de",
                3478,
                ProtoType.udp
            ),
            (
                "turns:google.de?transport=tcp",
                "turns:google.de:5349?transport=tcp",
                SchemeType.turns,
                true,
                "google.de",
                5349,
                ProtoType.tcp
            ),
        ]

        for (
            rawUrl,
            expectedUrlString,
            expectedScheme,
            expectedSecure,
            expectedHost,
            expectedPort,
            expectedProto
        ) in tests {
            let url = try Url(rawUrl)
            XCTAssertEqual(url.scheme, expectedScheme)
            XCTAssertEqual(
                expectedUrlString,
                url.description
            )
            XCTAssertEqual(url.isSecure(), expectedSecure)
            XCTAssertEqual(url.host, expectedHost)
            XCTAssertEqual(url.port, expectedPort)
            XCTAssertEqual(url.proto, expectedProto)
        }
    }

    func testParseUrlFailure() throws {
        let tests = [
            ("", UrlError.errSchemeType),
            (":::", UrlError.errSchemeType),
            ("stun:[::1]:123:", UrlError.errPort),
            ("stun:[::1]:123a", UrlError.errPort),
            ("google.de", UrlError.errSchemeType),
            ("stun:", UrlError.errHost),
            ("stun:google.de:abc", UrlError.errPort),
            ("stun:google.de?transport=udp", UrlError.errStunQuery),
            ("stuns:google.de?transport=udp", UrlError.errStunQuery),
            ("turn:google.de?trans=udp", UrlError.errInvalidQuery),
            ("turns:google.de?trans=udp", UrlError.errInvalidQuery),
            (
                "turns:google.de?transport=udp&another=1",
                UrlError.errInvalidQuery
            ),
            ("turn:google.de?transport=ip", UrlError.errProtoType),
        ]

        for (rawUrl, expectedErr) in tests {
            do {
                let _ = try Url(rawUrl)
                XCTFail("should error: \(rawUrl)")
            } catch let err as UrlError {
                XCTAssertEqual(err, expectedErr, "\(rawUrl)")
            } catch {
                XCTFail("should UrlError: \(rawUrl)")
            }
        }
    }
}
