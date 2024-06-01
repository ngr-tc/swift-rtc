//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import NIOCore

#if os(Windows)
    import ucrt
#elseif os(Linux) || os(Android)
    #if canImport(Glibc)
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #endif
    import CNIOLinux

#elseif canImport(Darwin)
    import Darwin
#else
    #error("The BSD Socket module was unable to identify your C library.")
#endif

extension SocketAddress {
    public func octets() -> [UInt8] {
        let addressBytes: [UInt8]?
        switch self {
        case .v4(let addr):
            var mutAddr = addr.address.sin_addr
            addressBytes = withUnsafePointer(to: &mutAddr) {
                $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<in_addr>.size) {
                    Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<in_addr>.size))
                }
            }
        case .v6(let addr):
            var mutAddr = addr.address.sin6_addr
            addressBytes = withUnsafePointer(to: &mutAddr) {
                $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<in6_addr>.size) {
                    Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<in6_addr>.size))
                }
            }
        default:
            addressBytes = []
        }
        return addressBytes ?? []
    }
}

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
}

/// Transport Context with local address, peer address, ECN, protocol, etc.
public struct TransportContext {
    /// Local socket address, either IPv4 or IPv6
    var local: SocketAddress
    /// Peer socket address, either IPv4 or IPv6
    var peer: SocketAddress
    /// Type of protocol, either UDP or TCP
    var proto: TransportProtocol
    /// Explicit congestion notification bits to set on the packet
    var ecn: EcnCodepoint?

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
    var now: NIODeadline
    /// A transport context with [local_addr](TransportContext::local_addr) and [peer_addr](TransportContext::peer_addr)
    var transport: TransportContext
    /// Message body with generic type
    var message: T

    public init(now: NIODeadline, transport: TransportContext, message: T) {
        self.now = now
        self.transport = transport
        self.message = message
    }
}
