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

let rrtReportBlockLength: UInt16 = 8

/// ReceiverReferenceTimeReportBlock encodes a Receiver Reference Time
/// report block as described in RFC 3611 section 4.4.
///
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |     BT=4      |   reserved    |       block length = 2        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |              NTP timestamp, most significant word             |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |             NTP timestamp, least significant word             |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct ReceiverReferenceTimeReportBlock: Equatable {
    public var ntpTimestamp: UInt64

    public func xrHeader() -> XRHeader {
        XRHeader(
            blockType: BlockType.receiverReferenceTime,
            typeSpecific: 0,
            blockLength: UInt16(self.rawSize() / 4 - 1)
        )
    }
}

extension ReceiverReferenceTimeReportBlock: CustomStringConvertible {
    public var description: String {
        "\(self.ntpTimestamp)"
    }
}

extension ReceiverReferenceTimeReportBlock: Packet {
    public func header() -> Header {
        Header()
    }

    /// destination_ssrc returns an array of ssrc values that this report block refers to.
    public func destinationSsrc() -> [UInt32] {
        []
    }

    public func rawSize() -> Int {
        xrHeaderLength + Int(rrtReportBlockLength)
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension ReceiverReferenceTimeReportBlock: MarshalSize {
    public func marshalSize() -> Int {
        self.rawSize()
    }
}

extension ReceiverReferenceTimeReportBlock: Marshal {
    /// marshal_to encodes the ReceiverReferenceTimeReportBlock in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let h = self.xrHeader()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.ntpTimestamp)

        return self.marshalSize()
    }
}

extension ReceiverReferenceTimeReportBlock: Unmarshal {
    /// Unmarshal decodes the ReceiverReferenceTimeReportBlock from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < xrHeaderLength {
            throw RtcpError.errPacketTooShort
        }

        let (xrHeader, xrHeaderLen) = try XRHeader.unmarshal(buf)
        let blockLength = xrHeader.blockLength * 4

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: xrHeaderLen)

        if blockLength != rrtReportBlockLength || reader.readableBytes < Int(blockLength) {
            throw RtcpError.errPacketTooShort
        }

        guard let ntpTimestamp: UInt64 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        return (
            ReceiverReferenceTimeReportBlock(ntpTimestamp: ntpTimestamp),
            reader.readerIndex - readerStartIndex
        )
    }
}
