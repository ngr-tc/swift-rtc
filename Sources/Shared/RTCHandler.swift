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

/// Transport protocol
public enum TransportProtocol {
    /// UDP
    case udp
    /// TCP
    case tcp
}

/// Explicit congestion notification codepoint
public enum EcnCodepoint: UInt8, Equatable {
    case ect0 = 0b10
    case ect1 = 0b01
    case ce = 0b11

    /// Create new object from the given bits
    public static func fromBits(rawValue: UInt8) -> Self? {
        switch rawValue {
        case 0b10:
            return .ect0
        case 0b01:
            return .ect1
        case 0b11:
            return .ce
        default:
            return nil
        }
    }
}

/// Transport context with local address, peer address, ECN, protocol, etc.
public struct TransportContext {
    /// Local socket address, either IPv4 or IPv6
    public var local: SocketAddress
    /// Peer socket address, either IPv4 or IPv6
    public var peer: SocketAddress
    /// Type of protocol, either UDP or TCP
    public var proto: TransportProtocol
    /// Explicit congestion notification bits to set on the packet
    public var ecn: EcnCodepoint?

    public init(
        local: SocketAddress, peer: SocketAddress, proto: TransportProtocol,
        ecn: EcnCodepoint? = nil
    ) {
        self.local = local
        self.peer = peer
        self.proto = proto
        self.ecn = ecn
    }
}

/// A generic transmit with [TransportContext]
public struct Transmit<T> {
    /// Received/Sent time
    public var now: NIODeadline
    /// A transport context with [local_addr](TransportContext::local_addr) and [peer_addr](TransportContext::peer_addr)
    public var transport: TransportContext
    /// Message body with generic type
    public var message: T

    public init(now: NIODeadline, transport: TransportContext, message: T) {
        self.now = now
        self.transport = transport
        self.message = message
    }
}

/// RTC handler protocol
public protocol RTCHandler {
    /// Event input associated type
    associatedtype Ein
    /// Event output associated type
    associatedtype Eout
    /// Read input message associated type
    associatedtype Rin
    /// Read output message associated type
    associatedtype Rout
    /// Write input message associated type
    associatedtype Win
    /// Write output message associated type
    associatedtype Wout

    /// Handles Rin and returns Rout for next inbound handler handling
    mutating func handleRead(_ rin: Transmit<Rin>) throws

    /// Polls Rout from internal queue for next inbound handler handling
    mutating func pollRead() -> Transmit<Rout>?

    /// Handles Win and returns Wout for next outbound handler handling
    mutating func handleWrite(_ win: Transmit<Win>) throws

    /// Polls Wout from internal queue for next outbound handler handling
    mutating func pollWrite() -> Transmit<Wout>?

    /// Handle event
    mutating func handleEvent(_ evt: Ein) throws

    /// Polls event
    mutating func pollEvent() -> Eout?

    /// Handle timeout
    mutating func handleTimeout(_ now: NIODeadline) throws

    /// Polls timeout
    mutating func pollTimeout() -> NIODeadline?
}
