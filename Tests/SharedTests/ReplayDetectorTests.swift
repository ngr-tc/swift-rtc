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

final class ReplayDetectorTests: XCTestCase {
    func testReplayDetector() throws {
        let largeSeq: UInt64 = 0x1000_0000_0000

        let tests: [(String, UInt, UInt64, [UInt64], [Bool], [UInt64], [UInt64])] = [
            (
                "Continuous",
                16,
                0x0000_FFFF_FFFF_FFFF,
                [
                    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                ],
                [
                    true, true, true, true, true, true, true, true, true, true, true, true, true,
                    true,
                    true, true, true, true, true, true, true,
                ],
                [
                    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                ],
                []
            ),
            (
                "ValidLargeJump",
                16,
                0x0000_FFFF_FFFF_FFFF,
                [
                    0,
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    7,
                    8,
                    9,
                    largeSeq,
                    11,
                    largeSeq + 1,
                    largeSeq + 2,
                    largeSeq + 3,
                ],
                [
                    true, true, true, true, true, true, true, true, true, true, true, true, true,
                    true,
                    true,
                ],
                [
                    0,
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    7,
                    8,
                    9,
                    largeSeq,
                    largeSeq + 1,
                    largeSeq + 2,
                    largeSeq + 3,
                ],
                []
            ),
            (
                "InvalidLargeJump",
                16,
                0x0000_FFFF_FFFF_FFFF,
                [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, largeSeq, 11, 12, 13, 14, 15],
                [
                    true, true, true, true, true, true, true, true, true, true, false, true, true,
                    true, true, true,
                ],
                [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15],
                []
            ),
            (
                "DuplicateAfterValidJump",
                196,
                0x0000_FFFF_FFFF_FFFF,
                [0, 1, 2, 129, 0, 1, 2],
                [true, true, true, true, true, true, true],
                [0, 1, 2, 129],
                []
            ),
            (
                "DuplicateAfterInvalidJump",
                196,
                0x0000_FFFF_FFFF_FFFF,
                [0, 1, 2, 128, 0, 1, 2],
                [true, true, true, false, true, true, true],
                [0, 1, 2],
                []
            ),
            (
                "ContinuousOffset",
                16,
                0x0000_FFFF_FFFF_FFFF,
                [
                    100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114,
                ],
                [
                    true, true, true, true, true, true, true, true, true, true, true, true, true,
                    true,
                    true,
                ],
                [
                    100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114,
                ],
                []
            ),
            (
                "Reordered",
                128,
                0x0000_FFFF_FFFF_FFFF,
                [
                    96, 64, 16, 80, 32, 48, 8, 24, 88, 40, 128, 56, 72, 112, 104, 120,
                ],
                [
                    true, true, true, true, true, true, true, true, true, true, true, true, true,
                    true,
                    true, true,
                ],
                [
                    96, 64, 16, 80, 32, 48, 8, 24, 88, 40, 128, 56, 72, 112, 104, 120,
                ],
                []
            ),
            (
                "Old",
                100,
                0x0000_FFFF_FFFF_FFFF,
                [
                    24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, 128, 8, 16,
                ],
                [
                    true, true, true, true, true, true, true, true, true, true, true, true, true,
                    true,
                    true, true,
                ],
                [24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, 128],
                []
            ),
            (
                "ContinuouesReplayed",
                8,
                0x0000_FFFF_FFFF_FFFF,
                [
                    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
                ],
                [
                    true, true, true, true, true, true, true, true, true, true, true, true, true,
                    true,
                    true, true, true, true, true, true,
                ],
                [16, 17, 18, 19, 20, 21, 22, 23, 24, 25],
                []
            ),
            (
                "ReplayedLater",
                128,
                0x0000_FFFF_FFFF_FFFF,
                [
                    16, 32, 48, 64, 80, 96, 112, 128, 16, 32, 48, 64, 80, 96, 112, 128,
                ],
                [
                    true, true, true, true, true, true, true, true, true, true, true, true, true,
                    true,
                    true, true,
                ],
                [16, 32, 48, 64, 80, 96, 112, 128],
                []
            ),
            (
                "ReplayedQuick",
                128,
                0x0000_FFFF_FFFF_FFFF,
                [
                    16, 16, 32, 32, 48, 48, 64, 64, 80, 80, 96, 96, 112, 112, 128, 128,
                ],
                [
                    true, true, true, true, true, true, true, true, true, true, true, true, true,
                    true,
                    true, true,
                ],
                [16, 32, 48, 64, 80, 96, 112, 128],
                []
            ),
            (
                "Strict",
                0,
                0x0000_FFFF_FFFF_FFFF,
                [1, 3, 2, 4, 5, 6, 7, 8, 9, 10],
                [true, true, true, true, true, true, true, true, true, true],
                [1, 3, 4, 5, 6, 7, 8, 9, 10],
                []
            ),
            (
                "Overflow",
                128,
                0x0000_FFFF_FFFF_FFFF,
                [
                    0x0000_FFFF_FFFF_FFFE,
                    0x0000_FFFF_FFFF_FFFF,
                    0x0001_0000_0000_0000,
                    0x0001_0000_0000_0001,
                ],
                [true, true, true, true],
                [0x0000_FFFF_FFFF_FFFE, 0x0000_FFFF_FFFF_FFFF],
                []
            ),
            (
                "WrapContinuous",
                64,
                0xFFFF,
                [
                    0xFFFC, 0xFFFD, 0xFFFE, 0xFFFF, 0x0000, 0x0001, 0x0002, 0x0003,
                ],
                [true, true, true, true, true, true, true, true],
                [0xFFFC, 0xFFFD, 0xFFFE, 0xFFFF],
                [
                    0xFFFC, 0xFFFD, 0xFFFE, 0xFFFF, 0x0000, 0x0001, 0x0002, 0x0003,
                ]
            ),
            (
                "WrapReordered",
                64,
                0xFFFF,
                [
                    0xFFFD, 0xFFFC, 0x0002, 0xFFFE, 0x0000, 0x0001, 0xFFFF, 0x0003,
                ],
                [true, true, true, true, true, true, true, true],
                [0xFFFD, 0xFFFC, 0xFFFE, 0xFFFF],
                [
                    0xFFFD, 0xFFFC, 0x0002, 0xFFFE, 0x0000, 0x0001, 0xFFFF, 0x0003,
                ]
            ),
            (
                "WrapReorderedReplayed",
                64,
                0xFFFF,
                [
                    0xFFFD, 0xFFFC, 0xFFFC, 0x0002, 0xFFFE, 0xFFFC, 0x0000, 0x0001, 0x0001, 0xFFFF,
                    0x0001, 0x0003,
                ],
                [
                    true, true, true, true, true, true, true, true, true, true, true, true,
                ],
                [0xFFFD, 0xFFFC, 0xFFFE, 0xFFFF],
                [
                    0xFFFD, 0xFFFC, 0x0002, 0xFFFE, 0x0000, 0x0001, 0xFFFF, 0x0003,
                ]
            ),
        ]

        for (name, windowSize, maxSeq, input, valid, expected, var expectedWrap) in tests {
            if expectedWrap.isEmpty {
                expectedWrap.append(contentsOf: expected)
            }

            for k in 0..<2 {
                var det: ReplayDetector =
                    k == 0
                    ? SlidingWindowDetector(windowSize: windowSize, maxSeq: maxSeq)
                    : WrappedSlidingWindowDetector(windowSize: windowSize, maxSeq: maxSeq)
                let exp = k == 0 ? expected : expectedWrap

                var out: [UInt64] = []
                for (i, seq) in input.enumerated() {
                    let ok = det.check(seq: seq)
                    if ok && valid[i] {
                        out.append(seq)
                        det.accept()
                    }
                }

                XCTAssertEqual(out, exp, "\(name) failed")
            }
        }
    }
}
