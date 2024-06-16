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

final class TransportLayerCcTests: XCTestCase {
    func testTransportLayerCcRunLengthChunkUnmarshal() throws {
        let tests = [
            (
                // 3.1.3 example1: https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-7
                "example1",
                ByteBuffer(bytes: [0, 0xDD]),
                RunLengthChunk(
                    typeTcc: StatusChunkTypeTcc.runLengthChunk,
                    packetStatusSymbol: SymbolTypeTcc.packetNotReceived,
                    runLength: 221
                )
            ),
            (
                // 3.1.3 example2: https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-7
                "example2",
                ByteBuffer(bytes: [0x60, 0x18]),
                RunLengthChunk(
                    typeTcc: StatusChunkTypeTcc.runLengthChunk,
                    packetStatusSymbol: SymbolTypeTcc.packetReceivedWithoutDelta,
                    runLength: 24
                )
            ),
        ]

        for (name, data, want) in tests {
            let (got, _) = try RunLengthChunk.unmarshal(data)
            XCTAssertEqual(got, want, "Unmarshal \(name)")
        }
    }

    func testTransportLayerCcRunLengthChunkMarshal() throws {
        let tests = [
            (
                // 3.1.3 example1: https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-7
                "example1",
                RunLengthChunk(
                    typeTcc: StatusChunkTypeTcc.runLengthChunk,
                    packetStatusSymbol: SymbolTypeTcc.packetNotReceived,
                    runLength: 221
                ),
                ByteBuffer(bytes: [0, 0xDD])
            ),
            (
                // 3.1.3 example2: https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-7
                "example2",
                RunLengthChunk(
                    typeTcc: StatusChunkTypeTcc.runLengthChunk,
                    packetStatusSymbol: SymbolTypeTcc.packetReceivedWithoutDelta,
                    runLength: 24
                ),
                ByteBuffer(bytes: [0x60, 0x18])
            ),
        ]

        for (name, chunk, want) in tests {
            let got = try chunk.marshal()
            XCTAssertEqual(got, want, "Marshal \(name)")
        }
    }

    func testTransportLayerCcStatusVectorChunkUnmarshal() throws {
        let tests = [
            (
                // 3.1.4 example1: https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-7
                "example1",
                ByteBuffer(bytes: [0x9F, 0x1C]),
                StatusVectorChunk(
                    typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                    symbolSize: SymbolSizeTypeTcc.oneBit,
                    symbolList: [
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetNotReceived,
                    ]
                )
            ),
            (
                // 3.1.4 example2: https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-7
                "example2",
                ByteBuffer(bytes: [0xCD, 0x50]),
                StatusVectorChunk(
                    typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                    symbolSize: SymbolSizeTypeTcc.twoBit,
                    symbolList: [
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetReceivedWithoutDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetNotReceived,
                    ]
                )
            ),
        ]

        for (name, data, want) in tests {
            let (got, _) = try StatusVectorChunk.unmarshal(data)
            XCTAssertEqual(got, want, "Unmarshal \(name) : err")
        }
    }

    func testTransportLayerCcStatusVectorChunkMarshal() throws {
        let tests = [
            (
                //3.1.4 example1: https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-7
                "example1",
                StatusVectorChunk(
                    typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                    symbolSize: SymbolSizeTypeTcc.oneBit,
                    symbolList: [
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetNotReceived,
                    ]
                ),
                ByteBuffer(bytes: [0x9F, 0x1C])
            ),
            (
                //3.1.4 example2: https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-7
                "example2",
                StatusVectorChunk(
                    typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                    symbolSize: SymbolSizeTypeTcc.twoBit,
                    symbolList: [
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetReceivedWithoutDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetReceivedSmallDelta,
                        SymbolTypeTcc.packetNotReceived,
                        SymbolTypeTcc.packetNotReceived,
                    ]
                ),
                ByteBuffer(bytes: [0xCD, 0x50])
            ),
        ]

        for (name, chunk, want) in tests {
            let got = try chunk.marshal()
            XCTAssertEqual(got, want, "Marshal \(name): err")
        }
    }

    func testTransportLayerCcRecvDeltaUnmarshal() throws {
        let tests = [
            (
                "small delta 63.75ms",
                ByteBuffer(bytes: [0xFF]),
                RecvDelta(
                    typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                    // 255 * 250
                    delta: 63750
                )
            ),
            (
                "big delta 8191.75ms",
                ByteBuffer(bytes: [0x7F, 0xFF]),
                RecvDelta(
                    typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                    // 32767 * 250
                    delta: 8_191_750
                )
            ),
            (
                "big delta -8192ms",
                ByteBuffer(bytes: [0x80, 0x00]),
                RecvDelta(
                    typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                    // -32768 * 250
                    delta: -8_192_000
                )
            ),
        ]

        for (name, data, want) in tests {
            let (got, _) = try RecvDelta.unmarshal(data)
            XCTAssertEqual(got, want, "Unmarshal \(name) : err")
        }
    }

    func testTransportLayerCcRecvDeltaMarshal() throws {
        let tests = [
            (
                "small delta 63.75ms",
                RecvDelta(
                    typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                    // 255 * 250
                    delta: 63750
                ),
                ByteBuffer(bytes: [0xFF])
            ),
            (
                "big delta 8191.75ms",
                RecvDelta(
                    typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                    // 32767 * 250
                    delta: 8_191_750
                ),
                ByteBuffer(bytes: [0x7F, 0xFF])
            ),
            (
                "big delta -8192ms",
                RecvDelta(
                    typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                    // -32768 * 250
                    delta: -8_192_000
                ),
                ByteBuffer(bytes: [0x80, 0x00])
            ),
        ]

        for (name, chunk, want) in tests {
            let got = try chunk.marshal()
            XCTAssertEqual(got, want, "Marshal \(name): err")
        }
    }

    /// 0                   1                   2                   3
    /// 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    /// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    /// |V=2|P|  FMT=15 |    PT=205     |           length              |
    /// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    /// |                     SSRC of packet sender                     |
    /// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    /// |                      SSRC of media source                     |
    /// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    /// |      base sequence number     |      packet status count      |
    /// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    /// |                 reference time                | fb pkt. count |
    /// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    /// |         packet chunk          |  recv delta   |  recv delta   |
    /// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    /// 0b10101111,0b11001101,0b00000000,0b00000101,
    /// 0b11111010,0b00010111,0b11111010,0b00010111,
    /// 0b01000011,0b00000011,0b00101111,0b10100000,
    /// 0b00000000,0b10011001,0b00000000,0b00000001,
    /// 0b00111101,0b11101000,0b00000010,0b00010111,
    /// 0b00100000,0b00000001,0b10010100,0b00000001,
    func testTransportLayerCcUnmarshal() throws {
        let tests = [
            (
                "example1",
                ByteBuffer(bytes: [
                    0xaf, 0xcd, 0x0, 0x5, 0xfa, 0x17, 0xfa, 0x17, 0x43, 0x3, 0x2f, 0xa0, 0x0, 0x99,
                    0x0, 0x1, 0x3d, 0xe8, 0x2, 0x17, 0x20, 0x1, 0x94, 0x1,
                ]),
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 1_124_282_272,
                    baseSequenceNumber: 153,
                    packetStatusCount: 1,
                    referenceTime: 4_057_090,
                    fbPktCount: 23,
                    // 0b00100000, 0b00000001
                    packetChunks: [
                        PacketStatusChunk.runLengthChunk(
                            RunLengthChunk(
                                typeTcc: StatusChunkTypeTcc.runLengthChunk,
                                packetStatusSymbol: SymbolTypeTcc.packetReceivedSmallDelta,
                                runLength: 1
                            ))
                    ],
                    // 0b10010100
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 37000
                        )
                    ]
                )
            ),
            (
                "example2",
                ByteBuffer(bytes: [
                    0xaf, 0xcd, 0x0, 0x6, 0xfa, 0x17, 0xfa, 0x17, 0x19, 0x3d, 0xd8, 0xbb, 0x1, 0x74,
                    0x0, 0xe, 0x45, 0xb1, 0x5a, 0x40, 0xd8, 0x0, 0xf0, 0xff, 0xd0, 0x0, 0x0, 0x3,
                ]),
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 423_483_579,
                    baseSequenceNumber: 372,
                    packetStatusCount: 14,
                    referenceTime: 4_567_386,
                    fbPktCount: 64,
                    packetChunks: [
                        PacketStatusChunk.statusVectorChunk(
                            StatusVectorChunk(
                                typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                                symbolSize: SymbolSizeTypeTcc.twoBit,
                                symbolList: [
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedLargeDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                ]
                            )),
                        PacketStatusChunk.statusVectorChunk(
                            StatusVectorChunk(
                                typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                                symbolSize: SymbolSizeTypeTcc.twoBit,
                                symbolList: [
                                    SymbolTypeTcc.packetReceivedWithoutDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetReceivedWithoutDelta,
                                    SymbolTypeTcc.packetReceivedWithoutDelta,
                                    SymbolTypeTcc.packetReceivedWithoutDelta,
                                    SymbolTypeTcc.packetReceivedWithoutDelta,
                                ]
                            )),
                    ],
                    // 0b10010100
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 52000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                            delta: 0
                        ),
                    ]
                )
            ),
            (
                "example3",
                ByteBuffer(bytes: [
                    0x8f, 0xcd, 0x0, 0x7, 0xfa, 0x17, 0xfa, 0x17, 0x19, 0x3d, 0xd8, 0xbb, 0x1, 0x74,
                    0x0, 0x6, 0x45, 0xb1, 0x5a, 0x40, 0x40, 0x2, 0x20, 0x04, 0x1f, 0xfe, 0x1f, 0x9a,
                    0xd0, 0x0, 0xd0, 0x0,
                ]),
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 423_483_579,
                    baseSequenceNumber: 372,
                    packetStatusCount: 6,
                    referenceTime: 4_567_386,
                    fbPktCount: 64,
                    packetChunks: [
                        PacketStatusChunk.runLengthChunk(
                            RunLengthChunk(
                                typeTcc: StatusChunkTypeTcc.runLengthChunk,
                                packetStatusSymbol: SymbolTypeTcc.packetReceivedLargeDelta,
                                runLength: 2
                            )),
                        PacketStatusChunk.runLengthChunk(
                            RunLengthChunk(
                                typeTcc: StatusChunkTypeTcc.runLengthChunk,
                                packetStatusSymbol: SymbolTypeTcc.packetReceivedSmallDelta,
                                runLength: 4
                            )),
                    ],
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                            delta: 2_047_500
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                            delta: 2_022_500
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 52000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 0
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 52000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 0
                        ),
                    ]
                )
            ),
            (
                "example4",
                ByteBuffer(bytes: [
                    0xaf, 0xcd, 0x0, 0x7, 0xfa, 0x17, 0xfa, 0x17, 0x19, 0x3d, 0xd8, 0xbb, 0x0, 0x4,
                    0x0, 0x7, 0x10, 0x63, 0x6e, 0x1, 0x20, 0x7, 0x4c, 0x24, 0x24, 0x10, 0xc, 0xc,
                    0x10,
                    0x0, 0x0, 0x3,
                ]),
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 423_483_579,
                    baseSequenceNumber: 4,
                    packetStatusCount: 7,
                    referenceTime: 1_074_030,
                    fbPktCount: 1,
                    packetChunks: [
                        PacketStatusChunk.runLengthChunk(
                            RunLengthChunk(
                                typeTcc: StatusChunkTypeTcc.runLengthChunk,
                                packetStatusSymbol: SymbolTypeTcc.packetReceivedSmallDelta,
                                runLength: 7
                            ))
                    ],
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 19000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 9000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 9000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 4000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 3000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 3000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 4000
                        ),
                    ]
                )
            ),
            (
                "example5",
                ByteBuffer(bytes: [
                    0xaf, 0xcd, 0x0, 0x6, 0xfa, 0x17, 0xfa, 0x17, 0x19, 0x3d, 0xd8, 0xbb, 0x0, 0x1,
                    0x0, 0xe, 0x10, 0x63, 0x6d, 0x0, 0xba, 0x0, 0x10, 0xc, 0xc, 0x10, 0x0, 0x3,
                ]),
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 423_483_579,
                    baseSequenceNumber: 1,
                    packetStatusCount: 14,
                    referenceTime: 1_074_029,
                    fbPktCount: 0,
                    packetChunks: [
                        PacketStatusChunk.statusVectorChunk(
                            StatusVectorChunk(
                                typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                                symbolSize: SymbolSizeTypeTcc.oneBit,
                                symbolList: [
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                ]
                            ))
                    ],
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 4000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 3000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 3000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 4000
                        ),
                    ]
                )
            ),
            (
                "example6",
                ByteBuffer(bytes: [
                    0xaf, 0xcd, 0x0, 0x7, 0x9b, 0x74, 0xf6, 0x1f, 0x93, 0x71, 0xdc, 0xbc, 0x85,
                    0x3c,
                    0x0, 0x9, 0x63, 0xf9, 0x16, 0xb3, 0xd5, 0x52, 0x0, 0x30, 0x9b, 0xaa, 0x6a, 0xaa,
                    0x7b, 0x1, 0x9, 0x1,
                ]),
                TransportLayerCc(
                    senderSsrc: 2_608_133_663,
                    mediaSsrc: 2_473_712_828,
                    baseSequenceNumber: 34108,
                    packetStatusCount: 9,
                    referenceTime: 6_551_830,
                    fbPktCount: 179,
                    packetChunks: [
                        PacketStatusChunk.statusVectorChunk(
                            StatusVectorChunk(
                                typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                                symbolSize: SymbolSizeTypeTcc.twoBit,
                                symbolList: [
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetReceivedLargeDelta,
                                ]
                            )),
                        PacketStatusChunk.runLengthChunk(
                            RunLengthChunk(
                                typeTcc: StatusChunkTypeTcc.runLengthChunk,
                                packetStatusSymbol: SymbolTypeTcc.packetNotReceived,
                                runLength: 48
                            )),
                    ],
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 38750
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 42500
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 26500
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 42500
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 30750
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                            delta: 66250
                        ),
                    ]
                )
            ),
            (
                "example3",
                ByteBuffer(bytes: [
                    0x8f, 0xcd, 0x0, 0x4, 0x9a, 0xcb, 0x4, 0x42, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                    0x0, 0x0, 0x0, 0x0, 0x0,
                ]),
                TransportLayerCc(
                    senderSsrc: 2_596_996_162,
                    mediaSsrc: 0,
                    baseSequenceNumber: 0,
                    packetStatusCount: 0,
                    referenceTime: 0,
                    fbPktCount: 0,
                    packetChunks: [],
                    recvDeltas: []
                )
            ),
        ]

        for (name, data, want) in tests {
            let (got, _) = try TransportLayerCc.unmarshal(data)
            XCTAssertEqual(got, want, "Unmarshal \(name) : err")
        }
    }

    func testTransportLayerCcMarshal() throws {
        let tests = [
            (
                "example1",
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 1_124_282_272,
                    baseSequenceNumber: 153,
                    packetStatusCount: 1,
                    referenceTime: 4_057_090,
                    fbPktCount: 23,
                    // 0b00100000, 0b00000001
                    packetChunks: [
                        PacketStatusChunk.runLengthChunk(
                            RunLengthChunk(
                                typeTcc: StatusChunkTypeTcc.runLengthChunk,
                                packetStatusSymbol: SymbolTypeTcc.packetReceivedSmallDelta,
                                runLength: 1
                            ))
                    ],
                    // 0b10010100
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 37000
                        )
                    ]
                ),
                ByteBuffer(bytes: [
                    0xaf, 0xcd, 0x0, 0x5, 0xfa, 0x17, 0xfa, 0x17, 0x43, 0x3, 0x2f, 0xa0, 0x0, 0x99,
                    0x0, 0x1, 0x3d, 0xe8, 0x2, 0x17, 0x20, 0x1, 0x94, 0x1,
                ])
            ),
            (
                "example2",
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 423_483_579,
                    baseSequenceNumber: 372,
                    packetStatusCount: 2,
                    referenceTime: 4_567_386,
                    fbPktCount: 64,
                    packetChunks: [
                        PacketStatusChunk.statusVectorChunk(
                            StatusVectorChunk(
                                typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                                symbolSize: SymbolSizeTypeTcc.twoBit,
                                symbolList: [
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedLargeDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                ]
                            )),
                        PacketStatusChunk.statusVectorChunk(
                            StatusVectorChunk(
                                typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                                symbolSize: SymbolSizeTypeTcc.twoBit,
                                symbolList: [
                                    SymbolTypeTcc.packetReceivedWithoutDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetReceivedWithoutDelta,
                                    SymbolTypeTcc.packetReceivedWithoutDelta,
                                    SymbolTypeTcc.packetReceivedWithoutDelta,
                                    SymbolTypeTcc.packetReceivedWithoutDelta,
                                ]
                            )),
                    ],
                    // 0b10010100
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 52000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                            delta: 0
                        ),
                    ]
                ),
                ByteBuffer(bytes: [
                    0xaf, 0xcd, 0x0, 0x6, 0xfa, 0x17, 0xfa, 0x17, 0x19, 0x3d, 0xd8, 0xbb, 0x1, 0x74,
                    0x0, 0x2, 0x45, 0xb1, 0x5a, 0x40, 0xd8, 0x0, 0xf0, 0xff, 0xd0, 0x0, 0x0, 0x1,
                ])
            ),
            (
                "example3",
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 423_483_579,
                    baseSequenceNumber: 372,
                    packetStatusCount: 6,
                    referenceTime: 4_567_386,
                    fbPktCount: 64,
                    packetChunks: [
                        PacketStatusChunk.runLengthChunk(
                            RunLengthChunk(
                                typeTcc: StatusChunkTypeTcc.runLengthChunk,
                                packetStatusSymbol: SymbolTypeTcc.packetReceivedLargeDelta,
                                runLength: 2
                            )),
                        PacketStatusChunk.runLengthChunk(
                            RunLengthChunk(
                                typeTcc: StatusChunkTypeTcc.runLengthChunk,
                                packetStatusSymbol: SymbolTypeTcc.packetReceivedSmallDelta,
                                runLength: 4
                            )),
                    ],
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                            delta: 2_047_500
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedLargeDelta,
                            delta: 2_022_500
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 52000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 0
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 52000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 0
                        ),
                    ]
                ),
                ByteBuffer(bytes: [
                    0x8f, 0xcd, 0x0, 0x7, 0xfa, 0x17, 0xfa, 0x17, 0x19, 0x3d, 0xd8, 0xbb, 0x1, 0x74,
                    0x0, 0x6, 0x45, 0xb1, 0x5a, 0x40, 0x40, 0x2, 0x20, 0x04, 0x1f, 0xfe, 0x1f, 0x9a,
                    0xd0, 0x0, 0xd0, 0x0,
                ])
            ),
            (
                "example4",
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 423_483_579,
                    baseSequenceNumber: 4,
                    packetStatusCount: 7,
                    referenceTime: 1_074_030,
                    fbPktCount: 1,
                    packetChunks: [
                        PacketStatusChunk.runLengthChunk(
                            RunLengthChunk(
                                typeTcc: StatusChunkTypeTcc.runLengthChunk,
                                packetStatusSymbol: SymbolTypeTcc.packetReceivedSmallDelta,
                                runLength: 7
                            ))
                    ],
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 19000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 9000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 9000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 4000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 3000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 3000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 4000
                        ),
                    ]
                ),
                ByteBuffer(bytes: [
                    0xaf, 0xcd, 0x0, 0x7, 0xfa, 0x17, 0xfa, 0x17, 0x19, 0x3d, 0xd8, 0xbb, 0x0, 0x4,
                    0x0, 0x7, 0x10, 0x63, 0x6e, 0x1, 0x20, 0x7, 0x4c, 0x24, 0x24, 0x10, 0xc, 0xc,
                    0x10,
                    0x0, 0x0, 0x3,
                ])
            ),
            (
                "example5",
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 423_483_579,
                    baseSequenceNumber: 1,
                    packetStatusCount: 14,
                    referenceTime: 1_074_029,
                    fbPktCount: 0,
                    packetChunks: [
                        PacketStatusChunk.statusVectorChunk(
                            StatusVectorChunk(
                                typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                                symbolSize: SymbolSizeTypeTcc.oneBit,
                                symbolList: [
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                ]
                            ))
                    ],
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 4000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 3000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 3000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 4000
                        ),
                    ]
                ),
                ByteBuffer(bytes: [
                    0xaf, 0xcd, 0x0, 0x6, 0xfa, 0x17, 0xfa, 0x17, 0x19, 0x3d, 0xd8, 0xbb, 0x0, 0x1,
                    0x0, 0xe, 0x10, 0x63, 0x6d, 0x0, 0xba, 0x0, 0x10, 0xc, 0xc, 0x10, 0x0, 0x2,
                ])
            ),
            (
                "example6",
                TransportLayerCc(
                    senderSsrc: 4_195_875_351,
                    mediaSsrc: 1_124_282_272,
                    baseSequenceNumber: 39956,
                    packetStatusCount: 12,
                    referenceTime: 7_701_536,
                    fbPktCount: 0,
                    packetChunks: [
                        PacketStatusChunk.statusVectorChunk(
                            StatusVectorChunk(
                                typeTcc: StatusChunkTypeTcc.statusVectorChunk,
                                symbolSize: SymbolSizeTypeTcc.oneBit,
                                symbolList: [
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetReceivedSmallDelta,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                    SymbolTypeTcc.packetNotReceived,
                                ]
                            ))
                    ],
                    recvDeltas: [
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 48250
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 15750
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 14750
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 15750
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 20750
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 36000
                        ),
                        RecvDelta(
                            typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                            delta: 14750
                        ),
                    ]
                ),
                ByteBuffer(bytes: [
                    0xaf, 0xcd, 0x0, 0x7, 0xfa, 0x17, 0xfa, 0x17, 0x43, 0x3, 0x2f, 0xa0, 0x9c, 0x14,
                    0x0, 0xc, 0x75, 0x84, 0x20, 0x0, 0xbe, 0xc0, 0xc1, 0x3f, 0x3b, 0x3f, 0x53, 0x90,
                    0x3b, 0x0, 0x0, 0x3,
                ])
            ),
        ]

        for (name, chunk, want) in tests {
            let got = try chunk.marshal()
            XCTAssertEqual(got, want, "Marshal \(name): err")
        }
    }
}
