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

final class SliceLossIndicationTests: XCTestCase {
    func testSliceLossIndicationUnmarshal() throws {
        let tests = [
            (
                "valid",
                ByteBuffer(bytes: [
                    0x82, 0xcd, 0x0, 0x3,  // SliceLossIndication
                    0x90, 0x2f, 0x9e, 0x2e,  // sender=0x902f9e2e
                    0x90, 0x2f, 0x9e, 0x2e,  // media=0x902f9e2e
                    0x55, 0x50, 0x00, 0x2C,  // nack 0xAAAA, 0x5555
                ]),
                SliceLossIndication(
                    senderSsrc: 0x902f_9e2e,
                    mediaSsrc: 0x902f_9e2e,
                    sliEntries: [
                        SliEntry(
                            first: 0xaaa,
                            number: 0,
                            picture: 0x2C
                        )
                    ]
                ),
                nil
            ),
            (
                "short report",
                ByteBuffer(bytes: [
                    0x82, 0xcd, 0x0, 0x2,  // ssrc=0x902f9e2e
                    0x90, 0x2f, 0x9e, 0x2e,
                    // report ends early
                ]),
                SliceLossIndication(),
                RtcpError.errPacketTooShort
            ),
            (
                "wrong type",
                ByteBuffer(bytes: [
                    // v=2, p=0, count=1, SR, len=7
                    0x81, 0xc8, 0x0, 0x7,  // ssrc=0x902f9e2e
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0xbc5e9a40
                    0xbc, 0x5e, 0x9a, 0x40,  // fracLost=0, totalLost=0
                    0x0, 0x0, 0x0, 0x0,  // lastSeq=0x46e1
                    0x0, 0x0, 0x46, 0xe1,  // jitter=273
                    0x0, 0x0, 0x1, 0x11,  // lsr=0x9f36432
                    0x9, 0xf3, 0x64, 0x32,  // delay=150137
                    0x0, 0x2, 0x4a, 0x79,
                ]),
                SliceLossIndication(),
                RtcpError.errWrongType
            ),
            (
                "nil",
                ByteBuffer(bytes: []),
                SliceLossIndication(),
                RtcpError.errPacketTooShort
            ),
        ]

        for (name, data, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try SliceLossIndication.unmarshal(data)
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? SliceLossIndication.unmarshal(data)
                XCTAssertTrue(got != nil)
                let (actual, _) = got!
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testSliceLossIndicationRoundtrip() throws {
        let tests: [(String, SliceLossIndication, RtcpError?)] = [
            (
                "valid",
                SliceLossIndication(
                    senderSsrc: 0x902f_9e2e,
                    mediaSsrc: 0x902f_9e2e,
                    sliEntries: [
                        SliEntry(
                            first: 1,
                            number: 0xAA,
                            picture: 0x1F
                        ),
                        SliEntry(
                            first: 1034,
                            number: 0x05,
                            picture: 0x6
                        ),
                    ]
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
                let (actual, _) = try SliceLossIndication.unmarshal(data)
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

}
