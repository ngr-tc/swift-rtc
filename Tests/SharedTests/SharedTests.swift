import NIOCore
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

@testable import Shared

final class UtilsTests: XCTestCase {
    func testTrimmingWhitespace() throws {
        let str = "  Hello, World!  "
        let trimmed = str.trimmingWhitespace()
        XCTAssertEqual("Hello, World!", trimmed)
    }

    func testSocketAddressIPv4() throws {
        let socketAddressFromString = try SocketAddress(ipAddress: "127.0.0.1", port: 8080)
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: [127, 0, 0, 1]), port: 8080)
        XCTAssertEqual(socketAddressFromString, socketAddressFromByteBuffer)
        XCTAssertEqual(socketAddressFromString.description, "[IPv4]127.0.0.1:8080")
        XCTAssertEqual([127, 0, 0, 1], socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv4AllZeros() throws {
        let socketAddressFromString = try SocketAddress(ipAddress: "0.0.0.0", port: 0)
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: [0, 0, 0, 0]), port: 0)
        XCTAssertEqual(socketAddressFromString, socketAddressFromByteBuffer)
        XCTAssertEqual(socketAddressFromString.description, "[IPv4]0.0.0.0:0")
        XCTAssertEqual([0, 0, 0, 0], socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv6() throws {
        let socketAddressFromString1 = try SocketAddress(
            ipAddress: "fe80:0:0:0:0:0:0:5", port: 8080)
        let socketAddressFromString2 = try SocketAddress(ipAddress: "fe80::5", port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromString2)

        var ipv6Bytes = [UInt8](repeating: 0, count: 16)
        ipv6Bytes[0] = 0xfe
        ipv6Bytes[1] = 0x80
        ipv6Bytes[15] = 0x05
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromByteBuffer)
        XCTAssertEqual(ipv6Bytes, socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv6First() throws {
        let socketAddressFromString1 = try SocketAddress(ipAddress: "5:0:0:0:0:0:0:0", port: 8080)
        let socketAddressFromString2 = try SocketAddress(ipAddress: "5::", port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromString2)

        var ipv6Bytes = [UInt8](repeating: 0, count: 16)
        ipv6Bytes[1] = 0x05
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromByteBuffer)
        XCTAssertEqual(ipv6Bytes, socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv6Middle() throws {
        let socketAddressFromString1 = try SocketAddress(ipAddress: "0:0:0:5:0:0:0:0", port: 8080)
        let socketAddressFromString2 = try SocketAddress(ipAddress: "0:0:0:5::", port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromString2)
        XCTAssertEqual(socketAddressFromString1.description, "[IPv6]0:0:0:5:::8080")

        var ipv6Bytes = [UInt8](repeating: 0, count: 16)
        ipv6Bytes[7] = 0x05
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromByteBuffer)
        XCTAssertEqual(ipv6Bytes, socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv6Last() throws {
        let socketAddressFromString1 = try SocketAddress(ipAddress: "0:0:0:0:0:0:0:5", port: 8080)
        let socketAddressFromString2 = try SocketAddress(ipAddress: "::5", port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromString2)

        var ipv6Bytes = [UInt8](repeating: 0, count: 16)
        ipv6Bytes[15] = 0x05
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromByteBuffer)
        XCTAssertEqual(ipv6Bytes, socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv6FirstMiddle() throws {
        let socketAddressFromString1 = try SocketAddress(ipAddress: "1:0:0:7:0:0:0:0", port: 8080)
        let socketAddressFromString2 = try SocketAddress(ipAddress: "1:0:0:7::", port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromString2)
        XCTAssertEqual(socketAddressFromString1.description, "[IPv6]1:0:0:7:::8080")

        var ipv6Bytes = [UInt8](repeating: 0, count: 16)
        ipv6Bytes[1] = 0x01
        ipv6Bytes[7] = 0x07
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromByteBuffer)
        XCTAssertEqual(ipv6Bytes, socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv6MiddleLast() throws {
        let socketAddressFromString1 = try SocketAddress(ipAddress: "0:0:0:7:0:0:0:f", port: 8080)
        let socketAddressFromString2 = try SocketAddress(ipAddress: "::7:0:0:0:f", port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromString2)
        XCTAssertEqual(socketAddressFromString1.description, "[IPv6]::7:0:0:0:f:8080")

        var ipv6Bytes = [UInt8](repeating: 0, count: 16)
        ipv6Bytes[7] = 0x07
        ipv6Bytes[15] = 0x0f
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromByteBuffer)
        XCTAssertEqual(ipv6Bytes, socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv6FirstMiddleLast1() throws {
        let socketAddressFromString1 = try SocketAddress(ipAddress: "1:0:0:7:0:0:0:f", port: 8080)
        let socketAddressFromString2 = try SocketAddress(ipAddress: "1:0:0:7::f", port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromString2)
        XCTAssertEqual(socketAddressFromString1.description, "[IPv6]1:0:0:7::f:8080")

        var ipv6Bytes = [UInt8](repeating: 0, count: 16)
        ipv6Bytes[1] = 0x01
        ipv6Bytes[7] = 0x07
        ipv6Bytes[15] = 0x0f
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromByteBuffer)
        XCTAssertEqual(ipv6Bytes, socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv6FirstMiddleLast2() throws {
        let socketAddressFromString1 = try SocketAddress(ipAddress: "1:0:0:0:9:0:0:f", port: 8080)
        let socketAddressFromString2 = try SocketAddress(ipAddress: "1::9:0:0:f", port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromString2)
        XCTAssertEqual(socketAddressFromString1.description, "[IPv6]1::9:0:0:f:8080")

        var ipv6Bytes = [UInt8](repeating: 0, count: 16)
        ipv6Bytes[1] = 0x01
        ipv6Bytes[9] = 0x09
        ipv6Bytes[15] = 0x0f
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 8080)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromByteBuffer)
        XCTAssertEqual(ipv6Bytes, socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv6AllZeros() throws {
        let socketAddressFromString1 = try SocketAddress(ipAddress: "0:0:0:0:0:0:0:0", port: 0)
        let socketAddressFromString2 = try SocketAddress(ipAddress: "::", port: 0)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromString2)
        XCTAssertEqual(socketAddressFromString1.description, "[IPv6]:::0")

        let ipv6Bytes = [UInt8](repeating: 0, count: 16)
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 0)
        XCTAssertEqual(socketAddressFromString1, socketAddressFromByteBuffer)
        XCTAssertEqual(ipv6Bytes, socketAddressFromByteBuffer.octets())
    }

    func testSocketAddressIPv6NonZeros() throws {
        let socketAddressFromString = try SocketAddress(
            ipAddress: "fe80::dc2b:44ff:fe20:6009", port: 21254)

        var ipv6Bytes = [UInt8](repeating: 0, count: 16)
        ipv6Bytes[0] = 0xfe
        ipv6Bytes[1] = 0x80
        ipv6Bytes[8] = 0xdc
        ipv6Bytes[9] = 0x2b
        ipv6Bytes[10] = 0x44
        ipv6Bytes[11] = 0xff
        ipv6Bytes[12] = 0xfe
        ipv6Bytes[13] = 0x20
        ipv6Bytes[14] = 0x60
        ipv6Bytes[15] = 0x09
        let socketAddressFromByteBuffer = try SocketAddress(
            packedIPAddress: ByteBuffer(bytes: ipv6Bytes), port: 21254)
        XCTAssertEqual(socketAddressFromString, socketAddressFromByteBuffer)
        XCTAssertEqual(ipv6Bytes, socketAddressFromByteBuffer.octets())
    }
}
