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
import CRC
import NIOCore

/// FingerprintAttr represents FINGERPRINT attribute.
///
/// RFC 5389 Section 15.5
public struct FingerprintAttr {
    // Check reads fingerprint value from m and checks it, returning error if any.
    // Can return *AttrLengthErr, ErrAttributeNotFound, and *CRCMismatch.
    public func check(m: Message) throws {
        let b = try m.get(attrFingerprint)
        let v = ByteBufferView(b)
        try checkSize(attrFingerprint, got: v.count, expected: fingerprintSize)
        let val = UInt32.fromBeBytes(v[0], v[1], v[2], v[3])
        let rawView = ByteBufferView(m.raw)
        let attrStart = rawView.count - (fingerprintSize + attributeHeaderSize)
        let expected = fingerprintValue(rawView[..<attrStart])
        try checkFingerprint(got: val, expected: expected)
    }
}

/// FINGERPRINT is shorthand for FingerprintAttr.
///
/// Example:
///
///  m := FingerprintAttr()
///  FINGERPRINT.add_to(m)
public let fingerprint: FingerprintAttr = FingerprintAttr()
public let fingerprintXorValue: UInt32 = 0x5354_554e
public let fingerprintSize: Int = 4  // 32 bit

/// FingerprintValue returns CRC-32 of b XOR-ed by 0x5354554e.
///
/// The value of the attribute is computed as the CRC-32 of the STUN message
/// up to (but excluding) the FINGERPRINT attribute itself, XOR'ed with
/// the 32-bit value 0x5354554e (the XOR helps in cases where an
/// application packet is also using CRC-32 in it).
public func fingerprintValue(_ b: ByteBufferView) -> UInt32 {
    let checksum = CRC32(hashing: b).checksum
    return checksum ^ fingerprintXorValue  // XOR
}

extension FingerprintAttr: Setter {
    // add_to adds fingerprint to message.
    public func addTo(_ m: Message) throws {
        let l = m.length
        // length in header should include size of fingerprint attribute
        m.length += Int(fingerprintSize + attributeHeaderSize)  // increasing length
        m.writeLength()  // writing Length to Raw
        let val = fingerprintValue(ByteBufferView(m.raw))
        m.length = l
        m.add(attrFingerprint, ByteBufferView(val.toBeBytes()))
    }
}
