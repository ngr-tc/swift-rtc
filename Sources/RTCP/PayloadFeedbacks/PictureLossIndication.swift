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

let pliLength: Int = 2

/// The PictureLossIndication packet informs the encoder about the loss of an undefined amount of coded video data belonging to one or more pictures
public struct PictureLossIndication: Equatable {
    /// SSRC of sender
    public var senderSsrc: UInt32
    /// SSRC where the loss was experienced
    public var mediaSsrc: UInt32

    public init() {
        self.senderSsrc = 0
        self.mediaSsrc = 0
    }

    public init(senderSsrc: UInt32, mediaSsrc: UInt32) {
        self.senderSsrc = senderSsrc
        self.mediaSsrc = mediaSsrc
    }
}

extension PictureLossIndication: CustomStringConvertible {
    public var description: String {
        String(
            format: "PictureLossIndication %x %x",
            self.senderSsrc, self.mediaSsrc
        )
    }
}

extension PictureLossIndication: Packet {
    /// Header returns the Header associated with this packet.
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: formatPli,
            packetType: PacketType.payloadSpecificFeedback,
            length: UInt16((self.marshalSize() / 4) - 1)
        )
    }

    /// destination_ssrc returns an array of SSRC values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        [self.mediaSsrc]
    }

    public func rawSize() -> Int {
        headerLength + ssrcLength * 2
    }
}

extension PictureLossIndication: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension PictureLossIndication: Marshal {
    /// Marshal encodes the PictureLossIndication in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        /*
         * PLI does not require parameters.  Therefore, the length field MUST be
         * 2, and there MUST NOT be any Feedback Control Information.
         *
         * The semantics of this FB message is independent of the payload type.
         */
        let h = self.header()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.senderSsrc)
        buf.writeInteger(self.mediaSsrc)

        if h.padding {
            putPadding(&buf, self.rawSize())
        }

        return self.marshalSize()
    }
}

extension PictureLossIndication: Unmarshal {
    /// Unmarshal decodes the PictureLossIndication from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < (headerLength + (ssrcLength * 2)) {
            throw RtcpError.errPacketTooShort
        }

        let (h, headerLen) = try Header.unmarshal(buf)
        if h.packetType != PacketType.payloadSpecificFeedback || h.count != formatPli {
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

        /*h.padding &&*/
        if reader.readableBytes > 0 {
            reader.moveReaderIndex(forwardBy: reader.readableBytes)
        }

        return (
            PictureLossIndication(
                senderSsrc: senderSsrc,
                mediaSsrc: mediaSsrc
            ), reader.readerIndex - readerStartIndex
        )
    }
}
