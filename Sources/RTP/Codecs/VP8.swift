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

public let vp8HeaderSize: Int = 1

/// Vp8Payloader payloads VP8 packets
public struct Vp8Payloader {
    public var enablePictureId: Bool
    var pictureId: UInt16
    
    public init() {
        self.enablePictureId = false
        self.pictureId = 0
    }
    
    public init(enablePictureId: Bool, pictureId: UInt16) {
        self.enablePictureId = enablePictureId
        self.pictureId = pictureId
    }
}

extension Vp8Payloader: Payloader {
    /// Payload fragments a VP8 packet across one or more byte arrays
    public mutating func payload(mtu: Int, buf: inout ByteBuffer) throws -> [ByteBuffer] {
        if buf.readableBytes == 0 || mtu == 0 {
            return []
        }

        /*
         * https://tools.ietf.org/html/rfc7741#section-4.2
         *
         *       0 1 2 3 4 5 6 7
         *      +-+-+-+-+-+-+-+-+
         *      |X|R|N|S|R| PID | (REQUIRED)
         *      +-+-+-+-+-+-+-+-+
         * X:   |I|L|T|K| RSV   | (OPTIONAL)
         *      +-+-+-+-+-+-+-+-+
         * I:   |M| PictureID   | (OPTIONAL)
         *      +-+-+-+-+-+-+-+-+
         * L:   |   tl0picidx   | (OPTIONAL)
         *      +-+-+-+-+-+-+-+-+
         * T/K: |tid|Y| KEYIDX  | (OPTIONAL)
         *      +-+-+-+-+-+-+-+-+
         *  S: Start of VP8 partition.  SHOULD be set to 1 when the first payload
         *     octet of the RTP packet is the beginning of a new VP8 partition,
         *     and MUST NOT be 1 otherwise.  The S bit MUST be set to 1 for the
         *     first packet of each encoded frame.
         */
        var usingHeaderSize = vp8HeaderSize
        if self.enablePictureId {
            if self.pictureId == 0 || self.pictureId < 128 {
                usingHeaderSize = vp8HeaderSize + 2
            } else {
                usingHeaderSize = vp8HeaderSize + 3
            }
        }

        let maxFragmentSize = mtu - usingHeaderSize
        var payloadDataRemaining = buf.readableBytes
        var payloadDataIndex = 0
        var payloads: [ByteBuffer] = []

        // Make sure the fragment/payload size is correct
        if min(maxFragmentSize, payloadDataRemaining) <= 0 {
            return payloads
        }

        var first = true
        while payloadDataRemaining > 0 {
            let currentFragmentSize = min(maxFragmentSize, payloadDataRemaining)
            var out = ByteBuffer()
            var b: [UInt8] = Array(repeating: 0, count: 4)
            if first {
                b[0] = 0x10
                first = false
            }

            if self.enablePictureId {
                if usingHeaderSize == vp8HeaderSize + 2 {
                    b[0] |= 0x80
                    b[1] |= 0x80
                    b[2] |= UInt8(self.pictureId & 0x7F)
                } else if usingHeaderSize == vp8HeaderSize + 3 {
                    b[0] |= 0x80
                    b[1] |= 0x80
                    b[2] |= 0x80 | UInt8((self.pictureId >> 8) & 0x7F)
                    b[3] |= UInt8(self.pictureId & 0xFF)
                }
            }

            out.writeBytes(b[..<usingHeaderSize])

            guard let subBuf = buf.getSlice(at: payloadDataIndex, length: currentFragmentSize)
            else {
                throw RtpError.errBufferTooSmall
            }
            out.writeImmutableBuffer(subBuf)
            payloads.append(out)

            payloadDataRemaining -= currentFragmentSize
            payloadDataIndex += currentFragmentSize
        }

        self.pictureId += 1
        self.pictureId &= 0x7FFF

        return payloads
    }
}

/// Vp8Packet represents the VP8 header that is stored in the payload of an RTP Packet
public struct Vp8Packet: Equatable {
    /// Required Header
    /// extended controlbits present
    public var x: UInt8
    /// when set to 1 this frame can be discarded
    public var n: UInt8
    /// start of VP8 partition
    public var s: UInt8
    /// partition index
    public var pid: UInt8

    /// Extended control bits
    /// 1 if PictureID is present
    public var i: UInt8
    /// 1 if tl0picidx is present
    public var l: UInt8
    /// 1 if tid is present
    public var t: UInt8
    /// 1 if KEYIDX is present
    public var k: UInt8

    /// Optional extension
    /// 8 or 16 bits, picture ID
    public var pictureId: UInt16
    /// 8 bits temporal level zero index
    public var tl0PicIdx: UInt8
    /// 2 bits temporal layer index
    public var tid: UInt8
    /// 1 bit layer sync bit
    public var y: UInt8
    /// 5 bits temporal key frame index
    public var keyIdx: UInt8

    public init() {
        self.x = 0
        self.n = 0
        self.s = 0
        self.pid = 0
        self.i = 0
        self.l = 0
        self.t = 0
        self.k = 0
        self.pictureId = 0
        self.tl0PicIdx = 0
        self.tid = 0
        self.y = 0
        self.keyIdx = 0
    }
}

extension Vp8Packet: Depacketizer {
    /// depacketize parses the passed byte slice and stores the result in the VP8Packet this method is called upon
    public mutating func depacketize(buf: inout ByteBuffer) throws -> ByteBuffer {
        let payloadLen = buf.readableBytes
        if payloadLen < 4 {
            throw RtpError.errShortPacket
        }

        //    0 1 2 3 4 5 6 7                      0 1 2 3 4 5 6 7
        //    +-+-+-+-+-+-+-+-+                   +-+-+-+-+-+-+-+-+
        //    |X|R|N|S|R| PID | (REQUIRED)        |X|R|N|S|R| PID | (REQUIRED)
        //    +-+-+-+-+-+-+-+-+                   +-+-+-+-+-+-+-+-+
        // X: |I|L|T|K| RSV   | (OPTIONAL)   X:   |I|L|T|K| RSV   | (OPTIONAL)
        //    +-+-+-+-+-+-+-+-+                   +-+-+-+-+-+-+-+-+
        // I: |M| PictureID   | (OPTIONAL)   I:   |M| PictureID   | (OPTIONAL)
        //    +-+-+-+-+-+-+-+-+                   +-+-+-+-+-+-+-+-+
        // L: |   tl0picidx   | (OPTIONAL)        |   PictureID   |
        //    +-+-+-+-+-+-+-+-+                   +-+-+-+-+-+-+-+-+
        //T/K:|tid|Y| KEYIDX  | (OPTIONAL)   L:   |   tl0picidx   | (OPTIONAL)
        //    +-+-+-+-+-+-+-+-+                   +-+-+-+-+-+-+-+-+
        //T/K:|tid|Y| KEYIDX  | (OPTIONAL)
        //    +-+-+-+-+-+-+-+-+

        var reader = buf.slice()
        var payloadIndex = 0

        guard let b: UInt8 = reader.readInteger() else {
            throw RtpError.errShortPacket
        }
        payloadIndex += 1

        self.x = (b & 0x80) >> 7
        self.n = (b & 0x20) >> 5
        self.s = (b & 0x10) >> 4
        self.pid = b & 0x07

        if self.x == 1 {
            guard let b: UInt8 = reader.readInteger() else {
                throw RtpError.errShortPacket
            }
            payloadIndex += 1
            self.i = (b & 0x80) >> 7
            self.l = (b & 0x40) >> 6
            self.t = (b & 0x20) >> 5
            self.k = (b & 0x10) >> 4
        }

        if self.i == 1 {
            guard let b: UInt8 = reader.readInteger() else {
                throw RtpError.errShortPacket
            }
            payloadIndex += 1
            // PID present?
            if b & 0x80 > 0 {
                // M == 1, PID is 16bit
                guard let p: UInt8 = reader.readInteger() else {
                    throw RtpError.errShortPacket
                }
                self.pictureId = ((UInt16(b & 0x7f)) << 8) | UInt16(p)
                payloadIndex += 1
            } else {
                self.pictureId = UInt16(b)
            }
        }

        if payloadIndex >= payloadLen {
            throw RtpError.errShortPacket
        }

        if self.l == 1 {
            guard let b: UInt8 = reader.readInteger() else {
                throw RtpError.errShortPacket
            }
            self.tl0PicIdx = b
            payloadIndex += 1
        }

        if payloadIndex >= payloadLen {
            throw RtpError.errShortPacket
        }

        if self.t == 1 || self.k == 1 {
            guard let b: UInt8 = reader.readInteger() else {
                throw RtpError.errShortPacket
            }
            if self.t == 1 {
                self.tid = b >> 6
                self.y = (b >> 5) & 0x1
            }
            if self.k == 1 {
                self.keyIdx = b & 0x1F
            }
            payloadIndex += 1
        }

        if payloadIndex >= payloadLen {
            throw RtpError.errShortPacket
        }

        guard let subBuf = buf.getSlice(at: payloadIndex, length: payloadLen - payloadIndex)
        else {
            throw RtpError.errShortPacket
        }

        return subBuf
    }

    /// is_partition_head checks whether if this is a head of the VP8 partition
    public func isPartitionHead(payload: inout ByteBuffer) -> Bool {
        guard let b = payload.getBytes(at: 0, length: 1) else {
            return false
        }
        return (b[0] & 0x10) != 0
    }

    public func isPartitionTail(marker: Bool, payload: inout ByteBuffer) -> Bool {
        return marker
    }
}
