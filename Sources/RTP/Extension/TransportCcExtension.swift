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

// transport-wide sequence
public let transportCcExtensionSize: Int = 2

/// TransportCCExtension is a extension payload format in
/// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01
/// 0                   1                   2                   3
/// 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |       0xBE    |    0xDE       |           length=1            |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |  ID   | L=1   |transport-wide sequence number | zero padding  |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct TransportCcExtension: Equatable {
    public var transportSequence: UInt16
}

extension TransportCcExtension: Unmarshal {
    /// Unmarshal parses the passed byte slice and stores the result in the members
    public init(_ buf: inout ByteBuffer) throws {
        if buf.readableBytes < transportCcExtensionSize {
            throw RtpError.errBufferTooSmall
        }
        guard let b0: UInt8 = buf.readInteger() else {
            throw RtpError.errBufferTooSmall
        }
        guard let b1: UInt8 = buf.readInteger() else {
            throw RtpError.errBufferTooSmall
        }

        self.transportSequence = (UInt16(b0) << 8) | UInt16(b1)
    }
}

extension TransportCcExtension: MarshalSize {
    /// MarshalSize returns the size of the TransportCcExtension once marshaled.
    public func marshalSize() -> Int {
        return transportCcExtensionSize
    }
}

extension TransportCcExtension: Marshal {
    /// Marshal serializes the members to buffer
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        buf.writeInteger(self.transportSequence)
        return transportCcExtensionSize
    }
}
