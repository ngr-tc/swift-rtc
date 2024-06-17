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
    var srtpCipherKey: SymmetricKey
    var srtcpCipherKey: SymmetricKey
    var srtpSessionSalt: [UInt8]
    var srtcpSessionSalt: [UInt8]
    var allocator: ByteBufferAllocator

    /// Create a new AEAD instance.
    /*init(master_key: ByteBuffer, master_salt: ByteBuffer) throws {
        let srtp_session_key = aes_cm_key_derivation(
            LABEL_SRTP_ENCRYPTION,
            master_key,
            master_salt,
            0,
            master_key.len(),
        )?;

        let srtp_block = GenericArray::from_slice(&srtp_session_key);

        let srtp_cipher = Aes128Gcm::new(srtp_block);

        let srtcp_session_key = aes_cm_key_derivation(
            LABEL_SRTCP_ENCRYPTION,
            master_key,
            master_salt,
            0,
            master_key.len(),
        )?;

        let srtcp_block = GenericArray::from_slice(&srtcp_session_key);

        let srtcp_cipher = Aes128Gcm::new(srtcp_block);

        let srtp_session_salt = aes_cm_key_derivation(
            LABEL_SRTP_SALT,
            master_key,
            master_salt,
            0,
            master_key.len(),
        )?;

        let srtcp_session_salt = aes_cm_key_derivation(
            LABEL_SRTCP_SALT,
            master_key,
            master_salt,
            0,
            master_key.len(),
        )?;

        Ok(CipherAeadAesGcm {
            srtp_cipher,
            srtcp_cipher,
            srtp_session_salt,
            srtcp_session_salt,
        })
    }*/

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

    func getRtcpIndex(payload: ByteBuffer) throws -> UInt32 {
        var reader = payload.slice()
        let pos = payload.readableBytes - 4
        reader.moveReaderIndex(forwardBy: pos)
        guard let val: UInt32 = reader.readInteger() else {
            throw SrtpError.errTooShortRtcp
        }

        return val & ~(UInt32(rtcpEncryptionFlag) << 24)
    }

    mutating func encryptRtp(
        payload: ByteBuffer,
        header: RTP.Header,
        roc: UInt32
    ) throws -> ByteBuffer {
        // Grow the given buffer to fit the output.
        var writer = ByteBuffer()
        writer.reserveCapacity(header.marshalSize() + payload.readableBytes + self.authTagLen())

        let data = try header.marshal()
        writer.writeImmutableBuffer(data)

        let nonce = try AES.GCM.Nonce(data: self.rtpInitializationVector(header: header, roc: roc))

        let encrypted = try AES.GCM.seal(
            payload.readableBytesView,
            using: self.srtpCipherKey,
            nonce: nonce,
            authenticating: writer.readableBytesView)

        writer.writeImmutableBuffer(self.allocator.buffer(data: encrypted.ciphertext))
        return writer
    }

    mutating func decryptRtp(
        payload: ByteBuffer,
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

    mutating func encryptRtcp(payload: ByteBuffer, srtcpIndex: UInt32, ssrc: UInt32) throws
        -> ByteBuffer
    {
        /*let iv = self.rtcp_initialization_vector(srtcp_index, ssrc);
        let aad = self.rtcp_additional_authenticated_data(decrypted, srtcp_index);

        let encrypted_data = self.srtcp_cipher.encrypt(
            Nonce::from_slice(&iv),
            Payload {
                msg: &decrypted[8..],
                aad: &aad,
            },
        )?;

        let mut writer = BytesMut::with_capacity(encrypted_data.len() + aad.len());
        writer.extend_from_slice(&decrypted[..8]);
        writer.extend(encrypted_data);
        writer.extend_from_slice(&aad[8..]);

        Ok(writer)*/
        return ByteBuffer()
    }

    mutating func decryptRtcp(payload: ByteBuffer, srtcpIndex: UInt32, ssrc: UInt32) throws
        -> ByteBuffer
    {
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
