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

let srHeaderLength: Int = 24
let srSsrcOffset: Int = headerLength
let srReportOffset: Int = srSsrcOffset + srHeaderLength

let srNtpOffset: Int = srSsrcOffset + ssrcLength
let ntpTimeLength: Int = 8
let srRtpOffset: Int = srNtpOffset + ntpTimeLength
let rtpTimeLength: Int = 4
let srPacketCountOffset: Int = srRtpOffset + rtpTimeLength
let srPacketCountLength: Int = 4
let srOctetCountOffset: Int = srPacketCountOffset + srPacketCountLength
let srOctetCountLength: Int = 4

/// A SenderReport (SR) packet provides reception quality feedback for an RTP stream
public struct SenderReport: Equatable {
    /// The synchronization source identifier for the originator of this SR packet.
    public var ssrc: UInt32
    /// The wallclock time when this report was sent so that it may be used in
    /// combination with timestamps returned in reception reports from other
    /// receivers to measure round-trip propagation to those receivers.
    public var ntpTime: UInt64
    /// Corresponds to the same time as the NTP timestamp (above), but in
    /// the same units and with the same random offset as the RTP
    /// timestamps in data packets. This correspondence may be used for
    /// intra- and inter-media synchronization for sources whose NTP
    /// timestamps are synchronized, and may be used by media-independent
    /// receivers to estimate the nominal RTP clock frequency.
    public var rtpTime: UInt32
    /// The total number of RTP data packets transmitted by the sender
    /// since starting transmission up until the time this SR packet was
    /// generated.
    public var packetCount: UInt32
    /// The total number of payload octets (i.e., not including header or
    /// padding) transmitted in RTP data packets by the sender since
    /// starting transmission up until the time this SR packet was
    /// generated.
    public var octetCount: UInt32
    /// Zero or more reception report blocks depending on the number of other
    /// sources heard by this sender since the last report. Each reception report
    /// block conveys statistics on the reception of RTP packets from a
    /// single synchronization source.
    public var reports: [ReceptionReport]

    /// ProfileExtensions contains additional, payload-specific information that needs to
    /// be reported regularly about the sender.
    public var profileExtensions: ByteBuffer

    public init() {
        self.ssrc = 0
        self.ntpTime = 0
        self.rtpTime = 0
        self.packetCount = 0
        self.octetCount = 0
        self.reports = []
        self.profileExtensions = ByteBuffer()
    }

    public init(
        ssrc: UInt32, ntpTime: UInt64, rtpTime: UInt32, packetCount: UInt32, octetCount: UInt32,
        reports: [ReceptionReport], profileExtensions: ByteBuffer
    ) {
        self.ssrc = ssrc
        self.ntpTime = ntpTime
        self.rtpTime = rtpTime
        self.packetCount = packetCount
        self.octetCount = octetCount
        self.reports = reports
        self.profileExtensions = profileExtensions
    }
}

extension SenderReport: CustomStringConvertible {
    public var description: String {
        var out = "SenderReport from \(self.ssrc)\n"
        out += "\tNTPTime:\t\(self.ntpTime)\n"
        out += "\tRTPTIme:\t\(self.rtpTime)\n"
        out += "\tPacketCount:\t\(self.packetCount)\n"
        out += "\tOctetCount:\t\(self.octetCount)\n"
        out += "\tSSRC    \tLost\tLastSequence\n"
        for rep in self.reports {
            out += String(
                format: "\t%x\t%d/%d\t%d\n",
                rep.ssrc, rep.fractionLost, rep.totalLost, rep.lastSequenceNumber
            )
        }
        out += "\tProfile Extension Data: \(self.profileExtensions)\n"

        return out
    }
}

extension SenderReport: Packet {
    /// Header returns the Header associated with this packet.
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: UInt8(self.reports.count),
            packetType: PacketType.senderReport,
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

        return headerLength + srHeaderLength + repsLength + self.profileExtensions.readableBytes
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension SenderReport: Unmarshal {
    /// Unmarshal decodes the SenderReport from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        /*
         *         0                   1                   2                   3
         *         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * header |V=2|P|    RC   |   PT=SR=200   |             length            |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                         SSRC of sender                        |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * sender |              NTP timestamp, most significant word             |
         * info   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |             NTP timestamp, least significant word             |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                         RTP timestamp                         |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                     sender's packet count                     |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                      sender's octet count                     |
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
        if rawPacketLen < (headerLength + srHeaderLength) {
            throw RtcpError.errPacketTooShort
        }

        let (header, headerLen) = try Header.unmarshal(buf)
        if header.packetType != PacketType.senderReport {
            throw RtcpError.errWrongType
        }

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: headerLen)

        guard let ssrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let ntpTime: UInt64 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let rtpTime: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let packetCount: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let octetCount: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        var offset = srReportOffset
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
            SenderReport(
                ssrc: ssrc,
                ntpTime: ntpTime,
                rtpTime: rtpTime,
                packetCount: packetCount,
                octetCount: octetCount,
                reports: reports,
                profileExtensions: profileExtensions
            ), reader.readerIndex - readerStartIndex
        )
    }
}

extension SenderReport: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension SenderReport: Marshal {
    /// Marshal encodes the packet in binary.
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        if self.reports.count > countMax {
            throw RtcpError.errTooManyReports
        }

        /*
         *         0                   1                   2                   3
         *         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * header |V=2|P|    RC   |   PT=SR=200   |             length            |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                         SSRC of sender                        |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * sender |              NTP timestamp, most significant word             |
         * info   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |             NTP timestamp, least significant word             |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                         RTP timestamp                         |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                     sender's packet count                     |
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                      sender's octet count                     |
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
        buf.writeInteger(self.ntpTime)
        buf.writeInteger(self.rtpTime)
        buf.writeInteger(self.packetCount)
        buf.writeInteger(self.octetCount)

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
