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

/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatSli: UInt8 = 2
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatPli: UInt8 = 1
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatFir: UInt8 = 4
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatTln: UInt8 = 1
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatRrr: UInt8 = 5
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatRemb: UInt8 = 15
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here.
/// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-5
public let formatTcc: UInt8 = 15

/// PacketType specifies the type of an RTCP packet
/// RTCP packet types registered with IANA. See: https://www.iana.org/assignments/rtp-parameters/rtp-parameters.xhtml#rtp-parameters-4
public enum PacketType: UInt8, Equatable {
    case unsupported = 0
    case senderReport = 200  // RFC 3550, 6.4.1
    case receiverReport = 201  // RFC 3550, 6.4.2
    case sourceDescription = 202  // RFC 3550, 6.5
    case goodbye = 203  // RFC 3550, 6.6
    case applicationDefined = 204  // RFC 3550, 6.7 (unimplemented)
    case transportSpecificFeedback = 205  // RFC 4585, 6051
    case payloadSpecificFeedback = 206  // RFC 4585, 6.3
    case extendedReport = 207  // RFC 3611

    public init(rawValue: UInt8) {
        switch rawValue {
        case 200:
            self = PacketType.senderReport  // RFC 3550, 6.4.1
        case 201:
            self = PacketType.receiverReport  // RFC 3550, 6.4.2
        case 202:
            self = PacketType.sourceDescription  // RFC 3550, 6.5
        case 203:
            self = PacketType.goodbye  // RFC 3550, 6.6
        case 204:
            self = PacketType.applicationDefined  // RFC 3550, 6.7 (unimplemented)
        case 205:
            self = PacketType.transportSpecificFeedback  // RFC 4585, 6051
        case 206:
            self = PacketType.payloadSpecificFeedback  // RFC 4585, 6.3
        case 207:
            self = PacketType.extendedReport  // RFC 3611
        default:
            self = PacketType.unsupported
        }
    }
}

extension PacketType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unsupported:
            return "Unsupported"
        case .senderReport:
            return "SR"
        case .receiverReport:
            return "RR"
        case .sourceDescription:
            return "SDES"
        case .goodbye:
            return "BYE"
        case .applicationDefined:
            return "APP"
        case .transportSpecificFeedback:
            return "TSFB"
        case .payloadSpecificFeedback:
            return "PSFB"
        case .extendedReport:
            return "XR"
        }
    }
}

public let rtpVersion: UInt8 = 2
public let versionShift: UInt8 = 6
public let versionMask: UInt8 = 0x3
public let paddingShift: UInt8 = 5
public let paddingMask: UInt8 = 0x1
public let countShift: UInt8 = 0
public let countMask: UInt8 = 0x1f

public let headerLength: Int = 4
public let countMax: Int = (1 << 5) - 1
public let ssrcLength: Int = 4
//public let sdesMaxOctetCount: Int = (1 << 8) - 1

/// A Header is the common header shared by all RTCP packets
public struct Header: Equatable {
    /// If the padding bit is set, this individual RTCP packet contains
    /// some additional padding octets at the end which are not part of
    /// the control information but are included in the length field.
    public var padding: Bool
    /// The number of reception reports, sources contained or FMT in this packet (depending on the Type)
    public var count: UInt8
    /// The RTCP packet type for this packet
    public var packetType: PacketType
    /// The length of this RTCP packet in 32-bit words minus one,
    /// including the header and any padding.
    public var length: UInt16

    public init() {
        self.padding = false
        self.count = 0
        self.packetType = PacketType.unsupported
        self.length = 0
    }

    public init(padding: Bool, count: UInt8, packetType: PacketType, length: UInt16) {
        self.padding = padding
        self.count = count
        self.packetType = packetType
        self.length = length
    }
}

extension Header: Unmarshal {
    /// Unmarshal decodes the Header from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < headerLength {
            throw RtcpError.errPacketTooShort
        }

        /*
         *  0                   1                   2                   3
         *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |V=2|P|    RC   |      PT       |             length            |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        guard let b0: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        let version = (b0 >> versionShift) & versionMask
        if version != rtpVersion {
            throw RtcpError.errBadVersion
        }

        let padding = ((b0 >> paddingShift) & paddingMask) > 0
        let count = (b0 >> countShift) & countMask
        guard let b1: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        let packetType = PacketType(rawValue: b1)
        guard let length: UInt16 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        return (
            Header(padding: padding, count: count, packetType: packetType, length: length),
            reader.readerIndex - readerStartIndex
        )
    }
}

/// Marshal encodes the Header in binary
extension Header: MarshalSize {
    public func marshalSize() -> Int {
        return headerLength
    }
}

extension Header: Marshal {
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        if self.count > 31 {
            throw RtcpError.errInvalidHeader
        }
        /*
         *  0                   1                   2                   3
         *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |V=2|P|    RC   |   PT=SR=200   |             length            |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        let b0: UInt8 =
            (rtpVersion << versionShift)
            | (UInt8(self.padding ? 1 : 0) << paddingShift)
            | (self.count << countShift)

        buf.writeInteger(b0)
        buf.writeInteger(self.packetType.rawValue)
        buf.writeInteger(self.length)

        return headerLength
    }
}
