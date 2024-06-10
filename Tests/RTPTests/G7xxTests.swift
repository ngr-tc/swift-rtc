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

final class G7xxTests: XCTestCase {
    func testG7xxPayload() throws {
        var pck = G711Payloader()

        let testLen: Int = 10000
        let testMtu: Int = 1500

        //generate random 8-bit g722 samples
        let samples: [UInt8] = (0..<testLen).map { _ in
            UInt8.random(in: UInt8.min...UInt8.max)
        }

        //make a copy, for payloader input
        let samplesIn = ByteBuffer(bytes: samples)

        //split our samples into payloads
        let payloads = try pck.payload(mtu: testMtu, buf: samplesIn)

        let outcnt = Int(ceil(Double(testLen) / Double(testMtu)))
        XCTAssertEqual(
            outcnt,
            payloads.count
        )
        XCTAssertEqual(
            samples, samplesIn.getBytes(at: 0, length: testLen)!, "Modified input samples")

        var samplesOut = ByteBuffer()
        let _ = payloads.compactMap { buf in
            samplesOut.writeImmutableBuffer(buf)
        }
        XCTAssertEqual(samplesOut, samplesIn, "Output samples don't match")

        let empty = ByteBuffer()
        let payload = ByteBuffer(bytes: [0x90, 0x90, 0x90])

        // Positive MTU, empty payload
        var result = try pck.payload(mtu: 1, buf: empty)
        XCTAssertTrue(result.isEmpty, "Generated payload should be empty")

        // 0 MTU, small payload
        result = try pck.payload(mtu: 0, buf: payload)
        XCTAssertEqual(result.count, 0, "Generated payload should be empty")

        // Positive MTU, small payload
        result = try pck.payload(mtu: 10, buf: payload)
        XCTAssertEqual(result.count, 1, "Generated payload should be the 1")
    }
}
