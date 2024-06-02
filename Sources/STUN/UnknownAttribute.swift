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

/// UnknownAttributes represents UNKNOWN-ATTRIBUTES attribute.
///
/// RFC 5389 Section 15.9
public struct UnknownAttributes {
    var attributes: [AttrType]

    public init(attributes: [AttrType] = []) {
        self.attributes = attributes
    }
}

extension UnknownAttributes: CustomStringConvertible {
    public var description: String {
        if self.attributes.isEmpty {
            return "<nil>"
        } else {
            return self.attributes.map { $0.description }.joined(separator: ", ")
        }
    }
}

// type size is 16 bit.
let attrTypeSize: Int = 2

extension UnknownAttributes: Setter {
    /// add_to adds UNKNOWN-ATTRIBUTES attribute to message.
    public func addTo(_ m: inout Message) throws {
        var v = ByteBuffer()  //ATTR_TYPE_SIZE * 20); // 20 should be enough
        // If len(a.Types) > 20, there will be allocations.
        for t in self.attributes {
            v.writeBytes(t.value().toBeBytes())
        }

        m.add(attrUnknownAttributes, ByteBufferView(v))
    }
}

extension UnknownAttributes: Getter {
    /// GetFrom parses UNKNOWN-ATTRIBUTES from message.
    public mutating func getFrom(_ m: inout Message) throws {
        let b = try m.get(attrUnknownAttributes)
        let v = ByteBufferView(b)
        if v.count % attrTypeSize != 0 {
            throw StunError.errBadUnknownAttrsSize
        }
        self.attributes = []
        var first = 0
        while first < v.count {
            let last = first + attrTypeSize
            self.attributes
                .append(AttrType(UInt16.fromBeBytes(v[first], v[first + 1])))
            first = last
        }
    }
}
