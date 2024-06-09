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

    mutating func emit(nalu: inout ByteBuffer, mtu: Int, payloads: inout [ByteBuffer]) throws {
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
    public mutating func payload(mtu: Int, buf: inout ByteBuffer) throws -> [ByteBuffer] {
        if buf.readableBytes == 0 || mtu == 0 {
            return []
        }

        var payloads: [ByteBuffer] = []

        var (nextIndStart, nextIndLen) = H264Payloader.nextInd(nalu: buf.readableBytesView)
        if nextIndStart == -1 {
            try self.emit(nalu: &buf, mtu: mtu, payloads: &payloads)
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
                        var subBuf = buf.getSlice(
                            at: prevStart, length: nextIndStart - prevStart)
                    else {
                        throw RtpError.errBufferTooSmall
                    }
                    try self.emit(
                        nalu: &subBuf,
                        mtu: mtu,
                        payloads: &payloads
                    )
                } else {
                    // Emit until end of stream, no end indicator found
                    guard
                        var subBuf = buf.getSlice(
                            at: prevStart, length: buf.readableBytes - prevStart)
                    else {
                        throw RtpError.errBufferTooSmall
                    }
                    try self.emit(nalu: &subBuf, mtu: mtu, payloads: &payloads)
                }
            }
        }

        return payloads
    }
}
/*
/// H264Packet represents the H264 header that is stored in the payload of an RTP Packet
#[derive(PartialEq, Eq, Debug, Default, Clone)]
pub struct H264Packet {
    pub is_avc: bool,
    fua_buffer: Option<BytesMut>,
}

impl Depacketizer for H264Packet {
    /// depacketize parses the passed byte slice and stores the result in the H264Packet this method is called upon
    fn depacketize(&mut self, packet: &Bytes) -> Result<Bytes> {
        if packet.len() <= 2 {
            return Err(Error::ErrShortPacket);
        }

        let mut payload = BytesMut::new();

        // NALU Types
        // https://tools.ietf.org/html/rfc6184#section-5.4
        let b0 = packet[0];
        let nalu_type = b0 & NALU_TYPE_BITMASK;

        match nalu_type {
            1..=23 => {
                if self.is_avc {
                    payload.put_u32(packet.len() as u32);
                } else {
                    payload.put(&*ANNEXB_NALUSTART_CODE);
                }
                payload.put(&*packet.clone());
                Ok(payload.freeze())
            }
            STAPA_NALU_TYPE => {
                let mut curr_offset = STAPA_HEADER_SIZE;
                while curr_offset < packet.len() {
                    let nalu_size =
                        ((packet[curr_offset] as usize) << 8) | packet[curr_offset + 1] as usize;
                    curr_offset += STAPA_NALU_LENGTH_SIZE;

                    if packet.len() < curr_offset + nalu_size {
                        return Err(Error::StapASizeLargerThanBuffer(
                            nalu_size,
                            packet.len() - curr_offset,
                        ));
                    }

                    if self.is_avc {
                        payload.put_u32(nalu_size as u32);
                    } else {
                        payload.put(&*ANNEXB_NALUSTART_CODE);
                    }
                    payload.put(&*packet.slice(curr_offset..curr_offset + nalu_size));
                    curr_offset += nalu_size;
                }

                Ok(payload.freeze())
            }
            FUA_NALU_TYPE => {
                if packet.len() < FUA_HEADER_SIZE {
                    return Err(Error::ErrShortPacket);
                }

                if self.fua_buffer.is_none() {
                    self.fua_buffer = Some(BytesMut::new());
                }

                if let Some(fua_buffer) = &mut self.fua_buffer {
                    fua_buffer.put(&*packet.slice(FUA_HEADER_SIZE..));
                }

                let b1 = packet[1];
                if b1 & FU_END_BITMASK != 0 {
                    let nalu_ref_idc = b0 & NALU_REF_IDC_BITMASK;
                    let fragmented_nalu_type = b1 & NALU_TYPE_BITMASK;

                    if let Some(fua_buffer) = self.fua_buffer.take() {
                        if self.is_avc {
                            payload.put_u32((fua_buffer.len() + 1) as u32);
                        } else {
                            payload.put(&*ANNEXB_NALUSTART_CODE);
                        }
                        payload.put_UInt8(nalu_ref_idc | fragmented_nalu_type);
                        payload.put(fua_buffer);
                    }

                    Ok(payload.freeze())
                } else {
                    Ok(Bytes::new())
                }
            }
            _ => Err(Error::NaluTypeIsNotHandled(nalu_type)),
        }
    }

    /// is_partition_head checks if this is the head of a packetized nalu stream.
    fn is_partition_head(&self, payload: &Bytes) -> bool {
        if payload.len() < 2 {
            return false;
        }

        if payload[0] & NALU_TYPE_BITMASK == FUA_NALU_TYPE
            || payload[0] & NALU_TYPE_BITMASK == FUB_NALU_TYPE
        {
            (payload[1] & FU_START_BITMASK) != 0
        } else {
            true
        }
    }

    fn is_partition_tail(&self, marker: bool, _payload: &Bytes) -> bool {
        marker
    }
}
*/
