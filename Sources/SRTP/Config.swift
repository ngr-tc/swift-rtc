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

let labelExtractorDtlsSrtp: String = "EXTRACTOR-dtls_srtp"

/// SessionKeys bundles the keys required to setup an SRTP session
public struct SessionKeys {
    public var localMasterKey: ByteBuffer
    public var localMasterSalt: ByteBuffer
    public var remoteMasterKey: ByteBuffer
    public var remoteMasterSalt: ByteBuffer
}

/// Config is used to configure a session.
/// You can provide either a KeyingMaterialExporter to export keys
/// or directly pass the keys themselves.
/// After a Config is passed to a session it must not be modified.
public struct Config {
    public var keys: SessionKeys
    public var profile: ProtectionProfile
    //LoggerFactory: logging.LoggerFactory
    /// List of local/remote context options.
    /// ReplayProtection is enabled on remote context by default.
    /// Default replay protection window size is 64.
    public var localRtpOptions: ContextOption?
    public var remoteRtpOptions: ContextOption?

    public var localRtcpOptions: ContextOption?
    public var remoteRtcpOptions: ContextOption?

    /// ExtractSessionKeysFromDTLS allows setting the Config SessionKeys by
    /// extracting them from DTLS. This behavior is defined in RFC5764:
    /// https://tools.ietf.org/html/rfc5764
    public mutating func extractSessionKeysFromDtls(
        exporter: KeyingMaterialExporter,
        isClient: Bool
    ) throws {
        let keyLen = self.profile.keyLen()
        let saltLen = self.profile.saltLen()

        let keyingMaterial = try exporter.exportKeyingMaterial(
            label: labelExtractorDtlsSrtp,
            context: ByteBufferView(),
            length: (keyLen * 2) + (saltLen * 2)
        )

        var offset = 0
        guard let clientWriteKey = keyingMaterial.getSlice(at: offset, length: keyLen) else {
            throw SrtpError.errTooShortKeyingMaterial
        }
        offset += keyLen

        guard let serverWriteKey = keyingMaterial.getSlice(at: offset, length: keyLen) else {
            throw SrtpError.errTooShortKeyingMaterial
        }
        offset += keyLen

        guard let clientWriteSalt = keyingMaterial.getSlice(at: offset, length: saltLen) else {
            throw SrtpError.errTooShortKeyingMaterial
        }
        offset += saltLen

        guard let serverWriteSalt = keyingMaterial.getSlice(at: offset, length: saltLen) else {
            throw SrtpError.errTooShortKeyingMaterial
        }

        if isClient {
            self.keys.localMasterKey = clientWriteKey
            self.keys.localMasterSalt = clientWriteSalt
            self.keys.remoteMasterKey = serverWriteKey
            self.keys.remoteMasterSalt = serverWriteSalt
        } else {
            self.keys.localMasterKey = serverWriteKey
            self.keys.localMasterSalt = serverWriteSalt
            self.keys.remoteMasterKey = clientWriteKey
            self.keys.remoteMasterSalt = clientWriteSalt
        }
    }
}
