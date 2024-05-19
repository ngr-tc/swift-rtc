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

final class AddressTests: XCTestCase {
    func testMappedAddress() throws {
        let m = Message()
        let addr = MappedAddress(
            socketAddress: try SocketAddress(ipAddress: "122.12.34.5", port: 5412)
        )
        XCTAssertEqual("[IPv4]122.12.34.5:5412", addr.description)

        //"add_to"
        try addr.addTo(m)

        //"GetFrom"
        var got = MappedAddress()
        try got.getFrom(m)
        XCTAssertEqual(got.socketAddress.ipAddress, addr.socketAddress.ipAddress)

        //"Not found"
        do {
            let message = Message()
            try got.getFrom(message)
            XCTAssertTrue(false, "should throw STUNError.errAttributeNotFound")
        } catch STUNError.errAttributeNotFound {
            XCTAssertTrue(true)
        }

        //"Bad family"
        var (v, _) = m.attributes.get(attrMappedAddress)
        v.value[0] = 32
        try got.getFrom(m)

        //"Bad length"
        do {
            let message = Message()
            message.add(attrMappedAddress, [1, 2, 3])
            try got.getFrom(message)
            XCTAssertTrue(false, "should throw STUNError.errUnexpectedEof")
        } catch STUNError.errUnexpectedEof {
            XCTAssertTrue(true)
        }
    }

    func testMappedAddressV6() throws {
        let m = Message()
        let addr = MappedAddress(
            socketAddress: try SocketAddress(ipAddress: "::", port: 5412)
        )

        //"add_to"
        try addr.addTo(m)

        //"GetFrom"
        var got = MappedAddress()
        try got.getFrom(m)
        XCTAssertEqual(got.socketAddress.ipAddress, addr.socketAddress.ipAddress)

        //"Not found"
        do {
            let message = Message()
            try got.getFrom(message)
            XCTAssertTrue(false, "should throw STUNError.errAttributeNotFound")
        } catch STUNError.errAttributeNotFound {
            XCTAssertTrue(true)
        }
    }

    func testAlternateServer() throws {
        let m = Message()
        let addr = MappedAddress(
            socketAddress: try SocketAddress(ipAddress: "122.12.34.5", port: 5412)
        )

        //"add_to"
        try addr.addTo(m)

        //"GetFrom"
        var got = AlternateServer()
        try got.getFrom(m)
        XCTAssertEqual(got.socketAddress.ipAddress, addr.socketAddress.ipAddress)

        //"Not found"
        do {
            let message = Message()
            try got.getFrom(message)
            XCTAssertTrue(false, "should throw STUNError.errAttributeNotFound")
        } catch STUNError.errAttributeNotFound {
            XCTAssertTrue(true)
        }

    }

    func testOtherAddress() throws {
        let m = Message()
        let addr = MappedAddress(
            socketAddress: try SocketAddress(ipAddress: "122.12.34.5", port: 5412)
        )

        //"add_to"
        try addr.addTo(m)

        //"GetFrom"
        var got = OtherAddress()
        try got.getFrom(m)
        XCTAssertEqual(got.socketAddress.ipAddress, addr.socketAddress.ipAddress)

        //"Not found"
        do {
            let message = Message()
            try got.getFrom(message)
            XCTAssertTrue(false, "should throw STUNError.errAttributeNotFound")
        } catch STUNError.errAttributeNotFound {
            XCTAssertTrue(true)
        }
    }
}
