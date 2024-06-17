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
    case aes128CmHmacSha180 = 0x0001
    case aeadAes128Gcm = 0x0007

    func keyLen() -> Int {
        switch self {
        case ProtectionProfile.aes128CmHmacSha180, ProtectionProfile.aeadAes128Gcm:
            return 16
        }
    }

    func saltLen() -> Int {
        switch self {
        case ProtectionProfile.aes128CmHmacSha180:
            return 14
        case ProtectionProfile.aeadAes128Gcm:
            return 12
        }
    }

    func authTagLen() -> Int {
        switch self {
        case ProtectionProfile.aes128CmHmacSha180:
            return 10  //CIPHER_AES_CM_HMAC_SHA1AUTH_TAG_LEN,
        case ProtectionProfile.aeadAes128Gcm:
            return 16  //CIPHER_AEAD_AES_GCM_AUTH_TAG_LEN,
        }
    }

    func authKeyLen() -> Int {
        switch self {
        case ProtectionProfile.aes128CmHmacSha180:
            return 20
        case ProtectionProfile.aeadAes128Gcm:
            return 0
        }
    }
}
