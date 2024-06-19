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

public let cipherAeadAesGcmAuthTagLen: Int = 16

let rtcpEncryptionFlag: UInt8 = 0x80

/// AEAD Cipher based on AES.
struct CipherAeadAesGcm {
    var profile: ProtectionProfile

    var srtpSessionKey: SymmetricKey
    var srtcpSessionKey: SymmetricKey

    var srtpSessionSalt: ByteBuffer
    var srtcpSessionSalt: ByteBuffer

    var allocator: ByteBufferAllocator

    /// Create a new AEAD instance.
    init(profile: ProtectionProfile, masterKey: ByteBufferView, masterSalt: ByteBufferView) throws {
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

        self.allocator = ByteBufferAllocator()
    }

    /// The 12-octet IV used by AES-GCM SRTP is formed by first concatenating
    /// 2 octets of zeroes, the 4-octet SSRC, the 4-octet rollover counter
    /// (ROC), and the 2-octet sequence number (SEQ).  The resulting 12-octet
    /// value is then XORed to the 12-octet salt to form the 12-octet IV.
    ///
    /// https://tools.ietf.org/html/rfc7714#section-8.1
    func rtpInitializationVector(
        header: RTP.Header,
        roc: UInt32
    ) -> [UInt8] {
        var iv: [UInt8] = [0, 0]

        iv.append(contentsOf: header.ssrc.toBeBytes())  // 2..<6
        iv.append(contentsOf: roc.toBeBytes())  // 6..<10
        iv.append(contentsOf: header.sequenceNumber.toBeBytes())  // 10..<12

        let srtpSessionSalt = self.srtpSessionSalt.readableBytesView
        for i in 0..<iv.count {
            iv[i] ^= srtpSessionSalt[i]
        }

        return iv
    }

    /// The 12-octet IV used by AES-GCM SRTCP is formed by first
    /// concatenating 2 octets of zeroes, the 4-octet SSRC identifier,
    /// 2 octets of zeroes, a single "0" bit, and the 31-bit SRTCP index.
    /// The resulting 12-octet value is then XORed to the 12-octet salt to
    /// form the 12-octet IV.
    ///
    /// https://tools.ietf.org/html/rfc7714#section-9.1
    func rtcpInitializationVector(srtcpIndex: UInt32, ssrc: UInt32) -> [UInt8] {
        var iv: [UInt8] = [0, 0]

        iv.append(contentsOf: ssrc.toBeBytes())  // 2..<6
        iv.append(contentsOf: [0, 0])  // 6..<8
        iv.append(contentsOf: srtcpIndex.toBeBytes())  // 8..<12

        let srtcpSessionSalt = self.srtcpSessionSalt.readableBytesView
        for i in 0..<iv.count {
            iv[i] ^= srtcpSessionSalt[i]
        }

        return iv
    }

    /// In an SRTCP packet, a 1-bit Encryption flag is prepended to the
    /// 31-bit SRTCP index to form a 32-bit value we shall call the
    /// "ESRTCP word"
    ///
    /// https://tools.ietf.org/html/rfc7714#section-17
    func rtcpAdditionalAuthenticatedData(
        rtcpPacket: ByteBufferView,
        srtcpIndex: UInt32
    ) -> [UInt8] {
        var aad: [UInt8] = []

        aad.append(contentsOf: rtcpPacket[..<8])  // 0..<8
        aad.append(contentsOf: srtcpIndex.toBeBytes())  // 8..12
        aad[8] |= rtcpEncryptionFlag

        return aad
    }
}

extension CipherAeadAesGcm: Cipher {
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
        if payload.count < 4 {
            throw SrtpError.errTooShortRtcp
        }
        let pos = payload.startIndex + payload.count - 4
        let val: UInt32 = UInt32.fromBeBytes(
            payload[pos],
            payload[pos + 1],
            payload[pos + 2],
            payload[pos + 3])

        return val & ~(UInt32(rtcpEncryptionFlag) << 24)
    }

    mutating func encryptRtp(
        payload: ByteBufferView,
        header: RTP.Header,
        roc: UInt32
    ) throws -> ByteBuffer {
        // Grow the given buffer to fit the output.
        var writer = ByteBuffer()
        writer.reserveCapacity(header.marshalSize() + payload.count + self.aeadAuthTagLen())

        let data = try header.marshal()
        writer.writeImmutableBuffer(data)

        let nonce = try AES.GCM.Nonce(data: self.rtpInitializationVector(header: header, roc: roc))
        let encrypted = try AES.GCM.seal(
            payload,
            using: self.srtpSessionKey,
            nonce: nonce,
            authenticating: writer.readableBytesView)

        writer.writeImmutableBuffer(self.allocator.buffer(data: encrypted.ciphertext))
        writer.writeImmutableBuffer(self.allocator.buffer(data: encrypted.tag))

        return writer
    }

    mutating func encryptRtcp(
        plaintext: ByteBufferView,
        srtcpIndex: UInt32,
        ssrc: UInt32
    ) throws -> ByteBuffer {
        let nonce = try AES.GCM.Nonce(
            data: self.rtcpInitializationVector(srtcpIndex: srtcpIndex, ssrc: ssrc))
        let aad = self.rtcpAdditionalAuthenticatedData(
            rtcpPacket: plaintext, srtcpIndex: srtcpIndex)

        let encrypted = try AES.GCM.seal(
            plaintext[(plaintext.startIndex + 8)...],
            using: self.srtcpSessionKey,
            nonce: nonce,
            authenticating: aad
        )

        var writer = ByteBuffer()
        writer.reserveCapacity(encrypted.ciphertext.count + aad.count)
        writer.writeImmutableBuffer(
            ByteBuffer(plaintext[plaintext.startIndex..<plaintext.startIndex + 8]))
        writer.writeImmutableBuffer(self.allocator.buffer(data: encrypted.ciphertext))
        writer.writeImmutableBuffer(self.allocator.buffer(data: encrypted.tag))
        writer.writeBytes(aad[(aad.startIndex + 8)...])

        return writer
    }

    mutating func decryptRtp(
        ciphertext: ByteBufferView,
        header: RTP.Header,
        roc: UInt32
    ) throws -> ByteBuffer {
        if ciphertext.count < self.aeadAuthTagLen() {
            throw SrtpError.errFailedToVerifyAuthTag
        }

        let payloadOffset = header.marshalSize()

        let nonce = try AES.GCM.Nonce(data: self.rtpInitializationVector(header: header, roc: roc))
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext[
                (ciphertext.startIndex + payloadOffset)..<(ciphertext.startIndex + ciphertext.count
                    - self.aeadAuthTagLen())],
            tag: ciphertext[(ciphertext.startIndex + ciphertext.count - self.aeadAuthTagLen())...])
        let decrypted = try AES.GCM.open(
            sealedBox, using: self.srtpSessionKey,
            authenticating: ciphertext[
                ciphertext.startIndex..<ciphertext.startIndex + payloadOffset])

        var writer = ByteBuffer()
        writer.reserveCapacity(payloadOffset + decrypted.count)
        writer.writeImmutableBuffer(
            ByteBuffer(ciphertext[ciphertext.startIndex..<ciphertext.startIndex + payloadOffset]))
        writer.writeImmutableBuffer(self.allocator.buffer(data: decrypted))

        return writer
    }

    mutating func decryptRtcp(
        ciphertext: ByteBufferView,
        srtcpIndex: UInt32,
        ssrc: UInt32
    ) throws -> ByteBuffer {
        if ciphertext.count < self.aeadAuthTagLen() + srtcpIndexSize {
            throw SrtpError.errFailedToVerifyAuthTag
        }

        let nonce = try AES.GCM.Nonce(
            data: self.rtcpInitializationVector(srtcpIndex: srtcpIndex, ssrc: ssrc))
        let aad = self.rtcpAdditionalAuthenticatedData(
            rtcpPacket: ciphertext, srtcpIndex: srtcpIndex)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext[
                (ciphertext.startIndex + 8)..<(ciphertext.startIndex + ciphertext.count
                    - self.aeadAuthTagLen() - srtcpIndexSize)],
            tag: ciphertext[
                (ciphertext.startIndex + ciphertext.count - self.aeadAuthTagLen() - srtcpIndexSize)..<(ciphertext
                    .startIndex + ciphertext.count - srtcpIndexSize)])
        let decrypted = try AES.GCM.open(
            sealedBox, using: self.srtcpSessionKey, authenticating: aad)

        var writer = ByteBuffer()
        writer.reserveCapacity(8 + decrypted.count)
        writer.writeImmutableBuffer(
            ByteBuffer(ciphertext[ciphertext.startIndex..<ciphertext.startIndex + 8]))
        writer.writeImmutableBuffer(self.allocator.buffer(data: decrypted))

        return writer
    }
}
