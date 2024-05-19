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
public struct MappedAddress: CustomStringConvertible {
    var socketAddress: SocketAddress

    public var description: String {
        return self.socketAddress.description
    }

    public init(socketAddress: SocketAddress) {
        self.socketAddress = socketAddress
    }

    /// decodes MAPPED-ADDRESS value in message m as an attribute of type t.
    public mutating func getFromAs(_ m: Message, _ t: AttrType) throws {
        let v = try m.get(t)
        if v.count <= 4 {
            throw STUNError.errUnexpectedEof
        }

        let family = UInt16.fromBeBytes(v[0], v[1])
        if family != familyIpV6 && family != familyIpV4 {
            throw STUNError.errInvalidFamilyIpValue(family)
        }
        let port = UInt16.fromBeBytes(v[2], v[3])

        let l =
            if family == familyIpV6 {
                min(ipV6Len, v[4...].count)
            } else {
                min(ipV4Len, v[4...].count)
            }
        self.socketAddress = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: v[4..<4 + l]), port: Int(port))
    }

    /// adds MAPPED-ADDRESS value to m as t attribute.
    public func addToAs(_ m: Message, _ t: AttrType) throws {
        let family =
            switch self.socketAddress {
            case SocketAddress.v4(_):
                familyIpV4
            case SocketAddress.v6(_):
                familyIpV4
            default:
                throw STUNError.errInvalidFamilyIpValue(0)
            }

        guard let port = self.socketAddress.port else {
            throw STUNError.errInvalidFamilyIpValue(0)
        }
        var value: [UInt8] = []
        //value[0] = 0 // first 8 bits are zeroes
        value.append(contentsOf: family.toBeBytes())
        value.append(contentsOf: UInt16(port).toBeBytes())
        value.append(contentsOf: socketAddress.octets())

        m.add(t, value)
    }
}

extension MappedAddress: Setter {
    /// adds MAPPED-ADDRESS to message.
    public func addTo(_ m: Message) throws {
        try self.addToAs(m, attrMappedAddress)
    }
}

extension MappedAddress: Getter {
    /// decodes MAPPED-ADDRESS from message.
    public mutating func getFrom(_ m: Message) throws {
        try self.getFromAs(m, attrMappedAddress)
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
