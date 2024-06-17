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

let dlrrReportLength: UInt16 = 12

/// DLRRReport encodes a single report inside a DLRRReportBlock.
public struct DLRRReport: Equatable {
    public var ssrc: UInt32
    public var lastRr: UInt32
    public var dlrr: UInt32
}

extension DLRRReport: CustomStringConvertible {
    public var description: String {
        "\(self)"
    }
}

/// DLRRReportBlock encodes a DLRR Report Block as described in
/// RFC 3611 section 4.5.
///
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |     BT=5      |   reserved    |         block length          |
/// +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
/// |                 SSRC_1 (ssrc of first receiver)               | sub-
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ block
/// |                         last RR (LRR)                         |   1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                   delay since last RR (DLRR)                  |
/// +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
/// |                 SSRC_2 (ssrc of second receiver)              | sub-
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ block
/// :                               ...                             :   2
/// +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
public struct DLRRReportBlock: Equatable {
    public var reports: [DLRRReport]

    public func xrHeader() -> XRHeader {
        XRHeader(
            blockType: BlockType.dlrr,
            typeSpecific: 0,
            blockLength: UInt16(self.rawSize() / 4 - 1)
        )
    }
}

extension DLRRReportBlock: CustomStringConvertible {
    public var description: String {
        "\(self)"
    }
}

extension DLRRReportBlock: Packet {
    public func header() -> Header {
        Header()
    }

    /// destination_ssrc returns an array of ssrc values that this report block refers to.
    public func destinationSsrc() -> [UInt32] {
        self.reports.map { $0.ssrc }
    }

    public func rawSize() -> Int {
        xrHeaderLength + self.reports.count * 4 * 3
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension DLRRReportBlock: MarshalSize {
    public func marshalSize() -> Int {
        self.rawSize()
    }
}

extension DLRRReportBlock: Marshal {
    /// marshal_to encodes the DLRRReportBlock in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let h = self.xrHeader()
        let _ = try h.marshalTo(&buf)

        for rep in self.reports {
            buf.writeInteger(rep.ssrc)
            buf.writeInteger(rep.lastRr)
            buf.writeInteger(rep.dlrr)
        }

        return self.marshalSize()
    }
}

extension DLRRReportBlock: Unmarshal {
    /// Unmarshal decodes the DLRRReportBlock from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < xrHeaderLength {
            throw RtcpError.errPacketTooShort
        }

        let (xrHeader, xrHeaderLen) = try XRHeader.unmarshal(buf)
        let blockLength = xrHeader.blockLength * 4

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: xrHeaderLen)

        if blockLength % dlrrReportLength != 0 || reader.readableBytes < Int(blockLength) {
            throw RtcpError.errPacketTooShort
        }

        var offset: UInt16 = 0
        var reports: [DLRRReport] = []
        while offset < blockLength {
            guard let ssrc: UInt32 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            guard let lastRr: UInt32 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            guard let dlrr: UInt32 = reader.readInteger() else {
                throw RtcpError.errPacketTooShort
            }
            reports.append(
                DLRRReport(
                    ssrc: ssrc,
                    lastRr: lastRr,
                    dlrr: dlrr
                ))
            offset += dlrrReportLength
        }

        return (DLRRReportBlock(reports: reports), reader.readerIndex - readerStartIndex)
    }
}
