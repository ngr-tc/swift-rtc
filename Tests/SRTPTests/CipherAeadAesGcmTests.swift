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

@testable import SRTP

final class CipherAeadAesGcmTests: XCTestCase {

    let masterKey: ByteBuffer = ByteBuffer(bytes: [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e,
        0x0f,
    ])
    let masterSalt: ByteBuffer = ByteBuffer(bytes: [
        0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab,
    ])
    let decryptedRtpPacket: ByteBuffer = ByteBuffer(bytes: [
        0x80, 0x0f, 0x12, 0x34, 0xde, 0xca, 0xfb, 0xad, 0xca, 0xfe, 0xba, 0xbe, 0xab, 0xab, 0xab,
        0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab,
    ])
    let encryptedRtpPacket: ByteBuffer = ByteBuffer(bytes: [
        0x80, 0x0f, 0x12, 0x34, 0xde, 0xca, 0xfb, 0xad, 0xca, 0xfe, 0xba, 0xbe, 0xc5, 0x00, 0x2e,
        0xde, 0x04, 0xcf, 0xdd, 0x2e, 0xb9, 0x11, 0x59, 0xe0, 0x88, 0x0a, 0xa0, 0x6e, 0xd2, 0x97,
        0x68, 0x26, 0xf7, 0x96, 0xb2, 0x01, 0xdf, 0x31, 0x31, 0xa1, 0x27, 0xe8, 0xa3, 0x92,
    ])
    let decryptedRtcpPacket: ByteBuffer = ByteBuffer(bytes: [
        0x81, 0xc8, 0x00, 0x0b, 0xca, 0xfe, 0xba, 0xbe, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab,
        0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab,
    ])
    let encryptedRtcpPacket: ByteBuffer = ByteBuffer(bytes: [
        0x81, 0xc8, 0x00, 0x0b, 0xca, 0xfe, 0xba, 0xbe, 0xc9, 0x8b, 0x8b, 0x5d, 0xf0, 0x39, 0x2a,
        0x55, 0x85, 0x2b, 0x6c, 0x21, 0xac, 0x8e, 0x70, 0x25, 0xc5, 0x2c, 0x6f, 0xbe, 0xa2, 0xb3,
        0xb4, 0x46, 0xea, 0x31, 0x12, 0x3b, 0xa8, 0x8c, 0xe6, 0x1e, 0x80, 0x00, 0x00, 0x01,
    ])

    func testEncryptRtp() throws {
        var ctx = try Context(
            masterKey: masterKey.readableBytesView,
            masterSalt: masterSalt.readableBytesView,
            profile: ProtectionProfile.aeadAes128Gcm,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )

        let gottenEncryptedRtpPacket =
            try ctx
            .encryptRtp(decrypted: decryptedRtpPacket.readableBytesView)

        XCTAssertEqual(gottenEncryptedRtpPacket, encryptedRtpPacket)
    }

    func testDecryptrtp() throws {
        var ctx = try Context(
            masterKey: masterKey.readableBytesView,
            masterSalt: masterSalt.readableBytesView,
            profile: ProtectionProfile.aeadAes128Gcm,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )

        let gottenDecryptedRtpPacket =
            try ctx
            .decryptRtp(encrypted: encryptedRtpPacket.readableBytesView)

        XCTAssertEqual(gottenDecryptedRtpPacket, decryptedRtpPacket)
    }

    func testEncryptRtcp() throws {
        var ctx = try Context(
            masterKey: masterKey.readableBytesView,
            masterSalt: masterSalt.readableBytesView,
            profile: ProtectionProfile.aeadAes128Gcm,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )

        let gottenEncryptedRtcpPacket =
            try ctx
            .encryptRtcp(decrypted: decryptedRtcpPacket.readableBytesView)

        XCTAssertEqual(gottenEncryptedRtcpPacket, encryptedRtcpPacket)
    }

    func testDecryptRtcp() throws {
        var ctx = try Context(
            masterKey: masterKey.readableBytesView,
            masterSalt: masterSalt.readableBytesView,
            profile: ProtectionProfile.aeadAes128Gcm,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )

        let gottenDecryptedRtcpPacket =
            try ctx
            .decryptRtcp(encrypted: encryptedRtcpPacket.readableBytesView)

        XCTAssertEqual(gottenDecryptedRtcpPacket, decryptedRtcpPacket)
    }
}
