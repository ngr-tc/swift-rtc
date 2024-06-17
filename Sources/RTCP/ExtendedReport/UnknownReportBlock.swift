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

/// UnknownReportBlock is used to store bytes for any report block
/// that has an unknown Report Block Type.
public struct UnknownReportBlock: Equatable {
    public var bytes: ByteBuffer

    public func xrHeader() -> XRHeader {
        XRHeader(
            blockType: BlockType.unknown,
            typeSpecific: 0,
            blockLength: UInt16(self.rawSize() / 4 - 1)
        )
    }
}

extension UnknownReportBlock: CustomStringConvertible {
    public var description: String {
        "\(self)"
    }
}

extension UnknownReportBlock: Packet {
    public func header() -> Header {
        Header()
    }

    /// destination_ssrc returns an array of ssrc values that this report block refers to.
    public func destinationSsrc() -> [UInt32] {
        []
    }

    public func rawSize() -> Int {
        xrHeaderLength + self.bytes.readableBytes
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension UnknownReportBlock: MarshalSize {
    public func marshalSize() -> Int {
        self.rawSize()
    }
}

extension UnknownReportBlock: Marshal {
    /// marshal_to encodes the UnknownReportBlock in binary
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let h = self.xrHeader()
        let _ = try h.marshalTo(&buf)

        buf.writeImmutableBuffer(self.bytes)

        return self.marshalSize()
    }
}

extension UnknownReportBlock: Unmarshal {
    /// Unmarshal decodes the UnknownReportBlock from binary
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < xrHeaderLength {
            throw RtcpError.errPacketTooShort
        }

        let (xrHeader, xrHeaderLen) = try XRHeader.unmarshal(buf)
        let blockLength = xrHeader.blockLength * 4

        var reader = buf.slice()
        let readerStartIndex = reader.readerIndex
        reader.moveReaderIndex(forwardBy: xrHeaderLen)

        if reader.readableBytes < Int(blockLength) {
            throw RtcpError.errPacketTooShort
        }

        guard let bytes = reader.readSlice(length: Int(blockLength)) else {
            throw RtcpError.errPacketTooShort
        }

        return (UnknownReportBlock(bytes: bytes), reader.readerIndex - readerStartIndex)
    }
}
