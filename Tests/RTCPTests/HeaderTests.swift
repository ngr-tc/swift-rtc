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

final class HeaderTests: XCTestCase {
    func testHeaderUnmarshal() throws {
        let tests = [
            (
                "valid",
                ByteBuffer(bytes: [
                    // v=2, p=0, count=1, RR, len=7
                    0x81, 0xc9, 0x00, 0x07,
                ]),
                Header(
                    padding: false,
                    count: 1,
                    packetType: PacketType.receiverReport,
                    length: 7
                ),
                nil
            ),
            (
                "also valid",
                ByteBuffer(bytes: [
                    // v=2, p=1, count=1, BYE, len=7
                    0xa1, 0xcc, 0x00, 0x07,
                ]),
                Header(
                    padding: true,
                    count: 1,
                    packetType: PacketType.applicationDefined,
                    length: 7
                ),
                nil
            ),
            (
                "bad version",
                ByteBuffer(bytes: [
                    // v=0, p=0, count=0, RR, len=4
                    0x00, 0xc9, 0x00, 0x04,
                ]),
                Header(
                    padding: false,
                    count: 0,
                    packetType: PacketType.unsupported,
                    length: 0
                ),
                RtcpError.errBadVersion
            ),
        ]

        for (name, data, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try Header.unmarshal(data)
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? Header.unmarshal(data)
                XCTAssertTrue(got != nil)
                let (actual, _) = got!
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testHeaderRoundtrip() throws {
        let tests = [
            (
                "valid",
                Header(
                    padding: true,
                    count: 31,
                    packetType: PacketType.senderReport,
                    length: 4
                ),
                nil
            ),
            (
                "also valid",
                Header(
                    padding: false,
                    count: 28,
                    packetType: PacketType.receiverReport,
                    length: 65535
                ),
                nil
            ),
            (
                "invalid count",
                Header(
                    padding: false,
                    count: 40,
                    packetType: PacketType.unsupported,
                    length: 0
                ),
                RtcpError.errInvalidHeader
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
                let (actual, _) = try Header.unmarshal(data)
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }
}
