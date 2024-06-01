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

public enum EventResult {
    case ok(Message)
    case err(STUNError)
}

/// Event is passed to Handler describing the transaction event.
/// Do not reuse outside Handler.
public struct Event {
    var id: TransactionId
    var result: EventResult

    public init() {
        self.id = TransactionId()
        let message = Message()
        self.result = EventResult.ok(message)
    }

    public init(id: TransactionId, result: EventResult) {
        self.id = id
        self.result = result
    }
}

/// AgentTransaction represents transaction in progress.
/// Concurrent access is invalid.
struct AgentTransaction {
    var id: TransactionId
    var deadline: NIODeadline
}

/// AGENT_COLLECT_CAP is initial capacity for Agent.Collect slices,
/// sufficient to make function zero-alloc in most cases.
let agentCollectCap: Int = 100

/// ClientAgent is Agent implementation that is used by Client to
/// process transactions.
public enum ClientAgent {
    case process(Message)
    case collect(NIODeadline)
    case start(TransactionId, NIODeadline)
    case stop(TransactionId)
    case close
}

/// Agent is low-level abstraction over transaction list that
/// handles concurrency and time outs (via Collect call).
public class Agent {
    /// transactions is map of transactions that are currently
    /// in progress. Event handling is done in such way when
    /// transaction is unregistered before AgentTransaction access,
    /// minimizing mux lock and protecting AgentTransaction from
    /// data races via unexpected concurrent access.
    var transactions: [TransactionId: AgentTransaction]
    /// all calls are invalid if true
    var closed: Bool
    /// events queue
    var eventsQueue: CircularBuffer<Event>

    /// new initializes and returns new Agent with provided handler.
    public init() {
        self.transactions = [:]
        self.closed = false
        self.eventsQueue = CircularBuffer()
    }

    public func handleEvent(clientAgent: ClientAgent) throws {
        switch clientAgent {
        case .process(let message):
            try self.process(message)
        case .collect(let deadline):
            try self.collect(deadline)
        case .start(let tid, let deadline):
            try self.start(tid, deadline)
        case .stop(let tid):
            try self.stop(tid)
        case .close:
            try self.close()
        }
    }

    public func pollTimeout() -> NIODeadline? {
        var deadline: NIODeadline? = nil
        for transaction in self.transactions.values {
            if deadline == nil || transaction.deadline < deadline! {
                deadline = transaction.deadline
            }
        }
        return deadline
    }

    public func pollEvent() -> Event? {
        self.eventsQueue.popFirst()
    }

    /// process incoming message, synchronously passing it to handler.
    func process(_ message: Message) throws {
        if self.closed {
            throw STUNError.errAgentClosed
        }

        self.transactions.removeValue(forKey: message.transactionId)

        self.eventsQueue.append(
            Event(
                id: message.transactionId,
                result: .ok(message)
            ))
    }

    /// close terminates all transactions with ErrAgentClosed and renders Agent to
    /// closed state.
    func close() throws {
        if self.closed {
            throw STUNError.errAgentClosed
        }

        for id in self.transactions.keys {
            self.eventsQueue.append(
                Event(
                    id: id,
                    result: .err(STUNError.errAgentClosed)
                ))
        }
        self.transactions.removeAll()
        self.closed = true
    }

    /// start registers transaction with provided id and deadline.
    /// Could return ErrAgentClosed, ErrTransactionExists.
    ///
    /// Agent handler is guaranteed to be eventually called.
    func start(_ id: TransactionId, _ deadline: NIODeadline) throws {
        if self.closed {
            throw STUNError.errAgentClosed
        }
        if let _ = self.transactions[id] {
            throw STUNError.errTransactionExists
        }

        self.transactions[id] = AgentTransaction(id: id, deadline: deadline)
    }

    /// stop stops transaction by id with ErrTransactionStopped, blocking
    /// until handler returns.
    func stop(_ id: TransactionId) throws {
        if self.closed {
            throw STUNError.errAgentClosed
        }

        let v = self.transactions.removeValue(forKey: id)
        if let t = v {
            self.eventsQueue.append(
                Event(
                    id: t.id,
                    result: .err(STUNError.errTransactionStopped)
                ))
        } else {
            throw STUNError.errTransactionNotExists
        }
    }

    /// collect terminates all transactions that have deadline before provided
    /// time, blocking until all handlers will process ErrTransactionTimeOut.
    /// Will return ErrAgentClosed if agent is already closed.
    ///
    /// It is safe to call Collect concurrently but makes no sense.
    func collect(_ deadline: NIODeadline) throws {
        if self.closed {
            // Doing nothing if agent is closed.
            // All transactions should be already closed
            // during Close() call.
            throw STUNError.errAgentClosed
        }

        var toRemove: [TransactionId] = []

        // Adding all transactions with deadline before gc_time
        // to toCall and to_remove slices.
        // No allocs if there are less than AGENT_COLLECT_CAP
        // timed out transactions.
        for (id, t) in self.transactions {
            if t.deadline < deadline {
                toRemove.append(id)
            }
        }
        // Un-registering timed out transactions.
        for id in toRemove {
            self.transactions.removeValue(forKey: id)
        }

        for id in toRemove {
            self.eventsQueue.append(
                Event(
                    id: id,
                    result: .err(STUNError.errTransactionTimeOut)
                ))
        }
    }
}
