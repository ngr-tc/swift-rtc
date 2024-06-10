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
        var empty = ByteBuffer()
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
        var result = try pck.payload(mtu: 1, buf: &empty)
        XCTAssertTrue(result.isEmpty, "Generated payload should be empty")

        // 0 MTU, small payload
        var buf = smallPayload.slice()
        result = try pck.payload(mtu: 0, buf: &buf)
        XCTAssertEqual(result.count, 0, "Generated payload should be empty")

        // Positive MTU, small payload
        buf = smallPayload.slice()
        result = try pck.payload(mtu: 1, buf: &buf)
        XCTAssertEqual(result.count, 0, "Generated payload should be empty")

        // Positive MTU, small payload
        buf = smallPayload.slice()
        result = try pck.payload(mtu: 5, buf: &buf)
        XCTAssertEqual(result.count, 1, "Generated payload should be the 1")
        XCTAssertEqual(
            result[0].readableBytes,
            smallPayload.readableBytes,
            "Generated payload should be the same size as original payload size"
        )

        // Multiple NALU in a single payload
        buf = multiplePayload.slice()
        result = try pck.payload(mtu: 5, buf: &buf)
        XCTAssertEqual(result.count, 2, "2 nal units should be broken out")
        for i in 0..<2 {
            XCTAssertEqual(
                result[i].readableBytes,
                1
            )
        }

        // Large Payload split across multiple RTP Packets
        buf = largePayload.slice()
        result = try pck.payload(mtu: 5, buf: &buf)
        XCTAssertEqual(
            result, largePayloadPacketized,
            "FU-A packetization failed"
        )

        // Nalu type 9 or 12
        var smallPayload2 = ByteBuffer(bytes: [0x09, 0x00, 0x00])
        result = try pck.payload(mtu: 5, buf: &smallPayload2)
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

        var data = ByteBuffer()
        var result = try? pkt.depacketize(buf: &data)
        XCTAssertTrue(result == nil, "Unmarshal did not fail on nil payload")

        data = ByteBuffer(bytes: [0x00, 0x00])
        result = try? pkt.depacketize(buf: &data)
        XCTAssertTrue(
            result == nil,
            "Unmarshal accepted a packet that is too small for a payload and header"
        )

        data = ByteBuffer(bytes: [0xFF, 0x00, 0x00])
        result = try? pkt.depacketize(buf: &data)
        XCTAssertTrue(
            result == nil,
            "Unmarshal accepted a packet with a NALU Type we don't handle"
        )

        data = incompleteSinglePayloadMultiNalu.slice()
        result = try? pkt.depacketize(buf: &data)
        XCTAssertTrue(
            result == nil,
            "Unmarshal accepted a STAP-A packet with insufficient data"
        )

        data = singlePayload.slice()
        var payload = try pkt.depacketize(buf: &data)
        XCTAssertEqual(
            payload, singlePayloadUnmarshaled,
            "Unmarshaling a single payload shouldn't modify the payload"
        )

        data = singlePayload.slice()
        payload = try avcPkt.depacketize(buf: &data)
        XCTAssertEqual(
            payload, singlePayloadUnmarshaledAvc,
            "Unmarshaling a single payload into avc stream shouldn't modify the payload"
        )

        var largePayloadResult = ByteBuffer()
        for p in largePayloadPacketized {
            data = p.slice()
            let payload = try pkt.depacketize(buf: &data)
            largePayloadResult.writeImmutableBuffer(payload)
        }
        XCTAssertEqual(
            largePayloadResult,
            largePayload,
            "Failed to unmarshal a large payload"
        )

        var largePayloadResultAvc = ByteBuffer()
        for p in largePayloadPacketized {
            data = p.slice()
            let payload = try avcPkt.depacketize(buf: &data)
            largePayloadResultAvc.writeImmutableBuffer(payload)
        }
        XCTAssertEqual(
            largePayloadResultAvc,
            largePayloadAvc,
            "Failed to unmarshal a large payload into avc stream"
        )

        data = singlePayloadMultiNalu.slice()
        payload = try pkt.depacketize(buf: &data)
        XCTAssertEqual(
            payload, singlePayloadMultiNaluUnmarshaled,
            "Failed to unmarshal a single packet with multiple NALUs"
        )

        data = singlePayloadMultiNalu.slice()
        payload = try avcPkt.depacketize(buf: &data)
        XCTAssertEqual(
            payload, singlePayloadMultiNaluUnmarshaledAvc,
            "Failed to unmarshal a single packet with multiple NALUs into avc stream"
        )
    }

    func testH264PartitionHeadCheckerIsPartitionHead() throws {
        let h264 = H264Packet(isAvc: false)
        var emptyNalu = ByteBuffer()
        XCTAssertTrue(
            !h264.isPartitionHead(payload: &emptyNalu),
            "empty nalu must not be a partition head"
        )

        var singleNalu = ByteBuffer(bytes: [1, 0])
        XCTAssertTrue(
            h264.isPartitionHead(payload: &singleNalu),
            "single nalu must be a partition head"
        )

        var stapaNalu = ByteBuffer(bytes: [stapaNaluType, 0])
        XCTAssertTrue(
            h264.isPartitionHead(payload: &stapaNalu),
            "stapa nalu must be a partition head"
        )

        var fuaStartNalu = ByteBuffer(bytes: [fuaNaluType, fuStartBitmask])
        XCTAssertTrue(
            h264.isPartitionHead(payload: &fuaStartNalu),
            "fua start nalu must be a partition head"
        )

        var fuaEndNalu = ByteBuffer(bytes: [fuaNaluType, fuEndBitmask])
        XCTAssertTrue(
            !h264.isPartitionHead(payload: &fuaEndNalu),
            "fua end nalu must not be a partition head"
        )

        var fubStartNalu = ByteBuffer(bytes: [fubNaluType, fuStartBitmask])
        XCTAssertTrue(
            h264.isPartitionHead(payload: &fubStartNalu),
            "fub start nalu must be a partition head"
        )

        var fubEndNalu = ByteBuffer(bytes: [fubNaluType, fuEndBitmask])
        XCTAssertTrue(
            !h264.isPartitionHead(payload: &fubEndNalu),
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
        var buf = ByteBuffer(bytes: [0x07, 0x00, 0x01])
        var res = try pck.payload(mtu: 1500, buf: &buf)
        XCTAssertTrue(res.isEmpty, "Generated payload should be empty")

        buf = ByteBuffer(bytes: [0x08, 0x02, 0x03])
        res = try pck.payload(mtu: 1500, buf: &buf)
        XCTAssertTrue(res.isEmpty, "Generated payload should be empty")

        buf = ByteBuffer(bytes: [0x05, 0x04, 0x05])
        let actual = try pck.payload(mtu: 1500, buf: &buf)
        XCTAssertEqual(actual, expected, "SPS and PPS aren't packed together")
    }
}
