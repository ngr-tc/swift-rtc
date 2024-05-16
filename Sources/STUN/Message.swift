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
import Utils

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


// MAGIC_COOKIE is fixed value that aids in distinguishing STUN packets
// from packets of other protocols when STUN is multiplexed with those
// other protocols on the same Port.
//
// The magic cookie field MUST contain the fixed value 0x2112A442 in
// network byte order.
//
// Defined in "STUN Message Structure", section 6.
let MAGIC_COOKIE: UInt32 = 0x2112A442
let ATTRIBUTE_HEADER_SIZE: Int = 4
let MESSAGE_HEADER_SIZE: Int = 20

// TRANSACTION_ID_SIZE is length of transaction id array (in bytes).
let TRANSACTION_ID_SIZE: Int = 12; // 96 bit

public struct TransactionId: Setter {
    public var raw: [UInt8]
    
    /// new returns new random transaction ID using crypto/rand
    /// as source.
    public init() {
        self.raw = (0..<TRANSACTION_ID_SIZE).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
    }
    
    public func addTo(m: inout Message) throws {
        m.transactionId = self
        m.writeTransactionId()
    }
}


/// is_message returns true if b looks like STUN message.
/// Useful for multiplexing. is_message does not guarantee
/// that decoding will be successful.
public func isMessage(b: inout [UInt8]) -> Bool {
    b.count >= MESSAGE_HEADER_SIZE && UInt32.fromBeBytes(byte1: b[4], byte2: b[5], byte3: b[6], byte4: b[7]) == MAGIC_COOKIE
}

/// Message represents a single STUN packet. It uses aggressive internal
/// buffering to enable zero-allocation encoding and decoding,
/// so there are some usage constraints:
///
///     Message, its fields, results of m.Get or any attribute a.GetFrom
///    are valid only until Message.Raw is not modified.
public class Message {
    //var typ: MessageType
    var length: Int
    var transactionId: TransactionId
    //var attributes: Attributes
    var raw: [UInt8]
    
    public init(length: Int, transactionId: TransactionId, raw: [UInt8]) {
        self.length = length
        self.transactionId = transactionId
        self.raw = raw
    }
    
    // WriteTransactionID writes m.TransactionID to m.Raw.
    public func writeTransactionId() {
        self.raw[8..<MESSAGE_HEADER_SIZE] = self.transactionId.raw[...]
    }
}
