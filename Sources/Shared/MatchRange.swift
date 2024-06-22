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

// matchRange is a MatchFunc that accepts packets with the first byte in [lower..upper]
func matchRange(_ lower: UInt8, _ upper: UInt8) -> (ByteBufferView) -> Bool {
    return { (buf: ByteBufferView) -> Bool in
        if buf.isEmpty {
            return false
        }
        let b = buf.byte(0)
        return b >= lower && b <= upper
    }
}

/// MatchFuncs as described in RFC7983
/// <https://tools.ietf.org/html/rfc7983>
///              +----------------+
///              |        [0..3] -+--> forward to STUN
///              |                |
///              |      [16..19] -+--> forward to ZRTP
///              |                |
///  packet -->  |      [20..63] -+--> forward to DTLS
///              |                |
///              |      [64..79] -+--> forward to TURN Channel
///              |                |
///              |    [128..191] -+--> forward to RTP/RTCP
///              +----------------+
/// match_dtls is a MatchFunc that accepts packets with the first byte in [20..63]
/// as defied in RFC7983
public func matchDtls(_ b: ByteBufferView) -> Bool {
    return matchRange(20, 63)(b)
}

// match_srtp_or_srtcp is a MatchFunc that accepts packets with the first byte in [128..191]
// as defied in RFC7983
public func matchSrtpOrSrtcp(_ b: ByteBufferView) -> Bool {
    matchRange(128, 191)(b)
}

public func isRtcp(_ buf: ByteBufferView) -> Bool {
    // Not long enough to determine RTP/RTCP
    if buf.count < 4 {
        return false
    }

    let rtcpPacketType = buf.byte(1)
    return (192...223).contains(rtcpPacketType)
}

/// match_srtp is a MatchFunc that only matches SRTP and not SRTCP
public func matchSrtp(_ buf: ByteBufferView) -> Bool {
    matchSrtpOrSrtcp(buf) && !isRtcp(buf)
}

/// match_srtcp is a MatchFunc that only matches SRTCP and not SRTP
public func matchSrtcp(_ buf: ByteBufferView) -> Bool {
    matchSrtpOrSrtcp(buf) && isRtcp(buf)
}
