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

final class SenderReportTests: XCTestCase {
    func testSenderReportUnmarshal() throws {
        let tests = [
            (
                "nil",
                ByteBuffer(bytes: []),
                SenderReport(),
                RtcpError.errPacketTooShort
            ),
            (
                "valid",
                ByteBuffer(bytes: [
                    0x81, 0xc8, 0x0, 0x7,  // v=2, p=0, count=1, SR, len=7
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0xda, 0x8b, 0xd1, 0xfc, 0xdd, 0xdd, 0xa0, 0x5a,  // ntp=0xda8bd1fcdddda05a
                    0xaa, 0xf4, 0xed, 0xd5,  // rtp=0xaaf4edd5
                    0x00, 0x00, 0x00, 0x01,  // packetCount=1
                    0x00, 0x00, 0x00, 0x02,  // octetCount=2
                    0xbc, 0x5e, 0x9a, 0x40,  // ssrc=0xbc5e9a40
                    0x0, 0x0, 0x0, 0x0,  // fracLost=0, totalLost=0
                    0x0, 0x0, 0x46, 0xe1,  // lastSeq=0x46e1
                    0x0, 0x0, 0x1, 0x11,  // jitter=273
                    0x9, 0xf3, 0x64, 0x32,  // lsr=0x9f36432
                    0x0, 0x2, 0x4a, 0x79,  // delay=150137
                ]),
                SenderReport(
                    ssrc: 0x902f_9e2e,
                    ntpTime: 0xda8b_d1fc_dddd_a05a,
                    rtpTime: 0xaaf4_edd5,
                    packetCount: 1,
                    octetCount: 2,
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
                    profileExtensions: ByteBuffer(bytes: [])
                ),
                nil
            ),
            (
                "wrong type",
                ByteBuffer(bytes: [
                    0x81, 0xc9, 0x0, 0x7,  // v=2, p=0, count=1, RR, len=7
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0xda, 0x8b, 0xd1, 0xfc, 0xdd, 0xdd, 0xa0, 0x5a,  // ntp=0xda8bd1fcdddda05a
                    0xaa, 0xf4, 0xed, 0xd5,  // rtp=0xaaf4edd5
                    0x00, 0x00, 0x00, 0x01,  // packetCount=1
                    0x00, 0x00, 0x00, 0x02,  // octetCount=2
                    0xbc, 0x5e, 0x9a, 0x40,  // ssrc=0xbc5e9a40
                    0x0, 0x0, 0x0, 0x0,  // fracLost=0, totalLost=0
                    0x0, 0x0, 0x46, 0xe1,  // jitter=273
                    0x0, 0x0, 0x1, 0x11,  // lastSeq=0x46e1
                    0x9, 0xf3, 0x64, 0x32,  // lsr=0x9f36432
                    0x0, 0x2, 0x4a, 0x79,  // delay=150137
                ]),
                SenderReport(),
                RtcpError.errWrongType
            ),
            (
                "bad count in header",
                ByteBuffer(bytes: [
                    0x82, 0xc8, 0x0, 0x7,  // v=2, p=0, count=1, SR, len=7
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
                    0xda, 0x8b, 0xd1, 0xfc, 0xdd, 0xdd, 0xa0, 0x5a,  // ntp=0xda8bd1fcdddda05a
                    0xaa, 0xf4, 0xed, 0xd5,  // rtp=0xaaf4edd5
                    0x00, 0x00, 0x00, 0x01,  // packetCount=1
                    0x00, 0x00, 0x00, 0x02,  // octetCount=2
                    0xbc, 0x5e, 0x9a, 0x40,  // ssrc=0xbc5e9a40
                    0x0, 0x0, 0x0, 0x0,  // fracLost=0, totalLost=0
                    0x0, 0x0, 0x46, 0xe1,  // lastSeq=0x46e1
                    0x0, 0x0, 0x1, 0x11,  // jitter=273
                    0x9, 0xf3, 0x64, 0x32,  // lsr=0x9f36432
                    0x0, 0x2, 0x4a, 0x79,  // delay=150137
                ]),
                SenderReport(),
                RtcpError.errPacketTooShort
            ),
            (
                "with extension",  // issue #447
                ByteBuffer(bytes: [
                    0x80, 0xc8, 0x0, 0x6,  // v=2, p=0, count=0, SR, len=6
                    0x2b, 0x7e, 0xc0, 0xc5,  // ssrc=0x2b7ec0c5
                    0xe0, 0x20, 0xa2, 0xa9, 0x52, 0xa5, 0x3f, 0xc0,  // ntp=0xe020a2a952a53fc0
                    0x2e, 0x48, 0xa5, 0x52,  // rtp=0x2e48a552
                    0x0, 0x0, 0x0, 0x46,  // packetCount=70
                    0x0, 0x0, 0x12, 0x1d,  // octetCount=4637
                    0x81, 0xca, 0x0, 0x6, 0x2b, 0x7e, 0xc0, 0xc5, 0x1, 0x10, 0x4c, 0x63, 0x49, 0x66,
                    0x7a, 0x58, 0x6f, 0x6e, 0x44, 0x6f, 0x72, 0x64, 0x53, 0x65, 0x57, 0x36, 0x0,
                    0x0,  // profile-specific extension
                ]),
                SenderReport(
                    ssrc: 0x2b7e_c0c5,
                    ntpTime: 0xe020_a2a9_52a5_3fc0,
                    rtpTime: 0x2e48_a552,
                    packetCount: 70,
                    octetCount: 4637,
                    reports: [],
                    profileExtensions: ByteBuffer(bytes: [
                        0x81, 0xca, 0x0, 0x6, 0x2b, 0x7e, 0xc0, 0xc5, 0x1, 0x10, 0x4c, 0x63, 0x49,
                        0x66, 0x7a, 0x58, 0x6f, 0x6e, 0x44, 0x6f, 0x72, 0x64, 0x53, 0x65, 0x57,
                        0x36,
                        0x0, 0x0,
                    ])
                ),
                nil
            ),
        ]

        for (name, data, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try SenderReport.unmarshal(data)
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? SenderReport.unmarshal(data)
                XCTAssertTrue(got != nil)
                let (actual, _) = got!
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testSenderReportRoundtrip() throws {
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
                SenderReport(
                    ssrc: 1,
                    ntpTime: 999,
                    rtpTime: 555,
                    packetCount: 32,
                    octetCount: 11,
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
                    profileExtensions: ByteBuffer(bytes: [])
                ),
                nil
            ),
            (
                "also valid",
                SenderReport(
                    ssrc: 2,
                    ntpTime: 0,
                    rtpTime: 0,
                    packetCount: 0,
                    octetCount: 0,
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
                    profileExtensions: ByteBuffer(bytes: [])
                ),
                nil
            ),
            (
                "extension",
                SenderReport(
                    ssrc: 2,
                    ntpTime: 0,
                    rtpTime: 0,
                    packetCount: 0,
                    octetCount: 0,
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
                    profileExtensions: ByteBuffer(bytes: [1, 2, 3, 4])
                ),
                nil
            ),
            (
                "count overflow",
                SenderReport(
                    ssrc: 1,
                    ntpTime: 0,
                    rtpTime: 0,
                    packetCount: 0,
                    octetCount: 0,
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
                let (actual, _) = try SenderReport.unmarshal(data)
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }
}
