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

let sdesSourceLen: Int = 4
let sdesTypeLen: Int = 1
let sdesTypeOffset: Int = 0
let sdesOctetCountLen: Int = 1
let sdesOctetCountOffset: Int = 1
let sdesMaxOctetCount: Int = (1 << 8) - 1
let sdesTextOffset: Int = 2

/// SDESType is the item type used in the RTCP SDES control packet.
/// RTP SDES item types registered with IANA. See: https://www.iana.org/assignments/rtp-parameters/rtp-parameters.xhtml#rtp-parameters-5
public enum SdesType: UInt8, Equatable {
    case sdesEnd = 0  // end of SDES list                RFC 3550, 6.5
    case sdesCname = 1  // canonical name                  RFC 3550, 6.5.1
    case sdesName = 2  // user name                       RFC 3550, 6.5.2
    case sdesEmail = 3  // user's electronic mail address  RFC 3550, 6.5.3
    case sdesPhone = 4  // user's phone number             RFC 3550, 6.5.4
    case sdesLocation = 5  // geographic user location        RFC 3550, 6.5.5
    case sdesTool = 6  // name of application or tool     RFC 3550, 6.5.6
    case sdesNote = 7  // notice about the source         RFC 3550, 6.5.7
    case sdesPrivate = 8  // private extensions              RFC 3550, 6.5.8  (not implemented)

    public init(rawValue: UInt8) {
        switch rawValue {
        case 1: self = .sdesCname
        case 2: self = .sdesName
        case 3: self = .sdesEmail
        case 4: self = .sdesPhone
        case 5: self = .sdesLocation
        case 6: self = .sdesTool
        case 7: self = .sdesNote
        case 8: self = .sdesPrivate
        default: self = .sdesEnd
        }
    }
}

extension SdesType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .sdesEnd:
            return "END"
        case .sdesCname:
            return "CNAME"
        case .sdesName:
            return "NAME"
        case .sdesEmail:
            return "EMAIL"
        case .sdesPhone:
            return "PHONE"
        case .sdesLocation:
            return "LOC"
        case .sdesTool:
            return "TOOL"
        case .sdesNote:
            return "NOTE"
        case .sdesPrivate:
            return "PRIV"
        }
    }
}

/// A SourceDescriptionChunk contains items describing a single RTP source
public struct SourceDescriptionChunk: Equatable {
    /// The source (ssrc) or contributing source (csrc) identifier this packet describes
    public var source: UInt32
    public var items: [SourceDescriptionItem]

    func rawSize() -> Int {
        var len = sdesSourceLen
        for it in self.items {
            len += it.marshalSize()
        }
        len += sdesTypeLen  // for terminating null octet
        return len
    }
}

extension SourceDescriptionChunk: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension SourceDescriptionChunk: Marshal {
    /// Marshal encodes the SourceDescriptionChunk in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        /*
         *  +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         *  |                          SSRC/CSRC_1                          |
         *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *  |                           SDES items                          |
         *  |                              ...                              |
         *  +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         */

        buf.writeInteger(self.source)

        for it in self.items {
            let _ = try it.marshalTo(&buf)
        }

        // The list of items in each chunk MUST be terminated by one or more null octets
        buf.writeInteger(UInt8(SdesType.sdesEnd.rawValue))

        // additional null octets MUST be included if needed to pad until the next 32-bit boundary
        putPadding(&buf, self.rawSize())
        return self.marshalSize()
    }
}

extension SourceDescriptionChunk: Unmarshal {
    /// Unmarshal decodes the SourceDescriptionChunk from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        /*
         *  +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         *  |                          SSRC/CSRC_1                          |
         *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *  |                           SDES items                          |
         *  |                              ...                              |
         *  +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         */
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < (sdesSourceLen + sdesTypeLen) {
            throw RtcpError.errPacketTooShort
        }

        var reader = buf.slice()
        guard let source: UInt32 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }

        var offset = sdesSourceLen
        var items: [SourceDescriptionItem] = []
        while offset < rawPacketLen {
            let (item, itemLen) = try SourceDescriptionItem.unmarshal(reader)
            reader.moveReaderIndex(forwardBy: itemLen)
            if item.sdesType == SdesType.sdesEnd {
                // offset + 1 (one byte for SdesEnd)
                let paddingLen = getPadding(offset + 1)
                if reader.readableBytes >= paddingLen {
                    reader.moveReaderIndex(forwardBy: paddingLen)
                    return (
                        SourceDescriptionChunk(source: source, items: items), reader.readerIndex
                    )
                } else {
                    throw RtcpError.errPacketTooShort
                }
            }
            offset += item.marshalSize()
            items.append(item)
        }

        throw RtcpError.errPacketTooShort
    }
}

/// A SourceDescriptionItem is a part of a SourceDescription that describes a stream.
public struct SourceDescriptionItem: Equatable {
    /// The type identifier for this item. eg, SDESCNAME for canonical name description.
    ///
    /// Type zero or SDESEnd is interpreted as the end of an item list and cannot be used.
    public var sdesType: SdesType
    /// Text is a unicode text blob associated with the item. Its meaning varies based on the item's Type.
    public var text: ByteBuffer
}

extension SourceDescriptionItem: MarshalSize {
    public func marshalSize() -> Int {
        /*
         *   0                   1                   2                   3
         *   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *  |    CNAME=1    |     length    | user and domain name        ...
         *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        sdesTypeLen + sdesOctetCountLen + self.text.readableBytes
    }
}

extension SourceDescriptionItem: Marshal {
    /// Marshal encodes the SourceDescriptionItem in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        /*
         *   0                   1                   2                   3
         *   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *  |    CNAME=1    |     length    | user and domain name        ...
         *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */

        if self.sdesType == SdesType.sdesEnd {
            throw RtcpError.errSdesMissingType
        }

        buf.writeInteger(UInt8(self.sdesType.rawValue))

        if self.text.readableBytes > sdesMaxOctetCount {
            throw RtcpError.errSdesTextTooLong
        }
        buf.writeInteger(UInt8(self.text.readableBytes))
        buf.writeImmutableBuffer(self.text)

        //no padding for each SourceDescriptionItem
        return self.marshalSize()
    }
}

extension SourceDescriptionItem: Unmarshal {
    /// Unmarshal decodes the SourceDescriptionItem from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        /*
         *   0                   1                   2                   3
         *   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *  |    CNAME=1    |     length    | user and domain name        ...
         *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        let rawPacketLen = buf.readableBytes
        if rawPacketLen < sdesTypeLen {
            throw RtcpError.errPacketTooShort
        }

        var reader = buf.slice()
        guard let b0: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        let sdesType = SdesType(rawValue: b0)
        if sdesType == SdesType.sdesEnd {
            return (
                SourceDescriptionItem(
                    sdesType: sdesType,
                    text: ByteBuffer()
                ), reader.readerIndex
            )
        }

        if rawPacketLen < (sdesTypeLen + sdesOctetCountLen) {
            throw RtcpError.errPacketTooShort
        }

        guard let octetCount: UInt8 = reader.readInteger() else {
            throw RtcpError.errPacketTooShort
        }
        if sdesTextOffset + Int(octetCount) > rawPacketLen {
            throw RtcpError.errPacketTooShort
        }

        let text = reader.readSlice(length: Int(octetCount)) ?? ByteBuffer()

        return (SourceDescriptionItem(sdesType: sdesType, text: text), reader.readerIndex)
    }
}

/// A SourceDescription (SDES) packet describes the sources in an RTP stream.
public struct SourceDescription: Equatable {
    public var chunks: [SourceDescriptionChunk]
}

extension SourceDescription: CustomStringConvertible {
    public var description: String {
        var out = "Source Description:\n"
        for c in self.chunks {
            out += String(format: "\t%x\n", c.source)
            for it in c.items {
                out += ("\t\t\(it)\n")
            }
        }
        return out
    }
}

extension SourceDescription: Packet {
    /// Header returns the Header associated with this packet.
    public func header() -> Header {
        Header(
            padding: getPadding(self.rawSize()) != 0,
            count: UInt8(self.chunks.count),
            packetType: PacketType.sourceDescription,
            length: UInt16((self.marshalSize() / 4) - 1)
        )
    }

    /// destination_ssrc returns an array of SSRC values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        self.chunks.map { $0.source }
    }

    public func rawSize() -> Int {
        var chunksLength = 0
        for c in self.chunks {
            chunksLength += c.marshalSize()
        }

        return headerLength + chunksLength
    }
}

extension SourceDescription: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension SourceDescription: Marshal {
    /// Marshal encodes the SourceDescription in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        if self.chunks.count > countMax {
            throw RtcpError.errTooManyChunks
        }

        /*
         *         0                   1                   2                   3
         *         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * header |V=2|P|    SC   |  PT=SDES=202  |             length            |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * chunk  |                          SSRC/CSRC_1                          |
         *   1    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                           SDES items                          |
         *        |                              ...                              |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * chunk  |                          SSRC/CSRC_2                          |
         *   2    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                           SDES items                          |
         *        |                              ...                              |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         */

        let h = self.header()
        let _ = try h.marshalTo(&buf)

        for c in self.chunks {
            let _ = try c.marshalTo(&buf)
        }

        if h.padding {
            putPadding(&buf, self.rawSize())
        }

        return self.marshalSize()
    }
}

extension SourceDescription: Unmarshal {
    /// Unmarshal decodes the SourceDescription from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        /*
         *         0                   1                   2                   3
         *         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         *        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * header |V=2|P|    SC   |  PT=SDES=202  |             length            |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * chunk  |                          SSRC/CSRC_1                          |
         *   1    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                           SDES items                          |
         *        |                              ...                              |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * chunk  |                          SSRC/CSRC_2                          |
         *   2    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         *        |                           SDES items                          |
         *        |                              ...                              |
         *        +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         */
        let rawPacketLen = buf.readableBytes

        let (h, headerLen) = try Header.unmarshal(buf)
        if h.packetType != PacketType.sourceDescription {
            throw RtcpError.errWrongType
        }

        var reader = buf.slice()
        reader.moveReaderIndex(forwardBy: headerLen)

        var offset = headerLength
        var chunks: [SourceDescriptionChunk] = []
        while offset < rawPacketLen {
            let (chunk, chunkLen) = try SourceDescriptionChunk.unmarshal(reader)
            offset += chunkLen
            chunks.append(chunk)
        }

        if chunks.count != Int(h.count) {
            throw RtcpError.errInvalidHeader
        }

        /*h.padding &&*/
        if reader.readableBytes > 0 {
            reader.moveReaderIndex(forwardBy: reader.readableBytes)
        }

        return (SourceDescription(chunks: chunks), reader.readerIndex)
    }
}
