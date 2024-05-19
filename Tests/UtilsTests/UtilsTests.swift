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
import XCTest
import NIOCore

@testable import Utils

final class UtilsTests: XCTestCase {
    func testTrimmingWhitespace() throws {
        let str = "  Hello, World!  "
        let trimmed = str.trimmingWhitespace()
        XCTAssertEqual("Hello, World!", trimmed)
    }
    
    func testSocketAddressIPv4() throws {
        let socketAddressFromString = try SocketAddress(ipAddress: "127.0.0.1", port: 8080)
        let socketAddressFromByteBuffer = try SocketAddress(packedIPAddress: ByteBuffer(bytes: [127, 0, 0, 1]), port: 8080)
        XCTAssertEqual(socketAddressFromString,socketAddressFromByteBuffer)
        
        switch socketAddressFromByteBuffer {
        case SocketAddress.v4(let ipv4):
            XCTAssertEqual([127, 0, 0, 1], ipv4.octets())
        default:
            XCTAssertTrue(false, "invalid IPv4 address")
        }
    }
    
    func testSocketAddressIPv6() throws {
        let socketAddressFromString1 = try SocketAddress(ipAddress: "fe80:0:0:0:0:0:0:5", port: 8080)
        let socketAddressFromString2 = try SocketAddress(ipAddress: "fe80::5", port: 8080)
        XCTAssertEqual(socketAddressFromString1,socketAddressFromString2)
    
        var ipv6Bytes = [UInt8](repeating: 0, count: 16)
        ipv6Bytes[0] = 0xfe
        ipv6Bytes[1] = 0x80
        ipv6Bytes[15] = 0x05
        let socketAddressFromByteBuffer = try SocketAddress(packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 8080)
        XCTAssertEqual(socketAddressFromString1,socketAddressFromByteBuffer)
        
        switch socketAddressFromByteBuffer {
        case SocketAddress.v6(let ipv6):
            XCTAssertEqual(ipv6Bytes, ipv6.octets())
        default:
            XCTAssertTrue(false, "invalid IPv6 address")
        }
    }
}
