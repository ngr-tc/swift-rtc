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

public let absSendTimeExtensionSize: Int = 3

/// AbsSendTimeExtension is a extension payload format in
/// http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
public struct AbsSendTimeExtension: Equatable {
    public var timestamp: UInt64

    public init(timestamp: UInt64) {
        self.timestamp = timestamp
    }

    /// makes new AbsSendTimeExtension from time.Time.
    public init(sendTime: NIODeadline) {
        self.timestamp = unix2ntp(sendTime) >> 14
    }

    /// Estimate absolute send time according to the receive time.
    /// Note that if the transmission delay is larger than 64 seconds, estimated time will be wrong.
    public func estimate(_ receive: NIODeadline) -> NIODeadline {
        let receiveNtp = unix2ntp(receive)
        var ntp = receiveNtp & 0xFFFF_FFC0_0000_0000 | (self.timestamp & 0xFFFFFF) << 14
        if receiveNtp < ntp {
            // Receive time must be always later than send time
            ntp -= 0x1000000 << 14
        }

        return ntp2unix(ntp)
    }
}

extension AbsSendTimeExtension: Unmarshal {
    /// Unmarshal parses the passed byte slice and stores the result in the members.
    public init(_ buf: ByteBuffer) throws {
        var reader = buf.slice()
        guard let b0: UInt8 = reader.readInteger() else {
            throw RtpError.errBufferTooSmall
        }
        guard let b1: UInt8 = reader.readInteger() else {
            throw RtpError.errBufferTooSmall
        }
        guard let b2: UInt8 = reader.readInteger() else {
            throw RtpError.errBufferTooSmall
        }
        self.timestamp = UInt64(b0) << 16 | UInt64(b1) << 8 | UInt64(b2)
    }
}

extension AbsSendTimeExtension: MarshalSize {
    /// MarshalSize returns the size of the AbsSendTimeExtension once marshaled.
    public func marshalSize() -> Int {
        absSendTimeExtensionSize
    }
}

extension AbsSendTimeExtension: Marshal {
    /// MarshalTo serializes the members to buffer.
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        buf.writeInteger(UInt8((self.timestamp & 0xFF0000) >> 16))
        buf.writeInteger(UInt8((self.timestamp & 0xFF00) >> 8))
        buf.writeInteger(UInt8(self.timestamp & 0xFF))

        return absSendTimeExtensionSize
    }
}

extension AbsSendTimeExtension: HeaderExtension {
    public func uri() -> String {
        return "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time"
    }
}

public func unix2ntp(_ st: NIODeadline) -> UInt64 {
    let u = st.uptimeNanoseconds
    var s = u / 1_000_000_000
    s += 0x83AA_7E80  //offset in seconds between unix epoch and ntp epoch
    var f = u % 1_000_000_000
    f <<= 32
    f /= 1_000_000_000
    s <<= 32

    return s | f
}

public func ntp2unix(_ t: UInt64) -> NIODeadline {
    var s = t >> 32
    var f = t & 0xFFFF_FFFF
    f *= 1_000_000_000
    f >>= 32
    s -= 0x83AA_7E80
    let u = s * 1_000_000_000 + f

    return NIODeadline.uptimeNanoseconds(u)
}
