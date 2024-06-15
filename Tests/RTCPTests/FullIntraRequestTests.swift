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

final class FullIntraRequestTests: XCTestCase {
    func testFullIntraRequestUnmarshal() throws {
        let tests = [
            (
                "valid",
                ByteBuffer(bytes: [
                    0x84, 0xce, 0x00, 0x03,  // v=2, p=0, FMT=4, PSFB, len=3
                    0x00, 0x00, 0x00, 0x00,  // ssrc=0x0
                    0x4b, 0xc4, 0xfc, 0xb4,  // ssrc=0x4bc4fcb4
                    0x12, 0x34, 0x56, 0x78,  // ssrc=0x12345678
                    0x42, 0x00, 0x00, 0x00,  // Seqno=0x42
                ]),
                FullIntraRequest(
                    senderSsrc: 0x0,
                    mediaSsrc: 0x4bc4_fcb4,
                    fir: [
                        FirEntry(
                            ssrc: 0x1234_5678,
                            sequenceNumber: 0x42
                        )
                    ]
                ),
                nil
            ),
            (
                "also valid",
                ByteBuffer(bytes: [
                    0x84, 0xce, 0x00, 0x05,  // v=2, p=0, FMT=4, PSFB, len=3
                    0x00, 0x00, 0x00, 0x00,  // ssrc=0x0
                    0x4b, 0xc4, 0xfc, 0xb4,  // ssrc=0x4bc4fcb4
                    0x12, 0x34, 0x56, 0x78,  // ssrc=0x12345678
                    0x42, 0x00, 0x00, 0x00,  // Seqno=0x42
                    0x98, 0x76, 0x54, 0x32,  // ssrc=0x98765432
                    0x57, 0x00, 0x00, 0x00,  // Seqno=0x57
                ]),
                FullIntraRequest(
                    senderSsrc: 0x0,
                    mediaSsrc: 0x4bc4_fcb4,
                    fir: [
                        FirEntry(
                            ssrc: 0x1234_5678,
                            sequenceNumber: 0x42
                        ),
                        FirEntry(
                            ssrc: 0x9876_5432,
                            sequenceNumber: 0x57
                        ),
                    ]
                ),
                nil
            ),
            (
                "packet too short",
                ByteBuffer(bytes: [0x00, 0x00, 0x00, 0x00]),
                FullIntraRequest(),
                RtcpError.errPacketTooShort
            ),
            (
                "invalid header",
                ByteBuffer(bytes: [
                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                    0x00,
                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                ]),
                FullIntraRequest(),
                RtcpError.errBadVersion
            ),
            (
                "wrong type",
                ByteBuffer(bytes: [
                    0x84, 0xc9, 0x00, 0x03,  // v=2, p=0, FMT=4, RR, len=3
                    0x00, 0x00, 0x00, 0x00,  // ssrc=0x0
                    0x4b, 0xc4, 0xfc, 0xb4,  // ssrc=0x4bc4fcb4
                    0x12, 0x34, 0x56, 0x78,  // ssrc=0x12345678
                    0x42, 0x00, 0x00, 0x00,  // Seqno=0x42
                ]),
                FullIntraRequest(),
                RtcpError.errWrongType
            ),
            (
                "wrong fmt",
                ByteBuffer(bytes: [
                    0x82, 0xce, 0x00, 0x03,  // v=2, p=0, FMT=2, PSFB, len=3
                    0x00, 0x00, 0x00, 0x00,  // ssrc=0x0
                    0x4b, 0xc4, 0xfc, 0xb4,  // ssrc=0x4bc4fcb4
                    0x12, 0x34, 0x56, 0x78,  // ssrc=0x12345678
                    0x42, 0x00, 0x00, 0x00,  // Seqno=0x42
                ]),
                FullIntraRequest(),
                RtcpError.errWrongType
            ),
        ]

        for (name, data, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try FullIntraRequest.unmarshal(data)
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? FullIntraRequest.unmarshal(data)
                XCTAssertTrue(got != nil)
                let (actual, _) = got!
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testFullIntraRequestRoundtrip() throws {
        let tests: [(String, FullIntraRequest, RtcpError?)] = [
            (
                "valid",
                FullIntraRequest(
                    senderSsrc: 1,
                    mediaSsrc: 2,
                    fir: [
                        FirEntry(
                            ssrc: 3,
                            sequenceNumber: 42
                        )
                    ]
                ),
                nil
            ),
            (
                "also valid",
                FullIntraRequest(
                    senderSsrc: 5000,
                    mediaSsrc: 6000,
                    fir: [
                        FirEntry(
                            ssrc: 3,
                            sequenceNumber: 57
                        )
                    ]
                ),
                nil
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
                let (actual, _) = try FullIntraRequest.unmarshal(data)
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testFullIntraRequestUnmarshalHeader() throws {
        let tests = [
            (
                "valid header",
                ByteBuffer(bytes: [
                    0x84, 0xce, 0x00, 0x02,  // v=2, p=0, FMT=1, PSFB, len=1
                    0x00, 0x00, 0x00, 0x00,  // ssrc=0x0
                    0x4b, 0xc4, 0xfc, 0xb4, 0x00, 0x00, 0x00, 0x00,  // ssrc=0x4bc4fcb4
                ]),
                Header(
                    padding: false,
                    count: formatFir,
                    packetType: PacketType.payloadSpecificFeedback,
                    length: 2
                )
            )
        ]

        for (name, data, want) in tests {
            let (fir, _) = try FullIntraRequest.unmarshal(data)
            let h = fir.header()

            XCTAssertEqual(
                h, want,
                "Unmarshal header \(name)"
            )
        }
    }
}
