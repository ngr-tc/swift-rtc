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

public enum DtlsError: Error, Equatable {
    case errConnClosed
    case errDeadlineExceeded
    case errContextUnsupported
    case errDtlspacketInvalidLength
    case errHandshakeInProgress
    case errInvalidContentType
    case errInvalidMac
    case errInvalidPacketLength
    case errReservedExportKeyingMaterial
    case errCertificateVerifyNoCertificate
    case errCipherSuiteNoIntersection
    case errCipherSuiteUnset
    case errClientCertificateNotVerified
    case errClientCertificateRequired
    case errClientNoMatchingSrtpProfile
    case errClientRequiredButNoServerEms
    case errCompressionMethodUnset
    case errCookieMismatch
    case errCookieTooLong
    case errIdentityNoPsk
    case errInvalidCertificate
    case errInvalidCipherSpec
    case errInvalidCipherSuite
    case errInvalidClientKeyExchange
    case errInvalidCompressionMethod
    case errInvalidEcdsasignature
    case errInvalidEllipticCurveType
    case errInvalidExtensionType
    case errInvalidHashAlgorithm
    case errInvalidNamedCurve
    case errInvalidPrivateKey
    case errNamedCurveAndPrivateKeyMismatch
    case errInvalidSniFormat
    case errInvalidSignatureAlgorithm
    case errKeySignatureMismatch
    case errNilNextConn
    case errNoAvailableCipherSuites
    case errNoAvailableSignatureSchemes
    case errNoCertificates
    case errNoConfigProvided
    case errNoSupportedEllipticCurves
    case errUnsupportedProtocolVersion
    case errPskAndCertificate
    case errPskAndIdentityMustBeSetForClient
    case errRequestedButNoSrtpExtension
    case errServerMustHaveCertificate
    case errServerNoMatchingSrtpProfile
    case errServerRequiredButNoClientEms
    case errVerifyDataMismatch
    case errHandshakeMessageUnset
    case errInvalidFlight
    case errKeySignatureGenerateUnimplemented
    case errKeySignatureVerifyUnimplemented
    case errLengthMismatch
    case errNotEnoughRoomForNonce
    case errNotImplemented
    case errSequenceNumberOverflow
    case errUnableToMarshalFragmented
    case errInvalidFsmTransition
    case errApplicationDataEpochZero
    case errUnhandledContextType
    case errContextCanceled
    case errEmptyFragment
    case errAlertFatalOrClose
    case errFragmentBufferOverflow
    case errClientTransportNotSet
    case errEndpointStopping
    case errTooManyConnections
    case errInvalidDnsName(String)
    case errInvalidRemoteAddress
    case errNoClientConfig
    case errNoServerConfig
}

extension DtlsError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .errConnClosed:
            return "conn is closed"
        case .errDeadlineExceeded:
            return "read/write timeout"
        case .errContextUnsupported:
            return "context is not supported for export_keying_material"
        case .errDtlspacketInvalidLength:
            return "packet is too short"
        case .errHandshakeInProgress:
            return "handshake is in progress"
        case .errInvalidContentType:
            return "invalid content type"
        case .errInvalidMac:
            return "invalid mac"
        case .errInvalidPacketLength:
            return "packet length and declared length do not match"
        case .errReservedExportKeyingMaterial:
            return "export_keying_material can not be used with a reserved label"
        case .errCertificateVerifyNoCertificate:
            return "client sent certificate verify but we have no certificate to verify"
        case .errCipherSuiteNoIntersection:
            return "client+server do not support any shared cipher suites"
        case .errCipherSuiteUnset:
            return "server hello can not be created without a cipher suite"
        case .errClientCertificateNotVerified:
            return "client sent certificate but did not verify it"
        case .errClientCertificateRequired:
            return "server required client verification but got none"
        case .errClientNoMatchingSrtpProfile:
            return "server responded with SRTP Profile we do not support"
        case .errClientRequiredButNoServerEms:
            return "client required Extended Master Secret extension but server does not support it"
        case .errCompressionMethodUnset:
            return "server hello can not be created without a compression method"
        case .errCookieMismatch:
            return "client+server cookie does not match"
        case .errCookieTooLong:
            return "cookie must not be longer then 255 bytes"
        case .errIdentityNoPsk:
            return "PSK Identity Hint provided but PSK is nil"
        case .errInvalidCertificate:
            return "no certificate provided"
        case .errInvalidCipherSpec:
            return "cipher spec invalid"
        case .errInvalidCipherSuite:
            return "invalid or unknown cipher suite"
        case .errInvalidClientKeyExchange:
            return "unable to determine if ClientKeyExchange is a public key or PSK Identity"
        case .errInvalidCompressionMethod:
            return "invalid or unknown compression method"
        case .errInvalidEcdsasignature:
            return "ECDSA signature contained zero or negative values"
        case .errInvalidEllipticCurveType:
            return "invalid or unknown elliptic curve type"
        case .errInvalidExtensionType:
            return "invalid extension type"
        case .errInvalidHashAlgorithm:
            return "invalid hash algorithm"
        case .errInvalidNamedCurve:
            return "invalid named curve"
        case .errInvalidPrivateKey:
            return "invalid private key type"
        case .errNamedCurveAndPrivateKeyMismatch:
            return "named curve and private key type does not match"
        case .errInvalidSniFormat:
            return "invalid server name format"
        case .errInvalidSignatureAlgorithm:
            return "invalid signature algorithm"
        case .errKeySignatureMismatch:
            return "expected and actual key signature do not match"
        case .errNilNextConn:
            return "Conn can not be created with a nil nextConn"
        case .errNoAvailableCipherSuites:
            return "connection can not be created no CipherSuites satisfy this Config"
        case .errNoAvailableSignatureSchemes:
            return "connection can not be created no SignatureScheme satisfy this Config"
        case .errNoCertificates:
            return "no certificates configured"
        case .errNoConfigProvided:
            return "no config provided"
        case .errNoSupportedEllipticCurves:
            return
                "client requested zero or more elliptic curves that are not supported by the server"
        case .errUnsupportedProtocolVersion:
            return "unsupported protocol version"
        case .errPskAndCertificate:
            return "Certificate and PSK provided"
        case .errPskAndIdentityMustBeSetForClient:
            return "PSK and PSK Identity Hint must both be set for client"
        case .errRequestedButNoSrtpExtension:
            return "SRTP support was requested but server did not respond with use_srtp extension"
        case .errServerMustHaveCertificate:
            return "Certificate is mandatory for server"
        case .errServerNoMatchingSrtpProfile:
            return "client requested SRTP but we have no matching profiles"
        case .errServerRequiredButNoClientEms:
            return
                "server requires the Extended Master Secret extension but the client does not support it"
        case .errVerifyDataMismatch:
            return "expected and actual verify data does not match"
        case .errHandshakeMessageUnset:
            return "handshake message unset unable to marshal"
        case .errInvalidFlight:
            return "invalid flight number"
        case .errKeySignatureGenerateUnimplemented:
            return "unable to generate key signature unimplemented"
        case .errKeySignatureVerifyUnimplemented:
            return "unable to verify key signature unimplemented"
        case .errLengthMismatch:
            return "data length and declared length do not match"
        case .errNotEnoughRoomForNonce:
            return "buffer not long enough to contain nonce"
        case .errNotImplemented:
            return "feature has not been implemented yet"
        case .errSequenceNumberOverflow:
            return "sequence number overflow"
        case .errUnableToMarshalFragmented:
            return "unable to marshal fragmented handshakes"
        case .errInvalidFsmTransition:
            return "invalid state machine transition"
        case .errApplicationDataEpochZero:
            return "ApplicationData with epoch of 0"
        case .errUnhandledContextType:
            return "unhandled contentType"
        case .errContextCanceled:
            return "context canceled"
        case .errEmptyFragment:
            return "empty fragment"
        case .errAlertFatalOrClose:
            return "Alert is Fatal or Close Notify"
        case .errFragmentBufferOverflow:
            return "Fragment buffer overflow. New size is greater than specified max"
        case .errClientTransportNotSet:
            return "Client transport is not set yet"
        case .errEndpointStopping:
            return "endpoint stopping"
        case .errTooManyConnections:
            return "too many connections"
        case .errInvalidDnsName(let dns):
            return "invalid DNS name: \(dns)"
        case .errInvalidRemoteAddress:
            return "invalid remote address"
        case .errNoClientConfig:
            return "no client config"
        case .errNoServerConfig:
            return "no server config"
        }
    }
}
