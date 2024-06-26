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
import _CryptoExtras

let labelSrtpEncryption: UInt8 = 0x00
let labelSrtpAuthenticationTag: UInt8 = 0x01
let labelSrtpSalt: UInt8 = 0x02
let labelSrtcpEncryption: UInt8 = 0x03
let labelSrtcpAuthenticationTag: UInt8 = 0x04
let labelSrtcpSalt: UInt8 = 0x05

let srtcpIndexSize: Int = 4

func aesCmKeyDerivation(
    label: UInt8,
    masterKey: ByteBufferView,
    masterSalt: ByteBufferView,
    indexOverKdr: UInt32,
    outLen: Int
) throws -> ByteBuffer {
    if indexOverKdr != 0 {
        // 24-bit "index DIV kdr" must be xored to prf input.
        throw SrtpError.errUnsupportedIndexOverKdr
    }

    // https://tools.ietf.org/html/rfc3711#appendix-B.3
    // The input block for AES-CM is generated by exclusive-oring the master salt with the
    // concatenation of the encryption key label 0x00 with (index DIV kdr),
    // - index is 'rollover count' and DIV is 'divided by'

    let nMasterKey = masterKey.count
    let nMasterSalt = masterSalt.count

    var prfIn: [UInt8] = Array(repeating: 0, count: nMasterKey)
    prfIn.replaceSubrange(..<nMasterSalt, with: masterSalt)

    prfIn[7] ^= label

    //The resulting value is then AES encrypted using the master key to get the cipher key.
    let key = SymmetricKey(data: masterKey)

    var out: [UInt8] = Array(
        repeating: 0, count: ((outLen + nMasterKey) / nMasterKey) * nMasterKey)
    for (i, n) in stride(from: 0, to: outLen, by: nMasterKey).enumerated() {
        //BigEndian.PutUint16(prfIn[nMasterKey-2:], i)
        prfIn[nMasterKey - 2] = UInt8((i >> 8) & 0xFF)
        prfIn[nMasterKey - 1] = UInt8(i & 0xFF)

        out.replaceSubrange(n..<n + nMasterKey, with: prfIn)
        try AES.permute(&out[n..<n + nMasterKey], key: key)
    }

    return ByteBuffer(bytes: out[..<outLen])
}

/// Generate IV https://tools.ietf.org/html/rfc3711#section-4.1.1
/// where the 128-bit integer value IV SHALL be defined by the SSRC, the
/// SRTP packet index i, and the SRTP session salting key k_s, as below.
/// ROC = a 32-bit unsigned rollover counter (roc), which records how many
/// times the 16-bit RTP sequence number has been reset to zero after
/// passing through 65,535
/// ```nobuild
/// i = 2^16 * roc + SEQ
/// IV = (salt*2 ^ 16) | (ssrc*2 ^ 64) | (i*2 ^ 16)
/// ```
func generateCounter(
    sequenceNumber: UInt16,
    rolloverCounter: UInt32,
    ssrc: UInt32,
    sessionSalt: ByteBufferView
) throws -> ByteBuffer {
    assert(sessionSalt.count <= 16)

    var counter: [UInt8] = Array(repeating: 0, count: 4)  // 0:4
    counter.append(contentsOf: ssrc.toBeBytes())  //4:8
    counter.append(contentsOf: rolloverCounter.toBeBytes())  //8:12
    counter.append(contentsOf: (UInt32(sequenceNumber) << 16).toBeBytes())  //12:16

    for i in 0..<sessionSalt.count {
        counter[i] ^= sessionSalt[i]
    }

    return ByteBuffer(bytes: counter)
}
