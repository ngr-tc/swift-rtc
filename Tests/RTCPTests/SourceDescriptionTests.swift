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

final class SourceDescriptionTests: XCTestCase {
    func testSourceDescriptionUnmarshal() throws {
        let tests: [(String, ByteBuffer, SourceDescription, RtcpError?)] =
            [
                (
                    "nil",
                    ByteBuffer(bytes: []),
                    SourceDescription(),
                    RtcpError.errPacketTooShort
                ),
                (
                    "no chunks",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SDES, len=8
                        0x80, 0xca, 0x00, 0x04,
                    ]),
                    SourceDescription(),
                    nil
                ),
                (
                    "missing type",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SDES, len=8
                        0x81, 0xca, 0x00, 0x08,  // ssrc=0x00000000
                        0x00, 0x00, 0x00, 0x00,
                    ]),
                    SourceDescription(),
                    RtcpError.errPacketTooShort
                ),
                (
                    "bad cname length",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SDES, len=10
                        0x81, 0xca, 0x00, 0x0a,  // ssrc=0x00000000
                        0x00, 0x00, 0x00, 0x00,  // CNAME, len = 1
                        0x01, 0x01,
                    ]),
                    SourceDescription(),
                    RtcpError.errPacketTooShort
                ),
                (
                    "short cname",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SDES, len=9
                        0x81, 0xca, 0x00, 0x09,  // ssrc=0x00000000
                        0x00, 0x00, 0x00, 0x00,  // CNAME, Missing length
                        0x01,
                    ]),
                    SourceDescription(),
                    RtcpError.errPacketTooShort
                ),
                (
                    "no end",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SDES, len=11
                        0x81, 0xca, 0x00, 0x0b,  // ssrc=0x00000000
                        0x00, 0x00, 0x00, 0x00,  // CNAME, len=1, content=A
                        0x01, 0x02, 0x41,
                        // Missing END
                    ]),
                    SourceDescription(),
                    RtcpError.errPacketTooShort
                ),
                (
                    "bad octet count",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SDES, len=10
                        0x81, 0xca, 0x00, 0x0a,  // ssrc=0x00000000
                        0x00, 0x00, 0x00, 0x00,  // CNAME, len=1
                        0x01, 0x01,
                    ]),
                    SourceDescription(),
                    RtcpError.errPacketTooShort
                ),
                (
                    "zero item chunk",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SDES, len=12
                        0x81, 0xca, 0x00, 0x0c,  // ssrc=0x01020304
                        0x01, 0x02, 0x03, 0x04,  // END + padding
                        0x00, 0x00, 0x00, 0x00,
                    ]),
                    SourceDescription(
                        chunks: [
                            SourceDescriptionChunk(
                                source: 0x0102_0304,
                                items: []
                            )
                        ]
                    ),
                    nil
                ),
                (
                    "wrong type",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SR, len=12
                        0x81, 0xc8, 0x00, 0x0c,  // ssrc=0x01020304
                        0x01, 0x02, 0x03, 0x04,  // END + padding
                        0x00, 0x00, 0x00, 0x00,
                    ]),
                    SourceDescription(),
                    RtcpError.errWrongType
                ),
                (
                    "bad count in header",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SDES, len=12
                        0x81, 0xca, 0x00, 0x0c,
                    ]),
                    SourceDescription(),
                    RtcpError.errInvalidHeader
                ),
                (
                    "empty string",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SDES, len=12
                        0x81, 0xca, 0x00, 0x0c,  // ssrc=0x01020304
                        0x01, 0x02, 0x03, 0x04,  // CNAME, len=0
                        0x01, 0x00,  // END + padding
                        0x00, 0x00,
                    ]),
                    SourceDescription(
                        chunks: [
                            SourceDescriptionChunk(
                                source: 0x0102_0304,
                                items: [
                                    SourceDescriptionItem(
                                        sdesType: SdesType.sdesCname,
                                        text: ByteBuffer(string: "")
                                    )
                                ]
                            )
                        ]
                    ),
                    nil
                ),
                (
                    "two items",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=1, SDES, len=16
                        0x81, 0xca, 0x00, 0x10,  // ssrc=0x10000000
                        0x10, 0x00, 0x00, 0x00,  // CNAME, len=1, content=A
                        0x01, 0x01, 0x41,  // PHONE, len=1, content=B
                        0x04, 0x01, 0x42,  // END + padding
                        0x00, 0x00,
                    ]),
                    SourceDescription(
                        chunks: [
                            SourceDescriptionChunk(
                                source: 0x1000_0000,
                                items: [
                                    SourceDescriptionItem(
                                        sdesType: SdesType.sdesCname,
                                        text: ByteBuffer(string: "A")
                                    ),
                                    SourceDescriptionItem(
                                        sdesType: SdesType.sdesPhone,
                                        text: ByteBuffer(string: "B")
                                    ),
                                ]
                            )
                        ]
                    ),
                    nil
                ),
                (
                    "two chunks",
                    ByteBuffer(bytes: [
                        // v=2, p=0, count=2, SDES, len=24
                        0x82, 0xca, 0x00, 0x18,  // ssrc=0x01020304
                        0x01, 0x02, 0x03, 0x04,
                        // Chunk 1
                        // CNAME, len=1, content=A
                        0x01, 0x01, 0x41,  // END
                        0x00,  // Chunk 2
                        // SSRC 0x05060708
                        0x05, 0x06, 0x07, 0x08,  // CNAME, len=3, content=BCD
                        0x01, 0x03, 0x42, 0x43, 0x44,  // END
                        0x00, 0x00, 0x00,
                    ]),
                    SourceDescription(
                        chunks: [
                            SourceDescriptionChunk(
                                source: 0x0102_0304,
                                items: [
                                    SourceDescriptionItem(
                                        sdesType: SdesType.sdesCname,
                                        text: ByteBuffer(string: "A")
                                    )
                                ]
                            ),
                            SourceDescriptionChunk(
                                source: 0x0506_0708,
                                items: [
                                    SourceDescriptionItem(
                                        sdesType: SdesType.sdesCname,
                                        text: ByteBuffer(string: "BCD")
                                    )
                                ]
                            ),
                        ]
                    ),
                    nil
                ),
            ]

        for (name, data, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try SourceDescription.unmarshal(data)
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? SourceDescription.unmarshal(data)
                XCTAssertTrue(got != nil)
                let (actual, _) = got!
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testSourceDescriptionRoundtrip() throws {
        var tooLongText = String()
        for _ in 0..<(1 << 8) {
            tooLongText += "x"
        }

        var tooManyChunks: [SourceDescriptionChunk] = []
        for _ in 0..<(1 << 5) {
            tooManyChunks.append(SourceDescriptionChunk())
        }

        let tests = [
            (
                "valid",
                SourceDescription(
                    chunks: [
                        SourceDescriptionChunk(
                            source: 1,
                            items: [
                                SourceDescriptionItem(
                                    sdesType: SdesType.sdesCname,
                                    text: ByteBuffer(string: "test@example.com")
                                )
                            ]
                        ),
                        SourceDescriptionChunk(
                            source: 2,
                            items: [
                                SourceDescriptionItem(
                                    sdesType: SdesType.sdesNote,
                                    text: ByteBuffer(string: "some note")
                                ),
                                SourceDescriptionItem(
                                    sdesType: SdesType.sdesNote,
                                    text: ByteBuffer(string: "another note")
                                ),
                            ]
                        ),
                    ]
                ),
                nil
            ),
            (
                "item without type",
                SourceDescription(
                    chunks: [
                        SourceDescriptionChunk(
                            source: 1,
                            items: [
                                SourceDescriptionItem(
                                    sdesType: SdesType.sdesEnd,
                                    text: ByteBuffer(string: "test@example.com")
                                )
                            ]
                        )
                    ]
                ),
                RtcpError.errSdesMissingType
            ),
            (
                "zero items",
                SourceDescription(
                    chunks: [
                        SourceDescriptionChunk(
                            source: 1,
                            items: []
                        )
                    ]
                ),
                nil
            ),
            (
                "email item",
                SourceDescription(
                    chunks: [
                        SourceDescriptionChunk(
                            source: 1,
                            items: [
                                SourceDescriptionItem(
                                    sdesType: SdesType.sdesEmail,
                                    text: ByteBuffer(string: "test@example.com")
                                )
                            ]
                        )
                    ]
                ),
                nil
            ),
            (
                "empty text",
                SourceDescription(
                    chunks: [
                        SourceDescriptionChunk(
                            source: 1,
                            items: [
                                SourceDescriptionItem(
                                    sdesType: SdesType.sdesCname,
                                    text: ByteBuffer(string: "")
                                )
                            ]
                        )
                    ]
                ),
                nil
            ),
            (
                "text too long",
                SourceDescription(
                    chunks: [
                        SourceDescriptionChunk(
                            source: 1,
                            items: [
                                SourceDescriptionItem(
                                    sdesType: SdesType.sdesCname,
                                    text: ByteBuffer(string: tooLongText)
                                )
                            ]
                        )
                    ]
                ),
                RtcpError.errSdesTextTooLong
            ),
            (
                "count overflow",
                SourceDescription(
                    chunks: tooManyChunks
                ),
                RtcpError.errTooManyChunks
            ),
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
                let (actual, _) = try SourceDescription.unmarshal(data)
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }
}
