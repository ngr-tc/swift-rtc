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
import NIOCore
import RTP

///NOTE: Auth tag and AEAD auth tag are placed at the different position in SRTCP
///
///In non-AEAD cipher, the authentication tag is placed *after* the ESRTCP word
///(Encrypted-flag and SRTCP index).
///
///> AES_128_CM_HMAC_SHA1_80
///> | RTCP Header | Encrypted payload |E| SRTCP Index | Auth tag |
///>                                   ^               |----------|
///>                                   |                ^
///>                                   |                authTagLen=10
///>                                   aeadAuthTagLen=0
///
///In AEAD cipher, the AEAD authentication tag is embedded in the ciphertext.
///It is *before* the ESRTCP word (Encrypted-flag and SRTCP index).
///
///> AEAD_AES_128_GCM
///> | RTCP Header | Encrypted payload | AEAD auth tag |E| SRTCP Index |
///>                                   |---------------|               ^
///>                                    ^                              authTagLen=0
///>                                    aeadAuthTagLen=16
///
///See https://tools.ietf.org/html/rfc7714 for the full specifications.

/// Cipher represents a implementation of one
/// of the SRTP Specific ciphers.
protocol Cipher {
    /// Get RTP authenticated tag length.
    func rtpAuthTagLen() -> Int

    /// Get RTCP authenticated tag length.
    func rtcpAuthTagLen() -> Int

    /// Get AEAD auth key length of the cipher.
    func aeadAuthTagLen() -> Int

    /// Retrieved RTCP index.
    func getRtcpIndex(payload: ByteBufferView) throws -> UInt32

    /// Encrypt RTP payload.
    mutating func encryptRtp(
        payload: ByteBufferView,
        header: RTP.Header,
        roc: UInt32
    ) throws -> ByteBuffer

    /// Encrypt RTCP payload.
    mutating func encryptRtcp(
        plaintext: ByteBufferView,
        srtcpIndex: UInt32,
        ssrc: UInt32
    ) throws -> ByteBuffer

    /// Decrypt RTP payload.
    mutating func decryptRtp(
        ciphertext: ByteBufferView,
        header: RTP.Header,
        roc: UInt32
    ) throws -> ByteBuffer

    /// Decrypt RTCP payload.
    mutating func decryptRtcp(
        ciphertext: ByteBufferView,
        srtcpIndex: UInt32,
        ssrc: UInt32
    ) throws -> ByteBuffer
}
