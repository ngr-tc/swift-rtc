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

let vmReportBlockLength: UInt16 = 32

/// VoIPMetricsReportBlock encodes a VoIP Metrics Report Block as described
/// in RFC 3611, section 4.7.
///
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |     BT=7      |   reserved    |       block length = 8        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                        ssrc of source                         |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |   loss rate   | discard rate  | burst density |  gap density  |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |       burst duration          |         gap duration          |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |     round trip delay          |       end system delay        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// | signal level  |  noise level  |     RERL      |     Gmin      |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |   R factor    | ext. R factor |    MOS-LQ     |    MOS-CQ     |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |   RX config   |   reserved    |          JB nominal           |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |          JB maximum           |          JB abs max           |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct VoIPMetricsReportBlock: Equatable {
    public var ssrc: UInt32
    public var lossRate: UInt8
    public var discardRate: UInt8
    public var burstDensity: UInt8
    public var gapDensity: UInt8
    public var burstDuration: UInt16
    public var gapDuration: UInt16
    public var roundTripDelay: UInt16
    public var endSystemDelay: UInt16
    public var signalLevel: UInt8
    public var noiseLevel: UInt8
    public var rerl: UInt8
    public var gmin: UInt8
    public var rfactor: UInt8
    public var extRfactor: UInt8
    public var mosLq: UInt8
    public var mosCq: UInt8
    public var rxConfig: UInt8
    public var reserved: UInt8
    public var jbNominal: UInt16
    public var jbMaximum: UInt16
    public var jbAbsMax: UInt16

    public func xrHeader() -> XRHeader {
        XRHeader(
            blockType: BlockType.voipMetrics,
            typeSpecific: 0,
            blockLength: UInt16(self.rawSize() / 4 - 1)
        )
    }
}

extension VoIPMetricsReportBlock: CustomStringConvertible {
    public var description: String {
        "\(self.ssrc) \(self.lossRate) \(self.discardRate) \(self.burstDensity) "
            + "\(self.gapDensity) \(self.burstDuration) \(self.gapDuration) \(self.roundTripDelay) "
            + "\(self.endSystemDelay) \(self.signalLevel) \(self.noiseLevel) \(self.rerl) \(self.gmin) "
            + "\(self.rfactor) \(self.extRfactor) \(self.mosLq) \(self.mosCq) \(self.rxConfig) "
            + "\(self.reserved) \(self.jbNominal) \(self.jbMaximum) \(self.jbAbsMax)"
    }
}

extension VoIPMetricsReportBlock: Packet {
    public func header() -> Header {
        Header()
    }

    /// destination_ssrc returns an array of ssrc values that this report block refers to.
    public func destinationSsrc() -> [UInt32] {
        [self.ssrc]
    }

    public func rawSize() -> Int {
        xrHeaderLength + Int(vmReportBlockLength)
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension VoIPMetricsReportBlock: MarshalSize {
    public func marshalSize() -> Int {
        self.rawSize()
    }
}

extension VoIPMetricsReportBlock: Marshal {
    /// marshal_to encodes the VoIPMetricsReportBlock in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let h = self.xrHeader()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.ssrc)
        buf.writeInteger(self.lossRate)
        buf.writeInteger(self.discardRate)
        buf.writeInteger(self.burstDensity)
        buf.writeInteger(self.gapDensity)
        buf.writeInteger(self.burstDuration)
        buf.writeInteger(self.gapDuration)
        buf.writeInteger(self.roundTripDelay)
        buf.writeInteger(self.endSystemDelay)
        buf.writeInteger(self.signalLevel)
        buf.writeInteger(self.noiseLevel)
        buf.writeInteger(self.rerl)
        buf.writeInteger(self.gmin)
        buf.writeInteger(self.rfactor)
        buf.writeInteger(self.extRfactor)
        buf.writeInteger(self.mosLq)
        buf.writeInteger(self.mosCq)
        buf.writeInteger(self.rxConfig)
        buf.writeInteger(self.reserved)
        buf.writeInteger(self.jbNominal)
        buf.writeInteger(self.jbMaximum)
        buf.writeInteger(self.jbAbsMax)

        return self.marshalSize()
    }
}

extension VoIPMetricsReportBlock: Unmarshal {
    /// Unmarshal decodes the VoIPMetricsReportBlock from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < xrHeaderLength {
            throw RtcpError.errPacketTooShort
        }

        let (xrHeader, xrHeaderLen) = try XRHeader.unmarshal(buf)
        let blockLength = xrHeader.blockLength * 4

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: xrHeaderLen)

        if blockLength != vmReportBlockLength || reader.readableBytes < Int(blockLength) {
            throw RtcpError.errPacketTooShort
        }

        guard let ssrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let lossRate: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let discardRate: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let burstDensity: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let gapDensity: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let burstDuration: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let gapDuration: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let roundTripDelay: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let endSystemDelay: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let signalLevel: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let noiseLevel: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let rerl: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let gmin: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let rfactor: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let extRfactor: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let mosLq: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let mosCq: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let rxConfig: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let reserved: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let jbNominal: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let jbMaximum: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let jbAbsMax: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        return (
            VoIPMetricsReportBlock(
                ssrc: ssrc,
                lossRate: lossRate,
                discardRate: discardRate,
                burstDensity: burstDensity,
                gapDensity: gapDensity,
                burstDuration: burstDuration,
                gapDuration: gapDuration,
                roundTripDelay: roundTripDelay,
                endSystemDelay: endSystemDelay,
                signalLevel: signalLevel,
                noiseLevel: noiseLevel,
                rerl: rerl,
                gmin: gmin,
                rfactor: rfactor,
                extRfactor: extRfactor,
                mosLq: mosLq,
                mosCq: mosCq,
                rxConfig: rxConfig,
                reserved: reserved,
                jbNominal: jbNominal,
                jbMaximum: jbMaximum,
                jbAbsMax: jbAbsMax
            ), reader.readerIndex - readerStartIndex
        )
    }
}
