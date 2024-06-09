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

final class AbsSendTimeExtensionTests: XCTestCase {
    let absSendTimeResolution: Int64 = 1000

    func testNtpConversion() throws {
        let tests: [(UInt64, UInt64)] = [
            (
                488_365_200_000_000_000,
                0xa0c6_5b10_0000_0000
            ),
            (
                946_702_799_000_500_000,
                0xbc18_084f_0020_c49b
            ),
            (
                1_553_711_970_008_675_309,
                0xe046_41e2_0238_8b88
            ),
        ]

        for (t, n) in tests {
            let st = NIODeadline.uptimeNanoseconds(t)
            let ntp = unix2ntp(st)

            let actual = ntp
            let expected = n
            let diff: Int64 =
                actual > expected ? Int64(actual - expected) : -Int64(expected - actual)
            if !(-absSendTimeResolution...absSendTimeResolution).contains(diff) {
                XCTFail("unix2ntp error")
            }
        }

        for (t, n) in tests {
            let output = ntp2unix(n)
            let input = NIODeadline.uptimeNanoseconds(t)
            let diff: Int64 = (input - output).nanoseconds
            if !(-absSendTimeResolution...absSendTimeResolution).contains(diff) {
                XCTFail(
                    "Converted time.Time from NTP time differs"
                )
            }
        }
    }

    func testAbsSendTimeExtensionRoundtrip() throws {
        let tests = [
            AbsSendTimeExtension(timestamp: 123456),
            AbsSendTimeExtension(timestamp: 654321),
        ]

        for test in tests {
            var raw = ByteBuffer()
            let _ = try test.marshalTo(&raw)
            var buf = raw.slice()
            let out = try AbsSendTimeExtension(&buf)
            XCTAssertEqual(test.timestamp, out.timestamp)
        }
    }

    func testAbsSendTimeExtensionEstimate() throws {
        let tests: [(UInt64, UInt64)] = [
            //FFFFFFC000000000 mask of second
            (0xa0c6_5b10_0010_0000, 0xa0c6_5b10_0100_0000),  // not carried
            (0xa0c6_5b3f_0000_0000, 0xa0c6_5b40_0100_0000),  // carried during transmission
        ]

        for (send_ntp, receive_ntp) in tests {
            let inTime = ntp2unix(send_ntp)
            let send = AbsSendTimeExtension(
                timestamp: send_ntp >> 14
            )
            var raw = ByteBuffer()
            let _ = try send.marshalTo(&raw)
            var buf = raw.slice()
            let receive = try AbsSendTimeExtension(&buf)

            let estimated = receive.estimate(ntp2unix(receive_ntp))
            let diff: TimeAmount = estimated - inTime
            if !(-absSendTimeResolution...absSendTimeResolution).contains(diff.nanoseconds) {
                XCTFail(
                    "Converted time.Time from NTP time differs"
                )
            }
        }
    }
}
