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

final class VP8Tests: XCTestCase {
    func testVP8Unmarshal() throws {
        var pck = Vp8Packet()

        // Empty packet
        let emptyBytes = ByteBuffer(bytes: [])
        var result = try? pck.depacketize(buf: emptyBytes)
        XCTAssertTrue(result == nil, "Result should be err in case of error")

        // Payload smaller than header size
        var smallBytes = ByteBuffer(bytes: [0x00, 0x11, 0x22])
        result = try? pck.depacketize(buf: smallBytes)
        XCTAssertTrue(result == nil, "Result should be err in case of error")

        // Payload smaller than header size
        smallBytes = ByteBuffer(bytes: [0x00, 0x11])
        result = try? pck.depacketize(buf: smallBytes)
        XCTAssertTrue(result == nil, "Result should be err in case of error")

        // Normal packet
        var rawBytes = ByteBuffer(bytes: [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x90])
        var payload = try pck.depacketize(buf: rawBytes)
        XCTAssertTrue(payload.readableBytes != 0, "Payload must be not empty")

        // Header size, only X
        rawBytes = ByteBuffer(bytes: [0x80, 0x00, 0x00, 0x00])
        payload = try pck.depacketize(buf: rawBytes)
        XCTAssertTrue(payload.readableBytes != 0, "Payload must be not empty")
        XCTAssertEqual(pck.x, 1, "X must be 1")
        XCTAssertEqual(pck.i, 0, "I must be 0")
        XCTAssertEqual(pck.l, 0, "L must be 0")
        XCTAssertEqual(pck.t, 0, "T must be 0")
        XCTAssertEqual(pck.k, 0, "K must be 0")

        // Header size, X and I, PID 16bits
        rawBytes = ByteBuffer(bytes: [0x80, 0x80, 0x81, 0x00, 0x00])
        payload = try pck.depacketize(buf: rawBytes)
        XCTAssertTrue(payload.readableBytes != 0, "Payload must be not empty")
        XCTAssertEqual(pck.x, 1, "X must be 1")
        XCTAssertEqual(pck.i, 1, "I must be 1")
        XCTAssertEqual(pck.l, 0, "L must be 0")
        XCTAssertEqual(pck.t, 0, "T must be 0")
        XCTAssertEqual(pck.k, 0, "K must be 0")

        // Header size, X and L
        rawBytes = ByteBuffer(bytes: [0x80, 0x40, 0x00, 0x00])
        payload = try pck.depacketize(buf: rawBytes)
        XCTAssertTrue(payload.readableBytes != 0, "Payload must be not empty")
        XCTAssertEqual(pck.x, 1, "X must be 1")
        XCTAssertEqual(pck.i, 0, "I must be 0")
        XCTAssertEqual(pck.l, 1, "L must be 1")
        XCTAssertEqual(pck.t, 0, "T must be 0")
        XCTAssertEqual(pck.k, 0, "K must be 0")

        // Header size, X and T
        rawBytes = ByteBuffer(bytes: [0x80, 0x20, 0x00, 0x00])
        payload = try pck.depacketize(buf: rawBytes)
        XCTAssertTrue(payload.readableBytes != 0, "Payload must be not empty")
        XCTAssertEqual(pck.x, 1, "X must be 1")
        XCTAssertEqual(pck.i, 0, "I must be 0")
        XCTAssertEqual(pck.l, 0, "L must be 0")
        XCTAssertEqual(pck.t, 1, "T must be 1")
        XCTAssertEqual(pck.k, 0, "K must be 0")

        // Header size, X and K
        rawBytes = ByteBuffer(bytes: [0x80, 0x10, 0x00, 0x00])
        payload = try pck.depacketize(buf: rawBytes)
        XCTAssertTrue(payload.readableBytes != 0, "Payload must be not empty")
        XCTAssertEqual(pck.x, 1, "X must be 1")
        XCTAssertEqual(pck.i, 0, "I must be 0")
        XCTAssertEqual(pck.l, 0, "L must be 0")
        XCTAssertEqual(pck.t, 0, "T must be 0")
        XCTAssertEqual(pck.k, 1, "K must be 1")

        // Header size, all flags and 8bit picture_id
        rawBytes = ByteBuffer(bytes: [0xff, 0xff, 0x00, 0x00, 0x00, 0x00])
        payload = try pck.depacketize(buf: rawBytes)
        XCTAssertTrue(payload.readableBytes != 0, "Payload must be not empty")
        XCTAssertEqual(pck.x, 1, "X must be 1")
        XCTAssertEqual(pck.i, 1, "I must be 1")
        XCTAssertEqual(pck.l, 1, "L must be 1")
        XCTAssertEqual(pck.t, 1, "T must be 1")
        XCTAssertEqual(pck.k, 1, "K must be 1")

        // Header size, all flags and 16bit picture_id
        rawBytes = ByteBuffer(bytes: [0xff, 0xff, 0x80, 0x00, 0x00, 0x00, 0x00])
        payload = try pck.depacketize(buf: rawBytes)
        XCTAssertTrue(payload.readableBytes != 0, "Payload must be not empty")
        XCTAssertEqual(pck.x, 1, "X must be 1")
        XCTAssertEqual(pck.i, 1, "I must be 1")
        XCTAssertEqual(pck.l, 1, "L must be 1")
        XCTAssertEqual(pck.t, 1, "T must be 1")
        XCTAssertEqual(pck.k, 1, "K must be 1")
    }

    func test_vp8_payload() throws {
        let tests = [
            (
                "WithoutPictureID",
                Vp8Payloader(),
                2,
                [
                    ByteBuffer(bytes: [0x90, 0x90, 0x90]),
                    ByteBuffer(bytes: [0x91, 0x91]),
                ],
                [
                    [
                        ByteBuffer(bytes: [0x10, 0x90]),
                        ByteBuffer(bytes: [0x00, 0x90]),
                        ByteBuffer(bytes: [0x00, 0x90]),
                    ],
                    [
                        ByteBuffer(bytes: [0x10, 0x91]),
                        ByteBuffer(bytes: [0x00, 0x91]),
                    ],
                ]
            ),
            (
                "WithPictureID_1byte",
                Vp8Payloader(
                    enablePictureId: true,
                    pictureId: 0x20
                ),
                5,
                [
                    ByteBuffer(bytes: [0x90, 0x90, 0x90]),
                    ByteBuffer(bytes: [0x91, 0x91]),
                ],
                [
                    [
                        ByteBuffer(bytes: [0x90, 0x80, 0x20, 0x90, 0x90]),
                        ByteBuffer(bytes: [0x80, 0x80, 0x20, 0x90]),
                    ],
                    [ByteBuffer(bytes: [0x90, 0x80, 0x21, 0x91, 0x91])],
                ]
            ),
            (
                "WithPictureID_2bytes",
                Vp8Payloader(
                    enablePictureId: true,
                    pictureId: 0x120
                ),
                6,
                [
                    ByteBuffer(bytes: [0x90, 0x90, 0x90]),
                    ByteBuffer(bytes: [0x91, 0x91]),
                ],
                [
                    [
                        ByteBuffer(bytes: [0x90, 0x80, 0x81, 0x20, 0x90, 0x90]),
                        ByteBuffer(bytes: [0x80, 0x80, 0x81, 0x20, 0x90]),
                    ],
                    [ByteBuffer(bytes: [0x90, 0x80, 0x81, 0x21, 0x91, 0x91])],
                ]
            ),
        ]

        for (_, var pck, mtu, payloads, expected) in tests {
            for (i, payload) in payloads.enumerated() {
                let actual = try pck.payload(mtu: mtu, buf: payload)
                XCTAssertEqual(expected[i], actual)
            }
        }
    }

    func test_vp8_payload_eror() throws {
        var pck = Vp8Payloader()
        let empty = ByteBuffer()
        let payload = ByteBuffer(bytes: [0x90, 0x90, 0x90])

        // Positive MTU, empty payload
        var result = try pck.payload(mtu: 1, buf: empty)
        XCTAssertTrue(result.isEmpty, "Generated payload should be empty")

        // Positive MTU, small payload
        result = try pck.payload(mtu: 1, buf: payload)
        XCTAssertEqual(result.count, 0, "Generated payload should be empty")

        // Positive MTU, small payload
        result = try pck.payload(mtu: 2, buf: payload)
        XCTAssertEqual(
            result.count,
            payload.readableBytes,
            "Generated payload should be the same size as original payload size"
        )
    }

    func test_vp8_partition_head_checker_is_partition_head() throws {
        let vp8 = Vp8Packet()

        //"SmallPacket"
        var buf = ByteBuffer(bytes: [0x00])
        XCTAssertTrue(
            !vp8.isPartitionHead(payload: buf),
            "Small packet should not be the head of a new partition"
        )

        //"SFlagON",
        buf = ByteBuffer(bytes: [0x10, 0x00, 0x00, 0x00])
        XCTAssertTrue(
            vp8.isPartitionHead(payload: buf),
            "Packet with S flag should be the head of a new partition"
        )

        //"SFlagOFF"
        buf = ByteBuffer(bytes: [0x00, 0x00, 0x00, 0x00])
        XCTAssertTrue(
            !vp8.isPartitionHead(payload: buf),
            "Packet without S flag should not be the head of a new partition"
        )
    }
}
