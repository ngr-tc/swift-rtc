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

@testable import SRTP

final class ContextTests: XCTestCase {
    let cipherContextAlgo: ProtectionProfile = ProtectionProfile.aes128CmHmacSha1Tag80
    let defaultSsrc: UInt32 = 0

    func testContextRoc() throws {
        let keyLen = cipherContextAlgo.keyLen()
        let saltLen = cipherContextAlgo.saltLen()

        var c = try Context(
            masterKey: ByteBufferView(repeating: 0, count: keyLen),
            masterSalt: ByteBufferView(repeating: 0, count: saltLen),
            profile: cipherContextAlgo,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )

        var roc = c.getRoc(ssrc: 123)
        XCTAssertTrue(roc == nil, "ROC must return None for unused SSRC")

        c.setRoc(ssrc: 123, roc: 100)
        roc = c.getRoc(ssrc: 123)
        if let r = roc {
            XCTAssertEqual(r, 100, "ROC is set to 100, but returned {r}")
        } else {
            XCTFail("ROC must return value for used SSRC")
        }
    }

    func testContextIndex() throws {
        let keyLen = cipherContextAlgo.keyLen()
        let saltLen = cipherContextAlgo.saltLen()

        var c = try Context(
            masterKey: ByteBufferView(repeating: 0, count: keyLen),
            masterSalt: ByteBufferView(repeating: 0, count: saltLen),
            profile: cipherContextAlgo,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil
        )

        var index = c.getIndex(ssrc: 123)
        XCTAssertTrue(index == nil, "Index must return None for unused SSRC")

        c.setIndex(ssrc: 123, index: 100)
        index = c.getIndex(ssrc: 123)
        if let i = index {
            XCTAssertEqual(i, 100, "Index is set to 100, but returned {i}")
        } else {
            XCTFail("Index must return true for used SSRC")
        }
    }

    func testKeyLen() throws {
        let keyLen = cipherContextAlgo.keyLen()
        let saltLen = cipherContextAlgo.saltLen()

        var result = try? Context(
            masterKey: ByteBufferView(),
            masterSalt: ByteBufferView(repeating: 0, count: saltLen),
            profile: cipherContextAlgo,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil)
        XCTAssertTrue(result == nil, "CreateContext accepted a 0 length key")

        result = try? Context(
            masterKey: ByteBufferView(repeating: 0, count: keyLen),
            masterSalt: ByteBufferView(),
            profile: cipherContextAlgo,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil)
        XCTAssertTrue(result == nil, "CreateContext accepted a 0 length salt")

        result = try Context(
            masterKey: ByteBufferView(repeating: 0, count: keyLen),
            masterSalt: ByteBufferView(repeating: 0, count: saltLen),
            profile: cipherContextAlgo,
            srtpCtxOpt: nil,
            srtcpCtxOpt: nil)
        XCTAssertTrue(
            result != nil,
            "CreateContext failed with a valid length key and salt"
        )
    }

    func testValidPacketCounter() throws {
        let masterKey = ByteBuffer(bytes: [
            0x0d, 0xcd, 0x21, 0x3e, 0x4c, 0xbc, 0xf2, 0x8f, 0x01, 0x7f, 0x69, 0x94, 0x40, 0x1e,
            0x28,
            0x89,
        ])
        let masterSalt = ByteBuffer(bytes: [
            0x62, 0x77, 0x60, 0x38, 0xc0, 0x6d, 0xc9, 0x41, 0x9f, 0x6d, 0xd9, 0x43, 0x3e, 0x7c,
        ])

        let srtpSessionSalt = try aesCmKeyDerivation(
            label: labelSrtpSalt,
            masterKey: masterKey.readableBytesView,
            masterSalt: masterSalt.readableBytesView,
            indexOverKdr: 0,
            outLen: masterSalt.readableBytes
        )

        let s = SrtpSsrcState(
            ssrc: 4_160_032_510,
            rolloverCounter: 0,
            rolloverHasProcessed: false,
            lastSequenceNumber: 0)
        let expectedCounter = ByteBuffer(bytes: [
            0xcf, 0x90, 0x1e, 0xa5, 0xda, 0xd3, 0x2c, 0x15, 0x00, 0xa2, 0x24, 0xae, 0xae, 0xaf,
            0x00,
            0x00,
        ])
        let counter = try generateCounter(
            sequenceNumber: 32846,
            rolloverCounter: s.rolloverCounter,
            ssrc: s.ssrc,
            sessionSalt: srtpSessionSalt.readableBytesView)
        XCTAssertEqual(counter, expectedCounter)
    }

    func testRolloverCount() throws {
        var s = SrtpSsrcState(
            ssrc: defaultSsrc, rolloverCounter: 0, rolloverHasProcessed: false,
            lastSequenceNumber: 0)

        // Set initial seqnum
        var roc = s.nextRolloverCount(sequenceNumber: 65530)
        XCTAssertEqual(roc, 0, "Initial rolloverCounter must be 0")
        s.updateRolloverCount(sequenceNumber: 65530)

        // Invalid packets never update ROC
        let _ = s.nextRolloverCount(sequenceNumber: 0)
        let _ = s.nextRolloverCount(sequenceNumber: 0x4000)
        let _ = s.nextRolloverCount(sequenceNumber: 0x8000)
        let _ = s.nextRolloverCount(sequenceNumber: 0xFFFF)
        let _ = s.nextRolloverCount(sequenceNumber: 0)

        // We rolled over to 0
        roc = s.nextRolloverCount(sequenceNumber: 0)
        XCTAssertEqual(roc, 1, "rolloverCounter was not updated after it crossed 0")
        s.updateRolloverCount(sequenceNumber: 0)

        roc = s.nextRolloverCount(sequenceNumber: 65530)
        XCTAssertEqual(
            roc, 0,
            "rolloverCounter was not updated when it rolled back, failed to handle out of order"
        )
        s.updateRolloverCount(sequenceNumber: 65530)

        roc = s.nextRolloverCount(sequenceNumber: 5)
        XCTAssertEqual(
            roc, 1,
            "rolloverCounter was not updated when it rolled over initial, to handle out of order"
        )
        s.updateRolloverCount(sequenceNumber: 5)

        let _ = s.nextRolloverCount(sequenceNumber: 6)
        s.updateRolloverCount(sequenceNumber: 6)

        let _ = s.nextRolloverCount(sequenceNumber: 7)
        s.updateRolloverCount(sequenceNumber: 7)

        roc = s.nextRolloverCount(sequenceNumber: 8)
        XCTAssertEqual(
            roc, 1,
            "rolloverCounter was improperly updated for non-significant packets"
        )
        s.updateRolloverCount(sequenceNumber: 8)

        // valid packets never update ROC
        roc = s.nextRolloverCount(sequenceNumber: 0x4000)
        XCTAssertEqual(
            roc, 1,
            "rolloverCounter was improperly updated for non-significant packets"
        )
        s.updateRolloverCount(sequenceNumber: 0x4000)

        roc = s.nextRolloverCount(sequenceNumber: 0x8000)
        XCTAssertEqual(
            roc, 1,
            "rolloverCounter was improperly updated for non-significant packets"
        )
        s.updateRolloverCount(sequenceNumber: 0x8000)

        roc = s.nextRolloverCount(sequenceNumber: 0xFFFF)
        XCTAssertEqual(
            roc, 1,
            "rolloverCounter was improperly updated for non-significant packets"
        )
        s.updateRolloverCount(sequenceNumber: 0xFFFF)

        roc = s.nextRolloverCount(sequenceNumber: 0)
        XCTAssertEqual(
            roc, 2,
            "rolloverCounter must be incremented after wrapping, got {roc}"
        )
    }
}
