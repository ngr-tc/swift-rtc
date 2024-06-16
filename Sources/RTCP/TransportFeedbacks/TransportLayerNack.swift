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

/// PacketBitmap shouldn't be used like a normal integral,
/// so it's type is masked here. Access it with PacketList().
public typealias PacketBitmap = UInt16

public struct NackIterator {
    var packetId: UInt16
    var bitfield: PacketBitmap
    var hasYieldedPacketId: Bool
}

extension NackIterator: IteratorProtocol {
    public typealias Element = UInt16

    public mutating func next() -> Self.Element? {
        if !self.hasYieldedPacketId {
            self.hasYieldedPacketId = true

            return self.packetId
        } else {
            var i: UInt16 = 0

            while self.bitfield != 0 {
                if (self.bitfield & (1 << i)) != 0 {
                    self.bitfield &= ~(1 << i)

                    return self.packetId &+ (i + 1)
                }

                i += 1
            }

            return nil
        }
    }
}

/// NackPair is a wire-representation of a collection of
/// Lost RTP packets
public struct NackPair: Equatable {
    /// ID of lost packets
    public var packetId: UInt16
    /// Bitmask of following lost packets
    public var lostPackets: PacketBitmap

    public init(packetId: UInt16, lostPackets: PacketBitmap = 0) {
        self.packetId = packetId
        self.lostPackets = lostPackets
    }

    /// PacketList returns a list of Nack'd packets that's referenced by a NackPair
    public func packetList() -> [UInt16] {
        var list: [UInt16] = []
        var iter = self.makeIterator()
        while let e = iter.next() {
            list.append(e)
        }
        return list
    }

    public func range(f: (UInt16) -> Bool) {
        var iter = self.makeIterator()
        while let packetId = iter.next() {
            if !f(packetId) {
                return
            }
        }
    }

    public func makeIterator() -> NackIterator {
        NackIterator(
            packetId: self.packetId,
            bitfield: self.lostPackets,
            hasYieldedPacketId: false
        )
    }
}

let tlnLength: Int = 2
let nackOffset: Int = 8

// The TransportLayerNack packet informs the encoder about the loss of a transport packet
// IETF RFC 4585, Section 6.2.1
// https://tools.ietf.org/html/rfc4585#section-6.2.1
public struct TransportLayerNack: Equatable {
    /// SSRC of sender
    public var senderSsrc: UInt32
    /// SSRC of the media source
    public var mediaSsrc: UInt32

    public var nacks: [NackPair]

    public init() {
        self.senderSsrc = 0
        self.mediaSsrc = 0
        self.nacks = []
    }

    public init(senderSsrc: UInt32, mediaSsrc: UInt32, nacks: [NackPair]) {
        self.senderSsrc = senderSsrc
        self.mediaSsrc = mediaSsrc
        self.nacks = nacks
    }
}

extension TransportLayerNack: CustomStringConvertible {
    public var description: String {
        var out = String(format: "TransportLayerNack from %x\n", self.senderSsrc)
        out += String(format: "\tMedia Ssrc %x\n", self.mediaSsrc)
        out += "\tID\tLostPackets\n"
        for nack in self.nacks {
            out += String(format: "\t%d\t%b\n", nack.packetId, nack.lostPackets)
        }
        return out
    }
}

extension TransportLayerNack: Packet {
    /// returns the Header associated with this packet.
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: formatTln,
            packetType: PacketType.transportSpecificFeedback,
            length: UInt16((self.marshalSize() / 4) - 1)
        )
    }

    /// destination_ssrc returns an array of SSRC values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        [self.mediaSsrc]
    }

    public func rawSize() -> Int {
        headerLength + nackOffset + self.nacks.count * 4
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension TransportLayerNack: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension TransportLayerNack: Marshal {
    /// Marshal encodes the packet in binary.
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        if self.nacks.count + tlnLength > UInt8.max {
            throw RtcpError.errTooManyReports
        }

        let h = self.header()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.senderSsrc)
        buf.writeInteger(self.mediaSsrc)

        for nack in self.nacks {
            buf.writeInteger(nack.packetId)
            buf.writeInteger(nack.lostPackets)
        }

        if h.padding {
            putPadding(&buf, self.rawSize())
        }

        return self.marshalSize()
    }
}

extension TransportLayerNack: Unmarshal {
    /// Unmarshal decodes the ReceptionReport from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < (headerLength + ssrcLength) {
            throw RtcpError.errPacketTooShort
        }

        let (h, headerLen) = try Header.unmarshal(buf)

        if rawPacketLen < (headerLength + Int(4 * h.length)) {
            throw RtcpError.errPacketTooShort
        }

        if h.packetType != PacketType.transportSpecificFeedback || h.count != formatTln {
            throw RtcpError.errWrongType
        }

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: headerLen)

        guard let senderSsrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let mediaSsrc: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        var nacks: [NackPair] = []
        for _ in 0..<(Int(h.length) - nackOffset / 4) {
            guard let packetId: UInt16 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            guard let lostPackets: UInt16 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            nacks.append(
                NackPair(
                    packetId: packetId,
                    lostPackets: lostPackets
                ))
        }

        /*h.padding &&*/
        if reader.readableBytes > 0 {
            reader.moveReaderIndex(forwardBy: reader.readableBytes)
        }

        return (
            TransportLayerNack(
                senderSsrc: senderSsrc,
                mediaSsrc: mediaSsrc,
                nacks: nacks
            ), reader.readerIndex - readerStartIndex
        )
    }
}

public func nackPairsFromSequenceNumbers(_ seqNos: inout [UInt16]) -> [NackPair] {
    if seqNos.isEmpty {
        return []
    }

    var nackPair = NackPair(packetId: seqNos[0])
    var pairs: [NackPair] = []

    for i in 1..<seqNos.count {
        let seq = seqNos[i]
        if seq == nackPair.packetId {
            continue
        }
        if seq <= nackPair.packetId || (seq >= 16 && seq - 16 > nackPair.packetId) {
            pairs.append(nackPair)
            nackPair = NackPair(packetId: seq)
            continue
        }

        // Subtraction here is safe because the above checks that seqnum > nack_pair.packet_id.
        nackPair.lostPackets |= 1 << (seq - nackPair.packetId - 1)
    }

    pairs.append(nackPair)

    return pairs
}
