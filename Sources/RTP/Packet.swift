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

/// Packet represents an RTP Packet
/// NOTE: Raw is populated by Marshal/Unmarshal and should not be modified
public struct Packet: Equatable {
    public var header: Header
    public var payload: ByteBuffer
}

extension Packet: CustomStringConvertible {
    public var description: String {
        var out = "RTP PACKET:\n"

        out += "\tVersion: \(self.header.version)\n"
        out += "\tMarker: \(self.header.marker)\n"
        out += "\tPayload Type: \(self.header.payloadType)\n"
        out += "\tSequence Number: \(self.header.sequenceNumber)\n"
        out += "\tTimestamp: \(self.header.timestamp)\n"
        out += String(format: "\tSSRC: %d (%x)\n", self.header.ssrc, self.header.ssrc)
        out += "\tPayload Length: \(self.payload.readableBytes)\n"

        return out
    }
}

extension Packet: Unmarshal {
    /// Unmarshal parses the passed byte slice and stores the result in the Header this method is called upon
    public init(_ buf: inout ByteBuffer) throws {
        let header = try Header(&buf)
        let payloadLen = buf.readableBytes
        guard var payload = buf.readSlice(length: payloadLen) else {
            throw RtpError.errShortPacket
        }
        if header.padding {
            if payloadLen > 0 {
                guard let bytes = payload.getBytes(at: payloadLen - 1, length: 1) else {
                    throw RtpError.errShortPacket
                }
                let paddingLen = Int(bytes[0])
                if paddingLen <= payloadLen {
                    guard let payloadSlice = payload.readSlice(length: payloadLen - paddingLen)
                    else {
                        throw RtpError.errShortPacket
                    }
                    payload = payloadSlice
                } else {
                    throw RtpError.errShortPacket
                }
            } else {
                throw RtpError.errShortPacket
            }
        }
        self.header = header
        self.payload = payload
    }
}

extension Packet: MarshalSize {
    /// MarshalSize returns the size of the packet once marshaled.
    public func marshalSize() -> Int {
        let payloadLen = self.payload.readableBytes
        var paddingLen: Int
        if self.header.padding {
            paddingLen = getPadding(payloadLen)
            if paddingLen == 0 {
                paddingLen = 4
            }
        } else {
            paddingLen = 0
        }
        return self.header.marshalSize() + payloadLen + paddingLen
    }
}

extension Packet: Marshal {
    /// MarshalTo serializes the packet and writes to the buffer.
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let n = try self.header.marshalTo(&buf)
        buf.writeImmutableBuffer(self.payload)
        var paddingLen: Int
        if self.header.padding {
            paddingLen = getPadding(self.payload.readableBytes)
            if paddingLen == 0 {
                paddingLen = 4
            }
            for i in 0..<paddingLen {
                if i != paddingLen - 1 {
                    buf.writeInteger(UInt8(0))
                } else {
                    buf.writeInteger(UInt8(paddingLen))
                }
            }
        } else {
            paddingLen = 0
        }

        return n + self.payload.readableBytes + paddingLen
    }
}

/// getPadding Returns the padding required to make the length a multiple of 4
func getPadding(_ len: Int) -> Int {
    if len % 4 == 0 {
        return 0
    } else {
        return 4 - (len % 4)
    }
}
