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

public enum SrtpError: Error, Equatable {
    //SRTP
    case errDuplicated
    case errShortSrtpMasterKey
    case errShortSrtpMasterSalt
    case errNoSuchSrtpProfile
    case errNonZeroKdrNotSupported
    case errExporterWrongLabel
    case errNoConfig
    case errNoConn
    case errFailedToVerifyAuthTag
    case errTooShortRtp
    case errTooShortRtcp
    case errTooShortKeyingMaterial
    case errPayloadDiffers
    case errStartedChannelUsedIncorrectly
    case errStreamNotInited
    case errStreamAlreadyClosed
    case errStreamAlreadyInited
    case errFailedTypeAssertion

    case errUnsupportedIndexOverKdr
    case errSrtpMasterKeyLength(Int, Int)
    case errSrtpSaltLength(Int, Int)
    case errExtMapParse(String)
    case errSsrcMissingFromSrtp(UInt32)
    case errSrtpSsrcDuplicated(UInt32, UInt16)
    case errSrtcpSsrcDuplicated(UInt32, UInt32)
    case errSsrcMissingFromSrtcp(UInt32)
    case errStreamWithSsrcExists(UInt32)
    case errSessionRtpRtcpTypeMismatch
    case errSessionEof
    case errSrtpTooSmall(Int, Int)
    case errSrtcpTooSmall(Int, Int)
    case errRtpFailedToVerifyAuthTag
    case errRtcpFailedToVerifyAuthTag
    case errSessionSrtpAlreadyClosed
    case errInvalidRtpStream
    case errInvalidRtcpStream
    case errTooShortRtpAuthTag
    case errTooShortRtcpAuthTag
}

extension SrtpError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .errDuplicated:
            return "duplicated packet"
        case .errShortSrtpMasterKey:
            return "SRTP master key is not long enough"
        case .errShortSrtpMasterSalt:
            return "SRTP master salt is not long enough"
        case .errNoSuchSrtpProfile:
            return "no such SRTP Profile"
        case .errNonZeroKdrNotSupported:
            return "indexOverKdr > 0 is not supported yet"
        case .errExporterWrongLabel:
            return "exporter called with wrong label"
        case .errNoConfig:
            return "no config provided"
        case .errNoConn:
            return "no conn provided"
        case .errFailedToVerifyAuthTag:
            return "failed to verify auth tag"
        case .errTooShortRtp:
            return "packet is too short to be rtp packet"
        case .errTooShortRtcp:
            return "packet is too short to be rtcp packet"
        case .errTooShortKeyingMaterial:
            return "key material is too short"
        case .errPayloadDiffers:
            return "payload differs"
        case .errStartedChannelUsedIncorrectly:
            return "started channel used incorrectly, should only be closed"
        case .errStreamNotInited:
            return "stream has not been inited, unable to close"
        case .errStreamAlreadyClosed:
            return "stream is already closed"
        case .errStreamAlreadyInited:
            return "stream is already inited"
        case .errFailedTypeAssertion:
            return "failed to cast child"

        case .errUnsupportedIndexOverKdr:
            return "index_over_kdr > 0 is not supported yet"
        case .errSrtpMasterKeyLength(let a, let b):
            return "SRTP Master Key must be len \(a), got \(b)"
        case .errSrtpSaltLength(let a, let b):
            return "SRTP Salt must be len \(a), got \(b)"
        case .errExtMapParse(let a):
            return "SyntaxError: \(a)"
        case .errSsrcMissingFromSrtp(let a):
            return "ssrc \(a) not exist in srtp_ssrc_state"
        case .errSrtpSsrcDuplicated(let a, let b):
            return "srtp ssrc=\(a) index=\(b): duplicated"
        case .errSrtcpSsrcDuplicated(let a, let b):
            return "srtcp ssrc=\(a) index=\(b): duplicated"
        case .errSsrcMissingFromSrtcp(let a):
            return "ssrc \(a) not exist in srtcp_ssrc_state"
        case .errStreamWithSsrcExists(let a):
            return "Stream with ssrc \(a) exists"
        case .errSessionRtpRtcpTypeMismatch:
            return "Session RTP/RTCP type must be same as input buffer"
        case .errSessionEof:
            return "Session EOF"
        case .errSrtpTooSmall(let a, let b):
            return "too short SRTP packet: only \(a) bytes, expected > \(b) bytes"
        case .errSrtcpTooSmall(let a, let b):
            return "too short SRTCP packet: only \(a) bytes, expected > \(b) bytes"
        case .errRtpFailedToVerifyAuthTag:
            return "failed to verify rtp auth tag"
        case .errRtcpFailedToVerifyAuthTag:
            return "failed to verify rtcp auth tag"
        case .errSessionSrtpAlreadyClosed:
            return "SessionSRTP has been closed"
        case .errInvalidRtpStream:
            return "this stream is not a RTPStream"
        case .errInvalidRtcpStream:
            return "this stream is not a RTCPStream"
        case .errTooShortRtpAuthTag:
            return "too short RTP auth tag"
        case .errTooShortRtcpAuthTag:
            return "too short RTCP auth tag"
        }
    }
}
