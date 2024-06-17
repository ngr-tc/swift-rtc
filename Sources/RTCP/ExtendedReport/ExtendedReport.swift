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
/*
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
#[derive(Debug, PartialEq, Default, Clone)]
public struct ExtendedReport {
    public sender_ssrc: u32,
    public reports: Vec<Box<dyn Packet>>,
}

impl fmt::Display for ExtendedReport {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl Packet for ExtendedReport {
    /// Header returns the Header associated with this packet.
    fn header(&self) -> Header {
        Header {
            padding: get_padding_size(self.raw_size()) != 0,
            count: 0,
            packet_type: PacketType::ExtendedReport,
            length: ((self.marshal_size() / 4) - 1) as u16,
        }
    }

    /// destination_ssrc returns an array of ssrc values that this packet refers to.
    fn destination_ssrc(&self) -> Vec<u32> {
        let mut ssrc = vec![];
        for p in &self.reports {
            ssrc.extend(p.destination_ssrc());
        }
        ssrc
    }

    fn raw_size(&self) -> usize {
        let mut reps_length = 0;
        for rep in &self.reports {
            reps_length += rep.marshal_size();
        }
        HEADER_LENGTH + SSRC_LENGTH + reps_length
    }

    fn as_any(&self) -> &(dyn Any) {
        self
    }

    fn equal(&self, other: &(dyn Packet)) -> bool {
        other
            .as_any()
            .downcast_ref::<ExtendedReport>()
            .map_or(false, |a| self == a)
    }

    fn cloned(&self) -> Box<dyn Packet> {
        Box::new(self.clone())
    }
}

impl MarshalSize for ExtendedReport {
    fn marshal_size(&self) -> usize {
        let l = self.raw_size();
        // align to 32-bit boundary
        l + get_padding_size(l)
    }
}

impl Marshal for ExtendedReport {
    /// marshal_to encodes the ExtendedReport in binary
    fn marshal_to(&self, mut buf: &mut [u8]) -> Result<usize> {
        if buf.remaining_mut() < self.marshal_size() {
            return Err(Error::BufferTooShort);
        }

        let h = self.header();
        let n = h.marshal_to(buf)?;
        buf = &mut buf[n..];

        buf.put_u32(self.sender_ssrc);

        for report in &self.reports {
            let n = report.marshal_to(buf)?;
            buf = &mut buf[n..];
        }

        if h.padding {
            put_padding(buf, self.raw_size());
        }

        Ok(self.marshal_size())
    }
}

impl Unmarshal for ExtendedReport {
    /// Unmarshal decodes the ExtendedReport from binary
    fn unmarshal<B>(raw_packet: &mut B) -> Result<Self>
    where
        Self: Sized,
        B: Buf,
    {
        let raw_packet_len = raw_packet.remaining();
        if raw_packet_len < (HEADER_LENGTH + SSRC_LENGTH) {
            return Err(Error::PacketTooShort);
        }

        let header = Header::unmarshal(raw_packet)?;
        if header.packet_type != PacketType::ExtendedReport {
            return Err(Error::WrongType);
        }

        let sender_ssrc = raw_packet.get_u32();

        let mut offset = HEADER_LENGTH + SSRC_LENGTH;
        let mut reports = vec![];
        while raw_packet.remaining() > 0 {
            if offset + XR_HEADER_LENGTH > raw_packet_len {
                return Err(Error::PacketTooShort);
            }

            let block_type: BlockType = raw_packet.chunk()[0].into();
            let report: Box<dyn Packet> = match block_type {
                BlockType::LossRLE => Box::new(LossRLEReportBlock::unmarshal(raw_packet)?),
                BlockType::DuplicateRLE => {
                    Box::new(DuplicateRLEReportBlock::unmarshal(raw_packet)?)
                }
                BlockType::PacketReceiptTimes => {
                    Box::new(PacketReceiptTimesReportBlock::unmarshal(raw_packet)?)
                }
                BlockType::ReceiverReferenceTime => {
                    Box::new(ReceiverReferenceTimeReportBlock::unmarshal(raw_packet)?)
                }
                BlockType::DLRR => Box::new(DLRRReportBlock::unmarshal(raw_packet)?),
                BlockType::StatisticsSummary => {
                    Box::new(StatisticsSummaryReportBlock::unmarshal(raw_packet)?)
                }
                BlockType::VoIPMetrics => Box::new(VoIPMetricsReportBlock::unmarshal(raw_packet)?),
                _ => Box::new(UnknownReportBlock::unmarshal(raw_packet)?),
            };

            offset += report.marshal_size();
            reports.push(report);
        }

        Ok(ExtendedReport {
            sender_ssrc,
            reports,
        })
    }
}
*/
