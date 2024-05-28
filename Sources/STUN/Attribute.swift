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

/// Attributes is list of message attributes.
public struct Attributes: Equatable {
    var rawAttributes: [RawAttribute]

    public init() {
        self.rawAttributes = []
    }

    public init(_ rawAttributes: [RawAttribute]) {
        self.rawAttributes = rawAttributes
    }

    /// get returns first attribute from list by the type.
    /// If attribute is present the RawAttribute is returned and the
    /// boolean is true. Otherwise the returned RawAttribute will be
    /// empty and boolean will be false.
    public func get(_ t: AttrType) -> (RawAttribute, Bool) {
        for candidate in self.rawAttributes {
            if candidate.typ == t {
                return (candidate, true)
            }
        }

        return (RawAttribute(), false)
    }
}

/// AttrType is attribute type.
public struct AttrType: Equatable {
    var rawValue: UInt16

    public init(_ rawValue: UInt16) {
        self.rawValue = rawValue
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

extension AttrType: CustomStringConvertible {
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
        case attrSoftware:
            return "SOFTWARE"
        case attrAlternateServer:
            return "ALTERNATE-SERVER"
        case attrFingerprint:
            return "FINGERPRINT"
        case attrPriority:
            return "PRIORITY"
        case attrUseCandidate:
            return "USE-CANDIDATE"
        case attrIceControlled:
            return "ICE-CONTROLLED"
        case attrIceControlling:
            return "ICE-CONTROLLING"
        case attrChannelNumber:
            return "CHANNEL-NUMBER"
        case attrLifetime:
            return "LIFETIME"
        case attrXorPeerAddress:
            return "XOR-PEER-ADDRESS"
        case attrData:
            return "DATA"
        case attrXorRelayedAddress:
            return "XOR-RELAYED-ADDRESS"
        case attrEvenPort:
            return "EVEN-PORT"
        case attrRequestedTransport:
            return "REQUESTED-TRANSPORT"
        case attrDontFragment:
            return "DONT-FRAGMENT"
        case attrReservationToken:
            return "RESERVATION-TOKEN"
        case attrConnectionId:
            return "CONNECTION-ID"
        case attrRequestedAddressFamily:
            return "REQUESTED-ADDRESS-FAMILY"
        case attrMessageIntegritySha256:
            return "MESSAGE-INTEGRITY-SHA256"
        case attrPasswordAlgorithm:
            return "PASSWORD-ALGORITHM"
        case attrUserHash:
            return "USERHASH"
        case attrPasswordAlgorithms:
            return "PASSWORD-ALGORITHMS"
        case attrAlternateDomain:
            return "ALTERNATE-DOMAIN"
        default:
            return "0x\(String(self.rawValue, radix: 16, uppercase: false))"
        }
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
public let attrSoftware: AttrType = AttrType(0x8022)
// ALTERNATE-SERVER
public let attrAlternateServer: AttrType = AttrType(0x8023)
// FINGERPRINT
public let attrFingerprint: AttrType = AttrType(0x8028)

/// Attributes from RFC 5245 ICE.
// PRIORITY
public let attrPriority: AttrType = AttrType(0x0024)
// USE-CANDIDATE
public let attrUseCandidate: AttrType = AttrType(0x0025)
// ICE-CONTROLLED
public let attrIceControlled: AttrType = AttrType(0x8029)
// ICE-CONTROLLING
public let attrIceControlling: AttrType = AttrType(0x802A)
// NETWORK-COST
public let attrNetworkCost: AttrType = AttrType(0xC057)

/// Attributes from RFC 5766 TURN.
// CHANNEL-NUMBER
public let attrChannelNumber: AttrType = AttrType(0x000C)
// LIFETIME
public let attrLifetime: AttrType = AttrType(0x000D)
// XOR-PEER-ADDRESS
public let attrXorPeerAddress: AttrType = AttrType(0x0012)
// DATA
public let attrData: AttrType = AttrType(0x0013)
// XOR-RELAYED-ADDRESS
public let attrXorRelayedAddress: AttrType = AttrType(0x0016)
// EVEN-PORT
public let attrEvenPort: AttrType = AttrType(0x0018)
// REQUESTED-TRANSPORT
public let attrRequestedTransport: AttrType = AttrType(0x0019)
// DONT-FRAGMENT
public let attrDontFragment: AttrType = AttrType(0x001A)
// RESERVATION-TOKEN
public let attrReservationToken: AttrType = AttrType(0x0022)

/// Attributes from RFC 5780 NAT Behavior Discovery
// CHANGE-REQUEST
public let attrChangeRequest: AttrType = AttrType(0x0003)
// PADDING
public let attrPadding: AttrType = AttrType(0x0026)
// RESPONSE-PORT
public let attrResponsePort: AttrType = AttrType(0x0027)
// CACHE-TIMEOUT
public let attrCacheTimeout: AttrType = AttrType(0x8027)
// RESPONSE-ORIGIN
public let attrResponseOrigin: AttrType = AttrType(0x802b)
// OTHER-ADDRESS
public let attrOtherAddress: AttrType = AttrType(0x802C)

/// Attributes from RFC 3489, removed by RFC 5389,
///  but still used by RFC5389-implementing software like Vovida.org, reTURNServer, etc.
// SOURCE-ADDRESS
public let attrSourceAddress: AttrType = AttrType(0x0004)
// CHANGED-ADDRESS
public let attrChangedAddress: AttrType = AttrType(0x0005)

/// Attributes from RFC 6062 TURN Extensions for TCP Allocations.
// CONNECTION-ID
public let attrConnectionId: AttrType = AttrType(0x002a)

/// Attributes from RFC 6156 TURN IPv6.
// REQUESTED-ADDRESS-FAMILY
public let attrRequestedAddressFamily: AttrType = AttrType(0x0017)

/// Attributes from An Origin Attribute for the STUN Protocol.
public let attrOrigin: AttrType = AttrType(0x802F)

/// Attributes from RFC 8489 STUN.
// MESSAGE-INTEGRITY-SHA256
public let attrMessageIntegritySha256: AttrType = AttrType(0x001C)
// PASSWORD-ALGORITHM
public let attrPasswordAlgorithm: AttrType = AttrType(0x001D)
// USER-HASH
public let attrUserHash: AttrType = AttrType(0x001E)
// PASSWORD-ALGORITHMS
public let attrPasswordAlgorithms: AttrType = AttrType(0x8002)
// ALTERNATE-DOMAIN
public let attrAlternateDomain: AttrType = AttrType(0x8003)

/// RawAttribute is a Type-Length-Value (TLV) object that
/// can be added to a STUN message. Attributes are divided into two
/// types: comprehension-required and comprehension-optional.  STUN
/// agents can safely ignore comprehension-optional attributes they
/// don't understand, but cannot successfully process a message if it
/// contains comprehension-required attributes that are not
/// understood.
public struct RawAttribute: Equatable {
    var typ: AttrType
    var length: Int  // ignored while encoding
    var value: ByteBuffer

    public init() {
        self.typ = AttrType(0)
        self.length = 0
        self.value = ByteBuffer()
    }

    public init(typ: AttrType, length: Int, value: ByteBuffer) {
        self.typ = typ
        self.length = length
        self.value = value
    }

}

extension RawAttribute: CustomStringConvertible {
    public var description: String {
        return "\(self.typ): \(value)"
    }
}

extension RawAttribute: Setter {
    /// implements Setter, adding attribute as a.Type with a.Value and ignoring
    /// the Length field.
    public func addTo(_ m: Message) throws {
        m.add(self.typ, ByteBufferView(self.value))
    }
}

let padding: Int = 4

/// STUN aligns attributes on 32-bit boundaries, attributes whose content
/// is not a multiple of 4 bytes are padded with 1, 2, or 3 bytes of
/// padding so that its value contains a multiple of 4 bytes.  The
/// padding bits are ignored, and may be any value.
///
/// https://tools.ietf.org/html/rfc5389#section-15
func nearestPaddedValueLength(_ l: Int) -> Int {
    var n = padding * (l / padding)
    if n < l {
        n += padding
    }
    return n
}

/// This method converts uint16 vlue to AttrType. If it finds an old attribute
/// type value, it also translates it to the new value to enable backward
/// compatibility. (See: https://github.com/pion/stun/issues/21)
func compatAttrType(_ val: UInt16) -> AttrType {
    if val == 0x8020 {
        // draft-ietf-behave-rfc3489bis-02, MS-TURN
        return attrXormappedAddress  // new: 0x0020 (from draft-ietf-behave-rfc3489bis-03 on)
    } else {
        return AttrType(val)
    }
}
