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
public protocol Packet: Marshal, Unmarshal {
    func header() -> Header
    func destinationSsrc() -> [UInt32]
    func rawSize() -> Int
}

/// marshal takes an array of Packets and serializes them to a single buffer
public func marshal(packets: inout [Packet]) throws -> ByteBuffer {
    var out = ByteBuffer()
    for p in packets {
        let _ = try p.marshalTo(&out)
    }
    return out
}

/*
/// Unmarshal takes an entire udp datagram (which may consist of multiple RTCP packets) and
/// returns the unmarshaled packets it contains.
///
/// If this is a reduced-size RTCP packet a feedback packet (Goodbye, SliceLossIndication, etc)
/// will be returned. Otherwise, the underlying type of the returned packet will be
/// CompoundPacket.
pub fn unmarshal<B>(raw_data: &mut B) -> Result<Vec<Box<dyn Packet>>>
where
    B: Buf,
{
    let mut packets = vec![];

    while raw_data.has_remaining() {
        let p = unmarshaller(raw_data)?;
        packets.push(p);
    }

    match packets.len() {
        // Empty Packet
        0 => Err(Error::InvalidHeader),

        // Multiple Packet
        _ => Ok(packets),
    }
}

/// unmarshaller is a factory which pulls the first RTCP packet from a bytestream,
/// and returns it's parsed representation, and the amount of data that was processed.
pub(crate) fn unmarshaller<B>(raw_data: &mut B) -> Result<Box<dyn Packet>>
where
    B: Buf,
{
    let h = Header::unmarshal(raw_data)?;

    let length = (h.length as usize) * 4;
    if length > raw_data.remaining() {
        return Err(Error::PacketTooShort);
    }

    let mut in_packet = h.marshal()?.chain(raw_data.take(length));

    let p: Box<dyn Packet> = match h.packet_type {
        PacketType::SenderReport => Box::new(SenderReport::unmarshal(&mut in_packet)?),
        PacketType::ReceiverReport => Box::new(ReceiverReport::unmarshal(&mut in_packet)?),
        PacketType::SourceDescription => Box::new(SourceDescription::unmarshal(&mut in_packet)?),
        PacketType::Goodbye => Box::new(Goodbye::unmarshal(&mut in_packet)?),

        PacketType::TransportSpecificFeedback => match h.count {
            FORMAT_TLN => Box::new(TransportLayerNack::unmarshal(&mut in_packet)?),
            FORMAT_RRR => Box::new(RapidResynchronizationRequest::unmarshal(&mut in_packet)?),
            FORMAT_TCC => Box::new(TransportLayerCc::unmarshal(&mut in_packet)?),
            _ => Box::new(RawPacket::unmarshal(&mut in_packet)?),
        },
        PacketType::PayloadSpecificFeedback => match h.count {
            FORMAT_PLI => Box::new(PictureLossIndication::unmarshal(&mut in_packet)?),
            FORMAT_SLI => Box::new(SliceLossIndication::unmarshal(&mut in_packet)?),
            FORMAT_REMB => Box::new(ReceiverEstimatedMaximumBitrate::unmarshal(&mut in_packet)?),
            FORMAT_FIR => Box::new(FullIntraRequest::unmarshal(&mut in_packet)?),
            _ => Box::new(RawPacket::unmarshal(&mut in_packet)?),
        },
        PacketType::ExtendedReport => Box::new(ExtendedReport::unmarshal(&mut in_packet)?),
        _ => Box::new(RawPacket::unmarshal(&mut in_packet)?),
    };

    Ok(p)
}
*/
