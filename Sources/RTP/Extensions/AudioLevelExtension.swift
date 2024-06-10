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

// audioLevelExtensionSize One byte header size
public let audioLevelExtensionSize: Int = 1

/// AudioLevelExtension is a extension payload format described in
/// https://tools.ietf.org/html/rfc6464
///
/// Implementation based on:
/// https://chromium.googlesource.com/external/webrtc/+/e2a017725570ead5946a4ca8235af27470ca0df9/webrtc/modules/rtp_rtcp/source/rtp_header_extensions.cc#49
///
/// One byte format:
/// 0                   1
/// 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |  ID   | len=0 |V| level       |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
///
/// Two byte format:
/// 0                   1                   2                   3
/// 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |      ID       |     len=1     |V|    level    |    0 (pad)    |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct AudioLevelExtension: Equatable {
    public var level: UInt8
    public var voice: Bool
}

extension AudioLevelExtension: Unmarshal {
    /// Unmarshal parses the passed byte slice and stores the result in the members
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        if buf.readableBytes < audioLevelExtensionSize {
            throw RtpError.errBufferTooSmall
        }
        var reader = buf.slice()
        guard let b: UInt8 = reader.readInteger() else {
            throw RtpError.errBufferTooSmall
        }

        let level = b & 0x7F
        let voice = (b & 0x80) != 0
        return (AudioLevelExtension(level: level, voice: voice), reader.readerIndex)
    }
}

extension AudioLevelExtension: MarshalSize {
    /// MarshalSize returns the size of the AudioLevelExtension once marshaled.
    public func marshalSize() -> Int {
        return audioLevelExtensionSize
    }
}

extension AudioLevelExtension: Marshal {
    /// MarshalTo serializes the members to buffer
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        if self.level > 127 {
            throw RtpError.errAudioLevelOverflow
        }
        let voice: UInt8 = self.voice ? 0x80 : 0

        buf.writeInteger(UInt8(voice | self.level))

        return audioLevelExtensionSize
    }
}

extension AudioLevelExtension: HeaderExtension {
    public func uri() -> String {
        return "urn:ietf:params:rtp-hdrext:ssrc-audio-level"
    }
}
