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

let xrHeaderLength: Int = 4

/// BlockType specifies the type of report in a report block
/// Extended Report block types from RFC 3611.
public enum BlockType: UInt8, Equatable {
    case unknown = 0
    case lossRLE = 1  // RFC 3611, section 4.1
    case duplicateRLE = 2  // RFC 3611, section 4.2
    case packetReceiptTimes = 3  // RFC 3611, section 4.3
    case receiverReferenceTime = 4  // RFC 3611, section 4.4
    case dlrr = 5  // RFC 3611, section 4.5
    case statisticsSummary = 6  // RFC 3611, section 4.6
    case voipMetrics = 7  // RFC 3611, section 4.7

    public init(rawValue: UInt8) {
        switch rawValue {
        case 1:
            self = BlockType.lossRLE
        case 2:
            self = BlockType.duplicateRLE
        case 3:
            self = BlockType.packetReceiptTimes
        case 4:
            self = BlockType.receiverReferenceTime
        case 5:
            self = BlockType.dlrr
        case 6:
            self = BlockType.statisticsSummary
        case 7:
            self = BlockType.voipMetrics
        default:
            self = BlockType.unknown
        }
    }
}

/// converts the Extended report block types into readable strings
extension BlockType: CustomStringConvertible {
    public var description: String {
        switch self {
        case BlockType.lossRLE:
            return "LossRLEReportBlockType"
        case BlockType.duplicateRLE:
            return "DuplicateRLEReportBlockType"
        case BlockType.packetReceiptTimes:
            return "PacketReceiptTimesReportBlockType"
        case BlockType.receiverReferenceTime:
            return "ReceiverReferenceTimeReportBlockType"
        case BlockType.dlrr:
            return "DLRRReportBlockType"
        case BlockType.statisticsSummary:
            return "StatisticsSummaryReportBlockType"
        case BlockType.voipMetrics:
            return "VoIPMetricsReportBlockType"
        default:
            return "UnknownReportBlockType"
        }
    }
}

/// TypeSpecificField as described in RFC 3611 section 4.5. In typical
/// cases, users of ExtendedReports shouldn't need to access this,
/// and should instead use the corresponding fields in the actual
/// report blocks themselves.
public typealias TypeSpecificField = UInt8

/// XRHeader defines the common fields that must appear at the start
/// of each report block. In typical cases, users of ExtendedReports
/// shouldn't need to access this. For locally-constructed report
/// blocks, these values will not be accurate until the corresponding
/// packet is marshaled.
public struct XRHeader: Equatable {
    public var blockType: BlockType
    public var typeSpecific: TypeSpecificField
    public var blockLength: UInt16
}

extension XRHeader: MarshalSize {
    public func marshalSize() -> Int {
        xrHeaderLength
    }
}

extension XRHeader: Marshal {
    /// marshal_to encodes the ExtendedReport in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        buf.writeInteger(UInt8(self.blockType.rawValue))
        buf.writeInteger(UInt8(self.typeSpecific))
        buf.writeInteger(self.blockLength)

        return xrHeaderLength
    }
}

extension XRHeader: Unmarshal {
    /// Unmarshal decodes the ExtendedReport from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < xrHeaderLength {
            throw RtcpError.errPacketTooShort
        }

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex

        guard let blockType: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let typeSpecific: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let blockLength: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        return (
            XRHeader(
                blockType: BlockType(rawValue: blockType),
                typeSpecific: typeSpecific,
                blockLength: blockLength
            ), reader.readerIndex - readerStartIndex
        )
    }
}

/// The ExtendedReport packet is an Implementation of RTCP Extended
/// reports defined in RFC 3611. It is used to convey detailed
/// information about an RTP stream. Each packet contains one or
/// more report blocks, each of which conveys a different kind of
/// information.
///
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |V=2|P|reserved |   PT=XR=207   |             length            |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                              ssrc                             |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// :                         report blocks                         :
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct ExtendedReport {
    public var senderSsrc: UInt32
    public var reports: [Packet]
}

extension ExtendedReport: CustomStringConvertible {
    public var description: String {
        "\(self)"
    }
}

extension ExtendedReport: Packet {
    /// Header returns the Header associated with this packet.
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: 0,
            packetType: PacketType.extendedReport,
            length: UInt16((self.marshalSize() / 4) - 1)
        )
    }

    /// destination_ssrc returns an array of ssrc values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        var ssrcs: [UInt32] = []
        for p in self.reports {
            ssrcs.append(contentsOf: p.destinationSsrc())
        }
        return ssrcs
    }

    public func rawSize() -> Int {
        var repsLength = 0
        for rep in self.reports {
            repsLength += rep.marshalSize()
        }
        return headerLength + ssrcLength + repsLength
    }

    public func equal(other: Packet) -> Bool {
        var isEqual = true
        if let rhs = other as? Self {
            if self.reports.count == rhs.reports.count && self.senderSsrc == rhs.senderSsrc {
                for i in 0..<self.reports.count {
                    if !self.reports[i].equal(other: rhs.reports[i]) {
                        isEqual = false
                        break
                    }
                }
            } else {
                isEqual = false
            }
        } else {
            isEqual = false
        }
        return isEqual
    }
}

extension ExtendedReport: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension ExtendedReport: Marshal {
    /// marshal_to encodes the ExtendedReport in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let h = self.header()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.senderSsrc)

        for report in self.reports {
            let _ = try report.marshalTo(&buf)
        }

        if h.padding {
            putPadding(&buf, self.rawSize())
        }

        return self.marshalSize()
    }
}

extension ExtendedReport: Unmarshal {
    /// Unmarshal decodes the ExtendedReport from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < (headerLength + ssrcLength) {
            throw RtcpError.errPacketTooShort
        }

        let (header, headerLen) = try Header.unmarshal(buf)
        if header.packetType != PacketType.extendedReport {
            throw RtcpError.errWrongType
        }

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: headerLen)

        guard let senderSsrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        var offset = headerLength + ssrcLength
        var reports: [Packet] = []
        while reader.readableBytes > 0 {
            if offset + xrHeaderLength > rawPacketLen {
                throw RtcpError.errPacketTooShort
            }

            guard let b = reader.getBytes(at: offset, length: 1) else {
                throw RtcpError.errPacketTooShort
            }
            let blockType: BlockType = BlockType(rawValue: b[0])
            let report: Packet
            let reportLen: Int
            switch blockType {
            case BlockType.lossRLE:
                (report, reportLen) = try LossRLEReportBlock.unmarshal(reader)
                reader.moveReaderIndex(forwardBy: reportLen)
            case BlockType.duplicateRLE:
                (report, reportLen) = try DuplicateRLEReportBlock.unmarshal(reader)
                reader.moveReaderIndex(forwardBy: reportLen)
            case BlockType.packetReceiptTimes:
                (report, reportLen) = try PacketReceiptTimesReportBlock.unmarshal(reader)
                reader.moveReaderIndex(forwardBy: reportLen)
            case BlockType.receiverReferenceTime:
                (report, reportLen) = try ReceiverReferenceTimeReportBlock.unmarshal(reader)
                reader.moveReaderIndex(forwardBy: reportLen)
            case BlockType.dlrr:
                (report, reportLen) = try DLRRReportBlock.unmarshal(reader)
                reader.moveReaderIndex(forwardBy: reportLen)
            case BlockType.statisticsSummary:
                (report, reportLen) = try StatisticsSummaryReportBlock.unmarshal(reader)
                reader.moveReaderIndex(forwardBy: reportLen)
            case BlockType.voipMetrics:
                (report, reportLen) = try VoIPMetricsReportBlock.unmarshal(reader)
                reader.moveReaderIndex(forwardBy: reportLen)
            default:
                (report, reportLen) = try UnknownReportBlock.unmarshal(reader)
                reader.moveReaderIndex(forwardBy: reportLen)
            }

            offset += reportLen
            reports.append(report)
        }

        return (
            ExtendedReport(
                senderSsrc: senderSsrc,
                reports: reports
            ), reader.readerIndex - readerStartIndex
        )
    }
}
