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

final class AgentTests: XCTestCase {
    func testAgentProcessInTransaction() throws {
        let m = Message()
        let a = Agent()
        m.transactionId = TransactionId([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        try a.start(m.transactionId, NIODeadline.now())
        try a.process(m)
        try a.close()

        while let e = a.pollEvent() {
            if case Result.success(let message) = e.result {
                let tid = TransactionId([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
                XCTAssertEqual(message.transactionId, tid)
            } else {
                XCTAssertTrue(false)
            }
        }
    }

    func testAgentProcess() throws {
        let m = Message()
        let a = Agent()
        m.transactionId = TransactionId([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        try a.process(m)
        try a.close()

        while let e = a.pollEvent() {
            if case Result.success(let message) = e.result {
                let tid = TransactionId([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
                XCTAssertEqual(message.transactionId, tid)
            } else {
                XCTAssertTrue(false)
            }
        }

        do {
            try a.process(m)
            XCTAssertTrue(false)
        } catch STUNError.errAgentClosed {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false)
        }
    }

    func testAgentStart() throws {
        let a = Agent()
        let id1 = TransactionId()
        let deadline = NIODeadline.now() + TimeAmount.seconds(3600)
        try a.start(id1, deadline)

        do {
            try a.start(id1, deadline)
        } catch STUNError.errTransactionExists {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false)
        }
        try a.close()

        let id2 = TransactionId()
        do {
            try a.start(id2, deadline)
        } catch STUNError.errAgentClosed {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false)
        }
    }

    func testAgentStop() throws {
        let a = Agent()

        do {
            try a.stop(TransactionId())
        } catch STUNError.errTransactionNotExists {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false)
        }

        let id = TransactionId()
        let deadline = NIODeadline.now() + TimeAmount.milliseconds(200)
        try a.start(id, deadline)
        try a.stop(id)

        if case .failure(let err) = a.pollEvent()!.result {
            XCTAssertEqual(err, STUNError.errTransactionStopped)
        } else {
            XCTAssertTrue(false)
        }

        try a.close()

        do {
            try a.close()
        } catch STUNError.errAgentClosed {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false)
        }

        do {
            try a.stop(TransactionId())
        } catch STUNError.errAgentClosed {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false)
        }
    }
}
