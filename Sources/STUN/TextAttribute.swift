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

let maxUsernameB: Int = 513
let maxRealmB: Int = 763
let maxSoftwareB: Int = 763
let maxNonceB: Int = 763

/// Username represents USERNAME attribute.
///
/// RFC 5389 Section 15.3
public typealias Username = TextAttribute

/// Realm represents REALM attribute.
///
/// RFC 5389 Section 15.7
public typealias Realm = TextAttribute

/// Nonce represents NONCE attribute.
///
/// RFC 5389 Section 15.8
public typealias Nonce = TextAttribute

/// Software is SOFTWARE attribute.
///
/// RFC 5389 Section 15.10
public typealias Software = TextAttribute

// TextAttribute is helper for adding and getting text attributes.
public struct TextAttribute {
    var attr: AttrType
    var text: String

    public init(attr: AttrType, text: String) {
        self.attr = attr
        self.text = text
    }

    // gets t attribute from m and appends its value to reseted v.
    public static func getFromAs(_ m: Message, _ attr: AttrType) throws -> Self {
        if attr != attrUsername && attr != attrRealm && attr != attrSoftware && attr != attrNonce {
            throw STUNError.errUnsupportedAttrType(attr)
        }

        let a = try m.get(attr)
        let ab = ByteBuffer(a)
        guard let text = ab.getString(at: 0, length: a.count) else {
            throw STUNError.errInvalidTextAttribute
        }
        return TextAttribute(attr: attr, text: text)
    }
}

extension TextAttribute: CustomStringConvertible {
    public var description: String {
        return "\(self.text)"
    }
}

extension TextAttribute: Setter {
    /// adds attribute with type t to m, checking maximum length. If max_len
    /// is less than 0, no check is performed.
    public func addTo(_ m: Message) throws {
        let maxLen =
            switch self.attr {
            case attrUsername:
                maxUsernameB
            case attrRealm:
                maxRealmB
            case attrSoftware:
                maxSoftwareB
            case attrNonce:
                maxNonceB
            default:
                throw STUNError.errUnsupportedAttrType(self.attr)
            }
        let text = ByteBuffer(string: self.text)
        let textView = ByteBufferView(text)
        try checkOverflow(self.attr, textView.count, maxLen)
        m.add(self.attr, textView)
    }
}

extension TextAttribute: Getter {
    public mutating func getFrom(_ m: Message) throws {
        self = try TextAttribute.getFromAs(m, self.attr)
    }
}
