import Crypto
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
import NIOFoundationCompat
import RTCP
import RTP
import _CryptoExtras

struct CipherAesCmHmacSha1 {
    var profile: ProtectionProfile

    var srtpSessionKey: SymmetricKey
    var srtpSessionSalt: ByteBuffer
    var srtpSessionAuthTag: SymmetricKey

    var srtcpSessionKey: SymmetricKey
    var srtcpSessionSalt: ByteBuffer
    var srtcpSessionAuthTag: SymmetricKey

    var allocator: ByteBufferAllocator

    public init(profile: ProtectionProfile, masterKey: ByteBufferView, masterSalt: ByteBufferView)
        throws
    {
        self.profile = profile

        let srtpSessionKey = try aesCmKeyDerivation(
            label: labelSrtpEncryption,
            masterKey: masterKey,
            masterSalt: masterSalt,
            indexOverKdr: 0,
            outLen: masterKey.count
        )
        self.srtpSessionKey = SymmetricKey(
            data: srtpSessionKey.readableBytesView)

        let srtcpSessionKey = try aesCmKeyDerivation(
            label: labelSrtcpEncryption,
            masterKey: masterKey,
            masterSalt: masterSalt,
            indexOverKdr: 0,
            outLen: masterKey.count
        )
        self.srtcpSessionKey = SymmetricKey(
            data: srtcpSessionKey.readableBytesView)

        self.srtpSessionSalt = try aesCmKeyDerivation(
            label: labelSrtpSalt,
            masterKey: masterKey,
            masterSalt: masterSalt,
            indexOverKdr: 0,
            outLen: masterKey.count
        )

        self.srtcpSessionSalt = try aesCmKeyDerivation(
            label: labelSrtcpSalt,
            masterKey: masterKey,
            masterSalt: masterSalt,
            indexOverKdr: 0,
            outLen: masterKey.count
        )

        let srtpSessionAuthTag = try aesCmKeyDerivation(
            label: labelSrtpAuthenticationTag,
            masterKey: masterKey,
            masterSalt: masterSalt,
            indexOverKdr: 0,
            outLen: profile.authKeyLen()
        )
        self.srtpSessionAuthTag = SymmetricKey(
            data: srtpSessionAuthTag.readableBytesView)

        let srtcpSessionAuthTag = try aesCmKeyDerivation(
            label: labelSrtcpAuthenticationTag,
            masterKey: masterKey,
            masterSalt: masterSalt,
            indexOverKdr: 0,
            outLen: profile.authKeyLen()
        )
        self.srtcpSessionAuthTag = SymmetricKey(
            data: srtcpSessionAuthTag.readableBytesView)

        self.allocator = ByteBufferAllocator()
    }

    /// https://tools.ietf.org/html/rfc3711#section-4.2
    /// In the case of SRTP, M SHALL consist of the Authenticated
    /// Portion of the packet (as specified in Figure 1) concatenated with
    /// the roc, M = Authenticated Portion || roc;
    ///
    /// The pre-defined authentication transform for SRTP is HMAC-SHA1
    /// [RFC2104].  With HMAC-SHA1, the SRTP_PREFIX_LENGTH (Figure 3) SHALL
    /// be 0.  For SRTP (respectively SRTCP), the HMAC SHALL be applied to
    /// the session authentication key and M as specified above, i.e.,
    /// HMAC(k_a, M).  The HMAC output SHALL then be truncated to the n_tag
    /// left-most bits.
    /// - Authenticated portion of the packet is everything BEFORE MKI
    /// - k_a is the session message authentication key
    /// - n_tag is the bit-length of the output authentication tag
    mutating func generateSrtpAuthTag(buf: ByteBufferView, roc: UInt32) throws -> ByteBuffer {
        var srtpSessionAuth: HMAC<SHA256> = HMAC(key: self.srtpSessionAuthTag)

        srtpSessionAuth.update(data: buf)

        // For SRTP only, we need to hash the rollover counter as well.
        srtpSessionAuth.update(data: roc.toBeBytes())

        let mac = srtpSessionAuth.finalize()

        var v = ByteBuffer()
        let _ = mac.withUnsafeBytes { bufferPointer in
            v.writeBytes(bufferPointer)
        }

        // Truncate the hash to the first AUTH_TAG_SIZE bytes.
        guard let authTag = v.readSlice(length: self.profile.authKeyLen()) else {
            throw SrtpError.errTooShortRtpAuthTag
        }

        return authTag
    }

    /// https://tools.ietf.org/html/rfc3711#section-4.2
    ///
    /// The pre-defined authentication transform for SRTP is HMAC-SHA1
    /// [RFC2104].  With HMAC-SHA1, the SRTP_PREFIX_LENGTH (Figure 3) SHALL
    /// be 0.  For SRTP (respectively SRTCP), the HMAC SHALL be applied to
    /// the session authentication key and M as specified above, i.e.,
    /// HMAC(k_a, M).  The HMAC output SHALL then be truncated to the n_tag
    /// left-most bits.
    /// - Authenticated portion of the packet is everything BEFORE MKI
    /// - k_a is the session message authentication key
    /// - n_tag is the bit-length of the output authentication tag
    mutating func generateSrtcpAuthTag(buf: ByteBufferView) throws -> ByteBuffer {
        var srtcpSessionAuth: HMAC<SHA256> = HMAC(key: self.srtcpSessionAuthTag)

        srtcpSessionAuth.update(data: buf)

        let mac = srtcpSessionAuth.finalize()

        var v = ByteBuffer()
        let _ = mac.withUnsafeBytes { bufferPointer in
            v.writeBytes(bufferPointer)
        }

        // Truncate the hash to the first AUTH_TAG_SIZE bytes.
        guard let authTag = v.readSlice(length: self.profile.authKeyLen()) else {
            throw SrtpError.errTooShortRtcpAuthTag
        }

        return authTag
    }
}

extension CipherAesCmHmacSha1: Cipher {
    /// Get RTP authenticated tag length.
    func rtpAuthTagLen() -> Int {
        return profile.rtpAuthTagLen()
    }

    /// Get RTCP authenticated tag length.
    func rtcpAuthTagLen() -> Int {
        return profile.rtcpAuthTagLen()
    }

    /// Get AEAD auth key length of the cipher.
    func aeadAuthTagLen() -> Int {
        return profile.aeadAuthTagLen()
    }

    func getRtcpIndex(payload: ByteBufferView) throws -> UInt32 {
        let tailOffset = payload.count - (self.rtcpAuthTagLen() + srtcpIndexSize)
        return UInt32.fromBeBytes(
            payload[tailOffset],
            payload[tailOffset + 1],
            payload[tailOffset + 2],
            payload[tailOffset + 3]) & ~(UInt32(1) << 31)

    }

    mutating func encryptRtp(
        payload: ByteBufferView,
        header: RTP.Header,
        roc: UInt32
    ) throws -> ByteBuffer {
        // Encrypt the payload
        let counter = try generateCounter(
            sequenceNumber: header.sequenceNumber,
            rolloverCounter: roc,
            ssrc: header.ssrc,
            sessionSalt: self.srtpSessionSalt.readableBytesView
        )
        let nonce = try AES._CTR.Nonce(nonceBytes: counter.readableBytesView)
        let encrypted = try AES._CTR.encrypt(payload, using: self.srtpSessionKey, nonce: nonce)

        var writer = ByteBuffer()
        writer.reserveCapacity(header.marshalSize() + payload.count + self.rtpAuthTagLen())

        // Copy RTP header unencrypted.
        let data = try header.marshal()
        writer.writeImmutableBuffer(data)

        // Write RTP encrypted part
        writer.writeImmutableBuffer(self.allocator.buffer(data: encrypted))

        // Generate the auth tag.
        let authTag = try self.generateSrtpAuthTag(buf: writer.readableBytesView, roc: roc)
        writer.writeImmutableBuffer(authTag)

        return writer
    }

    mutating func encryptRtcp(
        plaintext: ByteBufferView,
        srtcpIndex: UInt32,
        ssrc: UInt32
    ) throws -> ByteBuffer {
        // Encrypt everything after header
        let counter = try generateCounter(
            sequenceNumber: UInt16(srtcpIndex & 0xFFFF),
            rolloverCounter: (srtcpIndex >> 16),
            ssrc: ssrc,
            sessionSalt: self.srtcpSessionSalt.readableBytesView
        )

        let nonce = try AES._CTR.Nonce(nonceBytes: counter.readableBytesView)
        let encrypted = try AES._CTR.encrypt(
            plaintext[(plaintext.startIndex + RTCP.headerLength + RTCP.ssrcLength)...],
            using: self.srtcpSessionKey, nonce: nonce)

        var writer = ByteBuffer()
        writer.reserveCapacity(plaintext.count + srtcpIndexSize + self.rtcpAuthTagLen())

        // Write RTCP header part
        writer.writeImmutableBuffer(
            ByteBuffer(
                plaintext[
                    plaintext
                        .startIndex..<(plaintext.startIndex + RTCP.headerLength + RTCP.ssrcLength)])
        )

        // Write RTCP encrypted part
        writer.writeImmutableBuffer(self.allocator.buffer(data: encrypted))

        // Add SRTCP index and set Encryption bit
        writer.writeInteger(srtcpIndex | (UInt32(1) << 31))

        // Generate the auth tag.
        let authTag = try self.generateSrtcpAuthTag(buf: writer.readableBytesView)
        writer.writeImmutableBuffer(authTag)

        return writer
    }

    mutating func decryptRtp(
        ciphertext: ByteBufferView,
        header: RTP.Header,
        roc: UInt32
    ) throws -> ByteBuffer {
        if ciphertext.count < self.rtpAuthTagLen() {
            throw SrtpError.errSrtpTooSmall(ciphertext.count, self.rtpAuthTagLen())
        }

        // Split the auth tag and the cipher text into two parts.
        let actualTag = ciphertext[
            (ciphertext.startIndex + ciphertext.count - self.rtpAuthTagLen())...]
        let encrypted = ciphertext[
            ciphertext.startIndex..<ciphertext.startIndex + ciphertext.count - self.rtpAuthTagLen()]

        // Generate the auth tag we expect to see from the ciphertext.
        let expectedTag = try self.generateSrtpAuthTag(buf: encrypted, roc: roc)

        // See if the auth tag actually matches.
        // FIXME: use a constant time comparison to prevent timing attacks.
        if actualTag != expectedTag.readableBytesView {
            throw SrtpError.errRtpFailedToVerifyAuthTag
        }

        // Decrypt the ciphertext for the payload.
        let counter = try generateCounter(
            sequenceNumber: header.sequenceNumber,
            rolloverCounter: roc,
            ssrc: header.ssrc,
            sessionSalt: self.srtpSessionSalt.readableBytesView
        )

        let payloadOffset = header.marshalSize()

        let nonce = try AES._CTR.Nonce(nonceBytes: counter.readableBytesView)
        let decrypted = try AES._CTR.decrypt(
            encrypted[(encrypted.startIndex + payloadOffset)...], using: self.srtpSessionKey,
            nonce: nonce)

        var writer = ByteBuffer()
        writer.reserveCapacity(ciphertext.count - self.rtpAuthTagLen())

        // Write RTP header
        writer.writeImmutableBuffer(
            ByteBuffer(encrypted[encrypted.startIndex..<(encrypted.startIndex + payloadOffset)]))

        // Write cipher_text to the destination buffer.
        writer.writeImmutableBuffer(self.allocator.buffer(data: decrypted))

        return writer
    }

    mutating func decryptRtcp(
        ciphertext: ByteBufferView,
        srtcpIndex: UInt32,
        ssrc: UInt32
    ) throws -> ByteBuffer {
        if ciphertext.count < self.rtcpAuthTagLen() + srtcpIndexSize {
            throw SrtpError.errSrtcpTooSmall(
                ciphertext.count,
                self.rtcpAuthTagLen() + srtcpIndexSize
            )
        }

        let tailOffset = ciphertext.count - (self.rtcpAuthTagLen() + srtcpIndexSize)

        let isEncrypted = ciphertext[ciphertext.startIndex + tailOffset] >> 7
        if isEncrypted == 0 {
            return ByteBuffer(
                ciphertext[ciphertext.startIndex..<ciphertext.startIndex + tailOffset])
        }

        // Split the auth tag and the cipher text into two parts.
        let actualTag = ciphertext[
            (ciphertext.startIndex + ciphertext.count - self.rtcpAuthTagLen())...]
        let encrypted = ciphertext[
            ciphertext.startIndex..<ciphertext.startIndex + ciphertext.count - self.rtcpAuthTagLen()
        ]

        // Generate the auth tag we expect to see from the ciphertext.
        let expectedTag = try self.generateSrtcpAuthTag(buf: encrypted)

        // See if the auth tag actually matches.
        // FIXME: use a constant time comparison to prevent timing attacks.
        if actualTag != expectedTag.readableBytesView {
            throw SrtpError.errRtcpFailedToVerifyAuthTag
        }

        let counter = try generateCounter(
            sequenceNumber: UInt16(srtcpIndex & 0xFFFF),
            rolloverCounter: (srtcpIndex >> 16),
            ssrc: ssrc,
            sessionSalt: self.srtcpSessionSalt.readableBytesView
        )

        let nonce = try AES._CTR.Nonce(nonceBytes: counter.readableBytesView)
        let decrypted = try AES._CTR.decrypt(
            encrypted[(encrypted.startIndex + RTCP.headerLength + RTCP.ssrcLength)...],
            using: self.srtcpSessionKey, nonce: nonce)

        var writer = ByteBuffer()
        writer.reserveCapacity(tailOffset)

        // Write RTCP header
        writer.writeImmutableBuffer(
            ByteBuffer(
                encrypted[
                    encrypted
                        .startIndex..<(encrypted.startIndex + RTCP.headerLength + RTCP.ssrcLength)])
        )

        // Write RTCP decrypted part
        writer.writeImmutableBuffer(self.allocator.buffer(data: decrypted))

        return writer
    }
}
