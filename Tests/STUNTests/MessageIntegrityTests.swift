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

final class MessageIntegrityTests: XCTestCase {
    func testMessageIntegrityAddToSimple() throws {
        do {
            let i = MessageIntegrity(username: "user", realm: "realm", password: "passsss")
            let expected: [UInt8] = [
                104, 228, 91, 113, 61, 154, 222, 34, 101, 61, 181, 146, 177, 90, 4, 29,
            ]
            XCTAssertEqual(i.rawValue.getBytes(at: 0, length: i.rawValue.readableBytes)!, expected)

        }

        let i = MessageIntegrity(username: "user", realm: "realm", password: "pass")
        let expected: [UInt8] = [
            0x84, 0x93, 0xfb, 0xc5, 0x3b, 0xa5, 0x82, 0xfb, 0x4c, 0x04, 0x4c, 0x45, 0x6b, 0xdc,
            0x40, 0xeb,
        ]
        XCTAssertEqual(i.rawValue.getBytes(at: 0, length: i.rawValue.readableBytes)!, expected)

        //"Check"
        do {
            var m = Message()
            m.writeHeader()
            try i.addTo(&m)

            let a = TextAttribute(
                attr: attrSoftware,
                text: "software"
            )
            try a.addTo(&m)
            m.writeHeader()

            var dm = Message()
            dm.raw = ByteBuffer(buffer: m.raw)
            try dm.decode()
            try i.check(&dm)

            dm.raw.setRepeatingByte(12, count: 1, at: 24)  // HMAC now invalid
            try dm.decode()
            do {
                try i.check(&dm)
                XCTAssertTrue(false, "should error")
            } catch StunError.errIntegrityMismatch {
                XCTAssertTrue(true)
            } catch {
                XCTAssertTrue(false, "should errIntegrityMismatch")
            }
        }
    }

    func testMessageIntegrityWithFingerprint() throws {
        var m = Message()
        m.transactionId = TransactionId(ByteBuffer(bytes: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0]))
        m.writeHeader()
        let a = TextAttribute(
            attr: attrSoftware,
            text: "software"
        )
        try a.addTo(&m)

        let i = MessageIntegrity(password: "pwd")
        XCTAssertEqual(i.description, "KEY: 0x[70 77 64]")

        do {
            try i.check(&m)
        } catch StunError.errAttributeNotFound {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errAttributeNotFound")
        }

        try i.addTo(&m)
        try fingerprint.addTo(&m)
        try i.check(&m)

        m.raw.setRepeatingByte(33, count: 1, at: 24)
        try m.decode()

        do {
            try i.check(&m)
        } catch StunError.errIntegrityMismatch {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errIntegrityMismatch")
        }
    }

    func testMessageIntegrity() throws {
        var m = Message()
        let i = MessageIntegrity(password: "password")
        m.writeHeader()
        try i.addTo(&m)
        let _ = try m.get(attrMessageIntegrity)
    }

    func testMessageIntegrityBeforeFingerprint() throws {
        var m = Message()
        m.writeHeader()
        try fingerprint.addTo(&m)
        let i = MessageIntegrity(password: "password")
        do {
            try i.addTo(&m)
            XCTAssertTrue(false, "should error")
        } catch StunError.errFingerprintBeforeIntegrity {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errFingerprintBeforeIntegrity")
        }
    }

}
