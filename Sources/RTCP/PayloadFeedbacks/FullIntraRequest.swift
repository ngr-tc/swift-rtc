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

/// A FIREntry is a (ssrc, seqno) pair, as carried by FullIntraRequest.
public struct FirEntry: Equatable {
    public var ssrc: UInt32
    public var sequenceNumber: UInt8
}

/// The FullIntraRequest packet is used to reliably request an Intra frame
/// in a video stream.  See RFC 5104 Section 3.5.1.  This is not for loss
/// recovery, which should use PictureLossIndication (PLI) instead.
public struct FullIntraRequest: Equatable {
    public var senderSsrc: UInt32
    public var mediaSsrc: UInt32
    public var fir: [FirEntry]

    public init() {
        self.senderSsrc = 0
        self.mediaSsrc = 0
        self.fir = []
    }

    public init(senderSsrc: UInt32, mediaSsrc: UInt32, fir: [FirEntry]) {
        self.senderSsrc = senderSsrc
        self.mediaSsrc = mediaSsrc
        self.fir = fir
    }
}

let firOffset: Int = 8

extension FullIntraRequest: CustomStringConvertible {
    public var description: String {
        var out = "FullIntraRequest \(self.senderSsrc), \(self.mediaSsrc)"
        for e in self.fir {
            out += " (\(e.ssrc), \(e.sequenceNumber))"
        }
        return out
    }
}

extension FullIntraRequest: Packet {
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: formatFir,
            packetType: PacketType.payloadSpecificFeedback,
            length: UInt16((self.marshalSize() / 4) - 1)
        )
    }

    /// destination_ssrc returns an array of SSRC values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        self.fir.map { $0.ssrc }
    }

    public func rawSize() -> Int {
        headerLength + firOffset + self.fir.count * 8
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension FullIntraRequest: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension FullIntraRequest: Marshal {
    /// Marshal encodes the FullIntraRequest
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let h = self.header()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.senderSsrc)
        buf.writeInteger(self.mediaSsrc)

        for fir in self.fir {
            buf.writeInteger(fir.ssrc)
            buf.writeInteger(fir.sequenceNumber)
            buf.writeInteger(UInt8(0))
            buf.writeInteger(UInt16(0))
        }

        if h.padding {
            putPadding(&buf, self.rawSize())
        }

        return self.marshalSize()
    }
}

extension FullIntraRequest: Unmarshal {
    /// Unmarshal decodes the FullIntraRequest
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < (headerLength + ssrcLength) {
            throw RtcpError.errPacketTooShort
        }

        let (h, headerLen) = try Header.unmarshal(buf)

        if rawPacketLen < (headerLength + Int(4 * h.length)) {
            throw RtcpError.errPacketTooShort
        }

        if h.packetType != PacketType.payloadSpecificFeedback || h.count != formatFir {
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

        var i = headerLength + firOffset
        var fir: [FirEntry] = []
        while i < headerLength + Int(h.length * 4) {
            guard let ssrc: UInt32 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            guard let sequenceNumber: UInt8 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }

            fir.append(
                FirEntry(
                    ssrc: ssrc,
                    sequenceNumber: sequenceNumber
                ))

            guard let _: UInt8 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            guard let _: UInt16 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }

            i += 8
        }

        /*h.padding &&*/
        if reader.readableBytes > 0 {
            reader.moveReaderIndex(forwardBy: reader.readableBytes)
        }

        return (
            FullIntraRequest(
                senderSsrc: senderSsrc,
                mediaSsrc: mediaSsrc,
                fir: fir
            ), reader.readerIndex - readerStartIndex
        )
    }
}
