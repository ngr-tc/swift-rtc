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

public enum RtcpError: Error, Equatable {
    //RTCP errors
    /// Wrong marshal size.
    case errWrongMarshalSize
    /// Packet lost exceeds maximum amount of packets
    /// that can possibly be lost.
    case errInvalidTotalLost
    /// Packet contains an invalid header.
    case errInvalidHeader
    /// Packet contains empty compound.
    case errEmptyCompound
    /// Invalid first packet in compound packets. First packet
    /// should either be a SenderReport packet or ReceiverReport
    case errBadFirstPacket
    /// CNAME was not defined.
    case errMissingCname
    /// Packet was defined before CNAME.
    case errPacketBeforeCname
    /// Too many reports.
    case errTooManyReports
    /// Too many chunks.
    case errTooManyChunks
    /// Too many sources.
    case errTooManySources
    /// Packet received is too short.
    case errPacketTooShort
    /// Buffer is too short.
    case errBufferTooShort
    /// Wrong packet type.
    case errWrongType
    /// SDES received is too long.
    case errSdesTextTooLong
    /// SDES type is missing.
    case errSdesMissingType
    /// Reason is too long.
    case errReasonTooLong
    /// Invalid packet version.
    case errBadVersion
    /// Invalid padding value.
    case errWrongPadding
    /// Wrong feedback message type.
    case errWrongFeedbackType
    /// Wrong payload type.
    case errWrongPayloadType
    /// Header length is too small.
    case errHeaderTooSmall
    /// Media ssrc was defined as zero.
    case errSsrcMustBeZero
    /// Missing REMB identifier.
    case errMissingRembIdentifier
    /// SSRC number and length mismatches.
    case errSsrcNumAndLengthMismatch
    /// Invalid size or start index.
    case errInvalidSizeOrStartIndex
    /// Delta exceeds limit.
    case errDeltaExceedLimit
    /// Packet status chunk is not 2 bytes.
    case errPacketStatusChunkLength
    case errInvalidBitrate
    case errWrongChunkType
    case errBadStructMemberType
    case errBadReadParameter
}

extension RtcpError: CustomStringConvertible {
    public var description: String {
        switch self {
        /// Wrong marshal size.
        case .errWrongMarshalSize:
            return "Wrong marshal size"
        /// Packet lost exceeds maximum amount of packets
        /// that can possibly be lost.
        case .errInvalidTotalLost:
            return "Invalid total lost count"
        /// Packet contains an invalid header.

        case .errInvalidHeader:
            return "Invalid header"
        /// Packet contains empty compound.

        case .errEmptyCompound:
            return "Empty compound packet"
        /// Invalid first packet in compound packets. First packet
        /// should either be a SenderReport packet or ReceiverReport

        case .errBadFirstPacket:
            return "First packet in compound must be SR or RR"
        /// CNAME was not defined.

        case .errMissingCname:
            return "Compound missing SourceDescription with CNAME"
        /// Packet was defined before CNAME.

        case .errPacketBeforeCname:
            return "Feedback packet seen before CNAME"
        /// Too many reports.

        case .errTooManyReports:
            return "Too many reports"
        /// Too many chunks.

        case .errTooManyChunks:
            return "Too many chunks"
        /// Too many sources.

        case .errTooManySources:
            return "too many sources"
        /// Packet received is too short.

        case .errPacketTooShort:
            return "Packet too short to be read"
        /// Buffer is too short.

        case .errBufferTooShort:
            return "Buffer too short to be written"
        /// Wrong packet type.

        case .errWrongType:
            return "Wrong packet type"
        /// SDES received is too long.

        case .errSdesTextTooLong:
            return "SDES must be < 255 octets long"
        /// SDES type is missing.

        case .errSdesMissingType:
            return "SDES item missing type"
        /// Reason is too long.

        case .errReasonTooLong:
            return "Reason must be < 255 octets long"
        /// Invalid packet version.

        case .errBadVersion:
            return "Invalid packet version"
        /// Invalid padding value.

        case .errWrongPadding:
            return "Invalid padding value"
        /// Wrong feedback message type.

        case .errWrongFeedbackType:
            return "Wrong feedback message type"
        /// Wrong payload type.

        case .errWrongPayloadType:
            return "Wrong payload type"
        /// Header length is too small.

        case .errHeaderTooSmall:
            return "Header length is too small"
        /// Media ssrc was defined as zero.

        case .errSsrcMustBeZero:
            return "Media SSRC must be 0"
        /// Missing REMB identifier.

        case .errMissingRembIdentifier:
            return "Missing REMB identifier"
        /// SSRC number and length mismatches.

        case .errSsrcNumAndLengthMismatch:
            return "SSRC num and length do not match"
        /// Invalid size or start index.
        case .errInvalidSizeOrStartIndex:
            return "Invalid size or startIndex"
        /// Delta exceeds limit.
        case .errDeltaExceedLimit:
            return "Delta exceed limit"
        /// Packet status chunk is not 2 bytes.
        case .errPacketStatusChunkLength:
            return "Packet status chunk must be 2 bytes"
        case .errInvalidBitrate:
            return "Invalid bitrate"
        case .errWrongChunkType:
            return "Wrong chunk type"
        case .errBadStructMemberType:
            return "Struct contains unexpected member type"
        case .errBadReadParameter:
            return "Cannot read into non-pointer"
        }
    }
}
