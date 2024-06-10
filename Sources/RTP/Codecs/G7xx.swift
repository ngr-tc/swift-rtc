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

/// G711Payloader payloads G711 packets
public typealias G711Payloader = G7xxPayloader
/// G722Payloader payloads G722 packets
public typealias G722Payloader = G7xxPayloader

public struct G7xxPayloader {
}

extension G7xxPayloader: Payloader {
    /// Payload fragments an G7xx packet across one or more byte arrays
    public mutating func payload(mtu: Int, buf: ByteBuffer) throws -> [ByteBuffer] {
        if buf.readableBytes == 0 || mtu == 0 {
            return []
        }

        var payloadDataRemaining = buf.readableBytes
        var payloadDataIndex = 0
        var payloads: [ByteBuffer] = []
        while payloadDataRemaining > 0 {
            let currentFragmentSize = min(mtu, payloadDataRemaining)
            guard let p = buf.getSlice(at: payloadDataIndex, length: currentFragmentSize) else {
                throw RtpError.errBufferTooSmall
            }
            payloads.append(p)

            payloadDataRemaining -= currentFragmentSize
            payloadDataIndex += currentFragmentSize
        }

        return payloads
    }
}

/// G7xxPacket represents the G7xx header that is stored in the payload of an RTP Packet
public struct G7xxPacket {
}

extension G7xxPacket: Depacketizer {
    public mutating func depacketize(buf: ByteBuffer) throws -> ByteBuffer {
        if buf.readableBytes == 0 {
            throw RtpError.errShortPacket
        } else {
            return buf.slice()
        }
    }

    public func isPartitionHead(payload: ByteBuffer) -> Bool {
        return true
    }

    public func isPartitionTail(marker: Bool, payload: ByteBuffer) -> Bool {
        return true
    }
}
