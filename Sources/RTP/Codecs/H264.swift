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

public let stapaNaluType: UInt8 = 24
public let fuaNaluType: UInt8 = 28
public let fubNaluType: UInt8 = 29
public let spsNaluType: UInt8 = 7
public let ppsNaluType: UInt8 = 8
public let audNaluType: UInt8 = 9
public let fillerNaluType: UInt8 = 12

public let fuaHeaderSize: Int = 2
public let stapaHeaderSize: Int = 1
public let stapaNaluLengthSize: Int = 2

public let naluTypeBitmask: UInt8 = 0x1F
public let naluRefIdcBitmask: UInt8 = 0x60
public let fuStartBitmask: UInt8 = 0x80
public let fuEndBitmask: UInt8 = 0x40

public let outputStapAHeader: UInt8 = 0x78

public let annexBNaluStartCode: ByteBuffer = ByteBuffer(bytes: [0x00, 0x00, 0x00, 0x01])

/// H264Payloader payloads H264 packets
public struct H264Payloader {
    var spsNalu: ByteBuffer?
    var ppsNalu: ByteBuffer?

    public init(spsNalu: ByteBuffer? = nil, ppsNalu: ByteBuffer? = nil) {
        self.spsNalu = spsNalu
        self.ppsNalu = ppsNalu
    }

    static func nextInd(nalu: ByteBufferView) -> (Int, Int) {
        var zeroCount = 0
        let start = nalu.startIndex

        for (i, b) in nalu[start...].enumerated() {
            if b == 0 {
                zeroCount += 1
                continue
            } else if b == 1 && zeroCount >= 2 {
                return ((start + i - zeroCount), zeroCount + 1)
            }
            zeroCount = 0
        }
        return (-1, -1)
    }

    mutating func emit(nalu: ByteBuffer, mtu: Int, payloads: inout [ByteBuffer]) throws {
        if nalu.readableBytes == 0 {
            return
        }
        guard let b = nalu.getBytes(at: 0, length: 1) else {
            throw RtpError.errBufferTooSmall
        }
        let naluType = b[0] & naluTypeBitmask
        let naluRefIdc = b[0] & naluRefIdcBitmask

        if naluType == audNaluType || naluType == fillerNaluType {
            return
        } else if naluType == spsNaluType {
            self.spsNalu = nalu.slice()
            return
        } else if naluType == ppsNaluType {
            self.ppsNalu = nalu.slice()
            return
        } else if let spsNalu = self.spsNalu, let ppsNalu = self.ppsNalu {
            // Pack current NALU with SPS and PPS as STAP-A
            let spsLen = UInt16(spsNalu.readableBytes).toBeBytes()
            let ppsLen = UInt16(ppsNalu.readableBytes).toBeBytes()

            var stapANalu = ByteBuffer()
            stapANalu.writeRepeatingByte(outputStapAHeader, count: 1)
            stapANalu.writeBytes(spsLen)
            stapANalu.writeImmutableBuffer(spsNalu)
            stapANalu.writeBytes(ppsLen)
            stapANalu.writeImmutableBuffer(ppsNalu)
            if stapANalu.readableBytes <= mtu {
                payloads.append(stapANalu)
            }
        }

        if self.spsNalu != nil && self.ppsNalu != nil {
            self.spsNalu = nil
            self.ppsNalu = nil
        }

        // Single NALU
        if nalu.readableBytes <= mtu {
            payloads.append(nalu.slice())
            return
        }

        // FU-A
        let maxFragmentSize = mtu - fuaHeaderSize

        // The FU payload consists of fragments of the payload of the fragmented
        // NAL unit so that if the fragmentation unit payloads of consecutive
        // FUs are sequentially concatenated, the payload of the fragmented NAL
        // unit can be reconstructed.  The NAL unit type octet of the fragmented
        // NAL unit is not included as such in the fragmentation unit payload,
        //     but rather the information of the NAL unit type octet of the
        // fragmented NAL unit is conveyed in the F and NRI fields of the FU
        // indicator octet of the fragmentation unit and in the type field of
        // the FU header.  An FU payload MAY have any number of octets and MAY
        // be empty.

        let naluData = nalu.slice()
        // According to the RFC, the first octet is skipped due to redundant information
        var naluDataIndex = 1
        let naluDataLength = naluData.readableBytes - naluDataIndex
        var naluDataRemaining = naluDataLength

        if min(maxFragmentSize, naluDataRemaining) <= 0 {
            return
        }

        while naluDataRemaining > 0 {
            let currentFragmentSize = min(maxFragmentSize, naluDataRemaining)
            //out: = make([]byte, fuaHeaderSize + currentFragmentSize)
            var out = ByteBuffer()
            // +---------------+
            // |0|1|2|3|4|5|6|7|
            // +-+-+-+-+-+-+-+-+
            // |F|NRI|  Type   |
            // +---------------+
            let b0: UInt8 = fuaNaluType | naluRefIdc
            out.writeInteger(b0)

            // +---------------+
            //|0|1|2|3|4|5|6|7|
            //+-+-+-+-+-+-+-+-+
            //|S|E|R|  Type   |
            //+---------------+

            var b1: UInt8 = naluType
            if naluDataRemaining == naluDataLength {
                // Set start bit
                b1 |= 1 << 7
            } else if naluDataRemaining - currentFragmentSize == 0 {
                // Set end bit
                b1 |= 1 << 6
            }
            out.writeInteger(b1)

            guard
                let subNaluData = naluData.getSlice(
                    at: naluDataIndex, length: currentFragmentSize)
            else {
                throw RtpError.errBufferTooSmall
            }
            out.writeImmutableBuffer(subNaluData)
            payloads.append(out)

            naluDataRemaining -= currentFragmentSize
            naluDataIndex += currentFragmentSize
        }
    }
}

extension H264Payloader: Payloader {
    /// Payload fragments a H264 packet across one or more byte arrays
    public mutating func payload(mtu: Int, buf: ByteBuffer) throws -> [ByteBuffer] {
        if buf.readableBytes == 0 || mtu == 0 {
            return []
        }

        var payloads: [ByteBuffer] = []

        var (nextIndStart, nextIndLen) = H264Payloader.nextInd(nalu: buf.readableBytesView)
        if nextIndStart == -1 {
            try self.emit(nalu: buf, mtu: mtu, payloads: &payloads)
        } else {
            while nextIndStart != -1 {
                let prevStart = nextIndStart + nextIndLen
                guard
                    let bufView = buf.viewBytes(
                        at: prevStart, length: buf.readableBytes - prevStart)
                else {
                    throw RtpError.errBufferTooSmall
                }
                let (nextIndStart2, nextIndLen2) = H264Payloader.nextInd(nalu: bufView)
                nextIndStart = nextIndStart2
                nextIndLen = nextIndLen2
                if nextIndStart != -1 {
                    guard
                        let subBuf = buf.getSlice(
                            at: prevStart, length: nextIndStart - prevStart)
                    else {
                        throw RtpError.errBufferTooSmall
                    }
                    try self.emit(
                        nalu: subBuf,
                        mtu: mtu,
                        payloads: &payloads
                    )
                } else {
                    // Emit until end of stream, no end indicator found
                    guard
                        let subBuf = buf.getSlice(
                            at: prevStart, length: buf.readableBytes - prevStart)
                    else {
                        throw RtpError.errBufferTooSmall
                    }
                    try self.emit(nalu: subBuf, mtu: mtu, payloads: &payloads)
                }
            }
        }

        return payloads
    }
}

/// H264Packet represents the H264 header that is stored in the payload of an RTP Packet
public struct H264Packet: Equatable {
    public var isAvc: Bool
    var fuaBuffer: ByteBuffer?

    public init(isAvc: Bool, fuaBuffer: ByteBuffer? = nil) {
        self.isAvc = isAvc
        self.fuaBuffer = fuaBuffer
    }
}

extension H264Packet: Depacketizer {
    /// depacketize parses the passed byte slice and stores the result in the H264Packet this method is called upon
    public mutating func depacketize(buf: ByteBuffer) throws -> ByteBuffer {
        guard let b = buf.getBytes(at: 0, length: 2) else {
            throw RtpError.errShortPacket
        }

        var payload = ByteBuffer()

        // NALU Types
        // https://tools.ietf.org/html/rfc6184#section-5.4
        let b0 = b[0]
        let naluType = b0 & naluTypeBitmask

        switch naluType {
        case 1...23:
            if self.isAvc {
                payload.writeInteger(UInt32(buf.readableBytes))
            } else {
                payload.writeImmutableBuffer(annexBNaluStartCode)
            }
            payload.writeImmutableBuffer(buf.slice())
            return payload

        case stapaNaluType:
            var currOffset = stapaHeaderSize
            while currOffset < buf.readableBytes {
                guard let p = buf.getBytes(at: currOffset, length: 2) else {
                    throw RtpError.errShortPacket
                }
                let naluSize = (Int(p[0]) << 8) | Int(p[1])
                currOffset += stapaNaluLengthSize

                if buf.readableBytes < currOffset + naluSize {
                    throw RtpError.errStapASizeLargerThanBuffer(
                        naluSize,
                        buf.readableBytes - currOffset
                    )
                }

                if self.isAvc {
                    payload.writeInteger(UInt32(naluSize))
                } else {
                    payload.writeImmutableBuffer(annexBNaluStartCode)
                }

                guard let subBuf = buf.getSlice(at: currOffset, length: naluSize) else {
                    throw RtpError.errShortPacket
                }
                payload.writeImmutableBuffer(subBuf)
                currOffset += naluSize
            }

            return payload

        case fuaNaluType:
            if buf.readableBytes < fuaHeaderSize {
                throw RtpError.errShortPacket
            }

            if self.fuaBuffer == nil {
                self.fuaBuffer = ByteBuffer()
            }

            guard
                let subBuf = buf.getSlice(
                    at: fuaHeaderSize, length: buf.readableBytes - fuaHeaderSize)
            else {
                throw RtpError.errShortPacket
            }
            self.fuaBuffer?.writeImmutableBuffer(subBuf)

            let b1 = b[1]
            if b1 & fuEndBitmask != 0 {
                let naluRefIdc = b0 & naluRefIdcBitmask
                let fragmentedNaluType = b1 & naluTypeBitmask

                if let fuaBuffer = self.fuaBuffer {
                    if self.isAvc {
                        payload.writeInteger(UInt32(fuaBuffer.readableBytes + 1))
                    } else {
                        payload.writeImmutableBuffer(annexBNaluStartCode)
                    }
                    payload.writeInteger(UInt8(naluRefIdc | fragmentedNaluType))
                    payload.writeImmutableBuffer(fuaBuffer)
                }
                self.fuaBuffer = nil

                return payload
            } else {
                return ByteBuffer()
            }
        default:
            throw RtpError.errNaluTypeIsNotHandled(naluType)
        }
    }

    /// is_partition_head checks if this is the head of a packetized nalu stream.
    public func isPartitionHead(payload: ByteBuffer) -> Bool {
        guard let b = payload.getBytes(at: 0, length: 2) else {
            return false
        }

        if b[0] & naluTypeBitmask == fuaNaluType
            || b[0] & naluTypeBitmask == fubNaluType
        {
            return (b[1] & fuStartBitmask) != 0
        } else {
            return true
        }
    }

    public func isPartitionTail(marker: Bool, payload: ByteBuffer) -> Bool {
        return marker
    }
}
