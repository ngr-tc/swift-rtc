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

final class RawPacketTests: XCTestCase {
    func testRawPacketRoundtrip() throws {
        let tests: [(String, RawPacket, RtcpError?)] = [
            (
                "valid",
                RawPacket(
                    raw: ByteBuffer(bytes: [
                        0x81, 0xcb, 0x00, 0x0c,  // v=2, p=0, count=1, BYE, len=12
                        0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                        0x03, 0x46, 0x4f, 0x4f,  // len=3, text=FOO
                    ])),
                nil
            ),
            (
                "short header",
                RawPacket(raw: ByteBuffer(bytes: [0x80])),
                RtcpError.errPacketTooShort
            ),
            (
                "invalid header",
                RawPacket(
                    // v=0, p=0, count=0, RR, len=4
                    raw: ByteBuffer(bytes: [0x00, 0xc9, 0x00, 0x04])
                ),
                RtcpError.errBadVersion
            ),
        ]

        for (name, pkt, unmarshalError) in tests {
            if unmarshalError == nil {
                let result = try? pkt.marshal()
                XCTAssertTrue(result != nil)
                let buf = result!
                let p = try? RawPacket.unmarshal(buf)
                XCTAssertTrue(result != nil)
                let decoded = p!
                XCTAssertEqual(decoded.0, pkt, "\(name) raw round trip")
            } else {
                do {
                    let _ = try pkt.marshal()
                    XCTFail("expect error")
                } catch let err as RtcpError {
                    XCTAssertEqual(err, unmarshalError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            }
        }
    }
}
