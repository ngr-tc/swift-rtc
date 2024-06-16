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

/// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-5
/// 0                   1                   2                   3
/// 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |V=2|P|  FMT=15 |    PT=205     |           length              |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                     SSRC of packet sender                     |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                      SSRC of media source                     |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |      base sequence number     |      packet status count      |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                 reference time                | fb pkt. count |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |          packet chunk         |         packet chunk          |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// .                                                               .
/// .                                                               .
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |         packet chunk          |  recv delta   |  recv delta   |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// .                                                               .
/// .                                                               .
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |           recv delta          |  recv delta   | zero padding  |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

// for packet status chunk
/// type of packet status chunk
public enum StatusChunkTypeTcc: UInt16, Equatable {
    case runLengthChunk = 0
    case statusVectorChunk = 1

    public init(rawValue: UInt16) {
        switch rawValue {
        case 0: self = StatusChunkTypeTcc.runLengthChunk
        default: self = StatusChunkTypeTcc.statusVectorChunk
        }
    }
}

/// type of packet status symbol and recv delta
public enum SymbolTypeTcc: UInt16, Equatable {
    /// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#section-3.1.1
    case packetNotReceived = 0
    /// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#section-3.1.1
    case packetReceivedSmallDelta = 1
    /// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#section-3.1.1
    case packetReceivedLargeDelta = 2
    /// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-7
    /// see Example 2: "packet received, w/o recv delta"
    case packetReceivedWithoutDelta = 3

    public init(rawValue: UInt16) {
        switch rawValue {
        case 0: self = SymbolTypeTcc.packetNotReceived
        case 1: self = SymbolTypeTcc.packetReceivedSmallDelta
        case 2: self = SymbolTypeTcc.packetReceivedLargeDelta
        default: self = SymbolTypeTcc.packetReceivedWithoutDelta
        }
    }
}

/// for status vector chunk
public enum SymbolSizeTypeTcc: UInt16, Equatable {
    /// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#section-3.1.4
    case oneBit = 0
    case twoBit = 1

    public init(rawValue: UInt16) {
        switch rawValue {
        case 0: self = SymbolSizeTypeTcc.oneBit
        default: self = SymbolSizeTypeTcc.twoBit
        }
    }
}

/// PacketStatusChunk has two kinds:
/// RunLengthChunk and StatusVectorChunk
public enum PacketStatusChunk: Equatable {
    case runLengthChunk(RunLengthChunk)
    case statusVectorChunk(StatusVectorChunk)
}

extension PacketStatusChunk: MarshalSize {
    public func marshalSize() -> Int {
        switch self {
        case .runLengthChunk(let c):
            return c.marshalSize()
        case .statusVectorChunk(let c):
            return c.marshalSize()
        }
    }
}

extension PacketStatusChunk: Marshal {
    /// Marshal ..
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        switch self {
        case .runLengthChunk(let c):
            return try c.marshalTo(&buf)
        case .statusVectorChunk(let c):
            return try c.marshalTo(&buf)
        }
    }
}

/// RunLengthChunk T=TypeTCCRunLengthChunk
/// 0                   1
/// 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |T| S |       Run Length        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct RunLengthChunk: Equatable {
    /// T = TypeTCCRunLengthChunk
    public var typeTcc: StatusChunkTypeTcc
    /// S: type of packet status
    /// kind: TypeTCCPacketNotReceived or...
    public var packetStatusSymbol: SymbolTypeTcc
    /// run_length: count of S
    public var runLength: UInt16
}

extension RunLengthChunk: MarshalSize {
    public func marshalSize() -> Int {
        packetStatusChunkLength
    }
}

extension RunLengthChunk: Marshal {
    /// Marshal ..
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        // append 1 bit '0'
        var dst: UInt16
        if let d = setNbitsOfUInt16(0, 1, 0, 0) {
            dst = d
        } else {
            throw RtcpError.errInvalidSizeOrStartIndex
        }

        // append 2 bit packet_status_symbol
        if let d = setNbitsOfUInt16(dst, 2, 1, UInt16(self.packetStatusSymbol.rawValue)) {
            dst = d
        } else {
            throw RtcpError.errInvalidSizeOrStartIndex
        }

        // append 13 bit run_length
        if let d = setNbitsOfUInt16(dst, 13, 3, self.runLength) {
            dst = d
        } else {
            throw RtcpError.errInvalidSizeOrStartIndex
        }

        buf.writeInteger(dst)

        return packetStatusChunkLength
    }
}

extension RunLengthChunk: Unmarshal {
    /// Unmarshal ..
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < packetStatusChunkLength {
            throw RtcpError.errPacketStatusChunkLength
        }

        // record type
        let typeTcc = StatusChunkTypeTcc.runLengthChunk

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex

        guard let b0: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let b1: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        // get PacketStatusSymbol
        let packetStatusSymbol = SymbolTypeTcc(rawValue: getNbitsFromByte(b0, 1, 2))

        // get RunLength
        let runLength = (UInt16(getNbitsFromByte(b0, 3, 5)) << 8) + UInt16(b1)

        return (
            RunLengthChunk(
                typeTcc: typeTcc,
                packetStatusSymbol: packetStatusSymbol,
                runLength: runLength
            ), reader.readerIndex - readerStartIndex
        )
    }
}

/// StatusVectorChunk T=typeStatusVecotrChunk
/// 0                   1
/// 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |T|S|       symbol list         |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct StatusVectorChunk: Equatable {
    /// T = TypeTCCRunLengthChunk
    public var typeTcc: StatusChunkTypeTcc

    /// TypeTCCSymbolSizeOneBit or TypeTCCSymbolSizeTwoBit
    public var symbolSize: SymbolSizeTypeTcc

    /// when symbol_size = TypeTCCSymbolSizeOneBit, symbol_list is 14*1bit:
    /// TypeTCCSymbolListPacketReceived or TypeTCCSymbolListPacketNotReceived
    /// when symbol_size = TypeTCCSymbolSizeTwoBit, symbol_list is 7*2bit:
    /// TypeTCCPacketNotReceived TypeTCCPacketReceivedSmallDelta TypeTCCPacketReceivedLargeDelta or typePacketReserved
    public var symbolList: [SymbolTypeTcc]
}

extension StatusVectorChunk: MarshalSize {
    public func marshalSize() -> Int {
        packetStatusChunkLength
    }
}

extension StatusVectorChunk: Marshal {
    /// Marshal ..
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        // set first bit '1'
        var dst: UInt16
        if let d = setNbitsOfUInt16(0, 1, 0, 1) {
            dst = d
        } else {
            throw RtcpError.errInvalidSizeOrStartIndex
        }

        // set second bit symbol_size
        if let d = setNbitsOfUInt16(dst, 1, 1, UInt16(self.symbolSize.rawValue)) {
            dst = d
        } else {
            throw RtcpError.errInvalidSizeOrStartIndex
        }

        let numOfBits = numOfBitsOfSymbolSize[Int(self.symbolSize.rawValue)]
        // append 14 bit symbol_list
        for (i, s) in self.symbolList.enumerated() {
            let index = numOfBits * UInt16(i) + 2
            if let d = setNbitsOfUInt16(dst, numOfBits, index, UInt16(s.rawValue)) {
                dst = d
            } else {
                throw RtcpError.errInvalidSizeOrStartIndex
            }
        }

        buf.writeInteger(dst)

        return packetStatusChunkLength
    }
}

extension StatusVectorChunk: Unmarshal {
    /// Unmarshal ..
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < packetStatusChunkLength {
            throw RtcpError.errPacketBeforeCname
        }

        let typeTcc = StatusChunkTypeTcc.statusVectorChunk

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex

        guard let b0: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let b1: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        let symbolSize = SymbolSizeTypeTcc(rawValue: getNbitsFromByte(b0, 1, 1))

        var symbolList: [SymbolTypeTcc] = []
        switch symbolSize {
        case SymbolSizeTypeTcc.oneBit:
            for i in 0..<6 {
                symbolList.append(SymbolTypeTcc(rawValue: getNbitsFromByte(b0, 2 + UInt16(i), 1)))
            }

            for i in 0..<8 {
                symbolList.append(SymbolTypeTcc(rawValue: getNbitsFromByte(b1, UInt16(i), 1)))
            }
        case SymbolSizeTypeTcc.twoBit:
            for i in 0..<3 {
                symbolList.append(
                    SymbolTypeTcc(rawValue: getNbitsFromByte(b0, 2 + UInt16(i) * 2, 2)))
            }

            for i in 0..<4 {
                symbolList.append(SymbolTypeTcc(rawValue: getNbitsFromByte(b1, UInt16(i) * 2, 2)))
            }
        }

        return (
            StatusVectorChunk(
                typeTcc: typeTcc,
                symbolSize: symbolSize,
                symbolList: symbolList
            ), reader.readerIndex - readerStartIndex
        )
    }
}

/// RecvDelta are represented as multiples of 250us
/// small delta is 1 byte: [0，63.75]ms = [0, 63750]us = [0, 255]*250us
/// big delta is 2 bytes: [-8192.0, 8191.75]ms = [-8192000, 8191750]us = [-32768, 32767]*250us
/// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#section-3.1.5
public struct RecvDelta: Equatable {
    public var typeTccPacket: SymbolTypeTcc
    /// us
    public var delta: Int64
}

extension RecvDelta: MarshalSize {
    public func marshalSize() -> Int {
        let delta = self.delta / typeTccDeltaScaleFactor

        // small delta
        if self.typeTccPacket == SymbolTypeTcc.packetReceivedSmallDelta
            && delta >= 0
            && delta <= Int64(UInt8.max)
        {
            return 1
        }

        // big delta
        if self.typeTccPacket == SymbolTypeTcc.packetReceivedLargeDelta
            && delta >= Int64(Int16.min)
            && delta <= Int64(Int16.max)
        {
            return 2
        }

        return 0
    }
}

extension RecvDelta: Marshal {
    /// Marshal ..
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let delta = self.delta / typeTccDeltaScaleFactor

        // small delta
        if self.typeTccPacket == SymbolTypeTcc.packetReceivedSmallDelta
            && delta >= 0
            && delta <= Int64(UInt8.max)
        {
            buf.writeInteger(UInt8(delta))
            return 1
        }

        // big delta
        if self.typeTccPacket == SymbolTypeTcc.packetReceivedLargeDelta
            && delta >= Int64(Int16.min)
            && delta <= Int64(Int16.max)
        {
            buf.writeInteger(Int16(delta))
            return 2
        }

        // overflow
        throw RtcpError.errDeltaExceedLimit
    }
}

extension RecvDelta: Unmarshal {
    /// Unmarshal ..
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let chunkLen = buf.readableBytes

        // must be 1 or 2 bytes
        if chunkLen != 1 && chunkLen != 2 {
            throw RtcpError.errDeltaExceedLimit
        }

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex

        let typeTccPacket: SymbolTypeTcc
        let delta: Int64
        if chunkLen == 1 {
            typeTccPacket = SymbolTypeTcc.packetReceivedSmallDelta
            guard let b: UInt8 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            delta = typeTccDeltaScaleFactor * Int64(b)
        } else {
            typeTccPacket = SymbolTypeTcc.packetReceivedLargeDelta
            guard let b: Int16 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            delta = typeTccDeltaScaleFactor * Int64(b)
        }

        return (
            RecvDelta(
                typeTccPacket: typeTccPacket,
                delta: delta
            ), reader.readerIndex - readerStartIndex
        )
    }
}

/// The offset after header
let baseSequenceNumberOffset: Int = 8
/// The offset after header
let packetStatusCountOffset: Int = 10
/// The offset after header
let referenceTimeOffset: Int = 12
/// The offset after header
let fbPktCountOffset: Int = 15
/// The offset after header
let packetChunkOffset: Int = 16
/// len of packet status chunk
let typeTccStatusVectorChunk: Int = 1

/// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#section-3.1.5
public let typeTccDeltaScaleFactor: Int64 = 250

// Notice: RFC is wrong: "packet received" (0) and "packet not received" (1)
// if S == TYPE_TCCSYMBOL_SIZE_ONE_BIT, symbol list will be: TypeTCCPacketNotReceived TypeTCCPacketReceivedSmallDelta
// if S == TYPE_TCCSYMBOL_SIZE_TWO_BIT, symbol list will be same as above:

let numOfBitsOfSymbolSize: [UInt16] = [1, 2]

/// len of packet status chunk
let packetStatusChunkLength: Int = 2

/// TransportLayerCC for sender-BWE
/// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-5
public struct TransportLayerCc: Equatable {
    /// SSRC of sender
    public var senderSsrc: UInt32
    /// SSRC of the media source
    public var mediaSsrc: UInt32
    /// Transport wide sequence of rtp extension
    public var baseSequenceNumber: UInt16
    /// packetStatusCount
    public var packetStatusCount: UInt16
    /// reference_time
    public var referenceTime: UInt32
    /// fb_pkt_count
    public var fbPktCount: UInt8
    /// packet_chunks
    public var packetChunks: [PacketStatusChunk]
    /// recv_deltas
    public var recvDeltas: [RecvDelta]
}

extension TransportLayerCc: CustomStringConvertible {
    public var description: String {
        var out = String()
        out += "TransportLayerCC:\n\tSender Ssrc \(self.senderSsrc)\n"
        out += "\tMedia Ssrc \(self.mediaSsrc)\n"
        out += "\tBase Sequence Number \(self.baseSequenceNumber)\n"
        out += "\tStatus Count \(self.packetStatusCount)\n"
        out += "\tReference Time \(self.referenceTime)\n"
        out += "\tFeedback Packet Count \(self.fbPktCount)\n"
        out += "\tpacket_chunks "
        out += "\n\trecv_deltas "
        for delta in self.recvDeltas {
            out += "\(delta) "
        }
        out += "\n"

        return out
    }
}

extension TransportLayerCc: Packet {
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: formatTcc,
            packetType: PacketType.transportSpecificFeedback,
            length: UInt16((self.marshalSize() / 4) - 1)
        )
    }

    /// destination_ssrc returns an array of SSRC values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        [self.mediaSsrc]
    }

    public func rawSize() -> Int {
        var n = headerLength + packetChunkOffset + self.packetChunks.count * 2
        for d in self.recvDeltas {
            // small delta
            if d.typeTccPacket == SymbolTypeTcc.packetReceivedSmallDelta {
                n += 1
            } else {
                n += 2
            }
        }
        return n
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension TransportLayerCc: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension TransportLayerCc: Marshal {
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let h = self.header()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.senderSsrc)
        buf.writeInteger(self.mediaSsrc)
        buf.writeInteger(self.baseSequenceNumber)
        buf.writeInteger(self.packetStatusCount)

        var referenceTimeAndFbPktCount: UInt32 = appendNbitsToUInt32(
            0, 24, self.referenceTime)
        referenceTimeAndFbPktCount =
            appendNbitsToUInt32(referenceTimeAndFbPktCount, 8, UInt32(self.fbPktCount))

        buf.writeInteger(referenceTimeAndFbPktCount)

        for chunk in self.packetChunks {
            let _ = try chunk.marshalTo(&buf)
        }

        for delta in self.recvDeltas {
            let _ = try delta.marshalTo(&buf)
        }

        if h.padding {
            putPadding(&buf, self.rawSize())
        }

        return self.marshalSize()
    }
}

extension TransportLayerCc: Unmarshal {
    /// Unmarshal ..
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < (headerLength + ssrcLength) {
            throw RtcpError.errPacketTooShort
        }

        let (h, headerLen) = try Header.unmarshal(buf)

        // https://tools.ietf.org/html/rfc4585#page-33
        // header's length + payload's length
        let totalLength = 4 * Int(h.length + 1)

        if totalLength < headerLength + packetChunkOffset {
            throw RtcpError.errPacketTooShort
        }

        if rawPacketLen < totalLength {
            throw RtcpError.errPacketTooShort
        }

        if h.packetType != PacketType.transportSpecificFeedback || h.count != formatTcc {
            throw RtcpError.errWrongType
        }

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: headerLen)

        guard let senderSsrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let mediaSsrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let baseSequenceNumber: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let packetStatusCount: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        guard let buf0: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let buf1: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let buf2: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        let buf = [buf0, buf1, buf2]
        let referenceTime = get24BitsFromBytes(ByteBufferView(buf))
        guard let fbPktCount: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        var packetChunks: [PacketStatusChunk] = []
        var recvDeltas: [RecvDelta] = []

        var packetStatusPos = headerLength + packetChunkOffset
        var processedPacketNum: UInt16 = 0
        while processedPacketNum < packetStatusCount {
            if packetStatusPos + packetStatusChunkLength >= totalLength {
                throw RtcpError.errPacketTooShort
            }

            var chunkReader = reader.readSlice(length: packetStatusChunkLength) ?? ByteBuffer()
            guard let b = chunkReader.getBytes(at: 0, length: 1) else {
                throw RtcpError.errPacketTooShort
            }

            let typ = StatusChunkTypeTcc(rawValue: getNbitsFromByte(b[0], 0, 1))
            let initialPacketStatus: PacketStatusChunk
            switch typ {
            case StatusChunkTypeTcc.runLengthChunk:
                let (packetStatus, packetLen) = try RunLengthChunk.unmarshal(chunkReader)
                chunkReader.moveReaderIndex(forwardBy: packetLen)

                let packetNumberToProcess =
                    min(packetStatusCount - processedPacketNum, packetStatus.runLength)

                if packetStatus.packetStatusSymbol == SymbolTypeTcc.packetReceivedSmallDelta
                    || packetStatus.packetStatusSymbol
                        == SymbolTypeTcc.packetReceivedLargeDelta
                {
                    var j: UInt16 = 0

                    while j < packetNumberToProcess {
                        recvDeltas.append(
                            RecvDelta(
                                typeTccPacket: packetStatus.packetStatusSymbol,
                                delta: 0
                            ))

                        j += 1
                    }
                }

                initialPacketStatus = PacketStatusChunk.runLengthChunk(packetStatus)
                processedPacketNum += packetNumberToProcess
            case StatusChunkTypeTcc.statusVectorChunk:
                let (packetStatus, packetLen) = try StatusVectorChunk.unmarshal(chunkReader)
                chunkReader.moveReaderIndex(forwardBy: packetLen)

                switch packetStatus.symbolSize {
                case SymbolSizeTypeTcc.oneBit:
                    for sym in packetStatus.symbolList {
                        if sym == SymbolTypeTcc.packetReceivedSmallDelta {
                            recvDeltas.append(
                                RecvDelta(
                                    typeTccPacket: SymbolTypeTcc.packetReceivedSmallDelta,
                                    delta: 0
                                ))
                        }
                    }
                case SymbolSizeTypeTcc.twoBit:
                    for sym in packetStatus.symbolList {
                        if sym == SymbolTypeTcc.packetReceivedSmallDelta
                            || sym == SymbolTypeTcc.packetReceivedLargeDelta
                        {
                            recvDeltas.append(
                                RecvDelta(
                                    typeTccPacket: sym,
                                    delta: 0
                                ))
                        }
                    }
                }

                processedPacketNum += UInt16(packetStatus.symbolList.count)
                initialPacketStatus = PacketStatusChunk.statusVectorChunk(packetStatus)
            }

            packetStatusPos += packetStatusChunkLength
            packetChunks.append(initialPacketStatus)
        }

        var recvDeltasPos = packetStatusPos

        for i in 0..<recvDeltas.count {
            if recvDeltasPos >= totalLength {
                throw RtcpError.errPacketTooShort
            }

            if recvDeltas[i].typeTccPacket == SymbolTypeTcc.packetReceivedSmallDelta {
                guard let deltaReader = reader.readSlice(length: 1) else {
                    throw RtcpError.errPacketTooShort
                }
                let (delta, _) = try RecvDelta.unmarshal(deltaReader)
                recvDeltas[i] = delta
                recvDeltasPos += 1
            }

            if recvDeltas[i].typeTccPacket == SymbolTypeTcc.packetReceivedLargeDelta {
                guard let deltaReader = reader.readSlice(length: 2) else {
                    throw RtcpError.errPacketTooShort
                }
                let (delta, _) = try RecvDelta.unmarshal(deltaReader)
                recvDeltas[i] = delta
                recvDeltasPos += 2
            }
        }

        /*h.padding &&*/
        if reader.readableBytes > 0 {
            reader.moveReaderIndex(forwardBy: reader.readableBytes)
        }

        return (
            TransportLayerCc(
                senderSsrc: senderSsrc,
                mediaSsrc: mediaSsrc,
                baseSequenceNumber: baseSequenceNumber,
                packetStatusCount: packetStatusCount,
                referenceTime: referenceTime,
                fbPktCount: fbPktCount,
                packetChunks: packetChunks,
                recvDeltas: recvDeltas
            ), reader.readerIndex - readerStartIndex
        )
    }
}
