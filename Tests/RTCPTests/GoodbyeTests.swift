import NIOCore
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

@testable import RTCP

final class GoodbyeTests: XCTestCase {
    func testGoodbyeUnmarshal() throws {
        let tests = [
            (
                "valid",
                ByteBuffer(bytes: [
                    0x81, 0xcb, 0x00, 0x0c,  // v=2, p=0, count=1, BYE, len=12
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0x03, 0x46, 0x4f, 0x4f,  // len=3, text=FOO
                ]),
                Goodbye(
                    sources: [0x902f_9e2e],
                    reason: ByteBuffer(string: "FOO")
                ),
                nil
            ),
            (
                "invalid octet count",
                ByteBuffer(bytes: [
                    0x81, 0xcb, 0x00, 0x0c,  // v=2, p=0, count=1, BYE, len=12
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0x04, 0x46, 0x4f, 0x4f,  // len=4, text=FOO
                ]),
                Goodbye(
                    sources: [],
                    reason: ByteBuffer(string: "")
                ),
                RtcpError.errPacketTooShort
            ),
            (
                "wrong type",
                ByteBuffer(bytes: [
                    0x81, 0xca, 0x00, 0x0c,  // v=2, p=0, count=1, SDES, len=12
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0x03, 0x46, 0x4f, 0x4f,  // len=3, text=FOO
                ]),
                Goodbye(
                    sources: [],
                    reason: ByteBuffer(string: "")
                ),
                RtcpError.errWrongType
            ),
            (
                "short reason",
                ByteBuffer(bytes: [
                    0x81, 0xcb, 0x00, 0x0c,  // v=2, p=0, count=1, BYE, len=12
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0x01, 0x46, 0x00, 0x00,  // len=3, text=F + padding
                ]),
                Goodbye(
                    sources: [0x902f_9e2e],
                    reason: ByteBuffer(string: "F")
                ),
                nil
            ),
            (
                "not byte aligned",
                ByteBuffer(bytes: [
                    0x81, 0xcb, 0x00, 0x0a,  // v=2, p=0, count=1, BYE, len=10
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0x01, 0x46,  // len=1, text=F
                ]),
                Goodbye(
                    sources: [],
                    reason: ByteBuffer(string: "")
                ),
                RtcpError.errPacketTooShort
            ),
            (
                "bad count in header",
                ByteBuffer(bytes: [
                    0x82, 0xcb, 0x00, 0x0c,  // v=2, p=0, count=2, BYE, len=8
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                ]),
                Goodbye(
                    sources: [],
                    reason: ByteBuffer(string: "")
                ),
                RtcpError.errPacketTooShort
            ),
            (
                "empty packet",
                ByteBuffer(bytes: [
                    // v=2, p=0, count=0, BYE, len=4
                    0x80, 0xcb, 0x00, 0x04,
                ]),
                Goodbye(
                    sources: [],
                    reason: ByteBuffer(string: "")
                ),
                nil
            ),
            (
                "nil",
                ByteBuffer(bytes: []),
                Goodbye(
                    sources: [],
                    reason: ByteBuffer(string: "")
                ),
                RtcpError.errPacketTooShort
            ),
        ]

        for (name, data, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try Goodbye.unmarshal(data)
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? Goodbye.unmarshal(data)
                XCTAssertTrue(got != nil)
                let (actual, _) = got!
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testGoodbyeRoundtrip() throws {
        let tooManySources: [uint32] = Array(repeating: 0, count: 1 << 5)

        var tooLongText = String()
        for _ in 0..<1 << 8 {
            tooLongText.append("x")
        }

        let tests = [
            (
                "empty",
                Goodbye(
                    sources: [],
                    reason: ByteBuffer(bytes: [])
                ),
                nil
            ),
            (
                "valid",
                Goodbye(
                    sources: [0x0102_0304, 0x0506_0708],
                    reason: ByteBuffer(string: "because")
                ),
                nil
            ),
            (
                "empty reason",
                Goodbye(
                    sources: [0x0102_0304],
                    reason: ByteBuffer(string: "")
                ),
                nil
            ),
            (
                "reason no source",
                Goodbye(
                    sources: [],
                    reason: ByteBuffer(string: "foo")
                ),
                nil
            ),
            (
                "short reason",
                Goodbye(
                    sources: [],
                    reason: ByteBuffer(string: "f")
                ),
                nil
            ),
            (
                "count overflow",
                Goodbye(
                    sources: tooManySources,
                    reason: ByteBuffer(string: "")
                ),
                RtcpError.errTooManySources
            ),
            (
                "reason too long",
                Goodbye(
                    sources: [],
                    reason: ByteBuffer(string: tooLongText)
                ),
                RtcpError.errReasonTooLong
            ),
        ]

        for (name, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try want.marshal()
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? want.marshal()
                XCTAssertTrue(got != nil)
                let data = got!
                let (actual, _) = try Goodbye.unmarshal(data)
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }
}
