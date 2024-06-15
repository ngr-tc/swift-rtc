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

final class TransportLayerNackTests: XCTestCase {
    func testTransportLayerNackUnmarshal() throws {
        let tests = [
            (
                "valid",
                ByteBuffer(bytes: [
                    // TransportLayerNack
                    0x81, 0xcd, 0x0, 0x3,  // sender=0x902f9e2e
                    0x90, 0x2f, 0x9e, 0x2e,  // media=0x902f9e2e
                    0x90, 0x2f, 0x9e, 0x2e,  // nack 0xAAAA, 0x5555
                    0xaa, 0xaa, 0x55, 0x55,
                ]),
                TransportLayerNack(
                    senderSsrc: 0x902f_9e2e,
                    mediaSsrc: 0x902f_9e2e,
                    nacks: [
                        NackPair(
                            packetId: 0xaaaa,
                            lostPackets: 0x5555
                        )
                    ]
                ),
                nil
            ),
            (
                "short report",
                ByteBuffer(bytes: [
                    0x81, 0xcd, 0x0, 0x2,  // ssrc=0x902f9e2e
                    0x90, 0x2f, 0x9e, 0x2e,
                    // report ends early
                ]),
                TransportLayerNack(),
                RtcpError.errPacketTooShort
            ),
            (
                "wrong type",
                ByteBuffer(bytes: [
                    // v=2, p=0, count=1, SR, len=7
                    0x81, 0xc8, 0x0, 0x7,  // ssrc=0x902f9e2e
                    0x90, 0x2f, 0x9e, 0x2e,  // ssrc=0xbc5e9a40
                    0xbc, 0x5e, 0x9a, 0x40,  // fracLost=0, totalLost=0
                    0x0, 0x0, 0x0, 0x0,  // lastSeq=0x46e1
                    0x0, 0x0, 0x46, 0xe1,  // jitter=273
                    0x0, 0x0, 0x1, 0x11,  // lsr=0x9f36432
                    0x9, 0xf3, 0x64, 0x32,  // delay=150137
                    0x0, 0x2, 0x4a, 0x79,
                ]),
                TransportLayerNack(),
                RtcpError.errWrongType
            ),
            (
                "nil",
                ByteBuffer(bytes: []),
                TransportLayerNack(),
                RtcpError.errPacketTooShort
            ),
        ]

        for (name, data, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try TransportLayerNack.unmarshal(data)
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? TransportLayerNack.unmarshal(data)
                XCTAssertTrue(got != nil)
                let (actual, _) = got!
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testTransportLayerNackRoundtrip() throws {
        let tests: [(String, TransportLayerNack, RtcpError?)] = [
            (
                "valid",
                TransportLayerNack(
                    senderSsrc: 0x902f_9e2e,
                    mediaSsrc: 0x902f_9e2e,
                    nacks: [
                        NackPair(
                            packetId: 1,
                            lostPackets: 0xAA
                        ),
                        NackPair(
                            packetId: 1034,
                            lostPackets: 0x05
                        ),
                    ]
                ),
                nil
            )
        ]

        for (name, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try want.marshal()
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? want.marshal()
                XCTAssertTrue(got != nil)
                let data = got!
                let (actual, _) = try TransportLayerNack.unmarshal(data)
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testNackPair() throws {
        let testNack = { (s: [UInt16], n: NackPair) in
            let l = n.packetList()

            XCTAssertEqual(s, l, "\(n): expected \(s), got \(l)")
        }

        testNack(
            [42],
            NackPair(
                packetId: 42,
                lostPackets: 0
            )
        )

        testNack(
            [42, 43],
            NackPair(
                packetId: 42,
                lostPackets: 1
            )
        )

        testNack(
            [42, 44],
            NackPair(
                packetId: 42,
                lostPackets: 2
            )
        )

        testNack(
            [42, 43, 44],
            NackPair(
                packetId: 42,
                lostPackets: 3
            )
        )

        testNack(
            [42, UInt16(42 + 16)],
            NackPair(
                packetId: 42,
                lostPackets: 0x8000
            )
        )

        // Wrap around
        testNack(
            [65534, 65535, 0, 1],
            NackPair(
                packetId: 65534,
                lostPackets: 0b0000_0111
            )
        )

        // Gap
        testNack(
            [123, 125, 127, 129],
            NackPair(
                packetId: 123,
                lostPackets: 0b0010_1010
            )
        )
    }

    func testNackPairRange() {
        let n = NackPair(
            packetId: 42,
            lostPackets: 2
        )

        var out1: [UInt16] = []
        n.range(f: { (s: UInt16) -> Bool in
            out1.append(s)
            return true
        })

        XCTAssertEqual([42, 44], out1)

        var out2: [UInt16] = []
        n.range(f: { (s: UInt16) -> Bool in
            out2.append(s)
            return false
        })

        XCTAssertEqual([42], out2)
    }

    func testTransportLayerNackPairGeneration() throws {
        let test: [(String, [UInt16], [NackPair])] = [
            ("No Sequence Numbers", [], []),
            (
                "Single Sequence Number",
                [100],
                [
                    NackPair(
                        packetId: 100,
                        lostPackets: 0x0
                    )
                ]
            ),
            // Make sure it doesn't crash.
            (
                "Single Sequence Number (duplicates)",
                [100, 100],
                [
                    NackPair(
                        packetId: 100,
                        lostPackets: 0x0
                    )
                ]
            ),
            (
                "Multiple in range, Single NACKPair",
                [100, 101, 105, 115],
                [
                    NackPair(
                        packetId: 100,
                        lostPackets: 0x4011
                    )
                ]
            ),
            (
                "Multiple Ranges, Multiple NACKPair",
                [100, 117, 500, 501, 502],
                [
                    NackPair(
                        packetId: 100,
                        lostPackets: 0
                    ),
                    NackPair(
                        packetId: 117,
                        lostPackets: 0
                    ),
                    NackPair(
                        packetId: 500,
                        lostPackets: 0x3
                    ),
                ]
            ),
            (
                "Multiple Ranges, Multiple NACKPair",
                [100, 117, 500, 501, 502],
                [
                    NackPair(
                        packetId: 100,
                        lostPackets: 0
                    ),
                    NackPair(
                        packetId: 117,
                        lostPackets: 0
                    ),
                    NackPair(
                        packetId: 500,
                        lostPackets: 0x3
                    ),
                ]
            ),
            (
                "Multiple Ranges, Multiple NACKPair (with rollover)",
                [100, 117, 65534, 65535, 0, 1, 99],
                [
                    NackPair(
                        packetId: 100,
                        lostPackets: 0
                    ),
                    NackPair(
                        packetId: 117,
                        lostPackets: 0
                    ),
                    NackPair(
                        packetId: 65534,
                        lostPackets: 1
                    ),
                    NackPair(
                        packetId: 0,
                        lostPackets: 1
                    ),
                    NackPair(
                        packetId: 99,
                        lostPackets: 0
                    ),
                ]
            ),
        ]

        for (name, var seqNumbers, expected) in test {
            let actual = nackPairsFromSequenceNumbers(&seqNumbers)

            XCTAssertEqual(
                actual, expected,
                "\(name) NackPair generation mismatch"
            )
        }
    }

    /// This test case reproduced a bug in the implementation
    func testLostPacketsIsResetWhenCrossing16BitBoundary() throws {
        var seq: [UInt16] = []
        for i in 0...17 {
            seq.append(UInt16(i))
        }
        XCTAssertEqual(
            nackPairsFromSequenceNumbers(&seq),
            [
                NackPair(
                    packetId: 0,
                    lostPackets: 0b1111_1111_1111_1111
                ),
                NackPair(
                    packetId: 17,
                    // Was 0xffff before fixing the bug
                    lostPackets: 0b0000_0000_0000_0000
                ),
            ]
        )
    }
}
