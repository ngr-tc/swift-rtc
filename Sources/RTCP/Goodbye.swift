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

/// The Goodbye packet indicates that one or more sources are no longer active.
public struct Goodbye: Equatable {
    /// The SSRC/CSRC identifiers that are no longer active
    public var sources: [UInt32]
    /// Optional text indicating the reason for leaving, e.g., "camera malfunction" or "RTP loop detected"
    public var reason: ByteBuffer

    public init(sources: [UInt32] = [], reason: ByteBuffer = ByteBuffer()) {
        self.sources = sources
        self.reason = reason
    }
}

extension Goodbye: CustomStringConvertible {
    public var description: String {
        var out = "Goodbye:\n\tSources:\n"
        for s in self.sources {
            out += "\t\(s)\n"
        }
        out += "\tReason: \(self.reason)\n"

        return out
    }
}

extension Goodbye: Packet {
    /// Header returns the Header associated with this packet.
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: UInt8(self.sources.count),
            packetType: PacketType.goodbye,
            length: UInt16((self.marshalSize() / 4) - 1)
        )
    }

    /// destination_ssrc returns an array of SSRC values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        self.sources
    }

    public func rawSize() -> Int {
        let srcsLength = self.sources.count * ssrcLength
        let reasonLength = self.reason.readableBytes + 1

        return headerLength + srcsLength + reasonLength
    }
}

extension Goodbye: Unmarshal {
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        /*
         *        0                   1                   2                   3
         *        0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *       |V=2|P|    SC   |   PT=BYE=203  |             length            |
         *       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *       |                           SSRC/CSRC                           |
         *       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *       :                              ...                              :
         *       +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * (opt) |     length    |               reason for leaving            ...
         *       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        let rawPacketLen = buf.readableBytes

        let (header, headerLen) = try Header.unmarshal(buf)
        if header.packetType != PacketType.goodbye {
            throw RtcpError.errWrongType
        }

        if getPadding(rawPacketLen) != 0 {
            throw RtcpError.errPacketTooShort
        }

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: headerLen)
        let reasonOffset = headerLength + Int(header.count) * ssrcLength

        if reasonOffset > rawPacketLen {
            throw RtcpError.errPacketTooShort
        }

        var sources: [UInt32] = []
        sources.reserveCapacity(Int(header.count))
        for _ in 0..<header.count {
            guard let ssrc: UInt32 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            sources.append(ssrc)
        }

        let reason: ByteBuffer
        if reasonOffset < rawPacketLen {
            guard let reasonLen: UInt8 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            let reasonEnd = reasonOffset + 1 + Int(reasonLen)

            if reasonEnd > rawPacketLen {
                throw RtcpError.errPacketTooShort
            }

            reason = reader.readSlice(length: Int(reasonLen)) ?? ByteBuffer()
        } else {
            reason = ByteBuffer()
        }

        /*header.padding &&*/
        if reader.readableBytes > 0 {
            reader.moveReaderIndex(forwardBy: reader.readableBytes)
        }

        return (Goodbye(sources: sources, reason: reason), reader.readerIndex - readerStartIndex)
    }
}

extension Goodbye: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension Goodbye: Marshal {
    /// marshal_to encodes the packet in binary.
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        if self.sources.count > countMax {
            throw RtcpError.errTooManySources
        }

        if self.reason.readableBytes > sdesMaxOctetCount {
            throw RtcpError.errReasonTooLong
        }

        /*
         *        0                   1                   2                   3
         *        0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *       |V=2|P|    SC   |   PT=BYE=203  |             length            |
         *       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *       |                           SSRC/CSRC                           |
         *       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *       :                              ...                              :
         *       +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * (opt) |     length    |               reason for leaving            ...
         *       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */

        let h = self.header()
        let _ = try h.marshalTo(&buf)

        for source in self.sources {
            buf.writeInteger(source)
        }

        buf.writeInteger(UInt8(self.reason.readableBytes))
        if self.reason.readableBytes > 0 {
            buf.writeImmutableBuffer(self.reason)
        }

        if h.padding {
            putPadding(&buf, self.rawSize())
        }

        return self.marshalSize()
    }
}
