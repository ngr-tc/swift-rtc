import ExtrasBase64
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

@testable import STUN

final class XorMappedAddressTests: XCTestCase {
    func testXorSafe() throws {
        var dst = ByteBuffer(repeating: 0, count: 8)
        let a = ByteBuffer(bytes: [1, 2, 3, 4, 5, 6, 7, 8])
        let b = ByteBuffer(bytes: [8, 7, 7, 6, 6, 3, 4, 1])
        let _ = safeXorBytes(&dst, ByteBufferView(a), ByteBufferView(b))

        let c = ByteBuffer(buffer: dst)
        let _ = safeXorBytes(&dst, ByteBufferView(c), ByteBufferView(a))

        let dstView = ByteBufferView(dst)
        let bView = ByteBufferView(b)
        for i in 0..<dstView.count {
            XCTAssertEqual(bView[i], dstView[i])
        }
    }

    func testXorSafeBsmaller() throws {
        var dst = ByteBuffer(repeating: 0, count: 5)
        let a = ByteBuffer(bytes: [1, 2, 3, 4, 5, 6, 7, 8])
        let b = ByteBuffer(bytes: [8, 7, 7, 6, 6])
        let _ = safeXorBytes(&dst, ByteBufferView(a), ByteBufferView(b))

        let c = ByteBuffer(buffer: dst)
        let _ = safeXorBytes(&dst, ByteBufferView(c), ByteBufferView(a))

        let dstView = ByteBufferView(dst)
        let bView = ByteBufferView(b)
        for i in 0..<dstView.count {
            XCTAssertEqual(bView[i], dstView[i])
        }
    }

    func testXorMappedAddressGetFrom() throws {
        let m = Message()
        let transactionId = try Base64.decode(string: "jxhBARZwX+rsC6er")
        m.transactionId.rawValue = ByteBuffer(bytes: transactionId)

        let addrValue = ByteBuffer(bytes: [0x00, 0x01, 0x9c, 0xd5, 0xf4, 0x9f, 0x38, 0xae])
        m.add(attrXorMappedAddress, ByteBufferView(addrValue))

        var addr = XorMappedAddress()
        try addr.getFrom(m)
        XCTAssertEqual(
            addr.socketAddress.ipAddress?.description,
            "213.141.156.236"
        )
        XCTAssertEqual(addr.socketAddress.port, 48583)

        //"UnexpectedEOF"
        do {
            let m = Message()
            // {0, 1} is correct addr family.
            m.add(attrXorMappedAddress, ByteBufferView([0, 1, 3, 4]))
            var addr = XorMappedAddress()
            do {
                let _ = try addr.getFrom(m)
                XCTAssertTrue(false, "should error")
            } catch STUNError.errUnexpectedEof {
                XCTAssertTrue(true)
            } catch {
                XCTAssertTrue(false, "should errAttributeNotFound")
            }
        }

        //"AttrOverflowErr"
        do {
            let m = Message()
            // {0, 1} is correct addr family.
            m.add(
                attrXorMappedAddress,
                ByteBufferView([0, 1, 3, 4, 5, 6, 7, 8, 9, 1, 1, 1, 1, 1, 2, 3, 4]))
            var addr = XorMappedAddress()
            do {
                let _ = try addr.getFrom(m)
                XCTAssertTrue(false, "should error")
            } catch STUNError.errAttributeSizeOverflow {
                XCTAssertTrue(true)
            } catch {
                XCTAssertTrue(false, "should errAttributeSizeOverflow")
            }
        }
    }

    func testXorMappedAddressGetFromInvalid() throws {
        let m = Message()
        let transactionId = try Base64.decode(string: "jxhBARZwX+rsC6er")
        m.transactionId.rawValue = ByteBuffer(bytes: transactionId)

        let expectedAddress = try SocketAddress(ipAddress: "213.141.156.236", port: 21254)
        var addr = XorMappedAddress()

        do {
            let _ = try addr.getFrom(m)
            XCTAssertTrue(false, "should error")
        } catch {
            XCTAssertTrue(true)
        }

        addr.socketAddress = expectedAddress
        try addr.addTo(m)
        m.writeHeader()

        let mRes = Message()
        m.raw.setRepeatingByte(0x21, count: 1, at: 20 + 4 + 1)
        try m.decode()

        let _ = try mRes.readFrom(ByteBufferView(m.raw))

        do {
            let _ = try addr.getFrom(m)
            XCTAssertTrue(false, "should error")
        } catch {
            XCTAssertTrue(true)
        }
    }

    func testXorMappedAddressAddTo() throws {
        let m = Message()
        let transactionId = try Base64.decode(string: "jxhBARZwX+rsC6er")
        m.transactionId.rawValue = ByteBuffer(bytes: transactionId)

        let expectedAddress = try SocketAddress(ipAddress: "213.141.156.236", port: 21254)
        var addr = XorMappedAddress(socketAddress: expectedAddress)

        try addr.addTo(m)
        m.writeHeader()

        let mRes = Message()
        let _ = try mRes.write(ByteBufferView(m.raw))
        try addr.getFrom(mRes)
        XCTAssertEqual(addr.socketAddress, expectedAddress)
    }

    func testXorMappedAddressAddToIpV6() throws {
        let m = Message()
        let transactionId = try Base64.decode(string: "jxhBARZwX+rsC6er")
        m.transactionId.rawValue = ByteBuffer(bytes: transactionId)

        let expectedAddress = try SocketAddress(ipAddress: "fe80::dc2b:44ff:fe20:6009", port: 21254)
        let addr = XorMappedAddress(socketAddress: expectedAddress)

        try addr.addTo(m)
        m.writeHeader()

        let mRes = Message()
        let _ = try mRes.readFrom(ByteBufferView(m.raw))

        var gotAddr = XorMappedAddress()
        let _ = try gotAddr.getFrom(m)

        XCTAssertEqual(gotAddr.socketAddress, expectedAddress)
    }

    func testXorMappedAddressString() throws {
        let tests = [
            (
                // 0
                XorMappedAddress(
                    socketAddress: try SocketAddress(
                        ipAddress: "fe80::dc2b:44ff:fe20:6009", port: 124)),
                "[IPv6]fe80::dc2b:44ff:fe20:6009:124"
            ),
            (
                // 1
                XorMappedAddress(
                    socketAddress: try SocketAddress(ipAddress: "213.141.156.236", port: 8147)),
                "[IPv4]213.141.156.236:8147"
            ),
        ]

        for (addr, ip) in tests {
            XCTAssertEqual(addr.description, ip)
        }
    }
}
