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

let rrSsrcOffset: Int = headerLength
let rrReportOffset: Int = rrSsrcOffset + ssrcLength

/// A ReceiverReport (RR) packet provides reception quality feedback for an RTP stream
public struct ReceiverReport: Equatable {
    /// The synchronization source identifier for the originator of this RR packet.
    public var ssrc: UInt32
    /// Zero or more reception report blocks depending on the number of other
    /// sources heard by this sender since the last report. Each reception report
    /// block conveys statistics on the reception of RTP packets from a
    /// single synchronization source.
    public var reports: [ReceptionReport]
    /// Extension contains additional, payload-specific information that needs to
    /// be reported regularly about the receiver.
    public var profileExtensions: ByteBuffer

    public init() {
        self.ssrc = 0
        self.reports = []
        self.profileExtensions = ByteBuffer()
    }

    public init(ssrc: UInt32, reports: [ReceptionReport], profileExtensions: ByteBuffer) {
        self.ssrc = ssrc
        self.reports = reports
        self.profileExtensions = profileExtensions
    }
}

extension ReceiverReport: CustomStringConvertible {
    public var description: String {
        var out = "ReceiverReport from \(self.ssrc)\n"
        out += "\tSSRC    \tLost\tLastSequence\n"
        for rep in self.reports {
            out += String(
                format:
                    "\t%x\t%d/%d\t%d\n",
                rep.ssrc, rep.fractionLost, rep.totalLost, rep.lastSequenceNumber
            )
        }
        out += "\tProfile Extension Data: \(self.profileExtensions)\n"

        return out
    }
}

extension ReceiverReport: Packet {
    /// Header returns the Header associated with this packet.
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: UInt8(self.reports.count),
            packetType: PacketType.receiverReport,
            length: UInt16((self.marshalSize() / 4) - 1)
        )
    }

    /// destination_ssrc returns an array of SSRC values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        self.reports.map { $0.ssrc }
    }

    public func rawSize() -> Int {
        var repsLength = 0
        for rep in self.reports {
            repsLength += rep.marshalSize()
        }

        return headerLength + ssrcLength + repsLength + self.profileExtensions.readableBytes
    }
}

extension ReceiverReport: Unmarshal {
    /// Unmarshal decodes the ReceiverReport from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        /*
         *         0                   1                   2                   3
         *         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * header |V=2|P|    RC   |   PT=RR=201   |             length            |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                     SSRC of packet sender                     |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * report |                 SSRC_1 (SSRC of first source)                 |
         * block  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *   1    | fraction lost |       cumulative number of packets lost       |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |           extended highest sequence number received           |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                      interarrival jitter                      |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                         last SR (LSR)                         |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                   delay since last SR (DLSR)                  |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * report |                 SSRC_2 (SSRC of second source)                |
         * block  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *   2    :                               ...                             :
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         *        |                  profile-specific extensions                  |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < (headerLength + ssrcLength) {
            throw RtcpError.errPacketTooShort
        }

        let (header, headerLen) = try Header.unmarshal(buf)
        if header.packetType != PacketType.receiverReport {
            throw RtcpError.errWrongType
        }

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: headerLen)

        guard let ssrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        var offset = rrReportOffset
        var reports: [ReceptionReport] = []
        reports.reserveCapacity(Int(header.count))
        for _ in 0..<header.count {
            if offset + receptionReportLength > rawPacketLen {
                throw RtcpError.errPacketTooShort
            }
            let (reception_report, receptionReportLen) = try ReceptionReport.unmarshal(reader)
            reader.moveReaderIndex(forwardBy: receptionReportLen)
            reports.append(reception_report)
            offset += receptionReportLen
        }
        let profileExtensions = reader.readSlice(length: reader.readableBytes) ?? ByteBuffer()
        /*
        if header.padding && raw_packet.has_remaining() {
            raw_packet.advance(raw_packet.remaining());
        }
         */

        return (
            ReceiverReport(
                ssrc: ssrc,
                reports: reports,
                profileExtensions: profileExtensions
            ),
            reader.readerIndex - readerStartIndex
        )
    }
}

extension ReceiverReport: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension ReceiverReport: Marshal {
    /// marshal_to encodes the packet in binary.
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        if self.reports.count > countMax {
            throw RtcpError.errTooManyReports
        }

        /*
         *         0                   1                   2                   3
         *         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * header |V=2|P|    RC   |   PT=RR=201   |             length            |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                     SSRC of packet sender                     |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * report |                 SSRC_1 (SSRC of first source)                 |
         * block  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *   1    | fraction lost |       cumulative number of packets lost       |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |           extended highest sequence number received           |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                      interarrival jitter                      |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                         last SR (LSR)                         |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                   delay since last SR (DLSR)                  |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * report |                 SSRC_2 (SSRC of second source)                |
         * block  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *   2    :                               ...                             :
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         *        |                  profile-specific extensions                  |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        let h = self.header()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.ssrc)

        for report in self.reports {
            let _ = try report.marshalTo(&buf)
        }

        buf.writeImmutableBuffer(self.profileExtensions)

        if h.padding {
            putPadding(&buf, self.rawSize())
        }

        return self.marshalSize()
    }
}
