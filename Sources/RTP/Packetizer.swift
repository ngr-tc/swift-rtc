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
    mutating func depacketize(buf: inout ByteBuffer) throws -> ByteBuffer

    /// Checks if the packet is at the beginning of a partition.  This
    /// should return false if the result could not be determined, in
    /// which case the caller will detect timestamp discontinuities.
    func isPartitionHead(payload: inout ByteBuffer) -> Bool

    /// Checks if the packet is at the end of a partition.  This should
    /// return false if the result could not be determined.
    func isPartitionTail(marker: Bool, payload: inout ByteBuffer) -> Bool
}

/// FnTimeGen provides current NIODeadline
public typealias FnTimeGen = () -> NIODeadline

public func newPacketizer(
    mtu: Int,
    payloadType: UInt8,
    ssrc: UInt32,
    payloader: Payloader,
    sequencer: Sequencer,
    clockRate: UInt32
) -> Packetizer {
    return PacketizerImpl(
        mtu: mtu,
        payloadType: payloadType,
        ssrc: ssrc,
        payloader: payloader,
        sequencer: sequencer,
        timestamp: UInt32.random(in: UInt32.min...UInt32.max),
        clockRate: clockRate,
        absSendTime: 0,
        timeGen: nil
    )
}

struct PacketizerImpl {
    var mtu: Int
    var payloadType: UInt8
    var ssrc: UInt32
    var payloader: Payloader
    var sequencer: Sequencer
    var timestamp: UInt32
    var clockRate: UInt32
    var absSendTime: UInt8  //http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
    var timeGen: FnTimeGen?
}

extension PacketizerImpl: Packetizer {
    public mutating func enableAbsSendTime(value: UInt8) {
        self.absSendTime = value
    }

    public mutating func packetize(payload: inout ByteBuffer, samples: UInt32) throws -> [Packet] {
        let payloads = try self.payloader.payload(mtu: self.mtu - 12, buf: &payload)
        let payloadsLen = payloads.count
        var packets: [Packet] = []
        for (i, payload) in payloads.enumerated() {
            packets.append(
                Packet(
                    header: Header(
                        version: 2,
                        padding: false,
                        ext: false,
                        marker: i == payloadsLen - 1,
                        payloadType: self.payloadType,
                        sequenceNumber: self.sequencer.nextSequenceNumber(),
                        timestamp: self.timestamp,  //TODO: Figure out how to do timestamps
                        ssrc: self.ssrc,
                        csrcs: [],
                        extensionProfile: 0,
                        extensions: []
                    ),
                    payload: payload
                ))
        }

        self.timestamp = self.timestamp &+ samples

        if payloadsLen != 0 && self.absSendTime != 0 {
            var st = NIODeadline.now()
            if let fnTimeGen = self.timeGen {
                st = fnTimeGen()
            }
            let sendTime = AbsSendTimeExtension(sendTime: st)
            //apply http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
            var raw = ByteBuffer()
            let _ = try sendTime.marshalTo(&raw)
            try packets[payloadsLen - 1]
                .header
                .setExtension(id: self.absSendTime, payload: raw)
        }

        return packets
    }

    /// skip_samples causes a gap in sample count between Packetize requests so the
    /// RTP payloads produced have a gap in timestamps
    public mutating func skipSamples(skippedSamples: UInt32) {
        self.timestamp = self.timestamp &+ skippedSamples
    }
}
