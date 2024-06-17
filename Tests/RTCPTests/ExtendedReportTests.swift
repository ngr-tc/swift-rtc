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

func decodedPacket() -> ExtendedReport {
    ExtendedReport(
        senderSsrc: 0x0102_0304,
        reports: [
            LossRLEReportBlock(
                isLossRLE: true,
                t: 12,

                ssrc: 0x1234_5689,
                beginSeq: 5,
                endSeq: 12,
                chunks: [
                    Chunk(rawValue: 0x4006), Chunk(rawValue: 0x0006), Chunk(rawValue: 0x8765),
                    Chunk(rawValue: 0x0000),
                ]
            ),
            DuplicateRLEReportBlock(
                isLossRLE: false,
                t: 6,

                ssrc: 0x1234_5689,
                beginSeq: 5,
                endSeq: 12,
                chunks: [
                    Chunk(rawValue: 0x4123), Chunk(rawValue: 0x3FFF), Chunk(rawValue: 0xFFFF),
                    Chunk(rawValue: 0x0000),
                ]
            ),
            PacketReceiptTimesReportBlock(
                t: 3,

                ssrc: 0x9876_5432,
                beginSeq: 15432,
                endSeq: 15577,
                receiptTime: [0x1111_1111, 0x2222_2222, 0x3333_3333, 0x4444_4444, 0x5555_5555]
            ),
            ReceiverReferenceTimeReportBlock(
                ntpTimestamp: 0x0102_0304_0506_0708
            ),
            DLRRReportBlock(
                reports: [
                    DLRRReport(
                        ssrc: 0x8888_8888,
                        lastRr: 0x1234_5678,
                        dlrr: 0x9999_9999
                    ),
                    DLRRReport(
                        ssrc: 0x0909_0909,
                        lastRr: 0x1234_5678,
                        dlrr: 0x9999_9999
                    ),
                    DLRRReport(
                        ssrc: 0x1122_3344,
                        lastRr: 0x1234_5678,
                        dlrr: 0x9999_9999
                    ),
                ]
            ),
            StatisticsSummaryReportBlock(
                lossReports: true,
                duplicateReports: true,
                jitterReports: true,
                ttlOrHopLimit: TTLorHopLimitType.ipv4,

                ssrc: 0xFEDC_BA98,
                beginSeq: 0x1234,
                endSeq: 0x5678,
                lostPackets: 0x1111_1111,
                dupPackets: 0x2222_2222,
                minJitter: 0x3333_3333,
                maxJitter: 0x4444_4444,
                meanJitter: 0x5555_5555,
                devJitter: 0x6666_6666,
                minTtlOrHl: 0x01,
                maxTtlOrHl: 0x02,
                meanTtlOrHl: 0x03,
                devTtlOrHl: 0x04
            ),
            VoIPMetricsReportBlock(
                ssrc: 0x89AB_CDEF,
                lossRate: 0x05,
                discardRate: 0x06,
                burstDensity: 0x07,
                gapDensity: 0x08,
                burstDuration: 0x1111,
                gapDuration: 0x2222,
                roundTripDelay: 0x3333,
                endSystemDelay: 0x4444,
                signalLevel: 0x11,
                noiseLevel: 0x22,
                rerl: 0x33,
                gmin: 0x44,
                rfactor: 0x55,
                extRfactor: 0x66,
                mosLq: 0x77,
                mosCq: 0x88,
                rxConfig: 0x99,
                reserved: 0x00,
                jbNominal: 0x1122,
                jbMaximum: 0x3344,
                jbAbsMax: 0x5566
            ),
        ]
    )
}

func encodedPacket() -> ByteBuffer {
    ByteBuffer(bytes: [
        // RTP Header
        0x80, 0xCF, 0x00, 0x33,  // byte 0 - 3
        // Sender SSRC
        0x01, 0x02, 0x03, 0x04,  // Loss RLE Report Block
        0x01, 0x0C, 0x00, 0x04,  // byte 8 - 11
        // Source SSRC
        0x12, 0x34, 0x56, 0x89,  // Begin & End Seq
        0x00, 0x05, 0x00, 0x0C,  // byte 16 - 19
        // Chunks
        0x40, 0x06, 0x00, 0x06, 0x87, 0x65, 0x00, 0x00,  // byte 24 - 27
        // Duplicate RLE Report Block
        0x02, 0x06, 0x00, 0x04,  // Source SSRC
        0x12, 0x34, 0x56, 0x89,  // byte 32 - 35
        // Begin & End Seq
        0x00, 0x05, 0x00, 0x0C,  // Chunks
        0x41, 0x23, 0x3F, 0xFF,  // byte 40 - 43
        0xFF, 0xFF, 0x00, 0x00,  // Packet Receipt Times Report Block
        0x03, 0x03, 0x00, 0x07,  // byte 48 - 51
        // Source SSRC
        0x98, 0x76, 0x54, 0x32,  // Begin & End Seq
        0x3C, 0x48, 0x3C, 0xD9,  // byte 56 - 59
        // Receipt times
        0x11, 0x11, 0x11, 0x11, 0x22, 0x22, 0x22, 0x22,  // byte 64 - 67
        0x33, 0x33, 0x33, 0x33, 0x44, 0x44, 0x44, 0x44,  // byte 72 - 75
        0x55, 0x55, 0x55, 0x55,  // Receiver Reference Time Report
        0x04, 0x00, 0x00, 0x02,  // byte 80 - 83
        // Timestamp
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,  // byte 88 - 91
        // DLRR Report
        0x05, 0x00, 0x00, 0x09,  // SSRC 1
        0x88, 0x88, 0x88, 0x88,  // byte 96 - 99
        // LastRR 1
        0x12, 0x34, 0x56, 0x78,  // DLRR 1
        0x99, 0x99, 0x99, 0x99,  // byte 104 - 107
        // SSRC 2
        0x09, 0x09, 0x09, 0x09,  // LastRR 2
        0x12, 0x34, 0x56, 0x78,  // byte 112 - 115
        // DLRR 2
        0x99, 0x99, 0x99, 0x99,  // SSRC 3
        0x11, 0x22, 0x33, 0x44,  // byte 120 - 123
        // LastRR 3
        0x12, 0x34, 0x56, 0x78,  // DLRR 3
        0x99, 0x99, 0x99, 0x99,  // byte 128 - 131
        // Statistics Summary Report
        0x06, 0xE8, 0x00, 0x09,  // SSRC
        0xFE, 0xDC, 0xBA, 0x98,  // byte 136 - 139
        // Various statistics
        0x12, 0x34, 0x56, 0x78, 0x11, 0x11, 0x11, 0x11,  // byte 144 - 147
        0x22, 0x22, 0x22, 0x22, 0x33, 0x33, 0x33, 0x33,  // byte 152 - 155
        0x44, 0x44, 0x44, 0x44, 0x55, 0x55, 0x55, 0x55,  // byte 160 - 163
        0x66, 0x66, 0x66, 0x66, 0x01, 0x02, 0x03, 0x04,  // byte 168 - 171
        // VoIP Metrics Report
        0x07, 0x00, 0x00, 0x08,  // SSRC
        0x89, 0xAB, 0xCD, 0xEF,  // byte 176 - 179
        // Various statistics
        0x05, 0x06, 0x07, 0x08, 0x11, 0x11, 0x22, 0x22,  // byte 184 - 187
        0x33, 0x33, 0x44, 0x44, 0x11, 0x22, 0x33, 0x44,  // byte 192 - 195
        0x55, 0x66, 0x77, 0x88, 0x99, 0x00, 0x11, 0x22,  // byte 200 - 203
        0x33, 0x44, 0x55, 0x66,  // byte 204 - 207
    ])
}

final class ExtendedReportTests: XCTestCase {
    func testEncode() throws {
        let expected = encodedPacket()
        let packet = decodedPacket()
        let actual = try packet.marshal()
        XCTAssertEqual(actual, expected)
    }

    func testDecode() throws {
        let encoded = encodedPacket()
        let expected = decodedPacket()
        let (actual, _) = try ExtendedReport.unmarshal(encoded)
        XCTAssertTrue(actual.equal(other: expected))
        XCTAssertEqual(actual.description, expected.description)
    }
}
