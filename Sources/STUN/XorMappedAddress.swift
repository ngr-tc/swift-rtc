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

func safeXorBytes(_ dst: inout ByteBuffer, _ a: ByteBufferView, _ b: ByteBufferView) -> Int {
    var n = a.count
    if b.count < n {
        n = b.count
    }
    if dst.writerIndex < n {
        n = dst.writerIndex
    }
    for i in 0..<n {
        let c = a[a.startIndex + i] ^ b[b.startIndex + i]
        dst.setRepeatingByte(c, count: 1, at: i)
    }
    return n
}

/// xor_bytes xors the bytes in a and b. The destination is assumed to have enough
/// space. Returns the number of bytes xor'd.
public func xorBytes(_ dst: inout ByteBuffer, _ a: ByteBufferView, _ b: ByteBufferView) -> Int {
    //TODO: if supportsUnaligned {
    //    return fastXORBytes(dst, a, b)
    //}
    return safeXorBytes(&dst, a, b)
}

/// XORMappedAddress implements XOR-MAPPED-ADDRESS attribute.
///
/// RFC 5389 Section 15.2
public struct XorMappedAddress {
    var socketAddress: SocketAddress

    public init() {
        self.socketAddress = try! SocketAddress(ipAddress: "0.0.0.0", port: 0)
    }

    public init(socketAddress: SocketAddress) {
        self.socketAddress = socketAddress
    }

    /// add_to_as adds XOR-MAPPED-ADDRESS value to m as t attribute.
    public func addToAs(_ m: inout Message, _ t: AttrType) throws {
        var (family, ipLen) = (familyIpV4, ipV4Len)
        switch self.socketAddress {
        case SocketAddress.v4(_):
            family = familyIpV4
            ipLen = ipV4Len
        case SocketAddress.v6(_):
            family = familyIpV6
            ipLen = ipV6Len
        default:
            throw StunError.errInvalidFamilyIpValue(0)
        }

        guard let port = self.socketAddress.port else {
            throw StunError.errInvalidFamilyIpValue(0)
        }

        var xorValue = ByteBuffer()
        xorValue.writeBytes(magicCookie.toBeBytes())
        xorValue.writeImmutableBuffer(m.transactionId.rawValue)

        let ip = ByteBuffer(bytes: self.socketAddress.octets())
        var xorIp = ByteBuffer(repeating: 0, count: ipLen)

        let _ = xorBytes(&xorIp, ip.readableBytesView, xorValue.readableBytesView)

        var value = ByteBuffer()
        value.writeBytes(family.toBeBytes())
        value.writeBytes((UInt16(port) ^ UInt16(magicCookie >> 16)).toBeBytes())
        value.writeImmutableBuffer(xorIp)
        m.add(t, value.readableBytesView)
    }

    /// get_from_as decodes XOR-MAPPED-ADDRESS attribute value in message
    /// getting it as for t type.
    public mutating func getFromAs(_ m: inout Message, _ t: AttrType) throws {
        let b = try m.get(t)
        let v = b.readableBytesView
        if v.count <= 4 {
            throw StunError.errUnexpectedEof
        }

        let family = UInt16.fromBeBytes(v[0], v[1])
        if family != familyIpV6 && family != familyIpV4 {
            throw StunError.errInvalidFamilyIpValue(family)
        }

        let ipLen = family == familyIpV4 ? ipV4Len : ipV6Len
        try checkOverflow(t, v[4...].count, ipLen)

        let port = UInt16.fromBeBytes(v[2], v[3]) ^ UInt16(magicCookie >> 16)
        var xorValue = ByteBuffer()
        xorValue.writeBytes(magicCookie.toBeBytes())
        xorValue.writeImmutableBuffer(m.transactionId.rawValue)
        let xorValueView = xorValue.readableBytesView

        if family == familyIpV6 {
            var ip = ByteBuffer(bytes: Array(repeating: 0, count: ipV6Len))
            let _ = xorBytes(&ip, v[4...], xorValueView)
            self.socketAddress = try SocketAddress(
                packedIPAddress: ip, port: Int(port))
        } else {
            var ip = ByteBuffer(bytes: Array(repeating: 0, count: ipV4Len))
            let _ = xorBytes(&ip, v[4...], xorValueView)
            self.socketAddress = try SocketAddress(
                packedIPAddress: ip, port: Int(port))
        }
    }
}

extension XorMappedAddress: CustomStringConvertible {
    public var description: String {
        return self.socketAddress.description
    }
}

extension XorMappedAddress: Setter {
    /// add_to adds XOR-MAPPED-ADDRESS to m. Can return ErrBadIPLength
    /// if len(a.IP) is invalid.
    public func addTo(_ m: inout Message) throws {
        try self.addToAs(&m, attrXorMappedAddress)
    }
}

extension XorMappedAddress: Getter {
    /// get_from decodes XOR-MAPPED-ADDRESS attribute in message and returns
    /// error if any. While decoding, a.IP is reused if possible and can be
    /// rendered to invalid state (e.g. if a.IP was set to IPv6 and then
    /// IPv4 value were decoded into it), be careful.
    public mutating func getFrom(_ m: inout Message) throws {
        try self.getFromAs(&m, attrXorMappedAddress)
    }
}
