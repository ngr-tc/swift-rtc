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
    var srtpSessionKey: SymmetricKey
    var srtcpSessionKey: SymmetricKey
    var srtpSessionSalt: [UInt8]
    var srtcpSessionSalt: [UInt8]
    var allocator: ByteBufferAllocator

    /// Create a new AEAD instance.
    init(masterKey: ByteBufferView, masterSalt: ByteBufferView) throws {
        self.srtpSessionKey = SymmetricKey(
            data: try aesCmKeyDerivation(
                label: labelSrtpEncryption,
                masterKey: masterKey,
                masterSalt: masterSalt,
                indexOverKdr: 0,
                outLen: masterKey.count
            ))

        self.srtcpSessionKey = SymmetricKey(
            data: try aesCmKeyDerivation(
                label: labelSrtcpEncryption,
                masterKey: masterKey,
                masterSalt: masterSalt,
                indexOverKdr: 0,
                outLen: masterKey.count
            ))

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

        for i in 0..<iv.count {
            iv[i] ^= self.srtpSessionSalt[i]
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

        for i in 0..<iv.count {
            iv[i] ^= self.srtcpSessionSalt[i]
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
    func authTagLen() -> Int {
        cipherAeadAesGcmAuthTagLen
    }

    func getRtcpIndex(payload: ByteBufferView) throws -> UInt32 {
        if payload.count < 4 {
            throw SrtpError.errTooShortRtcp
        }
        let pos = payload.count - 4
        let val: UInt32 = UInt32.fromBeBytes(
            payload[pos],
            payload[pos + 1],
            payload[pos + 2],
            payload[pos + 3])

        return val & ~(UInt32(rtcpEncryptionFlag) << 24)
    }

    mutating func encryptRtp(
        plaintext: ByteBufferView,
        header: RTP.Header,
        roc: UInt32
    ) throws -> ByteBuffer {
        // Grow the given buffer to fit the output.
        var writer = ByteBuffer()
        writer.reserveCapacity(header.marshalSize() + plaintext.count + self.authTagLen())

        let data = try header.marshal()
        writer.writeImmutableBuffer(data)

        let nonce = try AES.GCM.Nonce(data: self.rtpInitializationVector(header: header, roc: roc))

        let encrypted = try AES.GCM.seal(
            plaintext,
            using: self.srtpSessionKey,
            nonce: nonce,
            authenticating: writer.readableBytesView)

        writer.writeImmutableBuffer(self.allocator.buffer(data: encrypted.ciphertext))
        return writer
    }

    mutating func decryptRtp(
        ciphertext: ByteBufferView,
        header: RTP.Header,
        roc: UInt32
    ) throws -> ByteBuffer {
        /*if ciphertext.len() < self.auth_tag_len() {
            return Err(Error::ErrFailedToVerifyAuthTag);
        }

        let nonce = self.rtp_initialization_vector(header, roc);
        let payload_offset = header.marshal_size();
        let decrypted_msg: Vec<u8> = self.srtp_cipher.decrypt(
            Nonce::from_slice(&nonce),
            Payload {
                msg: &ciphertext[payload_offset..],
                aad: &ciphertext[..payload_offset],
            },
        )?;

        let mut writer = BytesMut::with_capacity(payload_offset + decrypted_msg.len());
        writer.extend_from_slice(&ciphertext[..payload_offset]);
        writer.extend(decrypted_msg);

        Ok(writer)*/
        return ByteBuffer()
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
            plaintext[8...],
            using: self.srtcpSessionKey,
            nonce: nonce,
            authenticating: aad
        )

        var writer = ByteBuffer()
        writer.reserveCapacity(encrypted.ciphertext.count + aad.count)
        writer.writeImmutableBuffer(ByteBuffer(plaintext[..<8]))
        writer.writeImmutableBuffer(self.allocator.buffer(data: encrypted.ciphertext))
        writer.writeBytes(aad[8...])

        return writer
    }

    mutating func decryptRtcp(
        ciphertext: ByteBufferView,
        srtcpIndex: UInt32,
        ssrc: UInt32
    ) throws -> ByteBuffer {
        /*if encrypted.len() < self.auth_tag_len() + SRTCP_INDEX_SIZE {
            return Err(Error::ErrFailedToVerifyAuthTag);
        }

        let nonce = self.rtcp_initialization_vector(srtcp_index, ssrc);
        let aad = self.rtcp_additional_authenticated_data(encrypted, srtcp_index);

        let decrypted_data = self.srtcp_cipher.decrypt(
            Nonce::from_slice(&nonce),
            Payload {
                msg: &encrypted[8..(encrypted.len() - SRTCP_INDEX_SIZE)],
                aad: &aad,
            },
        )?;

        let mut writer = BytesMut::with_capacity(8 + decrypted_data.len());
        writer.extend_from_slice(&encrypted[..8]);
        writer.extend(decrypted_data);

        Ok(writer)*/
        return ByteBuffer()
    }
}
