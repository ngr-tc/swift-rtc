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

/// Packet represents an RTCP packet, a protocol used for out-of-band statistics and
/// control information for an RTP session
public protocol Packet: Marshal, Unmarshal, CustomStringConvertible {
    func header() -> Header
    func destinationSsrc() -> [UInt32]
    func rawSize() -> Int
    func equal(other: Packet) -> Bool
}

/// marshal takes an array of Packets and serializes them to a single buffer
public func marshal(packets: inout [Packet]) throws -> ByteBuffer {
    var out = ByteBuffer()
    for p in packets {
        let _ = try p.marshalTo(&out)
    }
    return out
}

/// Unmarshal takes an entire udp datagram (which may consist of multiple RTCP packets) and
/// returns the unmarshaled packets it contains.
///
/// If this is a reduced-size RTCP packet a feedback packet (Goodbye, SliceLossIndication, etc)
/// will be returned. Otherwise, the underlying type of the returned packet will be
/// CompoundPacket.
public func unmarshal(_ buf: ByteBuffer) throws -> [Packet] {
    var packets: [Packet] = []

    var reader = buf.slice()
    while reader.readableBytes > 0 {
        let (p, l) = try unmarshaller(reader)
        reader.moveReaderIndex(forwardBy: l)
        packets.append(p)
    }

    if packets.isEmpty {
        throw RtcpError.errInvalidHeader
    }

    return packets
}

/// unmarshaller is a factory which pulls the first RTCP packet from a bytestream,
/// and returns it's parsed representation, and the amount of data that was processed.
func unmarshaller(_ buf: ByteBuffer) throws -> (Packet, Int) {
    let (h, headerLen) = try Header.unmarshal(buf)
    let length = Int(h.length) * 4

    var reader = buf.slice()
    guard let inPacket = reader.readSlice(length: headerLen + length) else {
        throw RtcpError.errPacketTooShort
    }

    let packet: Packet
    switch h.packetType {
    case PacketType.senderReport:
        (packet, _) = try SenderReport.unmarshal(inPacket)
    case PacketType.receiverReport:
        (packet, _) = try ReceiverReport.unmarshal(inPacket)
    case PacketType.sourceDescription:
        (packet, _) = try SourceDescription.unmarshal(inPacket)
    case PacketType.goodbye:
        (packet, _) = try Goodbye.unmarshal(inPacket)

    case PacketType.transportSpecificFeedback:
        switch h.count {
        case formatTln:
            (packet, _) = try TransportLayerNack.unmarshal(inPacket)
        case formatRrr:
            (packet, _) = try RapidResynchronizationRequest.unmarshal(inPacket)
        case formatTcc:
            (packet, _) = try TransportLayerCc.unmarshal(inPacket)
        default:
            (packet, _) = try RawPacket.unmarshal(inPacket)
        }
    case PacketType.payloadSpecificFeedback:
        switch h.count {
        case formatPli:
            (packet, _) = try PictureLossIndication.unmarshal(inPacket)
        case formatSli:
            (packet, _) = try SliceLossIndication.unmarshal(inPacket)
        case formatRemb:
            (packet, _) = try ReceiverEstimatedMaximumBitrate.unmarshal(inPacket)
        case formatFir:
            (packet, _) = try FullIntraRequest.unmarshal(inPacket)
        default:
            (packet, _) = try RawPacket.unmarshal(inPacket)
        }
    case PacketType.extendedReport:
        (packet, _) = try ExtendedReport.unmarshal(inPacket)
    default:
        (packet, _) = try RawPacket.unmarshal(inPacket)
    }

    return (packet, headerLen + length)
}
