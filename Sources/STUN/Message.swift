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

/// Interfaces that are implemented by message attributes, shorthands for them,
/// or helpers for message fields as type or transaction id.
public protocol Setter {
    func addTo(m: inout Message) throws
}

/// Getter parses attribute from *Message.
public protocol Getter {
    mutating func getFrom(m: inout Message) throws
}

/// Checker checks *Message attribute.
public protocol Checker {
    func check(m: inout Message) throws
}

/// is_message returns true if b looks like STUN message.
/// Useful for multiplexing. is_message does not guarantee
/// that decoding will be successful.
/*public func isMessage(b: &[u8]) -> bool {
    b.len() >= MESSAGE_HEADER_SIZE && u32::from_be_bytes([b[4], b[5], b[6], b[7]]) == MAGIC_COOKIE
}*/

/// Message represents a single STUN packet. It uses aggressive internal
/// buffering to enable zero-allocation encoding and decoding,
/// so there are some usage constraints:
///
///     Message, its fields, results of m.Get or any attribute a.GetFrom
///    are valid only until Message.Raw is not modified.
public struct Message {
    /*var typ: MessageType
        var length: UIn32
    var transactionId: TransactionId
        var attributes: Attributes
            var raw: [UInt8]*/
}
