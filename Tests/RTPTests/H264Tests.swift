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
    /*
    func testH264PacketUnmarshal() throws {
        let single_payload = ByteBuffer(bytes: [0x90, 0x90, 0x90]);
        let single_payload_unmarshaled =
            ByteBuffer(bytes: [0x00, 0x00, 0x00, 0x01, 0x90, 0x90, 0x90]);
        let single_payload_unmarshaled_avc =
            ByteBuffer(bytes: [0x00, 0x00, 0x00, 0x03, 0x90, 0x90, 0x90]);

        let large_payload = ByteBuffer(bytes: [
            0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10,
            0x11, 0x12, 0x13, 0x14, 0x15,
        ]);
        let large_payload_avc = ByteBuffer(bytes: [
            0x00, 0x00, 0x00, 0x10, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10,
            0x11, 0x12, 0x13, 0x14, 0x15,
        ]);
        let large_payload_packetized = vec![
            ByteBuffer(bytes: [0x1c, 0x80, 0x01, 0x02, 0x03]),
            ByteBuffer(bytes: [0x1c, 0x00, 0x04, 0x05, 0x06]),
            ByteBuffer(bytes: [0x1c, 0x00, 0x07, 0x08, 0x09]),
            ByteBuffer(bytes: [0x1c, 0x00, 0x10, 0x11, 0x12]),
            ByteBuffer(bytes: [0x1c, 0x40, 0x13, 0x14, 0x15]),
        ];

        let single_payload_multi_nalu = ByteBuffer(bytes: [
            0x78, 0x00, 0x0f, 0x67, 0x42, 0xc0, 0x1f, 0x1a, 0x32, 0x35, 0x01, 0x40, 0x7a, 0x40, 0x3c,
            0x22, 0x11, 0xa8, 0x00, 0x05, 0x68, 0x1a, 0x34, 0xe3, 0xc8,
        ]);
        let single_payload_multi_nalu_unmarshaled = ByteBuffer(bytes: [
            0x00, 0x00, 0x00, 0x01, 0x67, 0x42, 0xc0, 0x1f, 0x1a, 0x32, 0x35, 0x01, 0x40, 0x7a, 0x40,
            0x3c, 0x22, 0x11, 0xa8, 0x00, 0x00, 0x00, 0x01, 0x68, 0x1a, 0x34, 0xe3, 0xc8,
        ]);
        let single_payload_multi_nalu_unmarshaled_avc = ByteBuffer(bytes: [
            0x00, 0x00, 0x00, 0x0f, 0x67, 0x42, 0xc0, 0x1f, 0x1a, 0x32, 0x35, 0x01, 0x40, 0x7a, 0x40,
            0x3c, 0x22, 0x11, 0xa8, 0x00, 0x00, 0x00, 0x05, 0x68, 0x1a, 0x34, 0xe3, 0xc8,
        ]);

        let incomplete_single_payload_multi_nalu = ByteBuffer(bytes: [
            0x78, 0x00, 0x0f, 0x67, 0x42, 0xc0, 0x1f, 0x1a, 0x32, 0x35, 0x01, 0x40, 0x7a, 0x40, 0x3c,
            0x22, 0x11,
        ]);

        let mut pkt = H264Packet::default();
        let mut avc_pkt = H264Packet {
            is_avc: true,
            ..Default::default()
        };

        let data = ByteBuffer(bytes: []);
        let result = pkt.depacketize(&data);
        XCTAssertTrue(result.is_err(), "Unmarshal did not fail on nil payload");

        let data = ByteBuffer(bytes: [0x00, 0x00]);
        let result = pkt.depacketize(&data);
        XCTAssertTrue(
            result.is_err(),
            "Unmarshal accepted a packet that is too small for a payload and header"
        );

        let data = ByteBuffer(bytes: [0xFF, 0x00, 0x00]);
        let result = pkt.depacketize(&data);
        XCTAssertTrue(
            result.is_err(),
            "Unmarshal accepted a packet with a NALU Type we don't handle"
        );

        let result = pkt.depacketize(&incomplete_single_payload_multi_nalu);
        XCTAssertTrue(
            result.is_err(),
            "Unmarshal accepted a STAP-A packet with insufficient data"
        );

        let payload = pkt.depacketize(&single_payload)?;
        XCTAssertEqual(
            payload, single_payload_unmarshaled,
            "Unmarshaling a single payload shouldn't modify the payload"
        );

        let payload = avc_pkt.depacketize(&single_payload)?;
        XCTAssertEqual(
            payload, single_payload_unmarshaled_avc,
            "Unmarshaling a single payload into avc stream shouldn't modify the payload"
        );

        let mut large_payload_result = BytesMut::new();
        for p in &large_payload_packetized {
            let payload = pkt.depacketize(p)?;
            large_payload_result.put(&*payload.clone());
        }
        XCTAssertEqual(
            large_payload_result.freeze(),
            large_payload,
            "Failed to unmarshal a large payload"
        );

        let mut large_payload_result_avc = BytesMut::new();
        for p in &large_payload_packetized {
            let payload = avc_pkt.depacketize(p)?;
            large_payload_result_avc.put(&*payload.clone());
        }
        XCTAssertEqual(
            large_payload_result_avc.freeze(),
            large_payload_avc,
            "Failed to unmarshal a large payload into avc stream"
        );

        let payload = pkt.depacketize(&single_payload_multi_nalu)?;
        XCTAssertEqual(
            payload, single_payload_multi_nalu_unmarshaled,
            "Failed to unmarshal a single packet with multiple NALUs"
        );

        let payload = avc_pkt.depacketize(&single_payload_multi_nalu)?;
        XCTAssertEqual(
            payload, single_payload_multi_nalu_unmarshaled_avc,
            "Failed to unmarshal a single packet with multiple NALUs into avc stream"
        );

        Ok(())
    }

    func testH264PartitionHeadCheckerIsPartitionHead() throws {
        let h264 = H264Packet::default();
        let empty_nalu = ByteBuffer(bytes: []);
        XCTAssertTrue(
            !h264.is_partition_head(&empty_nalu),
            "empty nalu must not be a partition head"
        );

        let single_nalu = ByteBuffer(bytes: [1, 0]);
        XCTAssertTrue(
            h264.is_partition_head(&single_nalu),
            "single nalu must be a partition head"
        );

        let stapa_nalu = ByteBuffer(bytes: [STAPA_NALU_TYPE, 0]);
        XCTAssertTrue(
            h264.is_partition_head(&stapa_nalu),
            "stapa nalu must be a partition head"
        );

        let fua_start_nalu = ByteBuffer(bytes: [FUA_NALU_TYPE, FU_START_BITMASK]);
        XCTAssertTrue(
            h264.is_partition_head(&fua_start_nalu),
            "fua start nalu must be a partition head"
        );

        let fua_end_nalu = ByteBuffer(bytes: [FUA_NALU_TYPE, FU_END_BITMASK]);
        XCTAssertTrue(
            !h264.is_partition_head(&fua_end_nalu),
            "fua end nalu must not be a partition head"
        );

        let fub_start_nalu = ByteBuffer(bytes: [FUB_NALU_TYPE, FU_START_BITMASK]);
        XCTAssertTrue(
            h264.is_partition_head(&fub_start_nalu),
            "fub start nalu must be a partition head"
        );

        let fub_end_nalu = ByteBuffer(bytes: [FUB_NALU_TYPE, FU_END_BITMASK]);
        XCTAssertTrue(
            !h264.is_partition_head(&fub_end_nalu),
            "fub end nalu must not be a partition head"
        );

        Ok(())
    }

    #[test]
    fn test_h264_payloader_payload_sps_and_pps_handling() -> Result<()> {
        let mut pck = H264Payloader();
        let expected = vec![
            ByteBuffer(bytes: [
                0x78, 0x00, 0x03, 0x07, 0x00, 0x01, 0x00, 0x03, 0x08, 0x02, 0x03,
            ]),
            ByteBuffer(bytes: [0x05, 0x04, 0x05]),
        ];

        // When packetizing SPS and PPS are emitted with following NALU
        let res = pck.payload(1500, &ByteBuffer(bytes: [0x07, 0x00, 0x01]))?;
        XCTAssertTrue(res.is_empty(), "Generated payload should be empty");

        let res = pck.payload(1500, &ByteBuffer(bytes: [0x08, 0x02, 0x03]))?;
        XCTAssertTrue(res.is_empty(), "Generated payload should be empty");

        let actual = pck.payload(1500, &ByteBuffer(bytes: [0x05, 0x04, 0x05]))?;
        XCTAssertEqual(actual, expected, "SPS and PPS aren't packed together");

        Ok(())
    }
    */
}
