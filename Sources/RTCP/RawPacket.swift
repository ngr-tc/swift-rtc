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

/// RawPacket represents an unparsed RTCP packet. It's returned by Unmarshal when
/// a packet with an unknown type is encountered.
public struct RawPacket: Equatable {
    public var raw: ByteBuffer
}

extension RawPacket: CustomStringConvertible {
    public var description: String {
        return "RawPacket: \(self.raw)"
    }
}

extension RawPacket: Packet {
    /// Header returns the Header associated with this packet.
    public func header() -> Header {
        if let h = try? Header.unmarshal(self.raw) {
            return h.0
        } else {
            return Header()
        }
    }

    /// destination_ssrc returns an array of SSRC values that this packet refers to.
    public func destinationSsrc() -> [UInt32] {
        []
    }

    public func rawSize() -> Int {
        self.raw.readableBytes
    }

    public func equal(other: Packet) -> Bool {
        if let rhs = other as? Self {
            return self == rhs
        } else {
            return false
        }
    }
}

extension RawPacket: Unmarshal {
    /// Unmarshal decodes the packet from binary.
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        let _ = try Header.unmarshal(buf)
        return (RawPacket(raw: buf), buf.readableBytes)
    }
}

extension RawPacket: MarshalSize {
    public func marshalSize() -> Int {
        let l = self.rawSize()
        // align to 32-bit boundary
        return l + getPadding(l)
    }
}

extension RawPacket: Marshal {
    /// Marshal encodes the packet in binary.
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let (h, _) = try Header.unmarshal(self.raw)
        buf.writeImmutableBuffer(self.raw)
        if h.padding {
            putPadding(&buf, self.rawSize())
        }
        return self.marshalSize()
    }
}
