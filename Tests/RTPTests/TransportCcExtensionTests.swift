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

final class TransportCcExtensionTests: XCTestCase {
    func test_transport_cc_extension_too_small() throws {
        let buf = ByteBuffer()
        let result = try? TransportCcExtension(buf)
        XCTAssertTrue(result == nil)
    }

    func test_transport_cc_extension() throws {
        let raw = ByteBuffer(bytes: [0x00, 0x02])
        let t1 = try TransportCcExtension(raw)
        let t2 = TransportCcExtension(
            transportSequence: 2
        )
        XCTAssertEqual(t1, t2)

        var dst = ByteBuffer()
        let _ = try t2.marshalTo(&dst)
        XCTAssertEqual(raw, dst)
    }

    func test_transport_cc_extension_extra_bytes() throws {
        let raw = ByteBuffer(bytes: [0x00, 0x02, 0x00, 0xff, 0xff])
        let t1 = try TransportCcExtension(raw)
        let t2 = TransportCcExtension(
            transportSequence: 2
        )
        XCTAssertEqual(t1, t2)
    }

}
