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

/// ReceiverEstimatedMaximumBitrate contains the receiver's estimated maximum bitrate.
/// see: https://tools.ietf.org/html/draft-alvestrand-rmcat-remb-03
public struct ReceiverEstimatedMaximumBitrate: Equatable {
    /// SSRC of sender
    public var senderSsrc: UInt32

    /// Estimated maximum bitrate
    public var bitrate: Float

    /// SSRC entries which this packet applies to
    public var ssrcs: [UInt32]
}

let rembOffset: Int = 16
let bitrateMax: Float = 2.417_842_4e24  //0x3FFFFp+63;
let mantissaMax: UInt32 = 0x7FFFFF
/// Keep a table of powers to units for fast conversion.
let bitUnits: [String] = ["b", "Kb", "Mb", "Gb", "Tb", "Pb", "Eb"]
let uniqueIdentifier: [Character] = ["R", "E", "M", "B"]

/// String prints the REMB packet in a human-readable format.
extension ReceiverEstimatedMaximumBitrate: CustomStringConvertible {
    public var description: String {
        // Do some unit conversions because b/s is far too difficult to read.
        var bitrate = self.bitrate
        var powers = 0

        // Keep dividing the bitrate until it's under 1000
        while bitrate >= 1000.0 && powers < bitUnits.count {
            bitrate /= 1000.0
            powers += 1
        }

        let unit = bitUnits[powers]

        return String(
            format: "ReceiverEstimatedMaximumBitrate %x %.2f %s/s",
            self.senderSsrc, bitrate, unit
        )
    }
}

extension ReceiverEstimatedMaximumBitrate: Packet {
    /// Header returns the Header associated with this packet.
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: formatRemb,
            packetType: PacketType.payloadSpecificFeedback,
            length: UInt16((self.marshalSize() / 4) - 1)
        )
    }

    /// destination_ssrc returns an array of SSRC values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        self.ssrcs
    }

    public func rawSize() -> Int {
        headerLength + rembOffset + self.ssrcs.count * 4
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension ReceiverEstimatedMaximumBitrate: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension ReceiverEstimatedMaximumBitrate: Marshal {
    /// Marshal serializes the packet and returns a byte slice.
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        /*
            0                   1                   2                   3
            0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |V=2|P| FMT=15  |   PT=206      |             length            |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |                  SSRC of packet sender                        |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |                  SSRC of media source                         |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |  Unique identifier 'R' 'E' 'M' 'B'                            |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |  Num SSRC     | BR Exp    |  BR Mantissa                      |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |   SSRC feedback                                               |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |  ...                                                          |
        */
        let h = self.header()
        let _ = try h.marshalTo(&buf)

        buf.writeInteger(self.senderSsrc)
        buf.writeInteger(UInt32(0))  // always zero

        buf.writeBytes(String(uniqueIdentifier).utf8.map { UInt8($0) })

        // Write the length of the ssrcs to follow at the end
        buf.writeInteger(UInt8(self.ssrcs.count))

        var exp = 0
        var bitrate = self.bitrate
        if bitrate >= bitrateMax {
            bitrate = bitrateMax
        }

        if bitrate < 0.0 {
            throw RtcpError.errInvalidBitrate
        }

        while bitrate >= Float(1 << 18) {
            bitrate /= 2.0
            exp += 1
        }

        if exp >= (1 << 6) {
            throw RtcpError.errInvalidBitrate
        }

        let mantissa = UInt32(bitrate)  //FIXME: floor?

        // We can't quite use the binary package because
        // a) it's a uint24 and b) the exponent is only 6-bits
        // Just trust me; this is big-endian encoding.
        buf.writeInteger(UInt8(exp << 2) | UInt8(mantissa >> 16))
        buf.writeInteger(UInt8((mantissa >> 8) & 0xFF))
        buf.writeInteger(UInt8(mantissa & 0xFF))

        // Write the SSRCs at the very end.
        for ssrc in self.ssrcs {
            buf.writeInteger(ssrc)
        }

        if h.padding {
            putPadding(&buf, self.rawSize())
        }

        return self.marshalSize()
    }
}

extension ReceiverEstimatedMaximumBitrate: Unmarshal {
    /// Unmarshal reads a REMB packet from the given byte slice.
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let rawPacketLen = buf.readableBytes
        // 20 bytes is the size of the packet with no SSRCs
        if rawPacketLen < 20 {
            throw RtcpError.errPacketTooShort
        }

        /*
            0                   1                   2                   3
            0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |V=2|P| FMT=15  |   PT=206      |             length            |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |                  SSRC of packet sender                        |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |                  SSRC of media source                         |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |  Unique identifier 'R' 'E' 'M' 'B'                            |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |  Num SSRC     | BR Exp    |  BR Mantissa                      |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |   SSRC feedback                                               |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |  ...                                                          |
        */
        let (header, headerLen) = try Header.unmarshal(buf)

        if header.packetType != PacketType.payloadSpecificFeedback || header.count != formatRemb {
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
        if mediaSsrc != 0 {
            throw RtcpError.errSsrcMustBeZero
        }

        // REMB rules all around me
        guard let ui0: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let ui1: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let ui2: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let ui3: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        let ui = [ui0, ui1, ui2, ui3]
        if ui != Array(String(uniqueIdentifier).utf8) {
            throw RtcpError.errMissingRembIdentifier
        }

        // The next byte is the number of SSRC entries at the end.
        guard let ssrcsLen: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        // Get the 6-bit exponent value.
        guard let b17: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        var exp = UInt64(b17) >> 2
        exp += 127  // bias for IEEE754
        exp += 23  // IEEE754 biases the decimal to the left,
        //abs-send-time biases it to the right

        // The remaining 2-bits plus the next 16-bits are the mantissa.
        guard let b18: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        guard let b19: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        var mantissa = UInt32(b17 & 3) << 16 | UInt32(b18) << 8 | UInt32(b19)

        if mantissa != 0 {
            // ieee754 requires an implicit leading bit
            while (mantissa & (mantissaMax + 1)) == 0 {
                exp -= 1
                mantissa *= 2
            }
        }

        // bitrate = mantissa * 2^exp
        let bitrate = Float(bitPattern: (UInt32(exp) << 23) | UInt32(mantissa & mantissaMax))

        var ssrcs: [UInt32] = []
        for _ in 0..<ssrcsLen {
            guard let ssrc: UInt32 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            ssrcs.append(ssrc)
        }

        /*h.padding &&*/
        if reader.readableBytes > 0 {
            reader.moveReaderIndex(forwardBy: reader.readableBytes)
        }

        return (
            ReceiverEstimatedMaximumBitrate(
                senderSsrc: senderSsrc,
                //media_ssrc,
                bitrate: bitrate,
                ssrcs: ssrcs
            ), reader.readerIndex - readerStartIndex
        )
    }
}
