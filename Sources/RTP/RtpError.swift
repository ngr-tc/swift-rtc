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

public enum RtpError: Error, Equatable {
    //RTP errors
    case errHeaderSizeInsufficient
    case errHeaderSizeInsufficientForExtension
    case errBufferTooSmall
    case errHeaderExtensionsNotEnabled
    case errHeaderExtensionNotFound

    case errRfc8285oneByteHeaderIdrange
    case errRfc8285oneByteHeaderSize

    case errRfc8285twoByteHeaderIdrange
    case errRfc8285twoByteHeaderSize

    case errRfc3550headerIdrange

    case errShortPacket
    case errNilPacket
    case errTooManyPDiff
    case errTooManySpatialLayers
    case errUnhandledNaluType

    case errH265CorruptedPacket
    case errInvalidH265PacketType

    case errPayloadTooSmallForObuExtensionHeader
    case errPayloadTooSmallForObuPayloadSize

    case errHeaderExtensionPayloadNot32BitWords
    case errAudioLevelOverflow
    case errPayloadIsNotLargeEnough
    case errStapASizeLargerThanBuffer(Int, Int)
    case errNaluTypeIsNotHandled(UInt8)
}

extension RtpError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .errHeaderSizeInsufficient:
            return "RTP header size insufficient"
        case .errHeaderSizeInsufficientForExtension:
            return "RTP header size insufficient for extension"
        case .errBufferTooSmall:
            return "buffer too small"
        case .errHeaderExtensionsNotEnabled:
            return "extension not enabled"
        case .errHeaderExtensionNotFound:
            return "extension not found"
        case .errRfc8285oneByteHeaderIdrange:
            return "header extension id must be between 1 and 14 for RFC 5285 extensions"
        case .errRfc8285oneByteHeaderSize:
            return
                "header extension payload must be 16bytes or less for RFC 5285 one byte extensions"
        case .errRfc8285twoByteHeaderIdrange:
            return "header extension id must be between 1 and 255 for RFC 5285 extensions"
        case .errRfc8285twoByteHeaderSize:
            return
                "header extension payload must be 255bytes or less for RFC 5285 two byte extensions"
        case .errRfc3550headerIdrange:
            return "header extension id must be 0 for none RFC 5285 extensions"
        case .errShortPacket:
            return "packet is not large enough"
        case .errNilPacket:
            return "invalid nil packet"
        case .errTooManyPDiff:
            return "too many PDiff"
        case .errTooManySpatialLayers:
            return "too many spatial layers"
        case .errUnhandledNaluType:
            return "NALU Type is unhandled"
        case .errH265CorruptedPacket:
            return "corrupted h265 packet"
        case .errInvalidH265PacketType:
            return "invalid h265 packet type"
        case .errPayloadTooSmallForObuExtensionHeader:
            return "payload is too small for OBU extension header"
        case .errPayloadTooSmallForObuPayloadSize:
            return "payload is too small for OBU payload size"
        case .errHeaderExtensionPayloadNot32BitWords:
            return "extension_payload must be in 32-bit words"
        case .errAudioLevelOverflow:
            return "audio level overflow"
        case .errPayloadIsNotLargeEnough:
            return "payload is not large enough"
        case .errStapASizeLargerThanBuffer(let s1, let s2):
            return "STAP-A declared size(\(s1)) is larger than buffer(\(s2)"
        case .errNaluTypeIsNotHandled(let t):
            return "nalu type \(t) is currently not handled"
        }
    }
}
