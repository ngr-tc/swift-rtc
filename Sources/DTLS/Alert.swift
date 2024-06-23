import NIOCore
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
import Shared

enum AlertLevel: UInt8, Equatable {
    case invalid = 0
    case warning = 1
    case fatal = 2

    init(rawValue: UInt8) {
        switch rawValue {
        case 1:
            self = .warning
        case 2:
            self = .fatal
        default:
            self = .invalid
        }
    }
}

extension AlertLevel: CustomStringConvertible {
    public var description: String {
        switch self {
        case .warning:
            return "LevelWarning"
        case .fatal:
            return "LevelFatal"
        default:
            return "Invalid alert level"
        }
    }
}

enum AlertDescription: UInt8, Equatable {
    case closeNotify = 0
    case unexpectedMessage = 10
    case badRecordMac = 20
    case decryptionFailed = 21
    case recordOverflow = 22
    case decompressionFailure = 30
    case handshakeFailure = 40
    case noCertificate = 41
    case badCertificate = 42
    case unsupportedCertificate = 43
    case certificateRevoked = 44
    case certificateExpired = 45
    case certificateUnknown = 46
    case illegalParameter = 47
    case unknownCa = 48
    case accessDenied = 49
    case decodeError = 50
    case decryptError = 51
    case exportRestriction = 60
    case protocolVersion = 70
    case insufficientSecurity = 71
    case internalError = 80
    case userCanceled = 90
    case noRenegotiation = 100
    case unsupportedExtension = 110
    case unknownPskIdentity = 115
    case invalid

    init(rawValue: UInt8) {
        switch rawValue {
        case 0:
            self = AlertDescription.closeNotify
        case 10:
            self = AlertDescription.unexpectedMessage
        case 20:
            self = AlertDescription.badRecordMac
        case 21:
            self = AlertDescription.decryptionFailed
        case 22:
            self = AlertDescription.recordOverflow
        case 30:
            self = AlertDescription.decompressionFailure
        case 40:
            self = AlertDescription.handshakeFailure
        case 41:
            self = AlertDescription.noCertificate
        case 42:
            self = AlertDescription.badCertificate
        case 43:
            self = AlertDescription.unsupportedCertificate
        case 44:
            self = AlertDescription.certificateRevoked
        case 45:
            self = AlertDescription.certificateExpired
        case 46:
            self = AlertDescription.certificateUnknown
        case 47:
            self = AlertDescription.illegalParameter
        case 48:
            self = AlertDescription.unknownCa
        case 49:
            self = AlertDescription.accessDenied
        case 50:
            self = AlertDescription.decodeError
        case 51:
            self = AlertDescription.decryptError
        case 60:
            self = AlertDescription.exportRestriction
        case 70:
            self = AlertDescription.protocolVersion
        case 71:
            self = AlertDescription.insufficientSecurity
        case 80:
            self = AlertDescription.internalError
        case 90:
            self = AlertDescription.userCanceled
        case 100:
            self = AlertDescription.noRenegotiation
        case 110:
            self = AlertDescription.unsupportedExtension
        case 115:
            self = AlertDescription.unknownPskIdentity
        default:
            self = AlertDescription.invalid
        }
    }
}

extension AlertDescription: CustomStringConvertible {
    public var description: String {
        switch self {
        case .closeNotify:
            return "CloseNotify"
        case .unexpectedMessage:
            return "UnexpectedMessage"
        case .badRecordMac:
            return "BadRecordMac"
        case .decryptionFailed:
            return "DecryptionFailed"
        case .recordOverflow:
            return "RecordOverflow"
        case .decompressionFailure:
            return "DecompressionFailure"
        case .handshakeFailure:
            return "HandshakeFailure"
        case .noCertificate:
            return "NoCertificate"
        case .badCertificate:
            return "BadCertificate"
        case .unsupportedCertificate:
            return "UnsupportedCertificate"
        case .certificateRevoked:
            return "CertificateRevoked"
        case .certificateExpired:
            return "CertificateExpired"
        case .certificateUnknown:
            return "CertificateUnknown"
        case .illegalParameter:
            return "IllegalParameter"
        case .unknownCa:
            return "UnknownCA"
        case .accessDenied:
            return "AccessDenied"
        case .decodeError:
            return "DecodeError"
        case .decryptError:
            return "DecryptError"
        case .exportRestriction:
            return "ExportRestriction"
        case .protocolVersion:
            return "ProtocolVersion"
        case .insufficientSecurity:
            return "InsufficientSecurity"
        case .internalError:
            return "InternalError"
        case .userCanceled:
            return "UserCanceled"
        case .noRenegotiation:
            return "NoRenegotiation"
        case .unsupportedExtension:
            return "UnsupportedExtension"
        case .unknownPskIdentity:
            return "UnknownPskIdentity"
        default:
            return "Invalid alert description"
        }
    }
}

// One of the content types supported by the TLS record layer is the
// alert type.  Alert messages convey the severity of the message
// (warning or fatal) and a description of the alert.  Alert messages
// with a level of fatal result in the immediate termination of the
// connection.  In this case, other connections corresponding to the
// session may continue, but the session identifier MUST be invalidated,
// preventing the failed session from being used to establish new
// connections.  Like other messages, alert messages are encrypted and
// compressed, as specified by the current connection state.
// https://tools.ietf.org/html/rfc5246#section-7.2
public struct Alert: Equatable {
    var alertLevel: AlertLevel
    var alertDescription: AlertDescription

    public func contentType() -> ContentType {
        ContentType.alert
    }
}

extension Alert: CustomStringConvertible {
    public var description: String {
        "Alert \(self.alertLevel): \(self.alertDescription)"
    }
}

extension Alert: MarshalSize {
    public func marshalSize() -> Int {
        2
    }
}

extension Alert: Marshal {
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        buf.writeInteger(self.alertLevel.rawValue)
        buf.writeInteger(self.alertDescription.rawValue)

        return self.marshalSize()
    }
}

extension Alert: Unmarshal {
    public static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int) {
        var reader = buf.slice()
        guard let alertLevel: UInt8 = reader.readInteger() else {
            throw DtlsError.errTooShortBuffer
        }
        guard let alertDescription: UInt8 = reader.readInteger() else {
            throw DtlsError.errTooShortBuffer
        }

        return (
            Alert(
                alertLevel: AlertLevel(rawValue: alertLevel),
                alertDescription: AlertDescription(rawValue: alertDescription)),
            2
        )
    }
}
