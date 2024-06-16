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

/// A CompoundPacket is a collection of RTCP packets transmitted as a single packet with
/// the underlying protocol (for example UDP).
///
/// To maximize the resolution of receiption statistics, the first Packet in a CompoundPacket
/// must always be either a SenderReport or a ReceiverReport.  This is true even if no data
/// has been sent or received, in which case an empty ReceiverReport must be sent, and even
/// if the only other RTCP packet in the compound packet is a Goodbye.
///
/// Next, a SourceDescription containing a CNAME item must be included in each CompoundPacket
/// to identify the source and to begin associating media for purposes such as lip-sync.
///
/// Other RTCP packet types may follow in any order. Packet types may appear more than once.
public struct CompoundPacket {
    public var packets: [Packet]

    /// Validate returns an error if this is not an RFC-compliant CompoundPacket.
    public func validate() throws {
        if self.packets.isEmpty {
            throw RtcpError.errEmptyCompound
        }

        // SenderReport and ReceiverReport are the only types that
        // are allowed to be the first packet in a compound datagram
        if !(self.packets[0] is SenderReport || self.packets[0] is ReceiverReport) {
            throw RtcpError.errBadFirstPacket
        }

        for i in 1..<self.packets.count {
            // If the number of RecetpionReports exceeds 31 additional ReceiverReports
            // can be included here.
            if self.packets[i] is ReceiverReport {
                continue
                // A SourceDescription containing a CNAME must be included in every
                // CompoundPacket.
            } else if let e = self.packets[i] as? SourceDescription {
                var hasCname = false
                for c in e.chunks {
                    for it in c.items {
                        if it.sdesType == SdesType.sdesCname {
                            hasCname = true
                        }
                    }
                }

                if !hasCname {
                    throw RtcpError.errMissingCname
                }
                return
                // Other packets are not permitted before the CNAME
            } else {
                throw RtcpError.errPacketBeforeCname
            }
        }

        // CNAME never reached
        throw RtcpError.errMissingCname
    }

    /// CNAME returns the CNAME that *must* be present in every CompoundPacket
    public func cname() throws -> ByteBuffer {
        if self.packets.isEmpty {
            throw RtcpError.errEmptyCompound
        }

        for i in 1..<self.packets.count {
            if let sdes = self.packets[i] as? SourceDescription {
                for c in sdes.chunks {
                    for it in c.items {
                        if it.sdesType == SdesType.sdesCname {
                            return it.text.slice()
                        }
                    }
                }
            } else if !(self.packets[i] is ReceiverReport) {
                throw RtcpError.errPacketBeforeCname
            }
        }

        throw RtcpError.errMissingCname
    }
}

extension CompoundPacket: CustomStringConvertible {
    public var description: String {
        "\(self)"
    }
}

extension CompoundPacket: Packet {
    public func header() -> Header {
        Header()
    }

    /// destination_ssrc returns the synchronization sources associated with this
    /// CompoundPacket's reception report.
    public func destinationSsrc() -> [UInt32] {
        if self.packets.isEmpty {
            return []
        } else {
            return self.packets[0].destinationSsrc()
        }
    }

    public func rawSize() -> Int {
        var l = 0
        for packet in self.packets {
            l += packet.marshalSize()
        }
        return l
    }
}

extension CompoundPacket: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension CompoundPacket: Marshal {
    /// Marshal encodes the CompoundPacket as binary.
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        try self.validate()

        for packet in self.packets {
            let _ = try packet.marshalTo(&buf)
        }

        return self.marshalSize()
    }
}

extension CompoundPacket: Unmarshal {
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        var packets: [Packet] = []

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex

        while reader.readableBytes > 0 {
            let (p, l) = try unmarshaller(reader)
            reader.moveReaderIndex(forwardBy: l)
            packets.append(p)
        }

        let c = CompoundPacket(packets: packets)
        try c.validate()

        return (c, reader.readerIndex - readerStartIndex)
    }
}
