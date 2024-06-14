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

@testable import RTCP

final class PacketTests: XCTestCase {
    /*
     func test_packet_unmarshal() throws {
             let mut data = Bytes::from_static(&[
                 // Receiver Report (offset=0)
                 0x81, 0xc9, 0x0, 0x7, // v=2, p=0, count=1, RR, len=7
                 0x90, 0x2f, 0x9e, 0x2e, // ssrc=0x902f9e2e
                 0xbc, 0x5e, 0x9a, 0x40, // ssrc=0xbc5e9a40
                 0x0, 0x0, 0x0, 0x0, // fracLost=0, totalLost=0
                 0x0, 0x0, 0x46, 0xe1, // lastSeq=0x46e1
                 0x0, 0x0, 0x1, 0x11, // jitter=273
                 0x9, 0xf3, 0x64, 0x32, // lsr=0x9f36432
                 0x0, 0x2, 0x4a, 0x79, // delay=150137
                 // Source Description (offset=32)
                 0x81, 0xca, 0x0, 0xc, // v=2, p=0, count=1, SDES, len=12
                 0x90, 0x2f, 0x9e, 0x2e, // ssrc=0x902f9e2e
                 0x1, 0x26, // CNAME, len=38
                 0x7b, 0x39, 0x63, 0x30, 0x30, 0x65, 0x62, 0x39, 0x32, 0x2d, 0x31, 0x61, 0x66, 0x62,
                 0x2d, 0x39, 0x64, 0x34, 0x39, 0x2d, 0x61, 0x34, 0x37, 0x64, 0x2d, 0x39, 0x31, 0x66,
                 0x36, 0x34, 0x65, 0x65, 0x65, 0x36, 0x39, 0x66, 0x35,
                 0x7d, // text="{9c00eb92-1afb-9d49-a47d-91f64eee69f5}"
                 0x0, 0x0, 0x0, 0x0, // END + padding
                 // Goodbye (offset=84)
                 0x81, 0xcb, 0x0, 0x1, // v=2, p=0, count=1, BYE, len=1
                 0x90, 0x2f, 0x9e, 0x2e, // source=0x902f9e2e
                 0x81, 0xce, 0x0, 0x2, // Picture Loss Indication (offset=92)
                 0x90, 0x2f, 0x9e, 0x2e, // sender=0x902f9e2e
                 0x90, 0x2f, 0x9e, 0x2e, // media=0x902f9e2e
                 0x85, 0xcd, 0x0, 0x2, // RapidResynchronizationRequest (offset=104)
                 0x90, 0x2f, 0x9e, 0x2e, // sender=0x902f9e2e
                 0x90, 0x2f, 0x9e, 0x2e, // media=0x902f9e2e
             ]);

             let packet = unmarshal(&mut data).expect("Error unmarshalling packets");

             let a = ReceiverReport {
                 ssrc: 0x902f9e2e,
                 reports: vec![ReceptionReport {
                     ssrc: 0xbc5e9a40,
                     fraction_lost: 0,
                     total_lost: 0,
                     last_sequence_number: 0x46e1,
                     jitter: 273,
                     last_sender_report: 0x9f36432,
                     delay: 150137,
                 }],
                 ..Default::default()
             };

             let b = SourceDescription {
                 chunks: vec![SourceDescriptionChunk {
                     source: 0x902f9e2e,
                     items: vec![SourceDescriptionItem {
                         sdes_type: SdesType::SdesCname,
                         text: Bytes::from_static(b"{9c00eb92-1afb-9d49-a47d-91f64eee69f5}"),
                     }],
                 }],
             };

             let c = Goodbye {
                 sources: vec![0x902f9e2e],
                 ..Default::default()
             };

             let d = PictureLossIndication {
                 sender_ssrc: 0x902f9e2e,
                 media_ssrc: 0x902f9e2e,
             };

             let e = RapidResynchronizationRequest {
                 sender_ssrc: 0x902f9e2e,
                 media_ssrc: 0x902f9e2e,
             };

             let expected: Vec<Box<dyn Packet>> = vec![
                 Box::new(a),
                 Box::new(b),
                 Box::new(c),
                 Box::new(d),
                 Box::new(e),
             ];

             assert!(packet == expected, "Invalid packets");
         }

         #[test]
         fn test_packet_unmarshal_empty() -> Result<()> {
             let result = unmarshal(&mut Bytes::new());
             if let Err(got) = result {
                 let want = Error::InvalidHeader;
                 assert_eq!(got, want, "Unmarshal(nil) err = {got}, want {want}");
             } else {
                 panic!("want error");
             }

             Ok(())
         }

         #[test]
         fn test_packet_invalid_header_length() -> Result<()> {
             let mut data = Bytes::from_static(&[
                 // Goodbye (offset=84)
                 // v=2, p=0, count=1, BYE, len=100
                 0x81, 0xcb, 0x0, 0x64,
             ]);

             let result = unmarshal(&mut data);
             if let Err(got) = result {
                 let want = Error::PacketTooShort;
                 assert_eq!(
                     got, want,
                     "Unmarshal(invalid_header_length) err = {got}, want {want}"
                 );
             } else {
                 panic!("want error");
             }

             Ok(())
         }
         #[test]
         fn test_packet_unmarshal_firefox() -> Result<()> {
             // issue report from https://github.com/webrtc-rs/srtp/issues/7
             let tests = vec![
                 Bytes::from_static(&[
                     143, 205, 0, 6, 65, 227, 184, 49, 118, 243, 78, 96, 42, 63, 0, 5, 12, 162, 166, 0,
                     32, 5, 200, 4, 0, 4, 0, 0,
                 ]),
                 Bytes::from_static(&[
                     143, 205, 0, 9, 65, 227, 184, 49, 118, 243, 78, 96, 42, 68, 0, 17, 12, 162, 167, 1,
                     32, 17, 88, 0, 4, 0, 4, 8, 108, 0, 4, 0, 4, 12, 0, 4, 0, 4, 4, 0,
                 ]),
                 Bytes::from_static(&[
                     143, 205, 0, 8, 65, 227, 184, 49, 118, 243, 78, 96, 42, 91, 0, 12, 12, 162, 168, 3,
                     32, 12, 220, 4, 0, 4, 0, 8, 128, 4, 0, 4, 0, 8, 0, 0,
                 ]),
                 Bytes::from_static(&[
                     143, 205, 0, 7, 65, 227, 184, 49, 118, 243, 78, 96, 42, 103, 0, 8, 12, 162, 169, 4,
                     32, 8, 232, 4, 0, 4, 0, 4, 4, 0, 0, 0,
                 ]),
             ];

             for mut test in tests {
                 unmarshal(&mut test)?;
             }

             Ok(())
         }
     */
}
