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

final class H264Tests: XCTestCase {
    func testH264Payload() throws {
        let empty = ByteBuffer()
        let smallPayload = ByteBuffer(bytes: [0x90, 0x90, 0x90])
        let multiplePayload = ByteBuffer(bytes: [0x00, 0x00, 0x01, 0x90, 0x00, 0x00, 0x01, 0x90])
        let largePayload = ByteBuffer(bytes: [
            0x00, 0x00, 0x01, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10,
            0x11,
            0x12, 0x13, 0x14, 0x15,
        ])
        let largePayloadPacketized = [
            ByteBuffer(bytes: [0x1c, 0x80, 0x01, 0x02, 0x03]),
            ByteBuffer(bytes: [0x1c, 0x00, 0x04, 0x05, 0x06]),
            ByteBuffer(bytes: [0x1c, 0x00, 0x07, 0x08, 0x09]),
            ByteBuffer(bytes: [0x1c, 0x00, 0x10, 0x11, 0x12]),
            ByteBuffer(bytes: [0x1c, 0x40, 0x13, 0x14, 0x15]),
        ]

        var pck = H264Payloader()

        // Positive MTU, empty payload
        var result = try pck.payload(mtu: 1, buf: empty)
        XCTAssertTrue(result.isEmpty, "Generated payload should be empty")

        // 0 MTU, small payload
        result = try pck.payload(mtu: 0, buf: smallPayload)
        XCTAssertEqual(result.count, 0, "Generated payload should be empty")

        // Positive MTU, small payload
        result = try pck.payload(mtu: 1, buf: smallPayload)
        XCTAssertEqual(result.count, 0, "Generated payload should be empty")

        // Positive MTU, small payload
        result = try pck.payload(mtu: 5, buf: smallPayload)
        XCTAssertEqual(result.count, 1, "Generated payload should be the 1")
        XCTAssertEqual(
            result[0].readableBytes,
            smallPayload.readableBytes,
            "Generated payload should be the same size as original payload size"
        )

        // Multiple NALU in a single payload
        result = try pck.payload(mtu: 5, buf: multiplePayload)
        XCTAssertEqual(result.count, 2, "2 nal units should be broken out")
        for i in 0..<2 {
            XCTAssertEqual(
                result[i].readableBytes,
                1
            )
        }

        // Large Payload split across multiple RTP Packets
        result = try pck.payload(mtu: 5, buf: largePayload)
        XCTAssertEqual(
            result, largePayloadPacketized,
            "FU-A packetization failed"
        )

        // Nalu type 9 or 12
        let smallPayload2 = ByteBuffer(bytes: [0x09, 0x00, 0x00])
        result = try pck.payload(mtu: 5, buf: smallPayload2)
        XCTAssertEqual(result.count, 0, "Generated payload should be empty")
    }

    func testH264PacketUnmarshal() throws {
        let singlePayload = ByteBuffer(bytes: [0x90, 0x90, 0x90])
        let singlePayloadUnmarshaled =
            ByteBuffer(bytes: [0x00, 0x00, 0x00, 0x01, 0x90, 0x90, 0x90])
        let singlePayloadUnmarshaledAvc =
            ByteBuffer(bytes: [0x00, 0x00, 0x00, 0x03, 0x90, 0x90, 0x90])

        let largePayload = ByteBuffer(bytes: [
            0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
            0x10,
            0x11, 0x12, 0x13, 0x14, 0x15,
        ])
        let largePayloadAvc = ByteBuffer(bytes: [
            0x00, 0x00, 0x00, 0x10, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
            0x10,
            0x11, 0x12, 0x13, 0x14, 0x15,
        ])
        let largePayloadPacketized = [
            ByteBuffer(bytes: [0x1c, 0x80, 0x01, 0x02, 0x03]),
            ByteBuffer(bytes: [0x1c, 0x00, 0x04, 0x05, 0x06]),
            ByteBuffer(bytes: [0x1c, 0x00, 0x07, 0x08, 0x09]),
            ByteBuffer(bytes: [0x1c, 0x00, 0x10, 0x11, 0x12]),
            ByteBuffer(bytes: [0x1c, 0x40, 0x13, 0x14, 0x15]),
        ]

        let singlePayloadMultiNalu = ByteBuffer(bytes: [
            0x78, 0x00, 0x0f, 0x67, 0x42, 0xc0, 0x1f, 0x1a, 0x32, 0x35, 0x01, 0x40, 0x7a, 0x40,
            0x3c,
            0x22, 0x11, 0xa8, 0x00, 0x05, 0x68, 0x1a, 0x34, 0xe3, 0xc8,
        ])
        let singlePayloadMultiNaluUnmarshaled = ByteBuffer(bytes: [
            0x00, 0x00, 0x00, 0x01, 0x67, 0x42, 0xc0, 0x1f, 0x1a, 0x32, 0x35, 0x01, 0x40, 0x7a,
            0x40,
            0x3c, 0x22, 0x11, 0xa8, 0x00, 0x00, 0x00, 0x01, 0x68, 0x1a, 0x34, 0xe3, 0xc8,
        ])
        let singlePayloadMultiNaluUnmarshaledAvc = ByteBuffer(bytes: [
            0x00, 0x00, 0x00, 0x0f, 0x67, 0x42, 0xc0, 0x1f, 0x1a, 0x32, 0x35, 0x01, 0x40, 0x7a,
            0x40,
            0x3c, 0x22, 0x11, 0xa8, 0x00, 0x00, 0x00, 0x05, 0x68, 0x1a, 0x34, 0xe3, 0xc8,
        ])

        let incompleteSinglePayloadMultiNalu = ByteBuffer(bytes: [
            0x78, 0x00, 0x0f, 0x67, 0x42, 0xc0, 0x1f, 0x1a, 0x32, 0x35, 0x01, 0x40, 0x7a, 0x40,
            0x3c,
            0x22, 0x11,
        ])

        var pkt = H264Packet(isAvc: false)
        var avcPkt = H264Packet(isAvc: true)

        var result = try? pkt.depacketize(buf: ByteBuffer())
        XCTAssertTrue(result == nil, "Unmarshal did not fail on nil payload")

        result = try? pkt.depacketize(buf: ByteBuffer(bytes: [0x00, 0x00]))
        XCTAssertTrue(
            result == nil,
            "Unmarshal accepted a packet that is too small for a payload and header"
        )

        result = try? pkt.depacketize(buf: ByteBuffer(bytes: [0xFF, 0x00, 0x00]))
        XCTAssertTrue(
            result == nil,
            "Unmarshal accepted a packet with a NALU Type we don't handle"
        )

        result = try? pkt.depacketize(buf: incompleteSinglePayloadMultiNalu)
        XCTAssertTrue(
            result == nil,
            "Unmarshal accepted a STAP-A packet with insufficient data"
        )

        var payload = try pkt.depacketize(buf: singlePayload)
        XCTAssertEqual(
            payload, singlePayloadUnmarshaled,
            "Unmarshaling a single payload shouldn't modify the payload"
        )

        payload = try avcPkt.depacketize(buf: singlePayload)
        XCTAssertEqual(
            payload, singlePayloadUnmarshaledAvc,
            "Unmarshaling a single payload into avc stream shouldn't modify the payload"
        )

        var largePayloadResult = ByteBuffer()
        for p in largePayloadPacketized {
            let payload = try pkt.depacketize(buf: p)
            largePayloadResult.writeImmutableBuffer(payload)
        }
        XCTAssertEqual(
            largePayloadResult,
            largePayload,
            "Failed to unmarshal a large payload"
        )

        var largePayloadResultAvc = ByteBuffer()
        for p in largePayloadPacketized {
            let payload = try avcPkt.depacketize(buf: p)
            largePayloadResultAvc.writeImmutableBuffer(payload)
        }
        XCTAssertEqual(
            largePayloadResultAvc,
            largePayloadAvc,
            "Failed to unmarshal a large payload into avc stream"
        )

        payload = try pkt.depacketize(buf: singlePayloadMultiNalu)
        XCTAssertEqual(
            payload, singlePayloadMultiNaluUnmarshaled,
            "Failed to unmarshal a single packet with multiple NALUs"
        )

        payload = try avcPkt.depacketize(buf: singlePayloadMultiNalu)
        XCTAssertEqual(
            payload, singlePayloadMultiNaluUnmarshaledAvc,
            "Failed to unmarshal a single packet with multiple NALUs into avc stream"
        )
    }

    func testH264PartitionHeadCheckerIsPartitionHead() throws {
        let h264 = H264Packet(isAvc: false)
        let emptyNalu = ByteBuffer()
        XCTAssertTrue(
            !h264.isPartitionHead(payload: emptyNalu),
            "empty nalu must not be a partition head"
        )

        let singleNalu = ByteBuffer(bytes: [1, 0])
        XCTAssertTrue(
            h264.isPartitionHead(payload: singleNalu),
            "single nalu must be a partition head"
        )

        let stapaNalu = ByteBuffer(bytes: [stapaNaluType, 0])
        XCTAssertTrue(
            h264.isPartitionHead(payload: stapaNalu),
            "stapa nalu must be a partition head"
        )

        let fuaStartNalu = ByteBuffer(bytes: [fuaNaluType, fuStartBitmask])
        XCTAssertTrue(
            h264.isPartitionHead(payload: fuaStartNalu),
            "fua start nalu must be a partition head"
        )

        let fuaEndNalu = ByteBuffer(bytes: [fuaNaluType, fuEndBitmask])
        XCTAssertTrue(
            !h264.isPartitionHead(payload: fuaEndNalu),
            "fua end nalu must not be a partition head"
        )

        let fubStartNalu = ByteBuffer(bytes: [fubNaluType, fuStartBitmask])
        XCTAssertTrue(
            h264.isPartitionHead(payload: fubStartNalu),
            "fub start nalu must be a partition head"
        )

        let fubEndNalu = ByteBuffer(bytes: [fubNaluType, fuEndBitmask])
        XCTAssertTrue(
            !h264.isPartitionHead(payload: fubEndNalu),
            "fub end nalu must not be a partition head"
        )
    }

    func test_h264_payloader_payload_sps_and_pps_handling() throws {
        var pck = H264Payloader()
        let expected = [
            ByteBuffer(bytes: [
                0x78, 0x00, 0x03, 0x07, 0x00, 0x01, 0x00, 0x03, 0x08, 0x02, 0x03,
            ]),
            ByteBuffer(bytes: [0x05, 0x04, 0x05]),
        ]

        // When packetizing SPS and PPS are emitted with following NALU
        var res = try pck.payload(mtu: 1500, buf: ByteBuffer(bytes: [0x07, 0x00, 0x01]))
        XCTAssertTrue(res.isEmpty, "Generated payload should be empty")

        res = try pck.payload(mtu: 1500, buf: ByteBuffer(bytes: [0x08, 0x02, 0x03]))
        XCTAssertTrue(res.isEmpty, "Generated payload should be empty")

        let actual = try pck.payload(mtu: 1500, buf: ByteBuffer(bytes: [0x05, 0x04, 0x05]))
        XCTAssertEqual(actual, expected, "SPS and PPS aren't packed together")
    }
}
