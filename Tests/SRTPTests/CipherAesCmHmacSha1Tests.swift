import NIOCore
import RTP
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

@testable import SRTP

func getRtcpIndex(encrypted: ByteBufferView, authTagLen: Int) -> UInt32 {
    let tailOffset = encrypted.count - (authTagLen + srtcpIndexSize)
    let rtcpIndex = UInt32.fromBeBytes(
        encrypted.at(tailOffset),
        encrypted.at(tailOffset + 1),
        encrypted.at(tailOffset + 2),
        encrypted.at(tailOffset + 3))
    return rtcpIndex & 0x7FFF_FFFF  //^(1 << 31)
}

func buildTestContext() throws -> Context {
    let masterKey = ByteBuffer(bytes: [
        0x0d, 0xcd, 0x21, 0x3e, 0x4c, 0xbc, 0xf2, 0x8f, 0x01, 0x7f, 0x69, 0x94, 0x40, 0x1e, 0x28,
        0x89,
    ])
    let masterSalt = ByteBuffer(bytes: [
        0x62, 0x77, 0x60, 0x38, 0xc0, 0x6d, 0xc9, 0x41, 0x9f, 0x6d, 0xd9, 0x43, 0x3e, 0x7c,
    ])

    return try Context(
        masterKey: masterKey.readableBytesView,
        masterSalt: masterSalt.readableBytesView,
        profile: ProtectionProfile.aes128CmHmacSha1Tag80,
        srtpCtxOpt: nil,
        srtcpCtxOpt: nil
    )
}

final class CipherAesCmHmacSha1Tests: XCTestCase {

    let rtcpTestMasterKey: ByteBuffer = ByteBuffer(bytes: [
        0xfd, 0xa6, 0x25, 0x95, 0xd7, 0xf6, 0x92, 0x6f, 0x7d, 0x9c, 0x02, 0x4c, 0xc9, 0x20, 0x9f,
        0x34,
    ])

    let rtcpTestMasterSalt: ByteBuffer = ByteBuffer(bytes: [
        0xa9, 0x65, 0x19, 0x85, 0x54, 0x0b, 0x47, 0xbe, 0x2f, 0x27, 0xa8, 0xb8, 0x81, 0x23,
    ])

    let rtcpTtestCases:
        [(
            ssrc: UInt32,
            index: UInt32,
            encrypted: ByteBuffer,
            decrypted: ByteBuffer
        )] = [
            (
                ssrc: 0x66ef_91ff,
                index: 0,
                encrypted: ByteBuffer(bytes: [
                    0x80, 0xc8, 0x00, 0x06, 0x66, 0xef, 0x91, 0xff, 0xcd, 0x34, 0xc5, 0x78, 0xb2,
                    0x8b,
                    0xe1, 0x6b, 0xc5, 0x09, 0xd5, 0x77, 0xe4, 0xce, 0x5f, 0x20, 0x80, 0x21, 0xbd,
                    0x66,
                    0x74, 0x65, 0xe9, 0x5f, 0x49, 0xe5, 0xf5, 0xc0, 0x68, 0x4e, 0xe5, 0x6a, 0x78,
                    0x07,
                    0x75, 0x46, 0xed, 0x90, 0xf6, 0xdc, 0x9d, 0xef, 0x3b, 0xdf, 0xf2, 0x79, 0xa9,
                    0xd8,
                    0x80, 0x00, 0x00, 0x01, 0x60, 0xc0, 0xae, 0xb5, 0x6f, 0x40, 0x88, 0x0e, 0x28,
                    0xba,
                ]),
                decrypted: ByteBuffer(bytes: [
                    0x80, 0xc8, 0x00, 0x06, 0x66, 0xef, 0x91, 0xff, 0xdf, 0x48, 0x80, 0xdd, 0x61,
                    0xa6,
                    0x2e, 0xd3, 0xd8, 0xbc, 0xde, 0xbe, 0x00, 0x00, 0x00, 0x09, 0x00, 0x00, 0x16,
                    0x04,
                    0x81, 0xca, 0x00, 0x06, 0x66, 0xef, 0x91, 0xff, 0x01, 0x10, 0x52, 0x6e, 0x54,
                    0x35,
                    0x43, 0x6d, 0x4a, 0x68, 0x7a, 0x79, 0x65, 0x74, 0x41, 0x78, 0x77, 0x2b, 0x00,
                    0x00,
                ])
            ),
            (
                ssrc: 0x1111_1111,
                index: 0,
                encrypted: ByteBuffer(bytes: [
                    0x80, 0xc8, 0x00, 0x06, 0x11, 0x11, 0x11, 0x11, 0x17, 0x8c, 0x15, 0xf1, 0x4b,
                    0x11,
                    0xda, 0xf5, 0x74, 0x53, 0x86, 0x2b, 0xc9, 0x07, 0x29, 0x40, 0xbf, 0x22, 0xf6,
                    0x46,
                    0x11, 0xa4, 0xc1, 0x3a, 0xff, 0x5a, 0xbd, 0xd0, 0xf8, 0x8b, 0x38, 0xe4, 0x95,
                    0x38,
                    0x5d, 0xcf, 0x1b, 0xf5, 0x27, 0x77, 0xfb, 0xdb, 0x3f, 0x10, 0x68, 0x99, 0xd8,
                    0xad,
                    0x80, 0x00, 0x00, 0x01, 0x34, 0x3c, 0x2e, 0x83, 0x17, 0x13, 0x93, 0x69, 0xcf,
                    0xc0,
                ]),
                decrypted: ByteBuffer(bytes: [
                    0x80, 0xc8, 0x00, 0x06, 0x11, 0x11, 0x11, 0x11, 0xdf, 0x48, 0x80, 0xdd, 0x61,
                    0xa6,
                    0x2e, 0xd3, 0xd8, 0xbc, 0xde, 0xbe, 0x00, 0x00, 0x00, 0x09, 0x00, 0x00, 0x16,
                    0x04,
                    0x81, 0xca, 0x00, 0x06, 0x66, 0xef, 0x91, 0xff, 0x01, 0x10, 0x52, 0x6e, 0x54,
                    0x35,
                    0x43, 0x6d, 0x4a, 0x68, 0x7a, 0x79, 0x65, 0x74, 0x41, 0x78, 0x77, 0x2b, 0x00,
                    0x00,
                ])
            ),
            (
                ssrc: 0x1111_1111,
                index: 0x7fff_fffe,  // Upper boundary of index
                encrypted: ByteBuffer(bytes: [
                    0x80, 0xc8, 0x00, 0x06, 0x11, 0x11, 0x11, 0x11, 0x17, 0x8c, 0x15, 0xf1, 0x4b,
                    0x11,
                    0xda, 0xf5, 0x74, 0x53, 0x86, 0x2b, 0xc9, 0x07, 0x29, 0x40, 0xbf, 0x22, 0xf6,
                    0x46,
                    0x11, 0xa4, 0xc1, 0x3a, 0xff, 0x5a, 0xbd, 0xd0, 0xf8, 0x8b, 0x38, 0xe4, 0x95,
                    0x38,
                    0x5d, 0xcf, 0x1b, 0xf5, 0x27, 0x77, 0xfb, 0xdb, 0x3f, 0x10, 0x68, 0x99, 0xd8,
                    0xad,
                    0xff, 0xff, 0xff, 0xff, 0x5a, 0x99, 0xce, 0xed, 0x9f, 0x2e, 0x4d, 0x9d, 0xfa,
                    0x97,
                ]),
                decrypted: ByteBuffer(bytes: [
                    0x80, 0xc8, 0x0, 0x6, 0x11, 0x11, 0x11, 0x11, 0x4, 0x99, 0x47, 0x53, 0xc4, 0x1e,
                    0xb9, 0xde, 0x52, 0xa3, 0x1d, 0x77, 0x2f, 0xff, 0xcc, 0x75, 0xbb, 0x6a, 0x29,
                    0xb8,
                    0x1, 0xb7, 0x2e, 0x4b, 0x4e, 0xcb, 0xa4, 0x81, 0x2d, 0x46, 0x4, 0x5e, 0x86,
                    0x90,
                    0x17, 0x4f, 0x4d, 0x78, 0x2f, 0x58, 0xb8, 0x67, 0x91, 0x89, 0xe3, 0x61, 0x1,
                    0x7d,
                ])
            ),
            (
                ssrc: 0x1111_1111,
                index: 0x7fff_ffff,  // Will be wrapped to 0
                encrypted: ByteBuffer(bytes: [
                    0x80, 0xc8, 0x00, 0x06, 0x11, 0x11, 0x11, 0x11, 0x17, 0x8c, 0x15, 0xf1, 0x4b,
                    0x11,
                    0xda, 0xf5, 0x74, 0x53, 0x86, 0x2b, 0xc9, 0x07, 0x29, 0x40, 0xbf, 0x22, 0xf6,
                    0x46,
                    0x11, 0xa4, 0xc1, 0x3a, 0xff, 0x5a, 0xbd, 0xd0, 0xf8, 0x8b, 0x38, 0xe4, 0x95,
                    0x38,
                    0x5d, 0xcf, 0x1b, 0xf5, 0x27, 0x77, 0xfb, 0xdb, 0x3f, 0x10, 0x68, 0x99, 0xd8,
                    0xad,
                    0x80, 0x00, 0x00, 0x00, 0x7d, 0x51, 0xf8, 0x0e, 0x56, 0x40, 0x72, 0x7b, 0x9e,
                    0x02,
                ]),
                decrypted: ByteBuffer(bytes: [
                    0x80, 0xc8, 0x0, 0x6, 0x11, 0x11, 0x11, 0x11, 0xda, 0xb5, 0xe0, 0x56, 0x9a,
                    0x4a,
                    0x74, 0xed, 0x8a, 0x54, 0xc, 0xcf, 0xd5, 0x9, 0xb1, 0x40, 0x1, 0x42, 0xc3, 0x9a,
                    0x76, 0x0, 0xa9, 0xd4, 0xf7, 0x29, 0x9e, 0x51, 0xfb, 0x3c, 0xc1, 0x74, 0x72,
                    0xf9,
                    0x52, 0xb1, 0x92, 0x31, 0xca, 0x22, 0xab, 0x3e, 0xc5, 0x5f, 0x83, 0x34, 0xf0,
                    0x28,
                ])
            ),
        ]

    func testRtcpLifecycle() throws {
        var encryptContext = try Context(
            masterKey: rtcpTestMasterKey.readableBytesView,
            masterSalt: rtcpTestMasterSalt.readableBytesView,
            profile: ProtectionProfile.aes128CmHmacSha1Tag80,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )
        var decryptContext = try Context(
            masterKey: rtcpTestMasterKey.readableBytesView,
            masterSalt: rtcpTestMasterSalt.readableBytesView,
            profile: ProtectionProfile.aes128CmHmacSha1Tag80,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )

        for testCase in rtcpTtestCases {
            let decryptResult = try decryptContext.decryptRtcp(
                encrypted: testCase.encrypted.readableBytesView)
            XCTAssertEqual(
                decryptResult, testCase.decrypted,
                "RTCP failed to decrypt"
            )

            encryptContext.setIndex(ssrc: testCase.ssrc, index: testCase.index)
            let encryptResult = try encryptContext.encryptRtcp(
                decrypted: testCase.decrypted.readableBytesView)
            XCTAssertEqual(
                encryptResult, testCase.encrypted,
                "RTCP failed to encrypt"
            )
        }
    }

    func testRtcpInvalidAuthTag() throws {
        let authTagLen = ProtectionProfile.aes128CmHmacSha1Tag80.rtcpAuthTagLen()

        var decryptContext = try Context(
            masterKey: rtcpTestMasterKey.readableBytesView,
            masterSalt: rtcpTestMasterSalt.readableBytesView,
            profile: ProtectionProfile.aes128CmHmacSha1Tag80,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )

        let decryptResult = try decryptContext.decryptRtcp(
            encrypted: rtcpTtestCases[0].encrypted.readableBytesView)
        XCTAssertEqual(
            decryptResult, rtcpTtestCases[0].decrypted,
            "RTCP failed to decrypt"
        )

        // Zero out auth tag
        var rtcpPacket = ByteBuffer()
        rtcpPacket.writeImmutableBuffer(rtcpTtestCases[0].encrypted)
        let rtcpPacketLen = rtcpPacket.readableBytes
        rtcpPacket.setBytes(
            Array(repeating: 0, count: authTagLen), at: rtcpPacketLen - authTagLen)
        let decryptResult2 = try? decryptContext.decryptRtcp(
            encrypted: rtcpPacket.readableBytesView)
        XCTAssertTrue(
            decryptResult2 == nil,
            "Was able to decrypt RTCP packet with invalid Auth Tag"
        )
    }

    func testRtcpReplayDetectorSeparation() throws {
        var decryptContext = try Context(
            masterKey: rtcpTestMasterKey.readableBytesView,
            masterSalt: rtcpTestMasterSalt.readableBytesView,
            profile: ProtectionProfile.aes128CmHmacSha1Tag80,
            srtpCtxOpt: nil,
            srtcpCtxOpt: srtcpReplayProtection(windowSize: 10)
        )

        let decryptResult1 = try decryptContext.decryptRtcp(
            encrypted: rtcpTtestCases[0].encrypted.readableBytesView)
        XCTAssertEqual(
            decryptResult1, rtcpTtestCases[0].decrypted,
            "RTCP failed to decrypt"
        )

        let decryptResult2 = try decryptContext.decryptRtcp(
            encrypted: rtcpTtestCases[1].encrypted.readableBytesView)
        XCTAssertEqual(
            decryptResult2, rtcpTtestCases[1].decrypted,
            "RTCP failed to decrypt"
        )

        var result = try? decryptContext.decryptRtcp(
            encrypted: rtcpTtestCases[0].encrypted.readableBytesView)
        XCTAssertTrue(
            result == nil,
            "Was able to decrypt duplicated RTCP packet"
        )

        result = try? decryptContext.decryptRtcp(
            encrypted: rtcpTtestCases[1].encrypted.readableBytesView)
        XCTAssertTrue(
            result == nil,
            "Was able to decrypt duplicated RTCP packet"
        )
    }

    func testEncryptRtcpSeparation() throws {
        var encryptContext = try Context(
            masterKey: rtcpTestMasterKey.readableBytesView,
            masterSalt: rtcpTestMasterSalt.readableBytesView,
            profile: ProtectionProfile.aes128CmHmacSha1Tag80,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )

        let authTagLen = ProtectionProfile.aes128CmHmacSha1Tag80.rtcpAuthTagLen()

        var decryptContext = try Context(
            masterKey: rtcpTestMasterKey.readableBytesView,
            masterSalt: rtcpTestMasterSalt.readableBytesView,
            profile: ProtectionProfile.aes128CmHmacSha1Tag80,
            srtpCtxOpt: nil,
            srtcpCtxOpt: srtcpReplayProtection(windowSize: 10)
        )

        let inputs = [
            rtcpTtestCases[0].decrypted,
            rtcpTtestCases[1].decrypted,
            rtcpTtestCases[0].decrypted,
            rtcpTtestCases[1].decrypted,
        ]
        var encryptedRctps: [ByteBuffer] = []

        for input in inputs {
            let encrypted = try encryptContext.encryptRtcp(decrypted: input.readableBytesView)
            encryptedRctps.append(encrypted)
        }

        for (i, expectedIndex) in [1, 1, 2, 2].enumerated() {
            XCTAssertEqual(
                UInt32(expectedIndex),
                getRtcpIndex(
                    encrypted: encryptedRctps[i].readableBytesView, authTagLen: authTagLen),
                "RTCP index does not match"
            )
        }

        for (i, output) in encryptedRctps.enumerated() {
            let decrypted = try decryptContext.decryptRtcp(encrypted: output.readableBytesView)
            XCTAssertEqual(inputs[i], decrypted)
        }
    }

    let rtpTestCaseDecrypted: ByteBuffer = ByteBuffer(bytes: [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05,
    ])
    let rtpTestCases: [(sequenceNumber: UInt16, encrypted: ByteBuffer)] = [
        (
            sequenceNumber: 5000,
            encrypted: ByteBuffer(bytes: [
                0x6d, 0xd3, 0x7e, 0xd5, 0x99, 0xb7, 0x2d, 0x28, 0xb1, 0xf3, 0xa1, 0xf0, 0xc, 0xfb,
                0xfd, 0x8,
            ])
        ),
        (
            sequenceNumber: 5001,
            encrypted: ByteBuffer(bytes: [
                0xda, 0x47, 0xb, 0x2a, 0x74, 0x53, 0x65, 0xbd, 0x2f, 0xeb, 0xdc, 0x4b, 0x6d, 0x23,
                0xf3, 0xde,
            ])
        ),
        (
            sequenceNumber: 5002,
            encrypted: ByteBuffer(bytes: [
                0x6e, 0xa7, 0x69, 0x8d, 0x24, 0x6d, 0xdc, 0xbf, 0xec, 0x2, 0x1c, 0xd1, 0x60, 0x76,
                0xc1, 0x0e,
            ])
        ),
        (
            sequenceNumber: 5003,
            encrypted: ByteBuffer(bytes: [
                0x24, 0x7e, 0x96, 0xc8, 0x7d, 0x33, 0xa2, 0x92, 0x8d, 0x13, 0x8d, 0xe0, 0x76, 0x9f,
                0x08, 0xdc,
            ])
        ),
        (
            sequenceNumber: 5004,
            encrypted: ByteBuffer(bytes: [
                0x75, 0x43, 0x28, 0xe4, 0x3a, 0x77, 0x59, 0x9b, 0x2e, 0xdf, 0x7b, 0x12, 0x68, 0x0b,
                0x57, 0x49,
            ])
        ),
        (
            sequenceNumber: 65535,  // upper boundary
            encrypted: ByteBuffer(bytes: [
                0xaf, 0xf7, 0xc2, 0x70, 0x37, 0x20, 0x83, 0x9c, 0x2c, 0x63, 0x85, 0x15, 0x0e, 0x44,
                0xca, 0x36,
            ])
        ),
    ]

    func testRtpInvalidAuth() throws {
        let masterKey = ByteBuffer(bytes: [
            0x0d, 0xcd, 0x21, 0x3e, 0x4c, 0xbc, 0xf2, 0x8f, 0x01, 0x7f, 0x69, 0x94, 0x40, 0x1e,
            0x28,
            0x89,
        ])
        let invalidSalt = ByteBuffer(bytes: [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ])

        var encryptContext = try buildTestContext()
        var invalidContext = try Context(
            masterKey: masterKey.readableBytesView,
            masterSalt: invalidSalt.readableBytesView,
            profile: ProtectionProfile.aes128CmHmacSha1Tag80,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )

        for testCase in rtpTestCases {
            let pkt = RTP.Packet(
                header: RTP.Header(
                    version: 0, padding: false, ext: false, marker: false, payloadType: 0,
                    sequenceNumber: testCase.sequenceNumber, timestamp: 0, ssrc: 0, csrcs: [],
                    extensionProfile: 0, extensions: []
                ),
                payload: rtpTestCaseDecrypted
            )

            let pktRaw = try pkt.marshal()
            let out = try encryptContext.encryptRtp(decrypted: pktRaw.readableBytesView)

            let result = try? invalidContext.decryptRtp(encrypted: out.readableBytesView)
            XCTAssertTrue(
                result == nil,
                "Managed to decrypt with incorrect salt for packet with SeqNum: \(testCase.sequenceNumber)"

            )
        }
    }

    func testRtpLifecyle() throws {
        var encryptContext = try buildTestContext()
        var decryptContext = try buildTestContext()
        let authTagLen = ProtectionProfile.aes128CmHmacSha1Tag80.rtpAuthTagLen()

        for testCase in rtpTestCases {
            let decryptedPkt = RTP.Packet(
                header: RTP.Header(
                    version: 0, padding: false, ext: false, marker: false, payloadType: 0,
                    sequenceNumber: testCase.sequenceNumber, timestamp: 0, ssrc: 0, csrcs: [],
                    extensionProfile: 0, extensions: []
                ),
                payload: rtpTestCaseDecrypted
            )

            let decryptedRaw = try decryptedPkt.marshal()

            let encryptedPkt = RTP.Packet(
                header: RTP.Header(
                    version: 0, padding: false, ext: false, marker: false, payloadType: 0,
                    sequenceNumber: testCase.sequenceNumber, timestamp: 0, ssrc: 0, csrcs: [],
                    extensionProfile: 0, extensions: []
                ),
                payload: testCase.encrypted
            )

            let encryptedRaw = try encryptedPkt.marshal()
            let actualEncrypted = try encryptContext.encryptRtp(
                decrypted: decryptedRaw.readableBytesView)
            XCTAssertEqual(
                actualEncrypted, encryptedRaw,
                "RTP packet with SeqNum invalid encryption: \(testCase.sequenceNumber)"
            )

            let actualDecrypted = try decryptContext.decryptRtp(
                encrypted: encryptedRaw.readableBytesView)
            XCTAssertNotEqual(
                encryptedRaw.getSlice(at: 0, length: encryptedRaw.readableBytes - authTagLen)!,
                actualDecrypted,
                "DecryptRTP improperly encrypted in place"
            )

            XCTAssertEqual(
                actualDecrypted, decryptedRaw,
                "RTP packet with SeqNum invalid decryption: \(testCase.sequenceNumber)"
            )
        }
    }
}
