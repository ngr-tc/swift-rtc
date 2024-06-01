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
