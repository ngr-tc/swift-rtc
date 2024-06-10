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

public struct OpusPayloader {
}

extension OpusPayloader: Payloader {
    public mutating func payload(mtu: Int, buf: inout ByteBuffer) throws -> [ByteBuffer] {
        if buf.readableBytes == 0 || mtu == 0 {
            return []
        }

        return [buf.slice()]
    }
}

/// OpusPacket represents the Opus header that is stored in the payload of an RTP Packet
public struct OpusPacket {
}

extension OpusPacket: Depacketizer {
    public mutating func depacketize(buf: inout ByteBuffer) throws -> ByteBuffer {
        if buf.readableBytes == 0 {
            throw RtpError.errShortPacket
        } else {
            return buf.slice()
        }
    }

    public func isPartitionHead(payload: inout ByteBuffer) -> Bool {
        return true
    }

    public func isPartitionTail(marker: Bool, payload: inout ByteBuffer) -> Bool {
        return true
    }
}
