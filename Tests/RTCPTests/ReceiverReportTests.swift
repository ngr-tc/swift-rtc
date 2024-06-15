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

final class ReceiverReportTests: XCTestCase {
    func testReceiverReportUnmarshal() throws {
        let tests = [
            (
                "valid",
                ByteBuffer(bytes: [
                    0x81, 0xc9, 0x0, 0x7,  // v=2, p=0, count=1, RR, len=7
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0xbc, 0x5e, 0x9a, 0x40,  // ssrc=0xbc5e9a40
                    0x0, 0x0, 0x0, 0x0,  // fracLost=0, totalLost=0
                    0x0, 0x0, 0x46, 0xe1,  // lastSeq=0x46e1
                    0x0, 0x0, 0x1, 0x11,  // jitter=273
                    0x9, 0xf3, 0x64, 0x32,  // lsr=0x9f36432
                    0x0, 0x2, 0x4a, 0x79,  // delay=150137
                ]),
                ReceiverReport(
                    ssrc: 0x902f_9e2e,
                    reports: [
                        ReceptionReport(
                            ssrc: 0xbc5e_9a40,
                            fractionLost: 0,
                            totalLost: 0,
                            lastSequenceNumber: 0x46e1,
                            jitter: 273,
                            lastSenderReport: 0x9f36432,
                            delay: 150137
                        )
                    ],
                    profileExtensions: ByteBuffer()
                ),
                nil
            ),
            (
                "valid with extension data",
                ByteBuffer(bytes: [
                    0x81, 0xc9, 0x0, 0x9,  // v=2, p=0, count=1, RR, len=9
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0xbc, 0x5e, 0x9a, 0x40,  // ssrc=0xbc5e9a40
                    0x0, 0x0, 0x0, 0x0,  // fracLost=0, totalLost=0
                    0x0, 0x0, 0x46, 0xe1,  // lastSeq=0x46e1
                    0x0, 0x0, 0x1, 0x11,  // jitter=273
                    0x9, 0xf3, 0x64, 0x32,  // lsr=0x9f36432
                    0x0, 0x2, 0x4a, 0x79,  // delay=150137
                    0x54, 0x45, 0x53, 0x54, 0x44, 0x41, 0x54,
                    0x41,  // profile-specific extension data
                ]),
                ReceiverReport(
                    ssrc: 0x902f_9e2e,
                    reports: [
                        ReceptionReport(
                            ssrc: 0xbc5e_9a40,
                            fractionLost: 0,
                            totalLost: 0,
                            lastSequenceNumber: 0x46e1,
                            jitter: 273,
                            lastSenderReport: 0x9f36432,
                            delay: 150137
                        )
                    ],
                    profileExtensions: ByteBuffer(bytes: [
                        0x54, 0x45, 0x53, 0x54, 0x44, 0x41, 0x54, 0x41,
                    ])
                ),
                nil
            ),
            (
                "short report",
                ByteBuffer(bytes: [
                    0x81, 0xc9, 0x00, 0x0c,  // v=2, p=0, count=1, RR, len=7
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0x00, 0x00, 0x00,
                    0x00,  // fracLost=0, totalLost=0
                    // report ends early
                ]),
                ReceiverReport(),
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
                ReceiverReport(),
                RtcpError.errWrongType
            ),
            (
                "bad count in header",
                ByteBuffer(bytes: [
                    0x82, 0xc9, 0x0, 0x7,  // v=2, p=0, count=2, RR, len=7
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0xbc, 0x5e, 0x9a, 0x40,  // ssrc=0xbc5e9a40
                    0x0, 0x0, 0x0, 0x0,  // fracLost=0, totalLost=0
                    0x0, 0x0, 0x46, 0xe1,  // lastSeq=0x46e1
                    0x0, 0x0, 0x1, 0x11,  // jitter=273
                    0x9, 0xf3, 0x64, 0x32,  // lsr=0x9f36432
                    0x0, 0x2, 0x4a, 0x79,  // delay=150137
                ]),
                ReceiverReport(),
                RtcpError.errPacketTooShort
            ),
            (
                "nil",
                ByteBuffer(bytes: []),
                ReceiverReport(),
                RtcpError.errPacketTooShort
            ),
        ]

        for (name, data, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try ReceiverReport.unmarshal(data)
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? ReceiverReport.unmarshal(data)
                XCTAssertTrue(got != nil)
                let (actual, _) = got!
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testReceiverReportRoundtrip() throws {
        var tooManyReports: [ReceptionReport] = []
        for _ in 0..<(1 << 5) {
            tooManyReports.append(
                ReceptionReport(
                    ssrc: 2,
                    fractionLost: 2,
                    totalLost: 3,
                    lastSequenceNumber: 4,
                    jitter: 5,
                    lastSenderReport: 6,
                    delay: 7
                ))
        }

        let tests = [
            (
                "valid",
                ReceiverReport(
                    ssrc: 1,
                    reports: [
                        ReceptionReport(
                            ssrc: 2,
                            fractionLost: 2,
                            totalLost: 3,
                            lastSequenceNumber: 4,
                            jitter: 5,
                            lastSenderReport: 6,
                            delay: 7
                        ),
                        ReceptionReport(),
                    ],
                    profileExtensions: ByteBuffer()
                ),
                nil
            ),
            (
                "also valid",
                ReceiverReport(
                    ssrc: 2,
                    reports: [
                        ReceptionReport(
                            ssrc: 999,
                            fractionLost: 30,
                            totalLost: 12345,
                            lastSequenceNumber: 99,
                            jitter: 22,
                            lastSenderReport: 92,
                            delay: 46
                        )
                    ],
                    profileExtensions: ByteBuffer()
                ),
                nil
            ),
            (
                "totallost overflow",
                ReceiverReport(
                    ssrc: 1,
                    reports: [
                        ReceptionReport(
                            ssrc: 0,
                            fractionLost: 0,
                            totalLost: 1 << 25,
                            lastSequenceNumber: 0,
                            jitter: 0,
                            lastSenderReport: 0,
                            delay: 0
                        )
                    ],
                    profileExtensions: ByteBuffer()
                ),
                RtcpError.errInvalidTotalLost
            ),
            (
                "count overflow",
                ReceiverReport(
                    ssrc: 1,
                    reports: tooManyReports,
                    profileExtensions: ByteBuffer()
                ),
                RtcpError.errTooManyReports
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
                let (actual, _) = try ReceiverReport.unmarshal(data)
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }
}
