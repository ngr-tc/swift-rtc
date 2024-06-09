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

/// Payloader payloads a byte array for use as rtp.Packet payloads
public protocol Payloader {
    mutating func payload(mtu: Int, buf: inout ByteBuffer) throws -> [ByteBuffer]
}

/// Packetizer packetizes a payload
public protocol Packetizer {
    mutating func enableAbsSendTime(value: UInt8)
    mutating func packetize(payload: inout ByteBuffer, samples: UInt32) throws -> [Packet]
    mutating func skipSamples(skippedSamples: UInt32)
}

/// Depacketizer depacketizes a RTP payload, removing any RTP specific data from the payload
public protocol Depacketizer {
    mutating func depacketize(buf: inout ByteBuffer) throws -> [ByteBuffer]

    /// Checks if the packet is at the beginning of a partition.  This
    /// should return false if the result could not be determined, in
    /// which case the caller will detect timestamp discontinuities.
    func isPartitionHead(payload: inout ByteBuffer) -> Bool

    /// Checks if the packet is at the end of a partition.  This should
    /// return false if the result could not be determined.
    func isPartitionTail(marker: Bool, payload: inout ByteBuffer) -> Bool
}
/*
//TODO: SystemTime vs Instant?
// non-monotonic clock vs monotonically non-decreasing clock
/// FnTimeGen provides current SystemTime
pub type FnTimeGen = Arc<dyn (Fn() -> SystemTime)>;

#[derive(Clone)]
pub(crate) struct PacketizerImpl {
    pub(crate) mtu: usize,
    pub(crate) payload_type: u8,
    pub(crate) ssrc: u32,
    pub(crate) payloader: Box<dyn Payloader>,
    pub(crate) sequencer: Box<dyn Sequencer>,
    pub(crate) timestamp: u32,
    pub(crate) clock_rate: u32,
    pub(crate) abs_send_time: u8, //http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
    pub(crate) time_gen: Option<FnTimeGen>,
}

impl fmt::Debug for PacketizerImpl {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PacketizerImpl")
            .field("mtu", &self.mtu)
            .field("payload_type", &self.payload_type)
            .field("ssrc", &self.ssrc)
            .field("timestamp", &self.timestamp)
            .field("clock_rate", &self.clock_rate)
            .field("abs_send_time", &self.abs_send_time)
            .finish()
    }
}

pub fn new_packetizer(
    mtu: usize,
    payload_type: u8,
    ssrc: u32,
    payloader: Box<dyn Payloader>,
    sequencer: Box<dyn Sequencer>,
    clock_rate: u32,
) -> impl Packetizer {
    PacketizerImpl {
        mtu,
        payload_type,
        ssrc,
        payloader,
        sequencer,
        timestamp: rand::random::<u32>(),
        clock_rate,
        abs_send_time: 0,
        time_gen: None,
    }
}

impl Packetizer for PacketizerImpl {
    fn enable_abs_send_time(&mut self, value: u8) {
        self.abs_send_time = value
    }

    fn packetize(&mut self, payload: &Bytes, samples: u32) -> Result<Vec<Packet>> {
        let payloads = self.payloader.payload(self.mtu - 12, payload)?;
        let payloads_len = payloads.len();
        let mut packets = Vec::with_capacity(payloads_len);
        for (i, payload) in payloads.into_iter().enumerate() {
            packets.push(Packet {
                header: Header {
                    version: 2,
                    padding: false,
                    extension: false,
                    marker: i == payloads_len - 1,
                    payload_type: self.payload_type,
                    sequence_number: self.sequencer.next_sequence_number(),
                    timestamp: self.timestamp, //TODO: Figure out how to do timestamps
                    ssrc: self.ssrc,
                    ..Default::default()
                },
                payload,
            });
        }

        self.timestamp = self.timestamp.wrapping_add(samples);

        if payloads_len != 0 && self.abs_send_time != 0 {
            let st = if let Some(fn_time_gen) = &self.time_gen {
                fn_time_gen()
            } else {
                SystemTime::now()
            };
            let send_time = AbsSendTimeExtension::new(st);
            //apply http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
            let mut raw = BytesMut::with_capacity(send_time.marshal_size());
            raw.resize(send_time.marshal_size(), 0);
            let _ = send_time.marshal_to(&mut raw)?;
            packets[payloads_len - 1]
                .header
                .set_extension(self.abs_send_time, raw.freeze())?;
        }

        Ok(packets)
    }

    /// skip_samples causes a gap in sample count between Packetize requests so the
    /// RTP payloads produced have a gap in timestamps
    fn skip_samples(&mut self, skipped_samples: u32) {
        self.timestamp = self.timestamp.wrapping_add(skipped_samples);
    }

    fn clone_to(&self) -> Box<dyn Packetizer> {
        Box::new(self.clone())
    }
}
*/
