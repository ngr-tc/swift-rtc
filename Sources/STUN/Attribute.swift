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

/// Attributes is list of message attributes.
public struct Attributes {
    var rawAttributes: [RawAttribute]

    /// get returns first attribute from list by the type.
    /// If attribute is present the RawAttribute is returned and the
    /// boolean is true. Otherwise the returned RawAttribute will be
    /// empty and boolean will be false.
    public func get(t: AttrType) -> (RawAttribute, Bool) {
        for candidate in self.rawAttributes {
            if candidate.typ == t {
                return (candidate, true)
            }
        }

        return (RawAttribute(), false)
    }
}

/// AttrType is attribute type.
public struct AttrType: Equatable, CustomStringConvertible {
    var rawValue: UInt16

    public init(_ rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public var description: String {
        switch self {
        case attrMappedAddress:
            return "MAPPED-ADDRESS"
        case attrUsername:
            return "USERNAME"
        case attrErrorCode:
            return "ERROR-CODE"
        case attrMessageIntegrity:
            return "MESSAGE-INTEGRITY"
        case attrUnknownAttributes:
            return "UNKNOWN-ATTRIBUTES"
        case attrRealm:
            return "REALM"
        case attrNonce:
            return "NONCE"
        case attrXormappedAddress:
            return "XOR-MAPPED-ADDRESS"
        case ATTR_SOFTWARE:
            return "SOFTWARE"
        case ATTR_ALTERNATE_SERVER:
            return "ALTERNATE-SERVER"
        case ATTR_FINGERPRINT:
            return "FINGERPRINT"
        case ATTR_PRIORITY:
            return "PRIORITY"
        case ATTR_USE_CANDIDATE:
            return "USE-CANDIDATE"
        case ATTR_ICE_CONTROLLED:
            return "ICE-CONTROLLED"
        case ATTR_ICE_CONTROLLING:
            return "ICE-CONTROLLING"
        case ATTR_CHANNEL_NUMBER:
            return "CHANNEL-NUMBER"
        case ATTR_LIFETIME:
            return "LIFETIME"
        case ATTR_XOR_PEER_ADDRESS:
            return "XOR-PEER-ADDRESS"
        case ATTR_DATA:
            return "DATA"
        case ATTR_XOR_RELAYED_ADDRESS:
            return "XOR-RELAYED-ADDRESS"
        case ATTR_EVEN_PORT:
            return "EVEN-PORT"
        case ATTR_REQUESTED_TRANSPORT:
            return "REQUESTED-TRANSPORT"
        case ATTR_DONT_FRAGMENT:
            return "DONT-FRAGMENT"
        case ATTR_RESERVATION_TOKEN:
            return "RESERVATION-TOKEN"
        case ATTR_CONNECTION_ID:
            return "CONNECTION-ID"
        case ATTR_REQUESTED_ADDRESS_FAMILY:
            return "REQUESTED-ADDRESS-FAMILY"
        case ATTR_MESSAGE_INTEGRITY_SHA256:
            return "MESSAGE-INTEGRITY-SHA256"
        case ATTR_PASSWORD_ALGORITHM:
            return "PASSWORD-ALGORITHM"
        case ATTR_USER_HASH:
            return "USERHASH"
        case ATTR_PASSWORD_ALGORITHMS:
            return "PASSWORD-ALGORITHMS"
        case ATTR_ALTERNATE_DOMAIN:
            return "ALTERNATE-DOMAIN"
        default:
            return "0x\(String(self.rawValue, radix: 16, uppercase: false))"
        }
    }

    /// required returns true if type is from comprehension-required range (0x0000-0x7FFF).
    public func required() -> Bool {
        self.rawValue <= 0x7FFF
    }

    /// optional returns true if type is from comprehension-optional range (0x8000-0xFFFF).
    public func optional() -> Bool {
        self.rawValue >= 0x8000
    }

    /// value returns uint16 representation of attribute type.
    public func value() -> UInt16 {
        self.rawValue
    }
}

/// Attributes from comprehension-required range (0x0000-0x7FFF).
// MAPPED-ADDRESS
public let attrMappedAddress: AttrType = AttrType(0x0001)
// USERNAME
public let attrUsername: AttrType = AttrType(0x0006)
// MESSAGE-INTEGRITY
public let attrMessageIntegrity: AttrType = AttrType(0x0008)
// ERROR-CODE
public let attrErrorCode: AttrType = AttrType(0x0009)
// UNKNOWN-ATTRIBUTES
public let attrUnknownAttributes: AttrType = AttrType(0x000A)
// REALM
public let attrRealm: AttrType = AttrType(0x0014)
// NONCE
public let attrNonce: AttrType = AttrType(0x0015)
// XOR-MAPPED-ADDRESS
public let attrXormappedAddress: AttrType = AttrType(0x0020)

/// Attributes from comprehension-optional range (0x8000-0xFFFF).
// SOFTWARE
public let ATTR_SOFTWARE: AttrType = AttrType(0x8022)
// ALTERNATE-SERVER
public let ATTR_ALTERNATE_SERVER: AttrType = AttrType(0x8023)
// FINGERPRINT
public let ATTR_FINGERPRINT: AttrType = AttrType(0x8028)

/// Attributes from RFC 5245 ICE.
// PRIORITY
public let ATTR_PRIORITY: AttrType = AttrType(0x0024)
// USE-CANDIDATE
public let ATTR_USE_CANDIDATE: AttrType = AttrType(0x0025)
// ICE-CONTROLLED
public let ATTR_ICE_CONTROLLED: AttrType = AttrType(0x8029)
// ICE-CONTROLLING
public let ATTR_ICE_CONTROLLING: AttrType = AttrType(0x802A)
// NETWORK-COST
public let ATTR_NETWORK_COST: AttrType = AttrType(0xC057)

/// Attributes from RFC 5766 TURN.
// CHANNEL-NUMBER
public let ATTR_CHANNEL_NUMBER: AttrType = AttrType(0x000C)
// LIFETIME
public let ATTR_LIFETIME: AttrType = AttrType(0x000D)
// XOR-PEER-ADDRESS
public let ATTR_XOR_PEER_ADDRESS: AttrType = AttrType(0x0012)
// DATA
public let ATTR_DATA: AttrType = AttrType(0x0013)
// XOR-RELAYED-ADDRESS
public let ATTR_XOR_RELAYED_ADDRESS: AttrType = AttrType(0x0016)
// EVEN-PORT
public let ATTR_EVEN_PORT: AttrType = AttrType(0x0018)
// REQUESTED-TRANSPORT
public let ATTR_REQUESTED_TRANSPORT: AttrType = AttrType(0x0019)
// DONT-FRAGMENT
public let ATTR_DONT_FRAGMENT: AttrType = AttrType(0x001A)
// RESERVATION-TOKEN
public let ATTR_RESERVATION_TOKEN: AttrType = AttrType(0x0022)

/// Attributes from RFC 5780 NAT Behavior Discovery
// CHANGE-REQUEST
public let ATTR_CHANGE_REQUEST: AttrType = AttrType(0x0003)
// PADDING
public let ATTR_PADDING: AttrType = AttrType(0x0026)
// RESPONSE-PORT
public let ATTR_RESPONSE_PORT: AttrType = AttrType(0x0027)
// CACHE-TIMEOUT
public let ATTR_CACHE_TIMEOUT: AttrType = AttrType(0x8027)
// RESPONSE-ORIGIN
public let ATTR_RESPONSE_ORIGIN: AttrType = AttrType(0x802b)
// OTHER-ADDRESS
public let ATTR_OTHER_ADDRESS: AttrType = AttrType(0x802C)

/// Attributes from RFC 3489, removed by RFC 5389,
///  but still used by RFC5389-implementing software like Vovida.org, reTURNServer, etc.
// SOURCE-ADDRESS
public let ATTR_SOURCE_ADDRESS: AttrType = AttrType(0x0004)
// CHANGED-ADDRESS
public let ATTR_CHANGED_ADDRESS: AttrType = AttrType(0x0005)

/// Attributes from RFC 6062 TURN Extensions for TCP Allocations.
// CONNECTION-ID
public let ATTR_CONNECTION_ID: AttrType = AttrType(0x002a)

/// Attributes from RFC 6156 TURN IPv6.
// REQUESTED-ADDRESS-FAMILY
public let ATTR_REQUESTED_ADDRESS_FAMILY: AttrType = AttrType(0x0017)

/// Attributes from An Origin Attribute for the STUN Protocol.
public let ATTR_ORIGIN: AttrType = AttrType(0x802F)

/// Attributes from RFC 8489 STUN.
// MESSAGE-INTEGRITY-SHA256
public let ATTR_MESSAGE_INTEGRITY_SHA256: AttrType = AttrType(0x001C)
// PASSWORD-ALGORITHM
public let ATTR_PASSWORD_ALGORITHM: AttrType = AttrType(0x001D)
// USER-HASH
public let ATTR_USER_HASH: AttrType = AttrType(0x001E)
// PASSWORD-ALGORITHMS
public let ATTR_PASSWORD_ALGORITHMS: AttrType = AttrType(0x8002)
// ALTERNATE-DOMAIN
public let ATTR_ALTERNATE_DOMAIN: AttrType = AttrType(0x8003)

/// RawAttribute is a Type-Length-Value (TLV) object that
/// can be added to a STUN message. Attributes are divided into two
/// types: comprehension-required and comprehension-optional.  STUN
/// agents can safely ignore comprehension-optional attributes they
/// don't understand, but cannot successfully process a message if it
/// contains comprehension-required attributes that are not
/// understood.
public struct RawAttribute: CustomStringConvertible, Setter {
    var typ: AttrType
    var length: UInt16  // ignored while encoding
    var value: [UInt8]

    public init() {
        self.typ = AttrType(0)
        self.length = 0
        self.value = []
    }

    public init(typ: AttrType, length: UInt16, value: [UInt8]) {
        self.typ = typ
        self.length = length
        self.value = value
    }

    public var description: String {
        return "\(self.typ): \(value)"
    }

    /// implements Setter, adding attribute as a.Type with a.Value and ignoring
    /// the Length field.
    public func addTo(m: inout Message) throws {
        m.add(t: self.typ, v: self.value)
    }
}

let padding: Int = 4

/// STUN aligns attributes on 32-bit boundaries, attributes whose content
/// is not a multiple of 4 bytes are padded with 1, 2, or 3 bytes of
/// padding so that its value contains a multiple of 4 bytes.  The
/// padding bits are ignored, and may be any value.
///
/// https://tools.ietf.org/html/rfc5389#section-15
func nearestPaddedValueLength(l: Int) -> Int {
    var n = padding * (l / padding)
    if n < l {
        n += padding
    }
    return n
}

/// This method converts uint16 vlue to AttrType. If it finds an old attribute
/// type value, it also translates it to the new value to enable backward
/// compatibility. (See: https://github.com/pion/stun/issues/21)
func compatAttrType(val: UInt16) -> AttrType {
    if val == 0x8020 {
        // draft-ietf-behave-rfc3489bis-02, MS-TURN
        return attrXormappedAddress  // new: 0x0020 (from draft-ietf-behave-rfc3489bis-03 on)
    } else {
        return AttrType(val)
    }
}
