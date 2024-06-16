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

final class CompoundPacketTests: XCTestCase {
    // An RTCP packet from a packet dump
    let realPacket: ByteBuffer = ByteBuffer(bytes: [
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
        0x7b, 0x39, 0x63, 0x30, 0x30, 0x65, 0x62, 0x39, 0x32, 0x2d, 0x31, 0x61, 0x66, 0x62, 0x2d,
        0x39,
        0x64, 0x34, 0x39, 0x2d, 0x61, 0x34, 0x37, 0x64, 0x2d, 0x39, 0x31, 0x66, 0x36, 0x34, 0x65,
        0x65,
        0x65, 0x36, 0x39, 0x66, 0x35, 0x7d,  // text="{9c00eb92-1afb-9d49-a47d-91f64eee69f5}"
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

    func testReadEof() throws {
        let shortHeader = ByteBuffer(bytes: [
            0x81, 0xc9,  // missing type & len
        ])
        let result = try? unmarshal(shortHeader)
        XCTAssertTrue(result == nil, "missing type & len")
    }

    func testBadCompound() throws {
        var badCompound = realPacket.getSlice(at: 0, length: 34)!
        let result = try? unmarshal(badCompound)
        XCTAssertTrue(result == nil, "trailing data!")

        badCompound = realPacket.getSlice(at: 84, length: 104 - 84)!
        let p = try unmarshal(badCompound)
        let compound = CompoundPacket(packets: p)

        // this should return an error,
        // it violates the "must start with RR or SR" rule
        do {
            try compound.validate()
            XCTFail("validation should return an error")
        } catch let err as RtcpError {
            XCTAssertEqual(RtcpError.errBadFirstPacket, err)
        } catch {
            XCTFail("validation should return an errBadFirstPacket")
        }

        let compoundLen = compound.packets.count
        XCTAssertEqual(2, compoundLen)

        if !(compound.packets[0] is Goodbye) {
            XCTFail("Unmarshal(badcompound), want Goodbye")
        }

        if !(compound.packets[1] is PictureLossIndication) {
            XCTFail("Unmarshal(badcompound), want PictureLossIndication")
        }
    }

    func testValidPacket() throws {
        let cname = SourceDescription(
            chunks: [
                SourceDescriptionChunk(
                    source: 1234,
                    items: [
                        SourceDescriptionItem(
                            sdesType: SdesType.sdesCname,
                            text: ByteBuffer(string: "cname")
                        )
                    ]
                )
            ]
        )

        let tests: [(String, CompoundPacket, RtcpError?)] = [
            (
                "no cname",
                CompoundPacket(packets: [SenderReport()]),
                RtcpError.errMissingCname
            ),
            (
                "SDES / no cname",
                CompoundPacket(packets: [
                    SenderReport(),
                    SourceDescription(),
                ]),
                RtcpError.errMissingCname
            ),
            (
                "just SR",
                CompoundPacket(packets: [
                    SenderReport(),
                    cname,
                ]),
                nil
            ),
            (
                "multiple SRs",
                CompoundPacket(packets: [
                    SenderReport(),
                    SenderReport(),
                    cname,
                ]),
                RtcpError.errPacketBeforeCname
            ),
            (
                "just RR",
                CompoundPacket(packets: [
                    ReceiverReport(),
                    cname,
                ]),
                nil
            ),
            (
                "multiple RRs",
                CompoundPacket(packets: [
                    ReceiverReport(),
                    cname,
                    ReceiverReport(),
                ]),
                nil
            ),
            (
                "goodbye",
                CompoundPacket(packets: [
                    ReceiverReport(),
                    cname,
                    Goodbye(),
                ]),
                nil
            ),
        ]

        for (name, packet, error) in tests {
            if let expected = error {
                do {
                    try packet.validate()
                    XCTFail("should error")
                } catch let actual as RtcpError {
                    XCTAssertEqual(expected, actual, "\(name)")
                } catch {
                    XCTFail("should RtcpError")
                }
            } else {
                try packet.validate()
            }
        }
    }

    func testCname() throws {
        let cname = SourceDescription(
            chunks: [
                SourceDescriptionChunk(
                    source: 1234,
                    items: [
                        SourceDescriptionItem(
                            sdesType: SdesType.sdesCname,
                            text: ByteBuffer(string: "cname")
                        )
                    ]
                )
            ]
        )

        let tests: [(String, CompoundPacket, RtcpError?, String)] = [
            (
                "no cname",
                CompoundPacket(packets: [SenderReport()]),
                RtcpError.errMissingCname,
                ""
            ),
            (
                "SDES / no cname",
                CompoundPacket(packets: [
                    SenderReport(),
                    SourceDescription(),
                ]),
                RtcpError.errMissingCname,
                ""
            ),
            (
                "just SR",
                CompoundPacket(packets: [
                    SenderReport(),
                    cname,
                ]),
                nil,
                "cname"
            ),
            (
                "multiple SRs",
                CompoundPacket(packets: [
                    SenderReport(),
                    SenderReport(),
                    cname,
                ]),
                RtcpError.errPacketBeforeCname,
                ""
            ),
            (
                "just RR",
                CompoundPacket(packets: [
                    ReceiverReport(),
                    cname,
                ]),
                nil,
                "cname"
            ),
            (
                "multiple RRs",
                CompoundPacket(packets: [
                    ReceiverReport(),
                    ReceiverReport(),
                    cname,
                ]),
                nil,
                "cname"
            ),
            (
                "goodbye",
                CompoundPacket(packets: [
                    ReceiverReport(),
                    cname,
                    Goodbye(),
                ]),
                nil,
                "cname"
            ),
        ]

        for (name, compoundPacket, wantError, text) in tests {
            if let expected = wantError {
                do {
                    try compoundPacket.validate()
                    XCTFail("should error")
                } catch let actual as RtcpError {
                    XCTAssertEqual(expected, actual, "\(name)")
                } catch {
                    XCTFail("should RtcpError")
                }

                do {
                    let _ = try compoundPacket.cname()
                    XCTFail("should error")
                } catch let actual as RtcpError {
                    XCTAssertEqual(expected, actual, "\(name)")
                } catch {
                    XCTFail("should RtcpError")
                }
            } else {
                try compoundPacket.validate()

                let cname = try compoundPacket.cname()
                XCTAssertEqual(ByteBuffer(string: text), cname, "\(name)")
            }
        }
    }

    func testCompoundPacketRoundtrip() throws {
        let cname = SourceDescription(
            chunks: [
                SourceDescriptionChunk(
                    source: 1234,
                    items: [
                        SourceDescriptionItem(
                            sdesType: SdesType.sdesCname,
                            text: ByteBuffer(string: "cname")
                        )
                    ]
                )
            ]
        )

        let tests = [
            (
                "goodbye",
                CompoundPacket(packets: [
                    ReceiverReport(),
                    cname,
                    Goodbye(
                        sources: [1234],
                        reason: ByteBuffer()
                    ),
                ]),
                nil
            ),
            (
                "no cname",
                CompoundPacket(packets: [ReceiverReport()]),
                RtcpError.errMissingCname
            ),
        ]

        for (name, packet, marshalError) in tests {
            if let expected = marshalError {
                do {
                    let _ = try packet.marshal()
                    XCTFail("should error")
                } catch let actual as RtcpError {
                    XCTAssertEqual(expected, actual, "\(name)")
                } catch {
                    XCTFail("should RtcpError")
                }
            } else {
                let data1 = try packet.marshal()
                let (c, _) = try CompoundPacket.unmarshal(data1)
                let data2 = try c.marshal()
                XCTAssertEqual(data1, data2, "Unmarshal(Marshal(\(name))")
            }
        }
    }
}
