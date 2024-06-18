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
import XCTest

@testable import SRTP

final class CipherAeadAesGcmTests: XCTestCase {
    /*
     func TestSrtpCipherAedAes128Gcm(t *testing.T) {
         decryptedRTPPacket := []byte{
             0x80, 0x0f, 0x12, 0x34, 0xde, 0xca, 0xfb, 0xad,
             0xca, 0xfe, 0xba, 0xbe, 0xab, 0xab, 0xab, 0xab,
             0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab,
             0xab, 0xab, 0xab, 0xab,
         }
         encryptedRTPPacket := []byte{
             0x80, 0x0f, 0x12, 0x34, 0xde, 0xca, 0xfb, 0xad,
             0xca, 0xfe, 0xba, 0xbe, 0xc5, 0x00, 0x2e, 0xde,
             0x04, 0xcf, 0xdd, 0x2e, 0xb9, 0x11, 0x59, 0xe0,
             0x88, 0x0a, 0xa0, 0x6e, 0xd2, 0x97, 0x68, 0x26,
             0xf7, 0x96, 0xb2, 0x01, 0xdf, 0x31, 0x31, 0xa1,
             0x27, 0xe8, 0xa3, 0x92,
         }
         decryptedRtcpPacket := []byte{
             0x81, 0xc8, 0x00, 0x0b, 0xca, 0xfe, 0xba, 0xbe,
             0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab,
             0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab,
         }
         encryptedRtcpPacket := []byte{
             0x81, 0xc8, 0x00, 0x0b, 0xca, 0xfe, 0xba, 0xbe,
             0xc9, 0x8b, 0x8b, 0x5d, 0xf0, 0x39, 0x2a, 0x55,
             0x85, 0x2b, 0x6c, 0x21, 0xac, 0x8e, 0x70, 0x25,
             0xc5, 0x2c, 0x6f, 0xbe, 0xa2, 0xb3, 0xb4, 0x46,
             0xea, 0x31, 0x12, 0x3b, 0xa8, 0x8c, 0xe6, 0x1e,
             0x80, 0x00, 0x00, 0x01,
         }

         masterKey := []byte{0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f}
         masterSalt := []byte{0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab}

         t.Run("Encrypt RTP", func(t *testing.T) {
             ctx, err := CreateContext(masterKey, masterSalt, ProtectionProfileAeadAes128Gcm)
             assert.NoError(t, err)

             t.Run("New Allocation", func(t *testing.T) {
                 actualEncrypted, err := ctx.EncryptRTP(nil, decryptedRTPPacket, nil)
                 assert.NoError(t, err)
                 assert.Equal(t, encryptedRTPPacket, actualEncrypted)
             })
         })

         t.Run("Decrypt RTP", func(t *testing.T) {
             ctx, err := CreateContext(masterKey, masterSalt, ProtectionProfileAeadAes128Gcm)
             assert.NoError(t, err)

             t.Run("New Allocation", func(t *testing.T) {
                 actualDecrypted, err := ctx.DecryptRTP(nil, encryptedRTPPacket, nil)
                 assert.NoError(t, err)
                 assert.Equal(t, decryptedRTPPacket, actualDecrypted)
             })
         })

         t.Run("Encrypt RTCP", func(t *testing.T) {
             ctx, err := CreateContext(masterKey, masterSalt, ProtectionProfileAeadAes128Gcm)
             assert.NoError(t, err)

             t.Run("New Allocation", func(t *testing.T) {
                 actualEncrypted, err := ctx.EncryptRTCP(nil, decryptedRtcpPacket, nil)
                 assert.NoError(t, err)
                 assert.Equal(t, encryptedRtcpPacket, actualEncrypted)
             })
         })

         t.Run("Decrypt RTCP", func(t *testing.T) {
             ctx, err := CreateContext(masterKey, masterSalt, ProtectionProfileAeadAes128Gcm)
             assert.NoError(t, err)

             t.Run("New Allocation", func(t *testing.T) {
                 actualDecrypted, err := ctx.DecryptRTCP(nil, encryptedRtcpPacket, nil)
                 assert.NoError(t, err)
                 assert.Equal(t, decryptedRtcpPacket, actualDecrypted)
             })
         })
     }

     func TestSrtpCipherAedAes256Gcm(t *testing.T) {
         decryptedRTPPacket := []byte{
             0x80, 0x0f, 0x12, 0x34, 0xde, 0xca, 0xfb, 0xad,
             0xca, 0xfe, 0xba, 0xbe, 0xab, 0xab, 0xab, 0xab,
             0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab,
             0xab, 0xab, 0xab, 0xab,
         }
         encryptedRTPPacket := []byte{
             0x80, 0xf, 0x12, 0x34, 0xde, 0xca, 0xfb, 0xad,
             0xca, 0xfe, 0xba, 0xbe, 0xaf, 0x49, 0x96, 0x8f,
             0x7e, 0x9c, 0x43, 0xf8, 0x01, 0xdd, 0x0c, 0x84,
             0x8b, 0x1e, 0xc9, 0xb0, 0x29, 0xcd, 0xf8, 0x5c,
             0xb7, 0x9a, 0x2f, 0x95, 0x60, 0xd4, 0x69, 0x75,
             0x98, 0x50, 0x77, 0x25,
         }
         decryptedRtcpPacket := []byte{
             0x81, 0xc8, 0x00, 0x0b, 0xca, 0xfe, 0xba, 0xbe,
             0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab,
             0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab, 0xab,
         }
         encryptedRtcpPacket := []byte{
             0x81, 0xc8, 0x00, 0x0b, 0xca, 0xfe, 0xba, 0xbe,
             0x98, 0x22, 0xba, 0x22, 0x96, 0x1c, 0x31, 0x48,
             0xe7, 0xb7, 0xec, 0x4f, 0x09, 0xf4, 0x26, 0xdc,
             0xf6, 0xb5, 0x9a, 0x75, 0xad, 0xec, 0x74, 0xfd,
             0xb9, 0x51, 0xb6, 0x66, 0x84, 0x24, 0xd4, 0xe2,
             0x80, 0x00, 0x00, 0x01,
         }

         masterKey := []byte{0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f}
         masterSalt := []byte{0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab}

         t.Run("Encrypt RTP", func(t *testing.T) {
             ctx, err := CreateContext(masterKey, masterSalt, ProtectionProfileAeadAes256Gcm)
             assert.NoError(t, err)

             t.Run("New Allocation", func(t *testing.T) {
                 actualEncrypted, err := ctx.EncryptRTP(nil, decryptedRTPPacket, nil)
                 assert.NoError(t, err)
                 assert.Equal(t, encryptedRTPPacket, actualEncrypted)
             })
         })

         t.Run("Decrypt RTP", func(t *testing.T) {
             ctx, err := CreateContext(masterKey, masterSalt, ProtectionProfileAeadAes256Gcm)
             assert.NoError(t, err)

             t.Run("New Allocation", func(t *testing.T) {
                 actualDecrypted, err := ctx.DecryptRTP(nil, encryptedRTPPacket, nil)
                 assert.NoError(t, err)
                 assert.Equal(t, decryptedRTPPacket, actualDecrypted)
             })
         })

         t.Run("Encrypt RTCP", func(t *testing.T) {
             ctx, err := CreateContext(masterKey, masterSalt, ProtectionProfileAeadAes256Gcm)
             assert.NoError(t, err)

             t.Run("New Allocation", func(t *testing.T) {
                 actualEncrypted, err := ctx.EncryptRTCP(nil, decryptedRtcpPacket, nil)
                 assert.NoError(t, err)
                 assert.Equal(t, encryptedRtcpPacket, actualEncrypted)
             })
         })

         t.Run("Decrypt RTCP", func(t *testing.T) {
             ctx, err := CreateContext(masterKey, masterSalt, ProtectionProfileAeadAes256Gcm)
             assert.NoError(t, err)

             t.Run("New Allocation", func(t *testing.T) {
                 actualDecrypted, err := ctx.DecryptRTCP(nil, encryptedRtcpPacket, nil)
                 assert.NoError(t, err)
                 assert.Equal(t, decryptedRtcpPacket, actualDecrypted)
             })
         })
     }

     */
}
