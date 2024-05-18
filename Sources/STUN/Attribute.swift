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
public struct Attributes{
    var rawAttributes: [RawAttribute]
}


/// AttrType is attribute type.
public struct AttrType{
    var rawValue: UInt16
}


/// RawAttribute is a Type-Length-Value (TLV) object that
/// can be added to a STUN message. Attributes are divided into two
/// types: comprehension-required and comprehension-optional.  STUN
/// agents can safely ignore comprehension-optional attributes they
/// don't understand, but cannot successfully process a message if it
/// contains comprehension-required attributes that are not
/// understood.
public struct RawAttribute {
    var typ: AttrType
    var length: UInt16 // ignored while encoding
    var value: [UInt8]
}
