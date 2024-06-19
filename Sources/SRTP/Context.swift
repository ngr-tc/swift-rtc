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
import RTCP
import RTP
import Shared

let maxRocDisorder: UInt16 = 100

/// Encrypt/Decrypt state for a single SRTP SSRC
struct SrtpSsrcState {
    var ssrc: UInt32
    var rolloverCounter: UInt32
    var rolloverHasProcessed: Bool
    var lastSequenceNumber: UInt16
    var replayDetector: ReplayDetector?

    public func nextRolloverCount(sequenceNumber: UInt16) -> UInt32 {
        var roc = self.rolloverCounter

        if !self.rolloverHasProcessed {
            // Do nothing
        } else if sequenceNumber == 0 {
            // We exactly hit the rollover count

            // Only update rolloverCounter if lastSequenceNumber is greater then MAX_ROCDISORDER
            // otherwise we already incremented for disorder
            if self.lastSequenceNumber > maxRocDisorder {
                roc += 1
            }
        } else if self.lastSequenceNumber < maxRocDisorder
            && sequenceNumber > (maxSequenceNumber - maxRocDisorder)
        {
            // Our last sequence number incremented because we crossed 0, but then our current number was within MAX_ROCDISORDER of the max
            // So we fell behind, drop to account for jitter
            roc -= 1
        } else if sequenceNumber < maxRocDisorder
            && self.lastSequenceNumber > (maxSequenceNumber - maxRocDisorder)
        {
            // our current is within a MAX_ROCDISORDER of 0
            // and our last sequence number was a high sequence number, increment to account for jitter
            roc += 1
        }

        return roc
    }

    /// https://tools.ietf.org/html/rfc3550#appendix-A.1
    public mutating func updateRolloverCount(sequenceNumber: UInt16) {
        if !self.rolloverHasProcessed {
            self.rolloverHasProcessed = true
        } else if sequenceNumber == 0 {
            // We exactly hit the rollover count

            // Only update rolloverCounter if lastSequenceNumber is greater then MAX_ROCDISORDER
            // otherwise we already incremented for disorder
            if self.lastSequenceNumber > maxRocDisorder {
                self.rolloverCounter += 1
            }
        } else if self.lastSequenceNumber < maxRocDisorder
            && sequenceNumber > (maxSequenceNumber - maxRocDisorder)
        {
            // Our last sequence number incremented because we crossed 0, but then our current number was within MAX_ROCDISORDER of the max
            // So we fell behind, drop to account for jitter
            self.rolloverCounter -= 1
        } else if sequenceNumber < maxRocDisorder
            && self.lastSequenceNumber > (maxSequenceNumber - maxRocDisorder)
        {
            // our current is within a MAX_ROCDISORDER of 0
            // and our last sequence number was a high sequence number, increment to account for jitter
            self.rolloverCounter += 1
        }
        self.lastSequenceNumber = sequenceNumber
    }
}

/// Encrypt/Decrypt state for a single SRTCP SSRC
struct SrtcpSsrcState {
    var srtcpIndex: UInt32
    var ssrc: UInt32
    var replayDetector: ReplayDetector?
}

/// Context represents a SRTP cryptographic context
/// Context can only be used for one-way operations
/// it must either used ONLY for encryption or ONLY for decryption
public struct Context {
    var cipher: Cipher

    var srtpSsrcStates: [UInt32: SrtpSsrcState]
    var srtcpSsrcStates: [UInt32: SrtcpSsrcState]

    var newSrtpReplayDetector: ContextOption
    var newSrtcpReplayDetector: ContextOption

    /// creates a new SRTP Context
    public init(
        masterKey: ByteBufferView,
        masterSalt: ByteBufferView,
        profile: ProtectionProfile,
        srtpCtxOpt: ContextOption?,
        srtcpCtxOpt: ContextOption?
    ) throws {
        let keyLen = profile.keyLen()
        let saltLen = profile.saltLen()

        if masterKey.count != keyLen {
            throw SrtpError.errSrtpMasterKeyLength(keyLen, masterKey.count)
        } else if masterSalt.count != saltLen {
            throw SrtpError.errSrtpSaltLength(saltLen, masterSalt.count)
        }

        switch profile {
        case .aes128CmHmacSha1Tag32, .aes128CmHmacSha1Tag80:
            self.cipher = try CipherAesCmHmacSha1(
                profile: profile, masterKey: masterKey, masterSalt: masterSalt)
        case .aeadAes128Gcm, .aeadAes256Gcm:
            self.cipher = try CipherAeadAesGcm(
                profile: profile, masterKey: masterKey, masterSalt: masterSalt)
        }

        if let ctxOpt = srtpCtxOpt {
            self.newSrtpReplayDetector = ctxOpt
        } else {
            self.newSrtpReplayDetector = srtpNoReplayProtection()
        }

        if let ctxOpt = srtcpCtxOpt {
            self.newSrtcpReplayDetector = ctxOpt
        } else {
            self.newSrtcpReplayDetector = srtcpNoReplayProtection()
        }

        self.srtpSsrcStates = [:]
        self.srtcpSsrcStates = [:]
    }

    /// roc returns SRTP rollover counter value of specified SSRC.
    func getRoc(ssrc: UInt32) -> UInt32? {
        self.srtpSsrcStates[ssrc]?.rolloverCounter
    }

    /// set_roc sets SRTP rollover counter value of specified SSRC.
    mutating func setRoc(ssrc: UInt32, roc: UInt32) {
        self.srtpSsrcStates[ssrc]?.rolloverCounter = roc
    }

    /// index returns SRTCP index value of specified SSRC.
    func getIndex(ssrc: UInt32) -> UInt32? {
        self.srtcpSsrcStates[ssrc]?.srtcpIndex
    }

    /// set_index sets SRTCP index value of specified SSRC.
    mutating func setIndex(ssrc: UInt32, index: UInt32) {
        self.srtcpSsrcStates[ssrc]?.srtcpIndex = index
    }

    /// DecryptRTCP decrypts a RTCP packet with an encrypted payload
    public mutating func decryptRtcp(encrypted: ByteBufferView) throws -> ByteBuffer {
        let _ = try RTCP.Header.unmarshal(ByteBuffer(encrypted))

        let index = try self.cipher.getRtcpIndex(payload: encrypted)
        let ssrc = UInt32.fromBeBytes(encrypted[4], encrypted[5], encrypted[6], encrypted[7])

        if self.srtcpSsrcStates[ssrc] == nil {
            self.srtcpSsrcStates[ssrc] = SrtcpSsrcState(
                srtcpIndex: 0, ssrc: ssrc, replayDetector: (self.newSrtcpReplayDetector)())
        }

        if let duplicated = self.srtcpSsrcStates[ssrc]?.replayDetector?.check(seq: UInt64(index)),
            duplicated
        {
            throw SrtpError.errSrtcpSsrcDuplicated(ssrc, index)
        }

        let dst = try self.cipher.decryptRtcp(
            ciphertext: encrypted,
            srtcpIndex: index,
            ssrc: ssrc)

        self.srtcpSsrcStates[ssrc]?.replayDetector?.accept()

        return dst
    }

    /// EncryptRTCP marshals and encrypts an RTCP packet, writing to the dst buffer provided.
    /// If the dst buffer does not have the capacity to hold `len(plaintext) + 14` bytes, a new one will be allocated and returned.
    public mutating func encryptRtcp(decrypted: ByteBufferView) throws -> ByteBuffer {
        let _ = try RTCP.Header.unmarshal(ByteBuffer(decrypted))

        let ssrc = UInt32.fromBeBytes(decrypted[4], decrypted[5], decrypted[6], decrypted[7])

        if self.srtcpSsrcStates[ssrc] == nil {
            self.srtcpSsrcStates[ssrc] = SrtcpSsrcState(
                srtcpIndex: 0, ssrc: ssrc, replayDetector: (self.newSrtcpReplayDetector)())
        }

        self.srtcpSsrcStates[ssrc]?.srtcpIndex += 1
        if let srtcpIndex = self.srtcpSsrcStates[ssrc]?.srtcpIndex, srtcpIndex > maxSrtcpIndex {
            self.srtcpSsrcStates[ssrc]?.srtcpIndex = 0
        }

        return try self.cipher.encryptRtcp(
            plaintext: decrypted,
            srtcpIndex: self.srtcpSsrcStates[ssrc]?.srtcpIndex ?? 0,
            ssrc: ssrc)
    }

    public mutating func decryptRtpWithHeader(
        encrypted: ByteBufferView,
        header: RTP.Header
    ) throws -> ByteBuffer {
        if self.srtpSsrcStates[header.ssrc] == nil {
            self.srtpSsrcStates[header.ssrc] = SrtpSsrcState(
                ssrc: header.ssrc, rolloverCounter: 0, rolloverHasProcessed: false,
                lastSequenceNumber: 0, replayDetector: (self.newSrtcpReplayDetector)())
        }

        if let duplicated = self.srtpSsrcStates[header.ssrc]?.replayDetector?.check(
            seq: UInt64(header.sequenceNumber)),
            duplicated
        {
            throw SrtpError.errSrtpSsrcDuplicated(
                header.ssrc,
                header.sequenceNumber
            )
        }

        let roc =
            self.srtpSsrcStates[header.ssrc]?.nextRolloverCount(
                sequenceNumber: header.sequenceNumber) ?? 0

        let dst = try self.cipher.decryptRtp(
            ciphertext: encrypted,
            header: header,
            roc: roc)

        self.srtpSsrcStates[header.ssrc]?.replayDetector?.accept()
        self.srtpSsrcStates[header.ssrc]?.updateRolloverCount(sequenceNumber: header.sequenceNumber)

        return dst
    }

    /// DecryptRTP decrypts a RTP packet with an encrypted payload
    public mutating func decryptRtp(encrypted: ByteBufferView) throws -> ByteBuffer {
        let (header, _) = try RTP.Header.unmarshal(ByteBuffer(encrypted))
        return try self.decryptRtpWithHeader(encrypted: encrypted, header: header)
    }

    public mutating func encryptRtpWithHeader(
        plaintext: ByteBufferView,
        header: RTP.Header
    ) throws -> ByteBuffer {
        if self.srtpSsrcStates[header.ssrc] == nil {
            self.srtpSsrcStates[header.ssrc] = SrtpSsrcState(
                ssrc: header.ssrc, rolloverCounter: 0, rolloverHasProcessed: false,
                lastSequenceNumber: 0, replayDetector: (self.newSrtcpReplayDetector)())
        }

        let roc =
            self.srtpSsrcStates[header.ssrc]?.nextRolloverCount(
                sequenceNumber: header.sequenceNumber) ?? 0

        let dst =
            try self
            .cipher
            .encryptRtp(
                payload: plaintext[(plaintext.startIndex + header.marshalSize())...],
                header: header, roc: roc)

        self.srtpSsrcStates[header.ssrc]?.updateRolloverCount(sequenceNumber: header.sequenceNumber)

        return dst
    }

    /// EncryptRTP marshals and encrypts an RTP packet, writing to the dst buffer provided.
    /// If the dst buffer does not have the capacity to hold `len(plaintext) + 10` bytes, a new one will be allocated and returned.
    public mutating func encryptRtp(plaintext: ByteBufferView) throws -> ByteBuffer {
        let (header, _) = try RTP.Header.unmarshal(ByteBuffer(plaintext))
        return try self.encryptRtpWithHeader(plaintext: plaintext, header: header)
    }
}
