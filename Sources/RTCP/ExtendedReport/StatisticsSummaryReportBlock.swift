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

let ssrReportBlockLength: UInt16 = 4 + 2 * 2 + 4 * 6 + 4

/// TTLorHopLimitType encodes values for the ToH field in
/// a StatisticsSummaryReportBlock
public enum TTLorHopLimitType: UInt8, Equatable {
    case missing = 0
    case ipv4 = 1
    case ipv6 = 2

    public init(rawValue: UInt8) {
        switch rawValue {
        case 1:
            self = TTLorHopLimitType.ipv4
        case 2:
            self = TTLorHopLimitType.ipv6
        default:
            self = TTLorHopLimitType.missing
        }
    }
}

extension TTLorHopLimitType: CustomStringConvertible {
    public var description: String {
        switch self {
        case TTLorHopLimitType.missing:
            return "[ToH Missing]"
        case TTLorHopLimitType.ipv4:
            return "[ToH = IPv4]"
        case TTLorHopLimitType.ipv6:
            return "[ToH = IPv6]"
        }
    }
}

/// StatisticsSummaryReportBlock encodes a Statistics Summary Report
/// Block as described in RFC 3611, section 4.6.
///
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |     BT=6      |L|D|J|ToH|rsvd.|       block length = 9        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                        ssrc of source                         |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |          begin_seq            |             end_seq           |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                        lost_packets                           |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                        dup_packets                            |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                         min_jitter                            |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                         max_jitter                            |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                         mean_jitter                           |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                         dev_jitter                            |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// | min_ttl_or_hl | max_ttl_or_hl |mean_ttl_or_hl | dev_ttl_or_hl |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct StatisticsSummaryReportBlock: Equatable {
    //not included in marshal/unmarshal
    public var lossReports: Bool
    public var duplicateReports: Bool
    public var jitterReports: Bool
    public var ttlOrHopLimit: TTLorHopLimitType

    //marshal/unmarshal
    public var ssrc: UInt32
    public var beginSeq: UInt16
    public var endSeq: UInt16
    public var lostPackets: UInt32
    public var dupPackets: UInt32
    public var minJitter: UInt32
    public var maxJitter: UInt32
    public var meanJitter: UInt32
    public var devJitter: UInt32
    public var minTtlOrHl: UInt8
    public var maxTtlOrHl: UInt8
    public var meanTtlOrHl: UInt8
    public var devTtlOrHl: UInt8

    public func xrHeader() -> XRHeader {
        var typeSpecific: UInt8 = 0x00
        if self.lossReports {
            typeSpecific |= 0x80
        }
        if self.duplicateReports {
            typeSpecific |= 0x40
        }
        if self.jitterReports {
            typeSpecific |= 0x20
        }
        typeSpecific |= (UInt8(self.ttlOrHopLimit.rawValue) & 0x03) << 3

        return XRHeader(
            blockType: BlockType.statisticsSummary,
            typeSpecific: typeSpecific,
            blockLength: UInt16(self.rawSize() / 4 - 1)
        )
    }
}

extension StatisticsSummaryReportBlock: CustomStringConvertible {
    public var description: String {
        "\(self)"
    }
}

extension StatisticsSummaryReportBlock: Packet {
    public func header() -> Header {
        Header()
    }

    /// destination_ssrc returns an array of ssrc values that this report block refers to.
    public func destinationSsrc() -> [UInt32] {
        [self.ssrc]
    }

    public func rawSize() -> Int {
        xrHeaderLength + Int(ssrReportBlockLength)
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension StatisticsSummaryReportBlock: MarshalSize {
    public func marshalSize() -> Int {
        self.rawSize()
    }
}

extension StatisticsSummaryReportBlock: Marshal {
    /// marshal_to encodes the StatisticsSummaryReportBlock in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let h = self.xrHeader()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.ssrc)
        buf.writeInteger(self.beginSeq)
        buf.writeInteger(self.endSeq)
        buf.writeInteger(self.lostPackets)
        buf.writeInteger(self.dupPackets)
        buf.writeInteger(self.minJitter)
        buf.writeInteger(self.maxJitter)
        buf.writeInteger(self.meanJitter)
        buf.writeInteger(self.devJitter)
        buf.writeInteger(self.minTtlOrHl)
        buf.writeInteger(self.maxTtlOrHl)
        buf.writeInteger(self.meanTtlOrHl)
        buf.writeInteger(self.devTtlOrHl)

        return self.marshalSize()
    }
}

extension StatisticsSummaryReportBlock: Unmarshal {
    /// Unmarshal decodes the StatisticsSummaryReportBlock from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < xrHeaderLength {
            throw RtcpError.errPacketTooShort
        }

        let (xrHeader, xrHeaderLen) = try XRHeader.unmarshal(buf)
        let blockLength = xrHeader.blockLength * 4

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: xrHeaderLen)

        if blockLength != ssrReportBlockLength || reader.readableBytes < Int(blockLength) {
            throw RtcpError.errPacketTooShort
        }

        let lossReports = xrHeader.typeSpecific & 0x80 != 0
        let duplicateReports = xrHeader.typeSpecific & 0x40 != 0
        let jitterReports = xrHeader.typeSpecific & 0x20 != 0
        let ttlOrHopLimit: TTLorHopLimitType = TTLorHopLimitType(
            rawValue: (xrHeader.typeSpecific & 0x18) >> 3)

        guard let ssrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let beginSeq: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let endSeq: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let lostPackets: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let dupPackets: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let minJitter: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let maxJitter: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let meanJitter: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let devJitter: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let minTtlOrHl: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let maxTtlOrHl: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let meanTtlOrHl: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let devTtlOrHl: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        return (
            StatisticsSummaryReportBlock(
                lossReports: lossReports,
                duplicateReports: duplicateReports,
                jitterReports: jitterReports,
                ttlOrHopLimit: ttlOrHopLimit,

                ssrc: ssrc,
                beginSeq: beginSeq,
                endSeq: endSeq,
                lostPackets: lostPackets,
                dupPackets: dupPackets,
                minJitter: minJitter,
                maxJitter: maxJitter,
                meanJitter: meanJitter,
                devJitter: devJitter,
                minTtlOrHl: minTtlOrHl,
                maxTtlOrHl: maxTtlOrHl,
                meanTtlOrHl: meanTtlOrHl,
                devTtlOrHl: devTtlOrHl
            ), reader.readerIndex - readerStartIndex
        )
    }
}
