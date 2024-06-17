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

let prtReportBlockMinLength: UInt16 = 8

/// PacketReceiptTimesReportBlock represents a Packet Receipt Times
/// report block, as described in RFC 3611 section 4.3.
///
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |     BT=3      | rsvd. |   t   |         block length          |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                        ssrc of source                         |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |          begin_seq            |             end_seq           |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |       Receipt time of packet begin_seq                        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |       Receipt time of packet (begin_seq + 1) mod 65536        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// :                              ...                              :
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |       Receipt time of packet (end_seq - 1) mod 65536          |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct PacketReceiptTimesReportBlock: Equatable {
    //not included in marshal/unmarshal
    public var t: UInt8

    //marshal/unmarshal
    public var ssrc: UInt32
    public var beginSeq: UInt16
    public var endSeq: UInt16
    public var receiptTime: [UInt32]

    public func xrHeader() -> XRHeader {
        XRHeader(
            blockType: BlockType.packetReceiptTimes,
            typeSpecific: self.t & 0x0F,
            blockLength: UInt16(self.rawSize() / 4 - 1)
        )
    }
}

extension PacketReceiptTimesReportBlock: CustomStringConvertible {
    public var description: String {
        "\(self)"
    }
}

extension PacketReceiptTimesReportBlock: Packet {
    public func header() -> Header {
        Header()
    }

    /// destination_ssrc returns an array of ssrc values that this report block refers to.
    public func destinationSsrc() -> [UInt32] {
        [self.ssrc]
    }

    public func rawSize() -> Int {
        xrHeaderLength + Int(prtReportBlockMinLength) + self.receiptTime.count * 4
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension PacketReceiptTimesReportBlock: MarshalSize {
    public func marshalSize() -> Int {
        self.rawSize()
    }
}

extension PacketReceiptTimesReportBlock: Marshal {
    /// marshal_to encodes the PacketReceiptTimesReportBlock in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let h = self.xrHeader()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.ssrc)
        buf.writeInteger(self.beginSeq)
        buf.writeInteger(self.endSeq)
        for rt in self.receiptTime {
            buf.writeInteger(rt)
        }

        return self.marshalSize()
    }
}

extension PacketReceiptTimesReportBlock: Unmarshal {
    /// Unmarshal decodes the PacketReceiptTimesReportBlock from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < xrHeaderLength {
            throw RtcpError.errPacketTooShort
        }

        let (xrHeader, xrHeaderLen) = try XRHeader.unmarshal(buf)
        let blockLength = xrHeader.blockLength * 4

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: xrHeaderLen)

        if blockLength < prtReportBlockMinLength
            || (blockLength - prtReportBlockMinLength) % 4 != 0
            || reader.readableBytes < Int(blockLength)
        {
            throw RtcpError.errPacketTooShort
        }

        let t = xrHeader.typeSpecific & 0x0F

        guard let ssrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let beginSeq: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let endSeq: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        let remaining = blockLength - prtReportBlockMinLength
        var receiptTime: [UInt32] = []
        for _ in 0..<remaining / 4 {
            guard let time: UInt32 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            receiptTime.append(time)
        }

        return (
            PacketReceiptTimesReportBlock(
                t: t,

                ssrc: ssrc,
                beginSeq: beginSeq,
                endSeq: endSeq,
                receiptTime: receiptTime
            ), reader.readerIndex - readerStartIndex
        )
    }
}
