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

final class OpusTests: XCTestCase {
    func testOpusUnmarshal() throws {
        var pck = OpusPacket()

        // Empty packet
        let emptyBytes = ByteBuffer()
        let result = try? pck.depacketize(buf: emptyBytes)
        XCTAssertTrue(result == nil, "Result should be err in case of error")

        // Normal packet
        let rawBytes = ByteBuffer(bytes: [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x90])
        let payload = try pck.depacketize(buf: rawBytes)
        XCTAssertEqual(rawBytes, payload, "Payload must be same")
    }

    func testOpusPayload() throws {
        var pck = OpusPayloader()
        let empty = ByteBuffer()
        let payload = ByteBuffer(bytes: [0x90, 0x90, 0x90])

        // Positive MTU, empty payload
        var result = try pck.payload(mtu: 1, buf: empty)
        XCTAssertTrue(result.isEmpty, "Generated payload should be empty")

        // Positive MTU, small payload
        result = try pck.payload(mtu: 1, buf: payload)
        XCTAssertEqual(result.count, 1, "Generated payload should be the 1")

        // Positive MTU, small payload
        result = try pck.payload(mtu: 2, buf: payload)
        XCTAssertEqual(result.count, 1, "Generated payload should be the 1")
    }

    func testOpusIsPartitionHead() throws {
        let opus = OpusPacket()
        //"NormalPacket"
        let buf = ByteBuffer(bytes: [0x00, 0x00])
        XCTAssertTrue(
            opus.isPartitionHead(payload: buf),
            "All OPUS RTP packet should be the head of a new partition"
        )
    }
}
