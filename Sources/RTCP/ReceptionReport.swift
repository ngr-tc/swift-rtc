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

let receptionReportLength: Int = 24
let fractionLostOffset: Int = 4
let totalLostOffset: Int = 5
let lastSeqOffset: Int = 8
let jitterOffset: Int = 12
let lastSrOffset: Int = 16
let delayOffset: Int = 20

/// A ReceptionReport block conveys statistics on the reception of RTP packets
/// from a single synchronization source.
public struct ReceptionReport: Equatable {
    /// The SSRC identifier of the source to which the information in this
    /// reception report block pertains.
    public var ssrc: UInt32
    /// The fraction of RTP data packets from source SSRC lost since the
    /// previous SR or RR packet was sent, expressed as a fixed point
    /// number with the binary point at the left edge of the field.
    public var fractionLost: UInt8
    /// The total number of RTP data packets from source SSRC that have
    /// been lost since the beginning of reception.
    public var totalLost: UInt32
    /// The least significant 16 bits contain the highest sequence number received
    /// in an RTP data packet from source SSRC, and the most significant 16 bits extend
    /// that sequence number with the corresponding count of sequence number cycles.
    public var lastSequenceNumber: UInt32
    /// An estimate of the statistical variance of the RTP data packet
    /// interarrival time, measured in timestamp units and expressed as an
    /// unsigned integer.
    public var jitter: UInt32
    /// The middle 32 bits out of 64 in the NTP timestamp received as part of
    /// the most recent RTCP sender report (SR) packet from source SSRC. If no
    /// SR has been received yet, the field is set to zero.
    public var lastSenderReport: UInt32
    /// The delay, expressed in units of 1/65536 seconds, between receiving the
    /// last SR packet from source SSRC and sending this reception report block.
    /// If no SR packet has been received yet from SSRC, the field is set to zero.
    public var delay: UInt32

    public init() {
        self.ssrc = 0
        self.fractionLost = 0
        self.totalLost = 0
        self.lastSequenceNumber = 0
        self.jitter = 0
        self.lastSenderReport = 0
        self.delay = 0
    }

    public init(
        ssrc: UInt32, fractionLost: UInt8, totalLost: UInt32, lastSequenceNumber: UInt32,
        jitter: UInt32, lastSenderReport: UInt32, delay: UInt32
    ) {
        self.ssrc = ssrc
        self.fractionLost = fractionLost
        self.totalLost = totalLost
        self.lastSequenceNumber = lastSequenceNumber
        self.jitter = jitter
        self.lastSenderReport = lastSenderReport
        self.delay = delay
    }
}

extension ReceptionReport: Packet {
    public func header() -> Header {
        Header()
    }

    public func destinationSsrc() -> [UInt32] {
        []
    }

    public func rawSize() -> Int {
        receptionReportLength
    }
}

extension ReceptionReport: Unmarshal {
    /// unmarshal decodes the ReceptionReport from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < receptionReportLength {
            throw RtcpError.errPacketTooShort
        }

        /*
         *  0                   1                   2                   3
         *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         * +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * |                              SSRC                             |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * | fraction lost |       cumulative number of packets lost       |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |           extended highest sequence number received           |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |                      interarrival jitter                      |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |                         last SR (LSR)                         |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |                   delay since last SR (DLSR)                  |
         * +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         */
        var reader = buf.slice()
        guard let ssrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let fractionLost: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        guard let t0: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let t1: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let t2: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        // TODO: The type of `total_lost` should be `i32`, per the RFC:
        // The total number of RTP data packets from source SSRC_n that have
        // been lost since the beginning of reception.  This number is
        // defined to be the number of packets expected less the number of
        // packets actually received, where the number of packets received
        // includes any which are late or duplicates.  Thus, packets that
        // arrive late are not counted as lost, and the loss may be negative
        // if there are duplicates.  The number of packets expected is
        // defined to be the extended last sequence number received, as
        // defined next, less the initial sequence number received.  This may
        // be calculated as shown in Appendix A.3.
        let totalLost: UInt32 = UInt32(t2) | UInt32(t1) << 8 | UInt32(t0) << 16

        guard let lastSequenceNumber: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let jitter: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let lastSenderReport: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let delay: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        return (
            ReceptionReport(
                ssrc: ssrc,
                fractionLost: fractionLost,
                totalLost: totalLost,
                lastSequenceNumber: lastSequenceNumber,
                jitter: jitter,
                lastSenderReport: lastSenderReport,
                delay: delay
            ), reader.readerIndex
        )
    }
}

extension ReceptionReport: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension ReceptionReport: Marshal {
    /// marshal_to encodes the ReceptionReport in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        /*
         *  0                   1                   2                   3
         *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         * +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * |                              SSRC                             |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * | fraction lost |       cumulative number of packets lost       |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |           extended highest sequence number received           |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |                      interarrival jitter                      |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |                         last SR (LSR)                         |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |                   delay since last SR (DLSR)                  |
         * +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         */
        buf.writeInteger(self.ssrc)

        buf.writeInteger(self.fractionLost)

        // pack TotalLost into 24 bits
        if self.totalLost >= (1 << 25) {
            throw RtcpError.errInvalidTotalLost
        }

        buf.writeInteger(UInt8((self.totalLost >> 16) & 0xFF))
        buf.writeInteger(UInt8((self.totalLost >> 8) & 0xFF))
        buf.writeInteger(UInt8(self.totalLost & 0xFF))

        buf.writeInteger(self.lastSequenceNumber)
        buf.writeInteger(self.jitter)
        buf.writeInteger(self.lastSenderReport)
        buf.writeInteger(self.delay)

        putPadding(&buf, self.rawSize())

        return self.marshalSize()
    }
}
