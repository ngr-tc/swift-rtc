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

let familyIpV4: UInt16 = 0x01
let familyIpV6: UInt16 = 0x02
let ipV4Len: Int = 4
let ipV6Len: Int = 16

/// MappedAddress represents MAPPED-ADDRESS attribute.
///
/// This attribute is used only by servers for achieving backwards
/// compatibility with RFC 3489 clients.
///
/// RFC 5389 Section 15.1
public struct MappedAddress {
    var socketAddress: SocketAddress

    public init() {
        self.socketAddress = try! SocketAddress(ipAddress: "0.0.0.0", port: 0)
    }

    public init(socketAddress: SocketAddress) {
        self.socketAddress = socketAddress
    }

    /// decodes MAPPED-ADDRESS value in message m as an attribute of type t.
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
        let port = UInt16.fromBeBytes(v[2], v[3])

        let l = family == familyIpV6 ? min(ipV6Len, v[4...].count) : min(ipV4Len, v[4...].count)
        self.socketAddress = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: v[4..<4 + l]), port: Int(port))
    }

    /// adds MAPPED-ADDRESS value to m as t attribute.
    public func addToAs(_ m: inout Message, _ t: AttrType) throws {
        var family = familyIpV4
        switch self.socketAddress {
        case SocketAddress.v4(_):
            family = familyIpV4
        case SocketAddress.v6(_):
            family = familyIpV6
        default:
            throw StunError.errInvalidFamilyIpValue(0)
        }

        guard let port = self.socketAddress.port else {
            throw StunError.errInvalidFamilyIpValue(0)
        }
        var value: ByteBuffer = ByteBuffer()
        value.reserveCapacity(minimumWritableBytes: 4 + family == familyIpV4 ? 4 : 16)
        value.writeBytes(family.toBeBytes())
        value.writeBytes(UInt16(port).toBeBytes())
        value.writeBytes(socketAddress.octets())

        m.add(t, value.readableBytesView)
    }
}

extension MappedAddress: CustomStringConvertible {
    public var description: String {
        return self.socketAddress.description
    }
}

extension MappedAddress: Setter {
    /// adds MAPPED-ADDRESS to message.
    public func addTo(_ m: inout Message) throws {
        try self.addToAs(&m, attrMappedAddress)
    }
}

extension MappedAddress: Getter {
    /// decodes MAPPED-ADDRESS from message.
    public mutating func getFrom(_ m: inout Message) throws {
        try self.getFromAs(&m, attrMappedAddress)
    }
}

/// AlternateServer represents ALTERNATE-SERVER attribute.
///
/// RFC 5389 Section 15.11
public typealias AlternateServer = MappedAddress

/// ResponseOrigin represents RESPONSE-ORIGIN attribute.
///
/// RFC 5780 Section 7.3
public typealias ResponseOrigin = MappedAddress

/// OtherAddress represents OTHER-ADDRESS attribute.
///
/// RFC 5780 Section 7.4
public typealias OtherAddress = MappedAddress
