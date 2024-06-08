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
    public var csrc: [UInt32]
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
    /*
     /// SetExtension sets an RTP header extension
     public mutating func setExtension(id: UInt8, payload: ByteBuffer) throws {
         if self.ext {
             switch self.extension_profile {
             case EXTENSION_PROFILE_ONE_BYTE:
                 if !(1...14).contains(id) {
                     throw RtpError.errRfc8285oneByteHeaderIdrange
                 }
                 if payload.len() > 16 {
                     return Err(Error::ErrRfc8285oneByteHeaderSize);
                 }
             case EXTENSION_PROFILE_TWO_BYTE:
                     if id < 1 {
                         return Err(Error::ErrRfc8285twoByteHeaderIdrange);
                     }
                     if payload.len() > 255 {
                         return Err(Error::ErrRfc8285twoByteHeaderSize);
                     }
             default:
                     if id != 0 {
                         return Err(Error::ErrRfc3550headerIdrange);
                     }
             }

             // Update existing if it exists else add new extension
             if let Some(extension) = self
                 .extensions
                 .iter_mut()
                 .find(|extension| extension.id == id)
             {
                 extension.payload = payload;
             } else {
                 self.extensions.push(Extension { id, payload });
             }
         } else {
             // No existing header extensions
             self.extension = true;

             self.extension_profile = match payload.len() {
                 0..=16 => EXTENSION_PROFILE_ONE_BYTE,
                 17..=255 => EXTENSION_PROFILE_TWO_BYTE,
                 _ => self.extension_profile,
             };

             self.extensions.push(Extension { id, payload });
         }
         Ok(())
     }*/
    /*
     /// returns an extension id array
     pub fn get_extension_ids(&self) -> Vec<UInt8> {
         if self.extension {
             self.extensions.iter().map(|e| e.id).collect()
         } else {
             vec![]
         }
     }

     /// returns an RTP header extension
     pub fn get_extension(&self, id: UInt8) -> Option<Bytes> {
         if self.extension {
             self.extensions
                 .iter()
                 .find(|extension| extension.id == id)
                 .map(|extension| extension.payload.clone())
         } else {
             None
         }
     }

     /// Removes an RTP Header extension
     pub fn del_extension(&mut self, id: UInt8) -> Result<()> {
         if self.extension {
             if let Some(index) = self
                 .extensions
                 .iter()
                 .position(|extension| extension.id == id)
             {
                 self.extensions.remove(index);
                 Ok(())
             } else {
                 Err(Error::ErrHeaderExtensionNotFound)
             }
         } else {
             Err(Error::ErrHeaderExtensionsNotEnabled)
         }
     }
     */
}

/*
impl Unmarshal for Header {
    /// Unmarshal parses the passed byte slice and stores the result in the Header this method is called upon
    fn unmarshal<B>(raw_packet: &mut B) -> Result<Self>
    where
        Self: Sized,
        B: Buf,
    {
        let raw_packet_len = raw_packet.remaining();
        if raw_packet_len < HEADER_LENGTH {
            return Err(Error::ErrHeaderSizeInsufficient);
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
        let b0 = raw_packet.get_UInt8();
        let version = b0 >> VERSION_SHIFT & VERSION_MASK;
        let padding = (b0 >> PADDING_SHIFT & PADDING_MASK) > 0;
        let extension = (b0 >> EXTENSION_SHIFT & EXTENSION_MASK) > 0;
        let cc = (b0 & CC_MASK) as Int;

        let mut curr_offset = CSRC_OFFSET + (cc * CSRC_LENGTH);
        if raw_packet_len < curr_offset {
            return Err(Error::ErrHeaderSizeInsufficient);
        }

        let b1 = raw_packet.get_UInt8();
        let marker = (b1 >> MARKER_SHIFT & MARKER_MASK) > 0;
        let payload_type = b1 & PT_MASK;

        let sequence_number = raw_packet.get_UInt16();
        let timestamp = raw_packet.get_UInt32();
        let ssrc = raw_packet.get_UInt32();

        let mut csrc = Vec::with_capacity(cc);
        for _ in 0..cc {
            csrc.push(raw_packet.get_UInt32());
        }

        let (extension_profile, extensions) = if extension {
            let expected = curr_offset + 4;
            if raw_packet_len < expected {
                return Err(Error::ErrHeaderSizeInsufficientForExtension);
            }
            let extension_profile = raw_packet.get_UInt16();
            curr_offset += 2;
            let extension_length = raw_packet.get_UInt16() as Int * 4;
            curr_offset += 2;

            let expected = curr_offset + extension_length;
            if raw_packet_len < expected {
                return Err(Error::ErrHeaderSizeInsufficientForExtension);
            }

            let mut extensions = vec![];
            match extension_profile {
                // RFC 8285 RTP One Byte Header Extension
                EXTENSION_PROFILE_ONE_BYTE => {
                    let end = curr_offset + extension_length;
                    while curr_offset < end {
                        let b = raw_packet.get_UInt8();
                        if b == 0x00 {
                            // padding
                            curr_offset += 1;
                            continue;
                        }

                        let extid = b >> 4;
                        let len = ((b & (0xFF ^ 0xF0)) + 1) as Int;
                        curr_offset += 1;

                        if extid == EXTENSION_ID_RESERVED {
                            break;
                        }

                        extensions.push(Extension {
                            id: extid,
                            payload: raw_packet.copy_to_bytes(len),
                        });
                        curr_offset += len;
                    }
                }
                // RFC 8285 RTP Two Byte Header Extension
                EXTENSION_PROFILE_TWO_BYTE => {
                    let end = curr_offset + extension_length;
                    while curr_offset < end {
                        let b = raw_packet.get_UInt8();
                        if b == 0x00 {
                            // padding
                            curr_offset += 1;
                            continue;
                        }

                        let extid = b;
                        curr_offset += 1;

                        let len = raw_packet.get_UInt8() as Int;
                        curr_offset += 1;

                        extensions.push(Extension {
                            id: extid,
                            payload: raw_packet.copy_to_bytes(len),
                        });
                        curr_offset += len;
                    }
                }
                // RFC3550 Extension
                _ => {
                    if raw_packet_len < curr_offset + extension_length {
                        return Err(Error::ErrHeaderSizeInsufficientForExtension);
                    }
                    extensions.push(Extension {
                        id: 0,
                        payload: raw_packet.copy_to_bytes(extension_length),
                    });
                }
            };

            (extension_profile, extensions)
        } else {
            (0, vec![])
        };

        Ok(Header {
            version,
            padding,
            extension,
            marker,
            payload_type,
            sequence_number,
            timestamp,
            ssrc,
            csrc,
            extension_profile,
            extensions,
        })
    }
}
*/
extension Header: MarshalSize {
    /// MarshalSize returns the size of the packet once marshaled.
    public func marshalSize() -> Int {
        var headSize = 12 + (self.csrc.count * csrcLength)
        if self.ext {
            let extensionPayloadLen = self.getExtensionPayloadLen()
            let extensionPayloadSize = (extensionPayloadLen + 3) / 4
            headSize += 4 + extensionPayloadSize * 4
        }
        return headSize
    }
}
/*
impl Marshal for Header {
    /// Marshal serializes the header and writes to the buffer.
    fn marshal_to(&self, mut buf: &mut [UInt8]) -> Result<Int> {
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
        let remaining_before = buf.remaining_mut();
        if remaining_before < self.marshal_size() {
            return Err(Error::ErrBufferTooSmall);
        }

        // The first byte contains the version, padding bit, extension bit, and csrc size
        let mut b0 = (self.version << VERSION_SHIFT) | self.csrc.len() as UInt8;
        if self.padding {
            b0 |= 1 << PADDING_SHIFT;
        }

        if self.extension {
            b0 |= 1 << EXTENSION_SHIFT;
        }
        buf.put_UInt8(b0);

        // The second byte contains the marker bit and payload type.
        let mut b1 = self.payload_type;
        if self.marker {
            b1 |= 1 << MARKER_SHIFT;
        }
        buf.put_UInt8(b1);

        buf.put_UInt16(self.sequence_number);
        buf.put_UInt32(self.timestamp);
        buf.put_UInt32(self.ssrc);

        for csrc in &self.csrc {
            buf.put_UInt32(*csrc);
        }

        if self.extension {
            buf.put_UInt16(self.extension_profile);

            // calculate extensions size and round to 4 bytes boundaries
            let extension_payload_len = self.get_extension_payload_len();
            if self.extension_profile != EXTENSION_PROFILE_ONE_BYTE
                && self.extension_profile != EXTENSION_PROFILE_TWO_BYTE
                && extension_payload_len % 4 != 0
            {
                //the payload must be in 32-bit words.
                return Err(Error::HeaderExtensionPayloadNot32BitWords);
            }
            let extension_payload_size = (extension_payload_len as UInt16 + 3) / 4;
            buf.put_UInt16(extension_payload_size);

            match self.extension_profile {
                // RFC 8285 RTP One Byte Header Extension
                EXTENSION_PROFILE_ONE_BYTE => {
                    for extension in &self.extensions {
                        buf.put_UInt8((extension.id << 4) | (extension.payload.len() as UInt8 - 1));
                        buf.put(&*extension.payload);
                    }
                }
                // RFC 8285 RTP Two Byte Header Extension
                EXTENSION_PROFILE_TWO_BYTE => {
                    for extension in &self.extensions {
                        buf.put_UInt8(extension.id);
                        buf.put_UInt8(extension.payload.len() as UInt8);
                        buf.put(&*extension.payload);
                    }
                }
                // RFC3550 Extension
                _ => {
                    if self.extensions.len() != 1 {
                        return Err(Error::ErrRfc3550headerIdrange);
                    }

                    if let Some(extension) = self.extensions.first() {
                        let ext_len = extension.payload.len();
                        if ext_len % 4 != 0 {
                            return Err(Error::HeaderExtensionPayloadNot32BitWords);
                        }
                        buf.put(&*extension.payload);
                    }
                }
            };

            // add padding to reach 4 bytes boundaries
            for _ in extension_payload_len..extension_payload_size as Int * 4 {
                buf.put_UInt8(0);
            }
        }

        let remaining_after = buf.remaining_mut();
        Ok(remaining_before - remaining_after)
    }
}
*/
