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

final class RapidResynchronizationRequestTests: XCTestCase {
    func testRapidResynchronizationRequestUnmarshal() throws {
        let tests = [
            (
                "valid",
                ByteBuffer(bytes: [
                    0x85, 0xcd, 0x0, 0x2,  // RapidResynchronizationRequest
                    0x90, 0x2f, 0x9e, 0x2e,  // sender=0x902f9e2e
                    0x90, 0x2f, 0x9e, 0x2e,  // media=0x902f9e2e
                ]),
                RapidResynchronizationRequest(
                    senderSsrc: 0x902f_9e2e,
                    mediaSsrc: 0x902f_9e2e
                ),
                nil
            ),
            (
                "short report",
                ByteBuffer(bytes: [
                    0x85, 0xcd, 0x0, 0x2,  // ssrc=0x902f9e2e
                    0x90, 0x2f, 0x9e, 0x2e,
                    // report ends early
                ]),
                RapidResynchronizationRequest(),
                RtcpError.errPacketTooShort
            ),
            (
                "wrong type",
                ByteBuffer(bytes: [
                    0x81, 0xc8, 0x0, 0x7,  // v=2, p=0, count=1, SR, len=7
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0xbc, 0x5e, 0x9a, 0x40,  // ssrc=0xbc5e9a40
                    0x0, 0x0, 0x0, 0x0,  // fracLost=0, totalLost=0
                    0x0, 0x0, 0x46, 0xe1,  // lastSeq=0x46e1
                    0x0, 0x0, 0x1, 0x11,  // jitter=273
                    0x9, 0xf3, 0x64, 0x32,  // lsr=0x9f36432
                    0x0, 0x2, 0x4a, 0x79,  // delay=150137
                ]),
                RapidResynchronizationRequest(),
                RtcpError.errWrongType
            ),
            (
                "nil",
                ByteBuffer(bytes: []),
                RapidResynchronizationRequest(),
                RtcpError.errPacketTooShort
            ),
        ]

        for (name, data, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try RapidResynchronizationRequest.unmarshal(data)
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? RapidResynchronizationRequest.unmarshal(data)
                XCTAssertTrue(got != nil)
                let (actual, _) = got!
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testRapidResynchronizationRequestRoundtrip() throws {
        let tests: [(String, RapidResynchronizationRequest, RtcpError?)] = [
            (
                "valid",
                RapidResynchronizationRequest(
                    senderSsrc: 0x902f_9e2e,
                    mediaSsrc: 0x902f_9e2e
                ),
                nil
            )
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
                let (actual, _) = try RapidResynchronizationRequest.unmarshal(data)
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

}
