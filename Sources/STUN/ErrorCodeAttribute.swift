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

/// ErrorCodeAttribute represents ERROR-CODE attribute.
///
/// RFC 5389 Section 15.6
public struct ErrorCodeAttribute {
    var code: ErrorCode
    var reason: String

    public init(code: ErrorCode, reason: String) {
        self.code = code
        self.reason = reason
    }
}

extension ErrorCodeAttribute: CustomStringConvertible {
    public var description: String {
        return "\(self.code.rawValue): \(self.reason)"
    }
}

// constants for ERROR-CODE encoding.
let errorCodeClassByte: Int = 2
let errorCodeNumberByte: Int = 3
let errorCodeReasonStart: Int = 4
let errorCodeReasonMaxB: Int = 763
let errorCodeModulo: UInt16 = 100

extension ErrorCodeAttribute: Setter {
    /// addTo adds ERROR-CODE to m.
    public func addTo(_ m: inout Message) throws {
        try checkOverflow(
            attrErrorCode,
            self.reason.count + errorCodeReasonStart,
            errorCodeReasonMaxB + errorCodeReasonStart
        )

        let numberByte = UInt8(self.code.rawValue % errorCodeModulo)  // error code modulo 100
        let classByte = UInt8(self.code.rawValue / errorCodeModulo)  // hundred digit

        var value = ByteBuffer()
        value.reserveCapacity(minimumWritableBytes: 4 + self.reason.count)
        value.writeBytes([0, 0])
        value.writeInteger(classByte)  // [ERROR_CODE_CLASS_BYTE]
        value.writeInteger(numberByte)  //[ERROR_CODE_NUMBER_BYTE]
        value.writeString(self.reason)  //[ERROR_CODE_REASON_START:]

        m.add(attrErrorCode, value.readableBytesView)
    }
}

extension ErrorCodeAttribute: Getter {
    /// getFrom decodes ERROR-CODE from m. Reason is valid until m.Raw is valid.
    public mutating func getFrom(_ m: inout Message) throws {
        let b = try m.get(attrErrorCode)
        let v = b.readableBytesView
        if v.count < errorCodeReasonStart {
            throw StunError.errUnexpectedEof
        }

        let classByte = UInt16(v[errorCodeClassByte])
        let numberByte = UInt16(v[errorCodeNumberByte])
        let code = classByte * errorCodeModulo + numberByte
        self.code = ErrorCode(code)
        if let reason = b.getString(
            at: errorCodeReasonStart, length: v.count - errorCodeReasonStart)
        {
            self.reason = reason
        } else {
            throw StunError.errInvalidString
        }
    }
}

/// ErrorCode is code for ERROR-CODE attribute.
public struct ErrorCode: Equatable, Hashable {
    var rawValue: UInt16

    public init(_ rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

extension ErrorCode: Setter {
    // add_to adds ERROR-CODE with default reason to m. If there
    // is no default reason, returns ErrNoDefaultReason.
    public func addTo(_ m: inout Message) throws {
        if let reason = errorReasons[self] {
            let a = ErrorCodeAttribute(
                code: self,
                reason: reason
            )
            try a.addTo(&m)
        } else {
            throw StunError.errNoDefaultReason
        }
    }
}

/// Possible error codes.
public let codeTryAlternate: ErrorCode = ErrorCode(300)
public let codeBadRequest: ErrorCode = ErrorCode(400)
public let codeUnauthorized: ErrorCode = ErrorCode(401)
public let codeUnknownAttribute: ErrorCode = ErrorCode(420)
public let codeStaleNonce: ErrorCode = ErrorCode(438)
public let codeRoleConflict: ErrorCode = ErrorCode(487)
public let codeServerError: ErrorCode = ErrorCode(500)

/// DEPRECATED constants.
/// DEPRECATED, use codeUnauthorized.
public let codeUnauthorised: ErrorCode = codeUnauthorized

/// Error codes from RFC 5766.
///
/// RFC 5766 Section 15
public let codeForbidden: ErrorCode = ErrorCode(403)  // Forbidden
public let codeAllocMismatch: ErrorCode = ErrorCode(437)  // Allocation Mismatch
public let codeWrongCredentials: ErrorCode = ErrorCode(441)  // Wrong Credentials
public let codeUnsupportedTransProto: ErrorCode = ErrorCode(442)  // Unsupported Transport Protocol
public let codeAllocQuotaReached: ErrorCode = ErrorCode(486)  // Allocation Quota Reached
public let codeInsufficientCapacity: ErrorCode = ErrorCode(508)  // Insufficient Capacity

/// Error codes from RFC 6062.
///
/// RFC 6062 Section 6.3
public let codeConnAlreadyExists: ErrorCode = ErrorCode(446)
public let codeConnTimeoutOrFailure: ErrorCode = ErrorCode(447)

/// Error codes from RFC 6156.
///
/// RFC 6156 Section 10.2
public let codeAddrFamilyNotSupported: ErrorCode = ErrorCode(440)  // Address Family not Supported
public let codePeerAddrFamilyMismatch: ErrorCode = ErrorCode(443)  // Peer Address Family Mismatch

public let errorReasons: [ErrorCode: String] =
    [
        codeTryAlternate: "Try Alternate",
        codeBadRequest: "Bad Request",
        codeUnauthorized: "Unauthorized",
        codeUnknownAttribute: "Unknown Attribute",
        codeStaleNonce: "Stale Nonce",
        codeServerError: "Server Error",
        codeRoleConflict: "Role Conflict",

        // RFC 5766.
        codeForbidden: "Forbidden",
        codeAllocMismatch: "Allocation Mismatch",
        codeWrongCredentials: "Wrong Credentials",
        codeUnsupportedTransProto: "Unsupported Transport Protocol",
        codeAllocQuotaReached: "Allocation Quota Reached",
        codeInsufficientCapacity: "Insufficient Capacity",

        // RFC 6062.
        codeConnAlreadyExists: "Connection Already Exists",
        codeConnTimeoutOrFailure: "Connection Timeout or Failure",

        // RFC 6156.
        codeAddrFamilyNotSupported: "Address Family not Supported",
        codePeerAddrFamilyMismatch: "Peer Address Family Mismatch",
    ]
