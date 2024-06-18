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

final class KeyDerivationTests: XCTestCase {
    func testValidSessionKeys() throws {
        // Key Derivation Test Vectors from https://tools.ietf.org/html/rfc3711#appendix-B.3
        let masterKey = ByteBuffer(bytes: [
            0xE1, 0xF9, 0x7A, 0x0D, 0x3E, 0x01, 0x8B, 0xE0, 0xD6, 0x4F, 0xA3, 0x2C, 0x06, 0xDE,
            0x41, 0x39,
        ])
        let masterSalt = ByteBuffer(bytes: [
            0x0E, 0xC6, 0x75, 0xAD, 0x49, 0x8A, 0xFE, 0xEB, 0xB6, 0x96, 0x0B, 0x3A, 0xAB, 0xE6,
        ])

        let expectedSessionKey = ByteBuffer(bytes: [
            0xC6, 0x1E, 0x7A, 0x93, 0x74, 0x4F, 0x39, 0xEE, 0x10, 0x73, 0x4A, 0xFE, 0x3F, 0xF7,
            0xA0, 0x87,
        ])
        let expectedSessionSalt = ByteBuffer(bytes: [
            0x30, 0xCB, 0xBC, 0x08, 0x86, 0x3D, 0x8C, 0x85, 0xD4, 0x9D, 0xB3, 0x4A, 0x9A, 0xE1,
        ])
        let expectedSessionAuthTag = ByteBuffer(bytes: [
            0xCE, 0xBE, 0x32, 0x1F, 0x6F, 0xF7, 0x71, 0x6B, 0x6F, 0xD4, 0xAB, 0x49, 0xAF, 0x25,
            0x6A, 0x15, 0x6D, 0x38, 0xBA, 0xA4,
        ])

        let sessionKey = try aesCmKeyDerivation(
            label: labelSrtpEncryption,
            masterKey: masterKey.readableBytesView,
            masterSalt: masterSalt.readableBytesView,
            indexOverKdr: 0,
            outLen: masterKey.readableBytes
        )
        XCTAssertEqual(ByteBuffer(bytes: sessionKey), expectedSessionKey)

        let sessionSalt = try aesCmKeyDerivation(
            label: labelSrtpSalt,
            masterKey: masterKey.readableBytesView,
            masterSalt: masterSalt.readableBytesView,
            indexOverKdr: 0,
            outLen: masterSalt.readableBytes
        )
        XCTAssertEqual(ByteBuffer(bytes: sessionSalt), expectedSessionSalt)

        let authKeyLen = ProtectionProfile.aes128CmHmacSha180.authKeyLen()
        let sessionAuthTag = try aesCmKeyDerivation(
            label: lableSrtpAuthenticationTag,
            masterKey: masterKey.readableBytesView,
            masterSalt: masterSalt.readableBytesView,
            indexOverKdr: 0,
            outLen: authKeyLen
        )
        XCTAssertEqual(ByteBuffer(bytes: sessionAuthTag), expectedSessionAuthTag)
    }

    // This test asserts that calling aesCmKeyDerivation with a non-zero indexOverKdr fails
    // Currently this isn't supported, but the API makes sure we can add this in the future
    func testIndexOverKdr() throws {
        let result = try? aesCmKeyDerivation(
            label: lableSrtpAuthenticationTag,
            masterKey: ByteBuffer().readableBytesView,
            masterSalt: ByteBuffer().readableBytesView,
            indexOverKdr: 1,
            outLen: 0)
        XCTAssertTrue(result == nil)
    }
}
