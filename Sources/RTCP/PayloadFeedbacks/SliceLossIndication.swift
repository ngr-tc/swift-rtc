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

let sliLength: Int = 2
let sliOffset: Int = 8

/// SLIEntry represents a single entry to the SLI packet's
/// list of lost slices.
public struct SliEntry: Equatable {
    /// ID of first lost slice
    public var first: UInt16
    /// Number of lost slices
    public var number: UInt16
    /// ID of related picture
    public var picture: UInt8
}

extension SliEntry: CustomStringConvertible {
    public var description: String {
        "(\(self.first) \(self.number) \(self.picture))"
    }
}

/// The SliceLossIndication packet informs the encoder about the loss of a picture slice
public struct SliceLossIndication: Equatable {
    /// SSRC of sender
    public var senderSsrc: UInt32
    /// SSRC of the media source
    public var mediaSsrc: UInt32

    public var sliEntries: [SliEntry]

    public init() {
        self.senderSsrc = 0
        self.mediaSsrc = 0
        self.sliEntries = []
    }

    public init(senderSsrc: UInt32, mediaSsrc: UInt32, sliEntries: [SliEntry]) {
        self.senderSsrc = senderSsrc
        self.mediaSsrc = mediaSsrc
        self.sliEntries = sliEntries
    }
}

extension SliceLossIndication: CustomStringConvertible {
    public var description: String {
        String(
            format: "SliceLossIndication %x %x \(self.sliEntries)",
            self.senderSsrc, self.mediaSsrc
        )
    }
}

extension SliceLossIndication: Packet {
    /// Header returns the Header associated with this packet.
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: formatSli,
            packetType: PacketType.transportSpecificFeedback,
            length: UInt16((self.marshalSize() / 4) - 1)
        )
    }

    /// destination_ssrc returns an array of SSRC values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        [self.mediaSsrc]
    }

    public func rawSize() -> Int {
        headerLength + sliOffset + self.sliEntries.count * 4
    }
}

extension SliceLossIndication: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension SliceLossIndication: Marshal {
    /// Marshal encodes the SliceLossIndication in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        if UInt8(self.sliEntries.count + sliLength) > UInt8.max {
            throw RtcpError.errTooManyReports
        }

        let h = self.header()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.senderSsrc)
        buf.writeInteger(self.mediaSsrc)

        for s in self.sliEntries {
            let sli: UInt32 =
                ((UInt32(s.first) & 0x1FFF) << 19)
                | ((UInt32(s.number) & 0x1FFF) << 6)
                | (UInt32(s.picture) & 0x3F)

            buf.writeInteger(sli)
        }

        if h.padding {
            putPadding(&buf, self.rawSize())
        }

        return self.marshalSize()
    }
}

extension SliceLossIndication: Unmarshal {
    /// Unmarshal decodes the SliceLossIndication from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < (headerLength + ssrcLength) {
            throw RtcpError.errPacketTooShort
        }

        let (h, headerLen) = try Header.unmarshal(buf)

        if rawPacketLen < (headerLength + Int(4 * h.length)) {
            throw RtcpError.errPacketTooShort
        }

        if h.packetType != PacketType.transportSpecificFeedback || h.count != formatSli {
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

        var i = headerLength + sliOffset
        var sliEntries: [SliEntry] = []
        while i < headerLength + Int(h.length * 4) {
            guard let sli: UInt32 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            sliEntries.append(
                SliEntry(
                    first: UInt16((sli >> 19) & 0x1FFF),
                    number: UInt16((sli >> 6) & 0x1FFF),
                    picture: UInt8(sli & 0x3F)
                ))

            i += 4
        }

        /*h.padding &&*/
        if reader.readableBytes > 0 {
            reader.moveReaderIndex(forwardBy: reader.readableBytes)
        }

        return (
            SliceLossIndication(
                senderSsrc: senderSsrc,
                mediaSsrc: mediaSsrc,
                sliEntries: sliEntries
            ), reader.readerIndex - readerStartIndex
        )
    }
}
