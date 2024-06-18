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

/// ProtectionProfile specifies Cipher and AuthTag details, similar to TLS cipher suite
public enum ProtectionProfile: UInt16, Equatable {
    case aes128CmHmacSha1Tag80 = 0x0001
    case aes128CmHmacSha1Tag32 = 0x0002
    case aeadAes128Gcm = 0x0007
    case aeadAes256Gcm = 0x0008

    func keyLen() -> Int {
        switch self {
        case .aes128CmHmacSha1Tag32, .aes128CmHmacSha1Tag80, .aeadAes128Gcm:
            return 16
        case .aeadAes256Gcm:
            return 32
        }
    }

    func saltLen() -> Int {
        switch self {
        case .aes128CmHmacSha1Tag32, .aes128CmHmacSha1Tag80:
            return 14
        case .aeadAes128Gcm, .aeadAes256Gcm:
            return 12
        }
    }

    func rtpAuthTagLen() -> Int {
        switch self {
        case .aes128CmHmacSha1Tag80:
            return 10
        case .aes128CmHmacSha1Tag32:
            return 4
        case .aeadAes128Gcm, .aeadAes256Gcm:
            return 0
        }
    }

    func rtcpAuthTagLen() -> Int {
        switch self {
        case .aes128CmHmacSha1Tag32, .aes128CmHmacSha1Tag80:
            return 10
        case .aeadAes128Gcm, .aeadAes256Gcm:
            return 0
        }
    }

    func aeadAuthTagLen() -> Int {
        switch self {
        case .aes128CmHmacSha1Tag32, .aes128CmHmacSha1Tag80:
            return 0
        case .aeadAes128Gcm, .aeadAes256Gcm:
            return 16
        }
    }

    func authKeyLen() -> Int {
        switch self {
        case .aes128CmHmacSha1Tag32, .aes128CmHmacSha1Tag80:
            return 20
        case .aeadAes128Gcm, .aeadAes256Gcm:
            return 0
        }
    }
}
