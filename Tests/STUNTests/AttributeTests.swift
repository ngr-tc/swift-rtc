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

final class AttributeTests: XCTestCase {
    func testRawAttributeAddTo() throws {
        let v: ByteBuffer = ByteBuffer([1, 2, 3, 4])
        var m = Message()
        let ra = RawAttribute(
            typ: attrData,
            length: 0,
            value: v
        )
        try m.build([ra])
        let gotV = try m.get(attrData)
        XCTAssertEqual(gotV, v)
    }

    func testMessageGetNoAllocs() throws {
        var m = Message()
        let a = TextAttribute(
            attr: attrSoftware,
            text: "c"
        )
        try a.addTo(&m)
        m.writeHeader()

        //"Default"
        let _ = try m.get(attrSoftware)

        //"Not found"
        do {
            let _ = try m.get(attrOrigin)
            XCTAssertTrue(false, "should error")
        } catch StunError.errAttributeNotFound {
            XCTAssertTrue(true)
        }
    }

    func testPadding() throws {
        let tt = [
            (4, 4),  // 0
            (2, 4),  // 1
            (5, 8),  // 2
            (8, 8),  // 3
            (11, 12),  // 4
            (1, 4),  // 5
            (3, 4),  // 6
            (6, 8),  // 7
            (7, 8),  // 8
            (0, 0),  // 9
            (40, 40),  // 10
        ]

        for (i, o) in tt {
            let got = nearestPaddedValueLength(i)
            XCTAssertEqual(got, o)
        }
    }

    func testAttrTypeRange() throws {
        let tests1 = [
            attrPriority,
            attrErrorCode,
            attrUseCandidate,
            attrEvenPort,
            attrRequestedAddressFamily,
        ]
        for a in tests1 {
            XCTAssertTrue(!a.optional() && a.required(), "should be required")
        }

        let tests2 = [attrSoftware, attrIceControlled, attrOrigin]
        for a in tests2 {
            XCTAssertTrue(!a.required() && a.optional(), "should be optional")
        }
    }
}
