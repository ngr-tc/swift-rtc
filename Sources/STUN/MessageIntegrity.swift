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

/// separator for credentials.
let credentialsSep: String = ":"

let messageIntegritySize: Int = 20

/// MessageIntegrity represents MESSAGE-INTEGRITY attribute.
///
/// add_to and Check methods are using zero-allocation version of hmac, see
/// newHMAC function and internal/hmac/pool.go.
///
/// RFC 5389 Section 15.4
public struct MessageIntegrity {
    var rawValue: ByteBuffer

    // new_long_term_integrity returns new MessageIntegrity with key for long-term
    // credentials. Password, username, and realm must be SASL-prepared.
    public init(username: String, realm: String, password: String) {
        let s = [username, realm, password].joined(separator: credentialsSep)
        var md5 = Insecure.MD5()
        s.utf8CString.withUnsafeBytes { bufferPointer in
            // remove null terminate byte due to CString
            let bufferPointerWithoutNullTerminate = UnsafeRawBufferPointer(
                start: bufferPointer.baseAddress, count: bufferPointer.count - 1)
            md5.update(bufferPointer: bufferPointerWithoutNullTerminate)
        }
        let h = md5.finalize()

        self.rawValue = ByteBuffer()
        let _ = h.withUnsafeBytes { bufferPointer in
            self.rawValue.writeBytes(bufferPointer)
        }
    }

    // new_short_term_integrity returns new MessageIntegrity with key for short-term
    // credentials. Password must be SASL-prepared.
    public init(password: String) {
        self.rawValue = ByteBuffer(string: password)
    }

    /// Check checks MESSAGE-INTEGRITY attribute.
    ///
    /// CPU costly, see BenchmarkMessageIntegrity_Check.
    public func check(_ m: Message) throws {
        let b = try m.get(attrMessageIntegrity)
        let v = ByteBufferView(b)

        // Adjusting length in header to match m.Raw that was
        // used when computing HMAC.

        let length = m.length
        var afterIntegrity = false
        var sizeReduced = 0

        for a in m.attributes.rawAttributes {
            if afterIntegrity {
                sizeReduced += nearestPaddedValueLength(a.length)
                sizeReduced += attributeHeaderSize
            }
            if a.typ == attrMessageIntegrity {
                afterIntegrity = true
            }
        }
        m.length -= sizeReduced
        m.writeLength()
        // start_of_hmac should be first byte of integrity attribute.
        let startOfHmac =
            messageHeaderSize + m.length - (attributeHeaderSize + messageIntegritySize)
        // data before integrity attribute
        guard let b = m.raw.viewBytes(at: 0, length: startOfHmac) else {
            throw STUNError.errBufferTooSmall
        }
        let expected = newHmac(key: ByteBufferView(self.rawValue), message: b)
        m.length = length
        m.writeLength()  // writing length back
        try checkHmac(got: v, expected: ByteBufferView(expected))
    }
}

func newHmac(key: ByteBufferView, message: ByteBufferView) -> ByteBuffer {
    var hmac = HMAC<Insecure.SHA1>(key: SymmetricKey(data: key))

    message.withUnsafeBytes { bufferPointer in
        hmac.update(data: bufferPointer)
    }

    let mac = hmac.finalize()

    var v = ByteBuffer()
    let _ = mac.withUnsafeBytes { bufferPointer in
        v.writeBytes(bufferPointer)
    }
    return v
}

extension MessageIntegrity: CustomStringConvertible {
    public var description: String {
        return "KEY: 0x[" + self.rawValue.hexDump(format: .plain) + "]"
    }
}

extension MessageIntegrity: Setter {
    /// add_to adds MESSAGE-INTEGRITY attribute to message.
    ///
    /// CPU costly, see BenchmarkMessageIntegrity_AddTo.
    public func addTo(_ m: Message) throws {
        for a in m.attributes.rawAttributes {
            // Message should not contain FINGERPRINT attribute
            // before MESSAGE-INTEGRITY.
            if a.typ == attrFingerprint {
                throw STUNError.errFingerprintBeforeIntegrity
            }
        }
        // The text used as input to HMAC is the STUN message,
        // including the header, up to and including the attribute preceding the
        // MESSAGE-INTEGRITY attribute.
        let length = m.length
        // Adjusting m.Length to contain MESSAGE-INTEGRITY TLV.
        m.length += messageIntegritySize + attributeHeaderSize
        // writing length to m.Raw
        m.writeLength()
        // calculating HMAC for adjusted m.Raw
        let v = newHmac(key: ByteBufferView(self.rawValue), message: ByteBufferView(m.raw))
        m.length = length  // changing m.Length back

        m.add(attrMessageIntegrity, ByteBufferView(v))
    }
}
