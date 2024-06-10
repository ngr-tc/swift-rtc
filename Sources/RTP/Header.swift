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

public let headerLength: Int = 4
public let versionShift: UInt8 = 6
public let versionMask: UInt8 = 0x3
public let paddingShift: UInt8 = 5
public let paddingMask: UInt8 = 0x1
public let extensionShift: UInt8 = 4
public let extensionMask: UInt8 = 0x1
public let extensionProfileOneByte: UInt16 = 0xBEDE
public let extensionProfileTwoByte: UInt16 = 0x1000
public let extensionIdReserved: UInt8 = 0xF
public let ccMask: UInt8 = 0xF
public let markerShift: UInt8 = 7
public let markerMask: UInt8 = 0x1
public let ptMask: UInt8 = 0x7F
public let seqNumOffset: Int = 2
public let seqNumLength: Int = 2
public let timestampOffset: Int = 4
public let timestampLength: Int = 4
public let ssrcOffset: Int = 8
public let ssrcLength: Int = 4
public let csrcOffset: Int = 12
public let csrcLength: Int = 4

/// A generic RTP header extension.
public protocol HeaderExtension: Marshal {
    func uri() -> String
}

public struct Extension: Equatable {
    public var id: UInt8
    public var payload: ByteBuffer
}

/// Header represents an RTP packet header
/// NOTE: PayloadOffset is populated by Marshal/Unmarshal and should not be modified
public struct Header: Equatable {
    public var version: UInt8
    public var padding: Bool
    public var ext: Bool
    public var marker: Bool
    public var payloadType: UInt8
    public var sequenceNumber: UInt16
    public var timestamp: UInt32
    public var ssrc: UInt32
    public var csrcs: [UInt32]
    public var extensionProfile: UInt16
    public var extensions: [Extension]

    public func getExtensionPayloadLen() -> Int {
        let payloadLen: Int = self
            .extensions.reduce(
                0,
                { sum, ext in
                    sum + ext.payload.readableBytes
                })

        var bytes = 0
        switch self.extensionProfile {
        case extensionProfileOneByte:
            bytes = 1
        case extensionProfileTwoByte:
            bytes = 2
        default:
            bytes = 0
        }
        let profileLen = self.extensions.count * bytes

        return payloadLen + profileLen
    }

    /// SetExtension sets an RTP header extension
    public mutating func setExtension(id: UInt8, payload: ByteBuffer) throws {
        if self.ext {
            switch self.extensionProfile {
            case extensionProfileOneByte:
                if !(1...14).contains(id) {
                    throw RtpError.errRfc8285oneByteHeaderIdrange
                }
                if payload.readableBytes > 16 {
                    throw RtpError.errRfc8285oneByteHeaderSize
                }
            case extensionProfileTwoByte:
                if id < 1 {
                    throw RtpError.errRfc8285twoByteHeaderIdrange
                }
                if payload.readableBytes > 255 {
                    throw RtpError.errRfc8285twoByteHeaderSize
                }
            default:
                if id != 0 {
                    throw RtpError.errRfc3550headerIdrange
                }
            }

            // Update existing if it exists else add new extension
            if let i = self
                .extensions.firstIndex(where: { $0.id == id })
            {
                self.extensions[i].payload = payload
            } else {
                self.extensions.append(Extension(id: id, payload: payload))
            }
        } else {
            // No existing header extensions
            self.ext = true

            switch payload.readableBytes {
            case 0...16:
                self.extensionProfile = extensionProfileOneByte
            case 17...255:
                self.extensionProfile = extensionProfileTwoByte
            default:
                break
            }

            self.extensions.append(Extension(id: id, payload: payload))
        }
    }

    /// returns an extension id array
    public func getExtensionIds() -> [UInt8] {
        if self.ext {
            return self.extensions.map { $0.id }
        } else {
            return []
        }
    }

    /// returns an RTP header extension
    public func getExtension(id: UInt8) -> ByteBuffer? {
        if self.ext,
            let i = self.extensions
                .firstIndex(where: { $0.id == id })
        {
            return self.extensions[i].payload
        } else {
            return nil
        }
    }

    /// Removes an RTP Header extension
    public mutating func delExtension(id: UInt8) throws {
        if self.ext {
            if let i = self
                .extensions.firstIndex(where: { $0.id == id })
            {
                self.extensions.remove(at: i)
            } else {
                throw RtpError.errHeaderExtensionNotFound
            }
        } else {
            throw RtpError.errHeaderExtensionsNotEnabled
        }
    }
}

extension Header: Unmarshal {
    /// Unmarshal parses the passed byte slice and stores the result in the Header this method is called upon
    public init(_ buf: ByteBuffer) throws {
        let bufLen = buf.readableBytes
        if bufLen < headerLength {
            throw RtpError.errHeaderSizeInsufficient
        }
        /*
         *  0                   1                   2                   3
         *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |V=2|P|X|  CC   |M|     PT      |       sequence number         |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |                           timestamp                           |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |           synchronization source (SSRC) identifier            |
         * +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * |            contributing source (CSRC) identifiers             |
         * |                             ....                              |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        var reader = buf.slice()
        guard let b0: UInt8 = reader.readInteger() else {
            throw RtpError.errHeaderSizeInsufficient
        }
        let version = b0 >> versionShift & versionMask
        let padding = (b0 >> paddingShift & paddingMask) > 0
        let ext = (b0 >> extensionShift & extensionMask) > 0
        let cc = Int(b0 & ccMask)

        var currOffset = csrcOffset + (cc * csrcLength)
        if bufLen < currOffset {
            throw RtpError.errHeaderSizeInsufficient
        }

        guard let b1: UInt8 = reader.readInteger() else {
            throw RtpError.errHeaderSizeInsufficient
        }
        let marker = (b1 >> markerShift & markerMask) > 0
        let payloadType = b1 & ptMask

        guard let sequenceNumber: UInt16 = reader.readInteger() else {
            throw RtpError.errHeaderSizeInsufficient
        }
        guard let timestamp: UInt32 = reader.readInteger() else {
            throw RtpError.errHeaderSizeInsufficient
        }
        guard let ssrc: UInt32 = reader.readInteger() else {
            throw RtpError.errHeaderSizeInsufficient
        }

        var csrcs: [UInt32] = []
        for _ in 0..<cc {
            guard let csrc: UInt32 = reader.readInteger() else {
                throw RtpError.errHeaderSizeInsufficient
            }
            csrcs.append(csrc)
        }

        var extensionProfile: UInt16
        var extensions: [Extension]
        if ext {
            var expected = currOffset + 4
            if bufLen < expected {
                throw RtpError.errHeaderSizeInsufficientForExtension
            }
            guard let profile: UInt16 = reader.readInteger() else {
                throw RtpError.errHeaderSizeInsufficient
            }
            currOffset += 2
            guard let length: UInt16 = reader.readInteger() else {
                throw RtpError.errHeaderSizeInsufficient
            }
            let extensionLength = Int(length) * 4
            currOffset += 2

            expected = currOffset + extensionLength
            if bufLen < expected {
                throw RtpError.errHeaderSizeInsufficientForExtension
            }

            var exts: [Extension] = []
            switch profile {
            // RFC 8285 RTP One Byte Header Extension
            case extensionProfileOneByte:
                let end = currOffset + extensionLength
                while currOffset < end {
                    guard let b: UInt8 = reader.readInteger() else {
                        throw RtpError.errHeaderSizeInsufficient
                    }
                    if b == 0x00 {
                        // padding
                        currOffset += 1
                        continue
                    }

                    let extid = b >> 4
                    let len = Int((b & (0xFF ^ 0xF0)) + 1)
                    currOffset += 1

                    if extid == extensionIdReserved {
                        break
                    }

                    guard let payload = reader.readSlice(length: len) else {
                        throw RtpError.errHeaderSizeInsufficient
                    }
                    exts.append(
                        Extension(
                            id: extid,
                            payload: payload
                        ))
                    currOffset += len
                }
            // RFC 8285 RTP Two Byte Header Extension
            case extensionProfileTwoByte:
                let end = currOffset + extensionLength
                while currOffset < end {
                    guard let b: UInt8 = reader.readInteger() else {
                        throw RtpError.errHeaderSizeInsufficient
                    }
                    if b == 0x00 {
                        // padding
                        currOffset += 1
                        continue
                    }

                    let extid = b
                    currOffset += 1

                    guard let len: UInt8 = reader.readInteger() else {
                        throw RtpError.errHeaderSizeInsufficient
                    }
                    currOffset += 1

                    guard let payload = reader.readSlice(length: Int(len)) else {
                        throw RtpError.errHeaderSizeInsufficient
                    }
                    exts.append(
                        Extension(
                            id: extid,
                            payload: payload
                        ))
                    currOffset += Int(len)
                }

            // RFC3550 Extension
            default:
                if bufLen < currOffset + extensionLength {
                    throw RtpError.errHeaderSizeInsufficientForExtension
                }
                guard let payload = reader.readSlice(length: extensionLength) else {
                    throw RtpError.errHeaderSizeInsufficient
                }
                exts.append(
                    Extension(
                        id: 0,
                        payload: payload
                    ))
            }

            extensionProfile = profile
            extensions = exts
        } else {
            extensionProfile = 0
            extensions = []
        }

        self.version = version
        self.padding = padding
        self.ext = ext
        self.marker = marker
        self.payloadType = payloadType
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.ssrc = ssrc
        self.csrcs = csrcs
        self.extensionProfile = extensionProfile
        self.extensions = extensions
    }
}

extension Header: MarshalSize {
    /// MarshalSize returns the size of the packet once marshaled.
    public func marshalSize() -> Int {
        var headSize = 12 + (self.csrcs.count * csrcLength)
        if self.ext {
            let extensionPayloadLen = self.getExtensionPayloadLen()
            let extensionPayloadSize = (extensionPayloadLen + 3) / 4
            headSize += 4 + extensionPayloadSize * 4
        }
        return headSize
    }
}

extension Header: Marshal {
    /// Marshal serializes the header and writes to the buffer.
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        /*
         *  0                   1                   2                   3
         *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |V=2|P|X|  CC   |M|     PT      |       sequence number         |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |                           timestamp                           |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |           synchronization source (SSRC) identifier            |
         * +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
         * |            contributing source (CSRC) identifiers             |
         * |                             ....                              |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */

        // The first byte contains the version, padding bit, extension bit, and csrc size
        var b0 = (self.version << versionShift) | UInt8(self.csrcs.count)
        if self.padding {
            b0 |= 1 << paddingShift
        }

        if self.ext {
            b0 |= 1 << extensionShift
        }
        buf.writeRepeatingByte(b0, count: 1)

        // The second byte contains the marker bit and payload type.
        var b1 = self.payloadType
        if self.marker {
            b1 |= 1 << markerShift
        }
        buf.writeInteger(b1)

        buf.writeInteger(self.sequenceNumber)
        buf.writeInteger(self.timestamp)
        buf.writeInteger(self.ssrc)

        for csrc in self.csrcs {
            buf.writeInteger(csrc)
        }

        if self.ext {
            buf.writeInteger(self.extensionProfile)

            // calculate extensions size and round to 4 bytes boundaries
            let extensionPayloadLen = self.getExtensionPayloadLen()
            if self.extensionProfile != extensionProfileOneByte
                && self.extensionProfile != extensionProfileTwoByte
                && extensionPayloadLen % 4 != 0
            {
                //the payload must be in 32-bit words.
                throw RtpError.errHeaderExtensionPayloadNot32BitWords
            }
            let extensionPayloadSize = (UInt16(extensionPayloadLen) + 3) / 4
            buf.writeInteger(extensionPayloadSize)

            switch self.extensionProfile {
            // RFC 8285 RTP One Byte Header Extension
            case extensionProfileOneByte:
                for ext in self.extensions {
                    buf.writeInteger((ext.id << 4) | (UInt8(ext.payload.readableBytes) - 1))
                    buf.writeImmutableBuffer(ext.payload)
                }

            // RFC 8285 RTP Two Byte Header Extension
            case extensionProfileTwoByte:
                for ext in self.extensions {
                    buf.writeInteger(ext.id)
                    buf.writeInteger(UInt8(ext.payload.readableBytes))
                    buf.writeImmutableBuffer(ext.payload)
                }

            // RFC3550 Extension
            default:
                if self.extensions.count != 1 {
                    throw RtpError.errRfc3550headerIdrange
                }

                if let ext = self.extensions.first {
                    let extLen = ext.payload.readableBytes
                    if extLen % 4 != 0 {
                        throw RtpError.errHeaderExtensionPayloadNot32BitWords
                    }
                    buf.writeImmutableBuffer(ext.payload)
                }

            }

            // add padding to reach 4 bytes boundaries
            for _ in extensionPayloadLen..<Int(extensionPayloadSize) * 4 {
                buf.writeInteger(UInt8(0))
            }
        }

        return buf.readableBytes
    }
}
