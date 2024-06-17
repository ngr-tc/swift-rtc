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

let rleReportBlockMinLength: UInt16 = 8

/// ChunkType enumerates the three kinds of chunks described in RFC 3611 section 4.1.
public enum ChunkType: UInt8, Equatable {
    case runLength = 0
    case bitVector = 1
    case terminatingNull = 2
}

/// Chunk as defined in RFC 3611, section 4.1. These represent information
/// about packet losses and packet duplication. They have three representations:
///
/// Run Length Chunk:
///
///   0                   1
///   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
///  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
///  |C|R|        run length         |
///  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
///
/// Bit Vector Chunk:
///
///   0                   1
///   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
///  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
///  |C|        bit vector           |
///  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
///
/// Terminating Null Chunk:
///
///   0                   1
///   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
///  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
///  |0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0|
///  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct Chunk: Equatable {
    public var rawValue: UInt16

    /// chunk_type returns the ChunkType that this Chunk represents
    public func chunkType() -> ChunkType {
        if self.rawValue == 0 {
            return ChunkType.terminatingNull
        } else if (self.rawValue >> 15) == 0 {
            return ChunkType.runLength
        } else {
            return ChunkType.bitVector
        }
    }

    /// run_type returns the run_type that this Chunk represents. It is
    /// only valid if ChunkType is RunLengthChunkType.
    public func runType() throws -> UInt8 {
        if self.chunkType() != ChunkType.runLength {
            throw RtcpError.errWrongChunkType
        }
        return UInt8(self.rawValue >> 14) & 0x01
    }

    /// value returns the value represented in this Chunk
    public func value() -> UInt16 {
        switch self.chunkType() {
        case ChunkType.runLength:
            return self.rawValue & 0x3FFF
        case ChunkType.bitVector:
            return self.rawValue & 0x7FFF
        case ChunkType.terminatingNull:
            return 0
        }
    }
}

extension Chunk: CustomStringConvertible {
    public var description: String {
        switch self.chunkType() {
        case ChunkType.runLength:
            var runType: UInt8 = 0
            if let rt = try? self.runType() {
                runType = rt
            }
            return "[RunLength type=\(runType), length=\(self.value())]"
        case ChunkType.bitVector:
            return String(format: "[BitVector {%b}", self.value())
        case ChunkType.terminatingNull:
            return "[TerminatingNull]"
        }
    }
}

/// RleReportBlock defines the common structure used by both
/// Loss RLE report blocks (RFC 3611 §4.1) and Duplicate RLE
/// report blocks (RFC 3611 §4.2).
///
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |  BT = 1 or 2  | rsvd. |   t   |         block length          |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                        ssrc of source                         |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |          begin_seq            |             end_seq           |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |          chunk 1              |             chunk 2           |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// :                              ...                              :
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |          chunk n-1            |             chunk n           |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct RLEReportBlock: Equatable {
    //not included in marshal/unmarshal
    public var isLossRLE: Bool
    public var t: UInt8

    //marshal/unmarshal
    public var ssrc: UInt32
    public var beginSeq: UInt16
    public var endSeq: UInt16
    public var chunks: [Chunk]

    public func xrHeader() -> XRHeader {
        XRHeader(
            blockType: self.isLossRLE ? BlockType.lossRLE : BlockType.duplicateRLE,
            typeSpecific: self.t & 0x0F,
            blockLength: UInt16(self.rawSize() / 4 - 1)
        )
    }
}

/// LossRLEReportBlock is used to report information about packet
/// losses, as described in RFC 3611, section 4.1
/// make sure to set is_loss_rle = true
public typealias LossRLEReportBlock = RLEReportBlock

/// DuplicateRLEReportBlock is used to report information about packet
/// duplication, as described in RFC 3611, section 4.1
/// make sure to set is_loss_rle = false
public typealias DuplicateRLEReportBlock = RLEReportBlock

extension RLEReportBlock: CustomStringConvertible {
    public var description: String {
        "\(self)"
    }
}

extension RLEReportBlock: Packet {
    public func header() -> Header {
        Header()
    }

    /// destination_ssrc returns an array of ssrc values that this report block refers to.
    public func destinationSsrc() -> [UInt32] {
        [self.ssrc]
    }

    public func rawSize() -> Int {
        xrHeaderLength + Int(rleReportBlockMinLength) + self.chunks.count * 2
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension RLEReportBlock: MarshalSize {
    public func marshalSize() -> Int {
        self.rawSize()
    }
}

extension RLEReportBlock: Marshal {
    /// marshal_to encodes the RLEReportBlock in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let h = self.xrHeader()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.ssrc)
        buf.writeInteger(self.beginSeq)
        buf.writeInteger(self.endSeq)
        for chunk in self.chunks {
            buf.writeInteger(UInt16(chunk.rawValue))
        }

        return self.marshalSize()
    }
}

extension RLEReportBlock: Unmarshal {
    /// Unmarshal decodes the RLEReportBlock from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < xrHeaderLength {
            throw RtcpError.errPacketTooShort
        }

        let (xrHeader, xrHeaderLen) = try XRHeader.unmarshal(buf)
        let blockLength = xrHeader.blockLength * 4

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: xrHeaderLen)

        if blockLength < rleReportBlockMinLength
            || (blockLength - rleReportBlockMinLength) % 2 != 0
            || reader.readableBytes < Int(blockLength)
        {
            throw RtcpError.errPacketTooShort
        }

        let isLossRLE = xrHeader.blockType == BlockType.lossRLE
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

        let remaining = blockLength - rleReportBlockMinLength
        var chunks: [Chunk] = []
        for _ in 0..<remaining / 2 {
            guard let v: UInt16 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            chunks.append(Chunk(rawValue: v))
        }

        return (
            RLEReportBlock(
                isLossRLE: isLossRLE,
                t: t,
                ssrc: ssrc,
                beginSeq: beginSeq,
                endSeq: endSeq,
                chunks: chunks
            ), reader.readerIndex - readerStartIndex
        )
    }
}
