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

final class BytesTests: XCTestCase {
    func testGetPadding() throws {
        let tests = [(0, 0), (1, 3), (2, 2), (3, 1), (4, 0), (100, 0), (500, 0)]

        for (n, p) in tests {
            XCTAssertEqual(
                getPadding(n),
                p,
                "Test case returned wrong value for input {n}"
            )
        }
    }

    func testSetNbitsOfUInt16() throws {
        let tests: [(String, UInt16, UInt16, UInt16, UInt16, UInt16, String?)] = [
            ("setOneBit", 0, 1, 8, 1, 128, nil),
            ("setStatusVectorBit", 0, 1, 0, 1, 32768, nil),
            ("setStatusVectorSecondBit", 32768, 1, 1, 1, 49152, nil),
            (
                "setStatusVectorInnerBitsAndCutValue",
                49152,
                2,
                6,
                11111,
                49920,
                nil
            ),
            ("setRunLengthSecondTwoBit", 32768, 2, 1, 1, 40960, nil),
            (
                "setOneBitOutOfBounds",
                32768,
                2,
                15,
                1,
                0,
                "invalid size or startIndex"
            ),
        ]

        for (name, source, size, index, value, result, err) in tests {
            let res = setNbitsOfUInt16(source, size, index, value)
            if err != nil {
                XCTAssertTrue(res == nil, "setNBitsOfUint16 \(name) : should be error")
            } else if let got = res {
                XCTAssertEqual(got, result, "setNBitsOfUint16 \(name)")
            } else {
                XCTFail("setNBitsOfUint16 \(name) :unexpected error result")
            }
        }
    }
}
