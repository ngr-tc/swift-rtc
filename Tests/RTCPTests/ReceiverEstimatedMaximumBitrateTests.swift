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

final class ReceiverEstimatedMaximumBitrateTests: XCTestCase {
    func testReceiverEstimatedMaximumBitrateMarshal() throws {
        let input = ReceiverEstimatedMaximumBitrate(
            senderSsrc: 1,
            bitrate: 8927168.0,
            ssrcs: [1_215_622_422]
        )

        let expected = ByteBuffer(bytes: [
            143, 206, 0, 5, 0, 0, 0, 1, 0, 0, 0, 0, 82, 69, 77, 66, 1, 26, 32, 223, 72, 116, 237,
            22,
        ])

        let output = try input.marshal()
        XCTAssertEqual(output, expected)
    }

    func testReceiverEstimatedMaximumBitrateUnmarshal() throws {
        // Real data sent by Chrome while watching a 6Mb/s stream
        let input = ByteBuffer(bytes: [
            143, 206, 0, 5, 0, 0, 0, 1, 0, 0, 0, 0, 82, 69, 77, 66, 1, 26, 32, 223, 72, 116, 237,
            22,
        ])

        // mantissa = []byte{26 & 3, 32, 223} = []byte{2, 32, 223} = 139487
        // exp = 26 >> 2 = 6
        // bitrate = 139487 * 2^6 = 139487 * 64 = 8927168 = 8.9 Mb/s
        let expected = ReceiverEstimatedMaximumBitrate(
            senderSsrc: 1,
            bitrate: 8927168.0,
            ssrcs: [1_215_622_422]
        )

        let (packet, _) = try ReceiverEstimatedMaximumBitrate.unmarshal(input)
        XCTAssertEqual(packet, expected)
    }

    func testReceiverEstimatedMaximumBitrateTruncate() throws {
        let input = ByteBuffer(bytes: [
            143, 206, 0, 5, 0, 0, 0, 1, 0, 0, 0, 0, 82, 69, 77, 66, 1, 26, 32, 223, 72, 116, 237,
            22,
        ])

        // Make sure that we're interpreting the bitrate correctly.
        // For the above example, we have:

        // mantissa = 139487
        // exp = 6
        // bitrate = 8927168

        var (packet, _) = try ReceiverEstimatedMaximumBitrate.unmarshal(input)
        XCTAssertEqual(packet.bitrate, 8927168.0)

        // Just verify marshal produces the same input.
        var output = try packet.marshal()
        XCTAssertEqual(output, input)

        // If we subtract the bitrate by 1, we'll round down a lower mantissa
        packet.bitrate -= 1.0

        // bitrate = 8927167
        // mantissa = 139486
        // exp = 6

        output = try packet.marshal()
        XCTAssertNotEqual(output, input)
        let expected = ByteBuffer(bytes: [
            143, 206, 0, 5, 0, 0, 0, 1, 0, 0, 0, 0, 82, 69, 77, 66, 1, 26, 32, 222, 72, 116, 237,
            22,
        ])
        XCTAssertEqual(output, expected)

        // Which if we actually unmarshal again, we'll find that it's actually decreased by 63 (which is exp)
        // mantissa = 139486
        // exp = 6
        // bitrate = 8927104

        let (packet2, _) = try ReceiverEstimatedMaximumBitrate.unmarshal(output)
        XCTAssertEqual(8927104.0, packet2.bitrate)
    }

    func testReceiverEstimatedMaximumBitrateOverflow() throws {
        // Marshal a packet with the maximum possible bitrate.
        let packet = ReceiverEstimatedMaximumBitrate(
            senderSsrc: 0, bitrate: Float.greatestFiniteMagnitude, ssrcs: [])

        // mantissa = 262143 = 0x3FFFF
        // exp = 63

        let expected = ByteBuffer(bytes: [
            143, 206, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 82, 69, 77, 66, 0, 255, 255, 255,
        ])

        var output = try packet.marshal()
        XCTAssertEqual(output, expected)

        // mantissa = 262143
        // exp = 63
        // bitrate = 0xFFFFC00000000000

        let (packet1, _) = try ReceiverEstimatedMaximumBitrate.unmarshal(output)
        XCTAssertEqual(packet1.bitrate, Float(bitPattern: 0x67FF_FFC0))

        // Make sure we marshal to the same result again.
        output = try packet1.marshal()
        XCTAssertEqual(output, expected)

        // Finally, try unmarshalling one number higher than we used to be able to handle.
        let input = ByteBuffer(bytes: [
            143, 206, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 82, 69, 77, 66, 0, 188, 0, 0,
        ])
        let (packet2, _) = try ReceiverEstimatedMaximumBitrate.unmarshal(input)
        XCTAssertEqual(packet2.bitrate, Float(bitPattern: 0x6280_0000))
    }
}
