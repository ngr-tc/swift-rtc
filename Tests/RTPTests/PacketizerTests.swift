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

final class PacketizerTests: XCTestCase {
    func testPacketizer() throws {
        let multiplePayload = ByteBuffer(bytes: Array(repeating: 0, count: 128))
        let g722 = G722Payloader()
        let seq = newRandomSequencer()

        //use the G722 payloader here, because it's very simple and all 0s is valid G722 data.
        var packetizer = newPacketizer(
            mtu: 100,
            payloadType: 98,
            ssrc: 0x1234_ABCD,
            payloader: g722,
            sequencer: seq,
            clockRate: 90000)
        let packets = try packetizer.packetize(payload: multiplePayload, samples: 2000)

        if packets.count != 2 {
            var packetLengths = ""
            for i in 0..<packets.count {
                packetLengths += "Packet \(i) length \(packets[i].payload.readableBytes)\n"
            }
            XCTFail(
                "Generated \(packets.count) packets instead of 2\n \(packetLengths)"
            )
        }
    }

    func testPacketizerAbsSendTime() throws {
        let g722 = G722Payloader()
        let sequencer = newFixedSequencer(1234)

        let timeGen: FnTimeGen? = { () -> NIODeadline in
            let t: UInt64 = 488_365_200_000_000_000
            return NIODeadline.uptimeNanoseconds(t)
        }

        //use the G722 payloader here, because it's very simple and all 0s is valid G722 data.
        var pktizer = PacketizerImpl(
            mtu: 100,
            payloadType: 98,
            ssrc: 0x1234_ABCD,
            payloader: g722,
            sequencer: sequencer,
            timestamp: 45678,
            clockRate: 90000,
            absSendTime: 0,
            timeGen: timeGen
        )
        pktizer.enableAbsSendTime(value: 1)

        let payload = ByteBuffer(bytes: [0x11, 0x12, 0x13, 0x14])
        let packets = try pktizer.packetize(payload: payload, samples: 2000)

        let expected = Packet(
            header: Header(
                version: 2,
                padding: false,
                ext: true,
                marker: true,
                payloadType: 98,
                sequenceNumber: 1234,
                timestamp: 45678,
                ssrc: 0x1234_ABCD,
                csrcs: [],
                extensionProfile: 0xBEDE,
                extensions: [
                    Extension(
                        id: 1,
                        payload: ByteBuffer(bytes: [0x40, 0, 0])
                    )
                ]
            ),
            payload: ByteBuffer(bytes: [0x11, 0x12, 0x13, 0x14])
        )

        XCTAssertEqual(1, packets.count)

        XCTAssertEqual(packets[0], expected)
    }

    func testPacketizerTimestampRolloverDoesNotPanic() throws {
        let g722 = G722Payloader()
        let seq = newRandomSequencer()

        let payload = ByteBuffer(bytes: Array(repeating: 0, count: 128))
        var packetizer = newPacketizer(
            mtu: 100,
            payloadType: 98,
            ssrc: 0x1234_ABCD,
            payloader: g722,
            sequencer: seq,
            clockRate: 90000)

        let _ = try packetizer.packetize(payload: payload, samples: 10)
        let _ = try packetizer.packetize(payload: payload, samples: UInt32.max)

        packetizer.skipSamples(skippedSamples: UInt32.max)
    }
}
