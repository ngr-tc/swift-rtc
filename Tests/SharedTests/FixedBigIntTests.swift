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

@testable import Shared

final class FixedBigIntTests: XCTestCase {
    func testFixedBigIntSetBit() throws {
        var bi = FixedBigInt(n: 224)

        bi.setBit(0)
        XCTAssertEqual(
            bi.description,
            "0000000000000000000000000000000000000000000000000000000000000001"
        )

        bi.lsh(1)
        XCTAssertEqual(
            bi.description,
            "0000000000000000000000000000000000000000000000000000000000000002"
        )

        bi.lsh(0)
        XCTAssertEqual(
            bi.description,
            "0000000000000000000000000000000000000000000000000000000000000002"
        )

        bi.setBit(10)
        XCTAssertEqual(
            bi.description,
            "0000000000000000000000000000000000000000000000000000000000000402"
        )
        bi.lsh(20)
        XCTAssertEqual(
            bi.description,
            "0000000000000000000000000000000000000000000000000000000040200000"
        )

        bi.setBit(80)
        XCTAssertEqual(
            bi.description,
            "0000000000000000000000000000000000000000000100000000000040200000"
        )
        bi.lsh(4)
        XCTAssertEqual(
            bi.description,
            "0000000000000000000000000000000000000000001000000000000402000000"
        )

        bi.setBit(130)
        XCTAssertEqual(
            bi.description,
            "0000000000000000000000000000000400000000001000000000000402000000"
        )
        bi.lsh(64)
        XCTAssertEqual(
            bi.description,
            "0000000000000004000000000010000000000004020000000000000000000000"
        )

        bi.setBit(7)
        XCTAssertEqual(
            bi.description,
            "0000000000000004000000000010000000000004020000000000000000000080"
        )

        bi.lsh(129)
        XCTAssertEqual(
            bi.description,
            "0000000004000000000000000000010000000000000000000000000000000000"
        )

        for _ in 0..<256 {
            bi.lsh(1)
            bi.setBit(0)
        }
        XCTAssertEqual(
            bi.description,
            "00000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
        )
    }
}
