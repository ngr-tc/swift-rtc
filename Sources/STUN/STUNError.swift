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

public enum STUNError: Error {
    //STUN errors
    case errAttributeNotFound
    case errTransactionStopped
    case errTransactionNotExists
    case errTransactionExists
    case errAgentClosed
    case errTransactionTimeOut
    case errNoDefaultReason
    case errUnexpectedEof
    case errAttributeSizeInvalid
    case errAttributeSizeOverflow
    case errDecodeToNil
    case errUnexpectedHeaderEof
    case errIntegrityMismatch
    case errFingerprintMismatch
    case errFingerprintBeforeIntegrity
    case errBadUnknownAttrsSize
    case errBadIpLength
    case errNoConnection
    case errClientClosed
    case errNoAgent
    case errCollectorClosed
    case errUnsupportedNetwork
    case errInvalidUrl
    case errSchemeType
    case errHost
    case errInvalidFamilyIpValue(UInt16)
    case errInvalidMagicCookie(UInt32)
    case errBufferTooSmall
    case errUnsupportedAttrType(AttrType)
    case errInvalidTextAttribute
    case errInvalidString
}

extension STUNError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .errAttributeNotFound:
            return "attribute not found"
        case .errTransactionStopped:
            return "transaction is stopped"
        case .errTransactionNotExists:
            return "transaction not exists"
        case .errTransactionExists:
            return "transaction exists with same id"
        case .errAgentClosed:
            return "agent is closed"
        case .errTransactionTimeOut:
            return "transaction is timed out"
        case .errNoDefaultReason:
            return "no default reason for ErrorCode"
        case .errUnexpectedEof:
            return "unexpected EOF"
        case .errAttributeSizeInvalid:
            return "attribute size is invalid"
        case .errAttributeSizeOverflow:
            return "attribute size overflow"
        case .errDecodeToNil:
            return "attempt to decode to nil message"
        case .errUnexpectedHeaderEof:
            return "unexpected EOF: not enough bytes to read header"
        case .errIntegrityMismatch:
            return "integrity check failed"
        case .errFingerprintMismatch:
            return "fingerprint check failed"
        case .errFingerprintBeforeIntegrity:
            return "FINGERPRINT before MESSAGE-INTEGRITY attribute"
        case .errBadUnknownAttrsSize:
            return "bad UNKNOWN-ATTRIBUTES size"
        case .errBadIpLength:
            return "invalid length of IP value"
        case .errNoConnection:
            return "no connection provided"
        case .errClientClosed:
            return "client is closed"
        case .errNoAgent:
            return "no agent is set"
        case .errCollectorClosed:
            return "collector is closed"
        case .errUnsupportedNetwork:
            return "unsupported network"
        case .errInvalidUrl:
            return "invalid url"
        case .errSchemeType:
            return "unknown scheme type"
        case .errHost:
            return "invalid hostname"
        case .errInvalidFamilyIpValue(let family):
            return "invalid family ip value \(family)"
        case .errInvalidMagicCookie(let cookie):
            return "\(cookie) is invalid magic cookie (should be \(magicCookie)"
        case .errBufferTooSmall:
            return "buffer too small"
        case .errUnsupportedAttrType(let attr):
            return "unsupported AttrType \(attr)"
        case .errInvalidTextAttribute:
            return "invalid text attribute"
        case .errInvalidString:
            return "invalid string"
        }
    }
}
