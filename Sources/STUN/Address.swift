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
        /*let port = UInt16.fromBeBytes(v[2], v[3])

        if family == familyIpV6 {
            let ip = ByteBuffer(repeating: 0, count: ipV6Len)
            let l = min(ip.readableBytes, v[4...].count)
            ip[..l].copy_from_slice(&v[4..4 + l]);
            self.ip = IpAddr::V6(Ipv6Addr::from(ip));
        } else {
            let mut ip = [0; ipV4Len];
            let l = std::cmp::min(ip.len(), v[4..].len());
            ip[..l].copy_from_slice(&v[4..4 + l]);
            self.ip = IpAddr::V4(Ipv4Addr::from(ip));
        }*/
    }

    /// adds MAPPED-ADDRESS value to m as t attribute.
    public func addToAs(_ m: Message, _ t: AttrType) throws {
        /*
        let family = match self.ip {
            IpAddr::V4(_) => FAMILY_IPV4,
            IpAddr::V6(_) => FAMILY_IPV6,
        };

        let mut value = vec![0u8; 4];
        //value[0] = 0 // first 8 bits are zeroes
        value[0..2].copy_from_slice(&family.to_be_bytes());
        value[2..4].copy_from_slice(&self.port.to_be_bytes());

        match self.ip {
            IpAddr::V4(ipv4) => value.extend_from_slice(&ipv4.octets()),
            IpAddr::V6(ipv6) => value.extend_from_slice(&ipv6.octets()),
        };

        m.add(t, value)
 */
    }
}

extension MappedAddress: Setter {
    /// adds MAPPED-ADDRESS to message.
    public func addTo(m: Message) throws {
        try self.addToAs(m, attrMappedAddress)
    }
}

extension MappedAddress: Getter {
    /// decodes MAPPED-ADDRESS from message.
    public mutating func getFrom(m: Message) throws {
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
