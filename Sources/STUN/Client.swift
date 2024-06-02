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
import Shared

let defaultTimeoutRate: TimeAmount = TimeAmount.milliseconds(5)
let defaultRto: TimeAmount = TimeAmount.milliseconds(300)
let defaultMaxAttempts: Int = 7
let defaultMaxBufferSize: Int = 8

/// ClientTransaction represents transaction in progress.
/// If transaction is succeed or failed, f will be called
/// provided by event.
/// Concurrent access is invalid.
public struct ClientTransaction {
    var id: TransactionId
    var attempt: Int
    var start: NIODeadline
    var rto: TimeAmount
    var raw: ByteBuffer

    public init(
        id: TransactionId, attempt: Int, start: NIODeadline, rto: TimeAmount, raw: ByteBuffer
    ) {
        self.id = id
        self.attempt = attempt
        self.start = start
        self.rto = rto
        self.raw = raw
    }

    func nextTimeout(_ now: NIODeadline) -> NIODeadline {
        return now + (self.attempt + 1) * self.rto
    }
}

struct ClientSettings {
    var bufferSize: Int
    var rto: TimeAmount
    var rtoRate: TimeAmount
    var maxAttempts: Int
    var closed: Bool

    init() {
        self.bufferSize = defaultMaxBufferSize
        self.rto = defaultRto
        self.rtoRate = defaultTimeoutRate
        self.maxAttempts = defaultMaxAttempts
        self.closed = false
    }

    init(bufferSize: Int, rto: TimeAmount, rtoRate: TimeAmount, maxAttempts: Int, closed: Bool) {
        self.bufferSize = bufferSize
        self.rto = rto
        self.rtoRate = rtoRate
        self.maxAttempts = maxAttempts
        self.closed = closed
    }
}

public struct ClientBuilder {
    var settings: ClientSettings

    public init() {
        self.settings = ClientSettings()
    }

    /// with_rto sets client RTO as defined in STUN RFC.
    public mutating func withRto(rto: TimeAmount) -> Self {
        self.settings.rto = rto
        return self
    }

    /// with_timeout_rate sets RTO timer minimum resolution.
    public mutating func withTimeoutRate(d: TimeAmount) -> Self {
        self.settings.rtoRate = d
        return self
    }

    /// with_buffer_size sets buffer size.
    public mutating func withBufferSize(bufferSize: Int) -> Self {
        self.settings.bufferSize = bufferSize
        return self
    }

    /// with_no_retransmit disables retransmissions and sets RTO to
    /// DEFAULT_MAX_ATTEMPTS * DEFAULT_RTO which will be effectively time out
    /// if not set.
    /// Useful for TCP connections where transport handles RTO.
    public mutating func withNoRetransmit() -> Self {
        self.settings.maxAttempts = 0
        if self.settings.rto == TimeAmount.seconds(0) {
            self.settings.rto = defaultMaxAttempts * defaultRto
        }
        return self
    }

    public func build(
        local: SocketAddress,
        remote: SocketAddress,
        proto: TransportProtocol
    ) -> Client {
        return Client(local: local, remote: remote, proto: proto, settings: self.settings)
    }
}

/// Client simulates "connection" to STUN server.
public struct Client {
    var local: SocketAddress
    var remote: SocketAddress
    var proto: TransportProtocol
    var settings: ClientSettings
    var agent: Agent
    var transactions: [TransactionId: ClientTransaction]
    var transmits: CircularBuffer<Transmit<ByteBuffer>>

    init(
        local: SocketAddress,
        remote: SocketAddress,
        proto: TransportProtocol,
        settings: ClientSettings
    ) {
        self.local = local
        self.remote = remote
        self.proto = proto
        self.settings = settings
        self.agent = Agent()
        self.transactions = [:]
        self.transmits = CircularBuffer()
    }

    /// Returns packets to transmit
    ///
    /// It should be polled for transmit after:
    /// - the application performed some I/O
    /// - a call was made to `handle_read`
    /// - a call was made to `handle_write`
    /// - a call was made to `handle_timeout`
    public mutating func pollTransmit() -> Transmit<ByteBuffer>? {
        self.transmits.popFirst()
    }

    public mutating func pollEvent() -> Event? {
        while let event = self.agent.pollEvent() {
            guard var ct = self.transactions.removeValue(forKey: event.id) else {
                continue
            }
            if ct.attempt >= self.settings.maxAttempts || event.result.isSuccess() {
                return event
            }

            // Doing re-transmission.
            ct.attempt += 1

            let payload = ct.raw
            let timeout = ct.nextTimeout(NIODeadline.now())
            let id = ct.id

            // Starting client transaction.
            self.transactions[ct.id] = ct

            // Starting agent transaction.
            do {
                try self
                    .agent
                    .handleEvent(ClientAgent.start(id, timeout))
            } catch {
                self.transactions.removeValue(forKey: id)
                return event
            }

            // Writing message to connection again.
            self.transmits.append(
                Transmit(
                    now: NIODeadline.now(),
                    transport: TransportContext(
                        local: self.local,
                        peer: self.remote,
                        proto: self.proto,
                        ecn: nil
                    ),
                    message: payload
                ))
        }

        return nil
    }

    public mutating func handleRead(_ buf: ByteBufferView) throws {
        var msg = Message()
        let _ = try msg.readFrom(buf)
        try self.agent.handleEvent(ClientAgent.process(msg))
    }

    public mutating func handleWrite(_ m: Message) throws {
        if self.settings.closed {
            throw StunError.errClientClosed
        }

        let payload = m.raw

        let ct = ClientTransaction(
            id: m.transactionId,
            attempt: 0,
            start: NIODeadline.now(),
            rto: self.settings.rto,
            raw: m.raw
        )
        let deadline = ct.nextTimeout(ct.start)
        self.transactions[ct.id] = ct
        try self.agent
            .handleEvent(ClientAgent.start(m.transactionId, deadline))

        self.transmits.append(
            Transmit(
                now: NIODeadline.now(),
                transport: TransportContext(
                    local: self.local,
                    peer: self.remote,
                    proto: self.proto,
                    ecn: nil
                ),
                message: payload
            ))
    }

    public func pollTimeout() -> NIODeadline? {
        return self.agent.pollTimeout()
    }

    public mutating func handleTimeout(_ now: NIODeadline) throws {
        try self.agent.handleEvent(ClientAgent.collect(now))
    }

    public mutating func handleClose() throws {
        if self.settings.closed {
            throw StunError.errClientClosed
        }
        self.settings.closed = true
        try self.agent.handleEvent(ClientAgent.close)
    }
}
