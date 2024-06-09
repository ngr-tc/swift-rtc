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

@testable import RTP

final class PacketTests: XCTestCase {
    func testBasic() throws {
        var emptyBytes = ByteBuffer()
        let result = try? Packet(&emptyBytes)
        XCTAssertTrue(
            result == nil,
            "Unmarshal did not error on zero length packet"
        )

        let rawPkt = ByteBuffer(bytes: [
            0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0x00, 0x01,
            0x00,
            0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0x98, 0x36, 0xbe, 0x88, 0x9e,
        ])
        let parsedPacket = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 1,
                extensions: [
                    Extension(
                        id: 0,
                        payload: ByteBuffer(bytes: [0xFF, 0xFF, 0xFF, 0xFF])
                    )
                ]
            ),
            payload: ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])
        )

        var buf = rawPkt.slice()
        let packet = try Packet(&buf)

        XCTAssertEqual(
            packet, parsedPacket,
            "TestBasic unmarshal: got {packet}, want {parsed_packet}"
        )
        XCTAssertEqual(
            packet.header.marshalSize(),
            20,
            "wrong computed header marshal size"
        )
        XCTAssertEqual(
            packet.marshalSize(),
            rawPkt.readableBytes,
            "wrong computed marshal size"
        )

        let raw = try packet.marshal()
        let n = raw.readableBytes
        XCTAssertEqual(n, rawPkt.readableBytes, "wrong marshal size")

        XCTAssertEqual(raw, rawPkt)
    }

    func testExtension() throws {
        let missingExtensionPkt = ByteBuffer(bytes: [
            0x90, 0x60, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82,
        ])
        var buf = missingExtensionPkt.slice()
        var result = try? Packet(&buf)
        XCTAssertTrue(
            result == nil,
            "Unmarshal did not error on packet with missing extension data"
        )

        let invalidExtensionLengthPkt = ByteBuffer(bytes: [
            0x90, 0x60, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0x99, 0x99,
            0x99,
            0x99,
        ])
        buf = invalidExtensionLengthPkt.slice()
        result = try? Packet(&buf)
        XCTAssertTrue(
            result == nil,
            "Unmarshal did not error on packet with invalid extension length"
        )

        let packet = Packet(
            header: Header(
                version: 0,
                padding: false,
                ext: true,
                marker: false,
                payloadType: 0,
                sequenceNumber: 0,
                timestamp: 0,
                ssrc: 0,
                csrcs: [],
                extensionProfile: 3,
                extensions: [
                    Extension(
                        id: 0,
                        payload: ByteBuffer(bytes: [0])
                    )
                ]
            ),
            payload: ByteBuffer()
        )

        do {
            var raw = ByteBuffer()
            let _ = try packet.marshalTo(&raw)
            XCTAssertTrue(
                false,
                "should error"
            )
        } catch RtpError.errHeaderExtensionPayloadNot32BitWords {
            XCTAssertTrue(
                true
            )
        } catch {
            XCTAssertTrue(
                false,
                "should be errHeaderExtensionPayloadNot32BitWords"
            )
        }
    }

    func testPadding() throws {
        let rawPkt = ByteBuffer(bytes: [
            0xa0, 0x60, 0x19, 0x58, 0x63, 0xff, 0x7d, 0x7c, 0x4b, 0x98, 0xd4, 0x0a, 0x67, 0x4d,
            0x00,
            0x29, 0x9a, 0x64, 0x03, 0xc0, 0x11, 0x3f, 0x2c, 0xd4, 0x04, 0x04, 0x05, 0x00, 0x00,
            0x03,
            0x03, 0xe8, 0x00, 0x00, 0xea, 0x60, 0x04, 0x00, 0x00, 0x03,
        ])
        var buf = rawPkt.slice()
        let packet = try Packet(&buf)
        XCTAssertEqual(packet.payload, rawPkt.getSlice(at: 12, length: 25)!)

        let raw = try packet.marshal()
        XCTAssertEqual(raw, rawPkt)
    }

    func testPacketMarshalUnmarshal() throws {
        let pkt = Packet(
            header: Header(
                version: 0,
                padding: false,
                ext: true,
                marker: false,
                payloadType: 0,
                sequenceNumber: 0,
                timestamp: 0,
                ssrc: 0,
                csrcs: [1, 2],
                extensionProfile: extensionProfileTwoByte,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [3, 4])
                    ),
                    Extension(
                        id: 2,
                        payload: ByteBuffer(bytes: [5, 6])
                    ),
                ]),
            payload: ByteBuffer(bytes: Array(repeating: 0xFF, count: 15))
        )
        var raw = try pkt.marshal()
        let p = try Packet(&raw)

        XCTAssertEqual(pkt, p)
    }

    func testRfc8285OneByteExtension() throws {
        let rawPkt = ByteBuffer(bytes: [
            0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0xBE, 0xDE,
            0x00,
            0x01, 0x50, 0xAA, 0x00, 0x00, 0x98, 0x36, 0xbe, 0x88, 0x9e,
        ])
        var buf = rawPkt.slice()
        let _ = try Packet(&buf)

        let p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0xBEDE,
                extensions: [
                    Extension(
                        id: 5,
                        payload: ByteBuffer(bytes: [0xAA])
                    )
                ]
            ),
            payload: rawPkt.getSlice(at: 20, length: rawPkt.readableBytes - 20)!
        )

        let dst = try p.marshal()
        XCTAssertEqual(dst, rawPkt)
    }

    func testRfc8285OneByteTwoExtensionOfTwoBytes() throws {
        //  0                   1                   2                   3
        //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |       0xBE    |    0xDE       |           length=1            |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |  ID   | L=0   |     data      |  ID   |  L=0  |   data...
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        let rawPkt = ByteBuffer(bytes: [
            0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0xBE, 0xDE,
            0x00,
            0x01, 0x10, 0xAA, 0x20, 0xBB,  // Payload
            0x98, 0x36, 0xbe, 0x88, 0x9e,
        ])
        var buf = rawPkt.slice()
        var p = try Packet(&buf)

        let ext1 = p.header.getExtension(id: 1)
        let ext1Expect = ByteBuffer(bytes: [0xAA])
        if let ext1 = ext1 {
            XCTAssertEqual(ext1, ext1Expect)
        } else {
            XCTFail("ext1 is none")
        }

        let ext2 = p.header.getExtension(id: 2)
        let ext2Expect = ByteBuffer(bytes: [0xBB])
        if let ext2 = ext2 {
            XCTAssertEqual(ext2, ext2Expect)
        } else {
            XCTFail("ext2 is none")
        }

        // Test Marshal
        p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0xBEDE,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0xAA])
                    ),
                    Extension(
                        id: 2,
                        payload: ByteBuffer(bytes: [0xBB])
                    ),
                ]
            ),
            payload: rawPkt.getSlice(at: 20, length: rawPkt.readableBytes - 20)!
        )

        let dst = try p.marshal()
        XCTAssertEqual(dst, rawPkt)
    }

    func testRfc8285OneByteMultipleExtensionsWithPadding() throws {
        //  0                   1                   2                   3
        //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |       0xBE    |    0xDE       |           length=3            |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |  ID   | L=0   |     data      |  ID   |  L=1  |   data...
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        //       ...data   |    0 (pad)    |    0 (pad)    |  ID   | L=3   |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |                          data                                 |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

        let rawPkt = ByteBuffer(bytes: [
            0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0xBE, 0xDE,
            0x00,
            0x03, 0x10, 0xAA, 0x21, 0xBB, 0xBB, 0x00, 0x00, 0x33, 0xCC, 0xCC, 0xCC, 0xCC,
            // Payload
            0x98, 0x36, 0xbe, 0x88, 0x9e,
        ])
        var buf = rawPkt.slice()
        var packet = try Packet(&buf)
        let ext1 = packet
            .header
            .getExtension(id: 1)!

        let ext1Expect = ByteBuffer(bytes: [0xAA])
        XCTAssertEqual(ext1, ext1Expect)

        let ext2 = packet
            .header
            .getExtension(id: 2)!

        let ext2Expect = ByteBuffer(bytes: [0xBB, 0xBB])
        XCTAssertEqual(ext2, ext2Expect)

        let ext3 = packet
            .header
            .getExtension(id: 3)!

        let ext3Expect = ByteBuffer(bytes: [0xCC, 0xCC, 0xCC, 0xCC])
        XCTAssertEqual(ext3, ext3Expect)

        var dstBuf: [ByteBuffer] = [
            ByteBuffer(), ByteBuffer(),
            ByteBuffer(),
        ]

        let rawPkgMarshal = ByteBuffer(bytes: [
            // padding is moved to the end by re-marshaling
            0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0xBE, 0xDE,
            0x00,
            0x03, 0x10, 0xAA, 0x21, 0xBB, 0xBB, 0x33, 0xCC, 0xCC, 0xCC, 0xCC, 0x00, 0x00,
            // Payload
            0x98, 0x36, 0xbe, 0x88, 0x9e,
        ])

        let checker = { (name: String, buf: inout ByteBuffer, p: inout Packet) throws in
            let size = try p.marshalTo(&buf)
            XCTAssertEqual(size, rawPkgMarshal.readableBytes)
            XCTAssertEqual(
                buf,
                rawPkgMarshal,
                "Marshalled fields are not equal for {name}."
            )
        }

        try checker("CleanBuffer", &dstBuf[0], &packet)
        try checker("DirtyBuffer", &dstBuf[1], &packet)
        try checker("SmallBuffer", &dstBuf[2], &packet)
    }

    func testRfc8285OneByteMultipleExtension() throws {
        //  0                   1                   2                   3
        //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |       0xBE    |    0xDE       |           length=3            |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |  ID=1 | L=0   |     data      |  ID=2 |  L=1  |   data...
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        //       ...data   |  ID=3 | L=3   |           data...
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        //             ...data             |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        let rawPkt = ByteBuffer(bytes: [
            0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0xBE, 0xDE,
            0x00,
            0x03, 0x10, 0xAA, 0x21, 0xBB, 0xBB, 0x33, 0xCC, 0xCC, 0xCC, 0xCC, 0x00, 0x00,
            // Payload
            0x98, 0x36, 0xbe, 0x88, 0x9e,
        ])

        let p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0xBEDE,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0xAA])
                    ),
                    Extension(
                        id: 2,
                        payload: ByteBuffer(bytes: [0xBB, 0xBB])
                    ),
                    Extension(
                        id: 3,
                        payload: ByteBuffer(bytes: [0xCC, 0xCC, 0xCC, 0xCC])
                    ),
                ]
            ),
            payload: rawPkt.getSlice(at: 28, length: rawPkt.readableBytes - 28)!
        )

        let dstData = try p.marshal()
        XCTAssertEqual(dstData, rawPkt)
    }

    func testRfc8285TwoByteExtension() throws {
        let rawPkt = ByteBuffer(bytes: [
            0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0x10, 0x00,
            0x00,
            0x07, 0x05, 0x18, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
            0xAA,
            0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0x00, 0x00,
            0x98,
            0x36, 0xbe, 0x88, 0x9e,
        ])
        var buf = rawPkt.slice()
        let _ = try Packet(&buf)

        let p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0x1000,
                extensions: [
                    Extension(
                        id: 5,
                        payload: ByteBuffer(bytes: [
                            0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
                            0xAA,
                            0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
                        ])
                    )
                ]
            ),
            payload: rawPkt.getSlice(at: 44, length: rawPkt.readableBytes - 44)!
        )

        let dstData = try p.marshal()
        XCTAssertEqual(dstData, rawPkt)
    }

    func testRfc8285WwoByteMultipleExtensionWithPadding() throws {
        // 0                   1                   2                   3
        // 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |       0x10    |    0x00       |           length=3            |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |      ID=1     |     L=0       |     ID=2      |     L=1       |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |       data    |    0 (pad)    |       ID=3    |      L=4      |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |                          data                                 |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

        let rawPkt = ByteBuffer(bytes: [
            0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0x10, 0x00,
            0x00,
            0x03, 0x01, 0x00, 0x02, 0x01, 0xBB, 0x00, 0x03, 0x04, 0xCC, 0xCC, 0xCC, 0xCC, 0x98,
            0x36,
            0xbe, 0x88, 0x9e,
        ])
        var buf = rawPkt.slice()
        let p = try Packet(&buf)

        var ext = p.header.getExtension(id: 1)!
        var extExpect = ByteBuffer(bytes: [])
        XCTAssertEqual(ext, extExpect)

        ext = p.header.getExtension(id: 2)!
        extExpect = ByteBuffer(bytes: [0xBB])
        XCTAssertEqual(ext, extExpect)

        ext = p.header.getExtension(id: 3)!
        extExpect = ByteBuffer(bytes: [0xCC, 0xCC, 0xCC, 0xCC])
        XCTAssertEqual(ext, extExpect)
    }

    func testRfc8285TwoByteMultipleExtensionWithLargeExtension() throws {
        // 0                   1                   2                   3
        // 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |       0x10    |    0x00       |           length=3            |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |      ID=1     |     L=0       |     ID=2      |     L=1       |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        // |       data    |       ID=3    |      L=17      |    data...
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        //                            ...data...
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        //                            ...data...
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        //                            ...data...
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        //                            ...data...                           |
        // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

        let rawPkt = ByteBuffer(bytes: [
            0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0x10, 0x00,
            0x00,
            0x06, 0x01, 0x00, 0x02, 0x01, 0xBB, 0x03, 0x11, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC,
            0xCC,
            0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC,  // Payload
            0x98, 0x36, 0xbe, 0x88, 0x9e,
        ])

        let p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0x1000,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [])
                    ),
                    Extension(
                        id: 2,
                        payload: ByteBuffer(bytes: [0xBB])
                    ),
                    Extension(
                        id: 3,
                        payload: ByteBuffer(bytes: [
                            0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC,
                            0xCC, 0xCC, 0xCC, 0xCC, 0xCC,
                        ])
                    ),
                ]
            ),
            payload: rawPkt.getSlice(at: 40, length: rawPkt.readableBytes - 40)!
        )

        let dstData = try p.marshal()
        XCTAssertEqual(dstData, rawPkt)
    }

    func testRfc8285GetExtensionReturnsNilWhenExtensionDisabled() throws {
        let payload = ByteBuffer(bytes: [
            // Payload
            0x98, 0x36, 0xbe, 0x88, 0x9e,
        ])

        let p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: false,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0,
                extensions: []
            ),
            payload: payload
        )

        let res = p.header.getExtension(id: 1)
        XCTAssertTrue(
            res == nil,
            "Should return none on get_extension when header extension is false"
        )
    }

    func testRfc8285DelExtension() throws {
        let payload = ByteBuffer(bytes: [
            // Payload
            0x98, 0x36, 0xbe, 0x88, 0x9e,
        ])
        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0xBEDE,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0xAA])
                    )
                ]
            ),
            payload: payload
        )

        var ext = p.header.getExtension(id: 1)
        XCTAssertTrue(ext != nil, "Extension should exist")

        try p.header.delExtension(id: 1)

        ext = p.header.getExtension(id: 1)
        XCTAssertTrue(ext == nil, "Extension should not exist")

        do {
            try p.header.delExtension(id: 1)
            XCTAssertTrue(false, "should error")
        } catch RtpError.errHeaderExtensionNotFound {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should be errHeaderExtensionNotFound")
        }
    }

    func testRfc8285GetExtensionIds() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        let p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0xBEDE,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0xAA])
                    ),
                    Extension(
                        id: 2,
                        payload: ByteBuffer(bytes: [0xBB])
                    ),
                ]
            ),
            payload: payload
        )

        let ids = p.header.getExtensionIds()
        XCTAssertTrue(!ids.isEmpty, "Extenstions should exist")

        XCTAssertEqual(
            ids.count,
            p.header.extensions.count
        )

        for id in ids {
            let ext = p.header.getExtension(id: id)
            XCTAssertTrue(ext != nil, "Extension should exist for id: {id}")
        }
    }

    func testRfc8285GetExtensionIdsReturnEmptyWhenExtensionDisabled() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        let p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: false,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0,
                extensions: []
            ),
            payload: payload
        )

        let ids = p.header.getExtensionIds()
        XCTAssertTrue(ids.isEmpty, "Extenstions should not exist")
    }

    func testRfc8285DelExtensionReturnsErrorWhenExtenstionsDisabled() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: false,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0,
                extensions: []
            ),
            payload: payload
        )

        do {
            let _ = try p.header.delExtension(id: 1)
            XCTAssertTrue(
                false,
                "Should return error on del_extension when header extension field is false"
            )
        } catch RtpError.errHeaderExtensionsNotEnabled {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(
                false,
                "Should return errHeaderExtensionsNotEnabled"
            )
        }
    }

    func testRfc8285OneByteSetExtensionShouldEnableExtensionWhenAdding() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: false,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0,
                extensions: []
            ),
            payload: payload
        )

        let ext = ByteBuffer(bytes: [0xAA, 0xAA])
        try p.header.setExtension(id: 1, payload: ext)

        XCTAssertTrue(p.header.ext, "Extension should be set to true")
        XCTAssertEqual(
            p.header.extensionProfile, 0xBEDE,
            "Extension profile should be set to 0xBEDE"
        )
        XCTAssertEqual(
            p.header.extensions.count,
            1,
            "Extensions len should be set to 1"
        )
        XCTAssertEqual(
            p.header.getExtension(id: 1)!,
            ext,
            "Extension value is not set"
        )
    }

    func testRfc8285SetExtensionShouldSetCorrectExtensionProfileFor16ByteExtension() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: false,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0,
                extensions: []
            ),
            payload: payload
        )

        let ext = ByteBuffer(bytes: [
            0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
            0xAA,
            0xAA,
        ])

        try p.header.setExtension(id: 1, payload: ext)
        XCTAssertEqual(
            p.header.extensionProfile, 0xBEDE,
            "Extension profile should be 0xBEDE"
        )
    }

    func testRfc8285SetExtensionShouldUpdateExistingExtension() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0xBEDE,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0xAA])
                    )
                ]
            ),
            payload: payload
        )

        XCTAssertEqual(
            p.header.getExtension(id: 1)!,
            ByteBuffer(bytes: [0xAA]),
            "Extension value not initialized properly"
        )

        let ext = ByteBuffer(bytes: [0xBB])
        try p.header.setExtension(id: 1, payload: ext)

        XCTAssertEqual(
            p.header.getExtension(id: 1)!,
            ext,
            "Extension value was not set"
        )
    }

    func testRfc8285OneByteSetExtensionShouldErrorWhenInvalidIdProvided() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0xBEDE,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0xAA])
                    )
                ]
            ),
            payload: payload
        )

        do {
            try p.header
                .setExtension(id: 0, payload: ByteBuffer(bytes: [0xBB]))
            XCTAssertTrue(false, "should err")
        } catch RtpError.errRfc8285oneByteHeaderIdrange {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errRfc8285oneByteHeaderIdrange")
        }
        do {
            try p.header
                .setExtension(id: 15, payload: ByteBuffer(bytes: [0xBB]))
            XCTAssertTrue(false, "should err")
        } catch RtpError.errRfc8285oneByteHeaderIdrange {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errRfc8285oneByteHeaderIdrange")
        }
    }

    func testRfc8285OneByteExtensionTerminateProcessingWhenReservedIdEncountered() throws {
        let reservedIdPkt = ByteBuffer(bytes: [
            0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda, 0x1c, 0x64, 0x27, 0x82, 0xBE, 0xDE,
            0x00,
            0x01, 0xF0, 0xAA, 0x98, 0x36, 0xbe, 0x88, 0x9e,
        ])

        var buf = reservedIdPkt.slice()
        let p = try Packet(&buf)

        XCTAssertEqual(
            p.header.extensions.count,
            0,
            "Extension should be empty for invalid ID"
        )

        let payload = reservedIdPkt.getSlice(at: 17, length: reservedIdPkt.readableBytes - 17)!
        XCTAssertEqual(p.payload, payload, "p.payload must be same as payload")
    }

    func testRfc8285OneByteSetExtensionShouldErrorWhenPayloadTooLarge() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0xBEDE,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0xAA])
                    )
                ]
            ),
            payload: payload
        )

        do {
            try p.header.setExtension(
                id:
                    1,
                payload: ByteBuffer(bytes: [
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB,
                ])
            )
            XCTAssertTrue(false, "should err")
        } catch RtpError.errRfc8285oneByteHeaderSize {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errRfc8285oneByteHeaderSize")
        }
    }

    func testRfc8285TwoBytesSetExtensionShouldEnableExtensionWhenAdding() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: false,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0xBEDE,
                extensions: []
            ),
            payload: payload
        )

        let ext = ByteBuffer(bytes: [
            0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
            0xAA,
            0xAA, 0xAA,
        ])

        try p.header.setExtension(id: 1, payload: ext)

        XCTAssertTrue(p.header.ext, "Extension should be set to true")
        XCTAssertEqual(
            p.header.extensionProfile, 0x1000,
            "Extension profile should be set to 0xBEDE"
        )
        XCTAssertEqual(
            p.header.extensions.count,
            1,
            "Extensions should be set to 1"
        )
        XCTAssertEqual(
            p.header.getExtension(id: 1)!,
            ext,
            "Extension value is not set"
        )
    }

    func testRfc8285TwoByteSetExtensionShouldUpdateExistingExtension() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0x1000,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0xAA])
                    )
                ]
            ),
            payload: payload
        )

        XCTAssertEqual(
            p.header.getExtension(id: 1)!,
            ByteBuffer(bytes: [0xAA]),
            "Extension value not initialized properly"
        )

        let ext = ByteBuffer(bytes: [
            0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
            0xBB,
            0xBB, 0xBB,
        ])

        try p.header.setExtension(id: 1, payload: ext)

        XCTAssertEqual(p.header.getExtension(id: 1)!, ext)

    }

    func testRfc8285TwoByteSetExtensionShouldErrorWhenPayloadTooLarge() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0x1000,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0xAA])
                    )
                ]
            ),
            payload: payload
        )

        do {
            try p.header.setExtension(
                id:
                    1,
                payload: ByteBuffer(bytes: [
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
                    0xBB,
                    0xBB, 0xBB, 0xBB, 0xBB,
                ])
            )
            XCTAssertTrue(false, "should err")
        } catch RtpError.errRfc8285twoByteHeaderSize {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errRfc8285twoByteHeaderSize")
        }
    }

    func testRfc3550SetExtensionShouldErrorWhenNonZero() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0x1111,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0xAA])
                    )
                ]
            ),
            payload: payload
        )

        try p.header.setExtension(id: 0, payload: ByteBuffer(bytes: [0xBB]))
        let res = p.header.getExtension(id: 0)!
        XCTAssertEqual(
            res,
            ByteBuffer(bytes: [0xBB]),
            "p.get_extenstion returned incorrect value"
        )
    }

    func testRfc3550SetExtensionShouldErrorWhenSettingNonZeroId() throws {
        let payload = ByteBuffer(bytes: [0x98, 0x36, 0xbe, 0x88, 0x9e])

        var p = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 96,
                sequenceNumber: 27023,
                timestamp: 3_653_407_706,
                ssrc: 476_325_762,
                csrcs: [],
                extensionProfile: 0x1111,
                extensions: []
            ),
            payload: payload
        )

        do {
            try p.header.setExtension(id: 1, payload: ByteBuffer(bytes: [0xBB]))
            XCTAssertTrue(false, "should err")
        } catch RtpError.errRfc3550headerIdrange {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errRfc3550headerIdrange")
        }
    }

    func testUnmarshalErrorHandling() {
        let cases = [
            (
                "ShortHeader",
                ByteBuffer(bytes: [
                    0x80, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda,  // timestamp
                    0x1c, 0x64, 0x27,  // SSRC (one byte missing)
                ]),
                RtpError.errHeaderSizeInsufficient

            ),
            (
                "MissingCSRC",
                ByteBuffer(bytes: [
                    0x81, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda,  // timestamp
                    0x1c, 0x64, 0x27, 0x82,  // SSRC
                ]),
                RtpError.errHeaderSizeInsufficient

            ),
            (
                "MissingExtension",
                ByteBuffer(bytes: [
                    0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda,  // timestamp
                    0x1c, 0x64, 0x27, 0x82,  // SSRC
                ]),
                RtpError.errHeaderSizeInsufficientForExtension

            ),

            (
                "MissingExtensionData",
                ByteBuffer(bytes: [
                    0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda,  // timestamp
                    0x1c, 0x64, 0x27, 0x82,  // SSRC
                    0xBE, 0xDE, 0x00, 0x03,  // specified to have 3 extensions, but actually not
                ]),
                RtpError.errHeaderSizeInsufficientForExtension

            ),
            (
                "MissingExtensionDataPayload",
                ByteBuffer(bytes: [
                    0x90, 0xe0, 0x69, 0x8f, 0xd9, 0xc2, 0x93, 0xda,  // timestamp
                    0x1c, 0x64, 0x27, 0x82,  // SSRC
                    0xBE, 0xDE, 0x00, 0x01,  // have 1 extension
                    0x12,
                    0x00,  // length of the payload is expected to be 3, but actually have only 1
                ]),
                RtpError.errHeaderSizeInsufficientForExtension

            ),
        ]

        for (_, var input, errExpected) in cases {
            do {
                let _ = try Header(&input)
                XCTAssertTrue(false, "should err")
            } catch let err {
                if let rtpErr = err as? RtpError {
                    XCTAssertEqual(rtpErr, errExpected)
                } else {
                    XCTAssertTrue(false, "should err")
                }
            }
        }
    }

    func testRoundTrip() throws {
        let rawPkt = ByteBuffer(bytes: [
            0x00, 0x10, 0x23, 0x45, 0x12, 0x34, 0x45, 0x67, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11,
            0x22,
            0x33, 0x44, 0x55, 0x66, 0x77,
        ])

        let payload = rawPkt.getSlice(at: 12, length: rawPkt.readableBytes - 12)

        var buf = rawPkt.slice()
        let p = try Packet(&buf)

        XCTAssertEqual(payload, p.payload)

        buf = try p.marshal()

        XCTAssertEqual(rawPkt, buf)
        XCTAssertEqual(payload, p.payload)
    }
}
