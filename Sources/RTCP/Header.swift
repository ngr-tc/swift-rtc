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

/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatSli: UInt8 = 2
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatPli: UInt8 = 1
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatFir: UInt8 = 4
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatTln: UInt8 = 1
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatRrr: UInt8 = 5
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here
public let formatRemb: UInt8 = 15
/// Transport and Payload specific feedback messages overload the count field to act as a message type. those are listed here.
/// https://tools.ietf.org/html/draft-holmer-rmcat-transport-wide-cc-extensions-01#page-5
public let formatTcc: UInt8 = 15

/// PacketType specifies the type of an RTCP packet
/// RTCP packet types registered with IANA. See: https://www.iana.org/assignments/rtp-parameters/rtp-parameters.xhtml#rtp-parameters-4
public enum PacketType: UInt8, Equatable {
    case senderReport = 200  // RFC 3550, 6.4.1
    case receiverReport = 201  // RFC 3550, 6.4.2
    case sourceDescription = 202  // RFC 3550, 6.5
    case goodbye = 203  // RFC 3550, 6.6
    case applicationDefined = 204  // RFC 3550, 6.7 (unimplemented)
    case transportSpecificFeedback = 205  // RFC 4585, 6051
    case payloadSpecificFeedback = 206  // RFC 4585, 6.3
    case extendedReport = 207  // RFC 3611
}

extension PacketType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .senderReport:
            return "SR"
        case .receiverReport:
            return "RR"
        case .sourceDescription:
            return "SDES"
        case .goodbye:
            return "BYE"
        case .applicationDefined:
            return "APP"
        case .transportSpecificFeedback:
            return "TSFB"
        case .payloadSpecificFeedback:
            return "PSFB"
        case .extendedReport:
            return "XR"
        }
    }
}

public let rtpVersion: UInt8 = 2
public let versionShift: UInt8 = 6
public let versionMask: UInt8 = 0x3
public let paddingShift: UInt8 = 5
public let paddingMask: UInt8 = 0x1
public let countShift: UInt8 = 0
public let countMask: UInt8 = 0x1f

public let headerLength: Int = 4
public let countMax: Int = (1 << 5) - 1
public let ssrcLength: Int = 4
public let sdesMaxOctetCount: Int = (1 << 8) - 1

/// A Header is the common header shared by all RTCP packets
public struct Header: Equatable {
    /// If the padding bit is set, this individual RTCP packet contains
    /// some additional padding octets at the end which are not part of
    /// the control information but are included in the length field.
    public var padding: Bool
    /// The number of reception reports, sources contained or FMT in this packet (depending on the Type)
    public var count: UInt8
    /// The RTCP packet type for this packet
    public var packetType: PacketType
    /// The length of this RTCP packet in 32-bit words minus one,
    /// including the header and any padding.
    public var length: UInt16
}

/// Marshal encodes the Header in binary
extension Header: MarshalSize {
    public func marshalSize() -> Int {
        return headerLength
    }
}

/*
extension Header: Marshal{
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        if self.count > 31 {
            throud Rtcp.InvalidHeader
        }
        if buf.remaining_mut() < HEADER_LENGTH {
            throud Rtcp.BufferTooShort)
        }

        /*
         *  0                   1                   2                   3
         *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |V=2|P|    RC   |   PT=SR=200   |             length            |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        let b0 = (RTP_VERSION << VERSION_SHIFT)
            | ((self.padding as UInt8) << PADDING_SHIFT)
            | (self.count << COUNT_SHIFT);

        buf.put_UInt8(b0);
        buf.put_UInt8(self.packet_type as UInt8);
        buf.put_u16(self.length);

        Ok(HEADER_LENGTH)
    }
}

impl Unmarshal for Header {
    /// Unmarshal decodes the Header from binary
    fn unmarshal<B>(raw_packet: &mut B) -> Result<Self>
    where
        Self: Sized,
        B: Buf,
    {
        if raw_packet.remaining() < HEADER_LENGTH {
            return Err(Error::PacketTooShort);
        }

        /*
         *  0                   1                   2                   3
         *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         * |V=2|P|    RC   |      PT       |             length            |
         * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        let b0 = raw_packet.get_UInt8();
        let version = (b0 >> VERSION_SHIFT) & VERSION_MASK;
        if version != RTP_VERSION {
            return Err(Error::BadVersion);
        }

        let padding = ((b0 >> PADDING_SHIFT) & PADDING_MASK) > 0;
        let count = (b0 >> COUNT_SHIFT) & COUNT_MASK;
        let packet_type = PacketType::from(raw_packet.get_UInt8());
        let length = raw_packet.get_u16();

        Ok(Header {
            padding,
            count,
            packet_type,
            length,
        })
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use bytes::Bytes;

    #[test]
    fn test_header_unmarshal() {
        let tests = vec![
            (
                "valid",
                Bytes::from_static(&[
                    // v=2, p=0, count=1, RR, len=7
                    0x81UInt8, 0xc9, 0x00, 0x07,
                ]),
                Header {
                    padding: false,
                    count: 1,
                    packet_type: PacketType::ReceiverReport,
                    length: 7,
                },
                None,
            ),
            (
                "also valid",
                Bytes::from_static(&[
                    // v=2, p=1, count=1, BYE, len=7
                    0xa1, 0xcc, 0x00, 0x07,
                ]),
                Header {
                    padding: true,
                    count: 1,
                    packet_type: PacketType::ApplicationDefined,
                    length: 7,
                },
                None,
            ),
            (
                "bad version",
                Bytes::from_static(&[
                    // v=0, p=0, count=0, RR, len=4
                    0x00, 0xc9, 0x00, 0x04,
                ]),
                Header {
                    padding: false,
                    count: 0,
                    packet_type: PacketType::Unsupported,
                    length: 0,
                },
                Some(Error::BadVersion),
            ),
        ];

        for (name, data, want, want_error) in tests {
            let buf = &mut data.clone();
            let got = Header::unmarshal(buf);

            assert_eq!(
                got.is_err(),
                want_error.is_some(),
                "Unmarshal {name}: err = {got:?}, want {want_error:?}"
            );

            if let Some(want_error) = want_error {
                let got_err = got.err().unwrap();
                assert_eq!(
                    want_error, got_err,
                    "Unmarshal {name}: err = {got_err:?}, want {want_error:?}",
                );
            } else {
                let actual = got.unwrap();
                assert_eq!(
                    actual, want,
                    "Unmarshal {name}: got {actual:?}, want {want:?}"
                );
            }
        }
    }

    #[test]
    fn test_header_roundtrip() {
        let tests = vec![
            (
                "valid",
                Header {
                    padding: true,
                    count: 31,
                    packet_type: PacketType::SenderReport,
                    length: 4,
                },
                None,
            ),
            (
                "also valid",
                Header {
                    padding: false,
                    count: 28,
                    packet_type: PacketType::ReceiverReport,
                    length: 65535,
                },
                None,
            ),
            (
                "invalid count",
                Header {
                    padding: false,
                    count: 40,
                    packet_type: PacketType::Unsupported,
                    length: 0,
                },
                Some(Error::InvalidHeader),
            ),
        ];

        for (name, want, want_error) in tests {
            let got = want.marshal();

            assert_eq!(
                got.is_ok(),
                want_error.is_none(),
                "Marshal {name}: err = {got:?}, want {want_error:?}"
            );

            if let Some(err) = want_error {
                let got_err = got.err().unwrap();
                assert_eq!(
                    err, got_err,
                    "Unmarshal {name} rr: err = {got_err:?}, want {err:?}",
                );
            } else {
                let data = got.ok().unwrap();
                let buf = &mut data.clone();
                let actual = Header::unmarshal(buf).unwrap_or_else(|_| panic!("Unmarshal {name}"));

                assert_eq!(
                    actual, want,
                    "{name} round trip: got {actual:?}, want {want:?}"
                )
            }
        }
    }
}
*/
