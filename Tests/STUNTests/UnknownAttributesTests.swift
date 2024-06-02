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

@testable import STUN

final class UnknownAttributesTests: XCTestCase {
    func testUnknownAttributes() throws {
        var m = Message()
        let a = UnknownAttributes(attributes: [attrDontFragment, attrChannelNumber])
        XCTAssertEqual(a.description, "DONT-FRAGMENT, CHANNEL-NUMBER")
        XCTAssertEqual(UnknownAttributes().description, "<nil>")

        try a.addTo(&m)

        //"GetFrom"
        do {
            var attrs = UnknownAttributes()
            try attrs.getFrom(&m)
            for i in 0..<a.attributes.count {
                XCTAssertEqual(a.attributes[i], attrs.attributes[i])
            }

            var mBlank = Message()
            do {
                let _ = try attrs.getFrom(&mBlank)
                XCTAssertTrue(false, "should error")
            } catch {
                XCTAssertTrue(true)
            }

            mBlank.add(attrUnknownAttributes, ByteBufferView([1, 2, 3]))
            do {
                let _ = try attrs.getFrom(&mBlank)
                XCTAssertTrue(false, "should error")
            } catch {
                XCTAssertTrue(true)
            }
        }
    }
}
