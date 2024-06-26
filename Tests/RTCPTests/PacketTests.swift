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

final class PacketTests: XCTestCase {
    func testPacketUnmarshal() throws {
        let data = ByteBuffer(bytes: [
            // Receiver Report (offset=0)
            0x81, 0xc9, 0x0, 0x7,  // v=2, p=0, count=1, RR, len=7
            0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
            0xbc, 0x5e, 0x9a, 0x40,  // ssrc=0xbc5e9a40
            0x0, 0x0, 0x0, 0x0,  // fracLost=0, totalLost=0
            0x0, 0x0, 0x46, 0xe1,  // lastSeq=0x46e1
            0x0, 0x0, 0x1, 0x11,  // jitter=273
            0x9, 0xf3, 0x64, 0x32,  // lsr=0x9f36432
            0x0, 0x2, 0x4a, 0x79,  // delay=150137
            // Source Description (offset=32)
            0x81, 0xca, 0x0, 0xc,  // v=2, p=0, count=1, SDES, len=12
            0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0x902f9e2e
            0x1, 0x26,  // CNAME, len=38
            0x7b, 0x39, 0x63, 0x30, 0x30, 0x65, 0x62, 0x39, 0x32, 0x2d, 0x31, 0x61, 0x66, 0x62,
            0x2d, 0x39, 0x64, 0x34, 0x39, 0x2d, 0x61, 0x34, 0x37, 0x64, 0x2d, 0x39, 0x31, 0x66,
            0x36, 0x34, 0x65, 0x65, 0x65, 0x36, 0x39, 0x66, 0x35,
            0x7d,  // text="{9c00eb92-1afb-9d49-a47d-91f64eee69f5}"
            0x0, 0x0, 0x0, 0x0,  // END + padding
            // Goodbye (offset=84)
            0x81, 0xcb, 0x0, 0x1,  // v=2, p=0, count=1, BYE, len=1
            0x90, 0x2f, 0x9e, 0x2e,  // source=0x902f9e2e
            0x81, 0xce, 0x0, 0x2,  // Picture Loss Indication (offset=92)
            0x90, 0x2f, 0x9e, 0x2e,  // sender=0x902f9e2e
            0x90, 0x2f, 0x9e, 0x2e,  // media=0x902f9e2e
            0x85, 0xcd, 0x0, 0x2,  // RapidResynchronizationRequest (offset=104)
            0x90, 0x2f, 0x9e, 0x2e,  // sender=0x902f9e2e
            0x90, 0x2f, 0x9e, 0x2e,  // media=0x902f9e2e
        ])

        let packet = try unmarshal(data)

        let a = ReceiverReport(
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
        )

        let b = SourceDescription(
            chunks: [
                SourceDescriptionChunk(
                    source: 0x902f_9e2e,
                    items: [
                        SourceDescriptionItem(
                            sdesType: SdesType.sdesCname,
                            text: ByteBuffer(string: "{9c00eb92-1afb-9d49-a47d-91f64eee69f5}")
                        )
                    ]
                )
            ]
        )

        let c = Goodbye(
            sources: [0x902f_9e2e]
        )

        let d = PictureLossIndication(
            senderSsrc: 0x902f_9e2e,
            mediaSsrc: 0x902f_9e2e
        )

        let e = RapidResynchronizationRequest(
            senderSsrc: 0x902f_9e2e,
            mediaSsrc: 0x902f_9e2e
        )

        let expected: [Packet] = [
            a,
            b,
            c,
            d,
            e,
        ]

        XCTAssertEqual(expected.count, packet.count, "Invalid packets")
        for i in 0..<expected.count {
            XCTAssertTrue(expected[i].equal(other: packet[i]), "Invalid packets")
        }
    }

    func testPacketUnmarshalEmpty() throws {
        do {
            let _ = try unmarshal(ByteBuffer())
            XCTFail("should error")
        } catch let got as RtcpError {
            let want = RtcpError.errInvalidHeader
            XCTAssertEqual(got, want)
        } catch {
            XCTFail("should errInvalidHeader")
        }
    }

    func testPacketInvalidHeaderLength() throws {
        let data = ByteBuffer(bytes: [
            // Goodbye (offset=84)
            // v=2, p=0, count=1, BYE, len=100
            0x81, 0xcb, 0x0, 0x64,
        ])

        do {
            let _ = try unmarshal(data)
            XCTFail("should error")
        } catch let got as RtcpError {
            let want = RtcpError.errPacketTooShort
            XCTAssertEqual(got, want)
        } catch {
            XCTFail("should errInvalidHeader")
        }
    }

    func testPacketUnmarshalFirefox() throws {
        // issue report from https://github.com/webrtc-rs/srtp/issues/7
        let tests = [
            ByteBuffer(bytes: [
                143, 205, 0, 6, 65, 227, 184, 49, 118, 243, 78, 96, 42, 63, 0, 5, 12, 162, 166, 0,
                32, 5, 200, 4, 0, 4, 0, 0,
            ]),
            ByteBuffer(bytes: [
                143, 205, 0, 9, 65, 227, 184, 49, 118, 243, 78, 96, 42, 68, 0, 17, 12, 162, 167, 1,
                32, 17, 88, 0, 4, 0, 4, 8, 108, 0, 4, 0, 4, 12, 0, 4, 0, 4, 4, 0,
            ]),
            ByteBuffer(bytes: [
                143, 205, 0, 8, 65, 227, 184, 49, 118, 243, 78, 96, 42, 91, 0, 12, 12, 162, 168, 3,
                32, 12, 220, 4, 0, 4, 0, 8, 128, 4, 0, 4, 0, 8, 0, 0,
            ]),
            ByteBuffer(bytes: [
                143, 205, 0, 7, 65, 227, 184, 49, 118, 243, 78, 96, 42, 103, 0, 8, 12, 162, 169, 4,
                32, 8, 232, 4, 0, 4, 0, 4, 4, 0, 0, 0,
            ]),
        ]

        for test in tests {
            let _ = try unmarshal(test)
        }
    }

}
