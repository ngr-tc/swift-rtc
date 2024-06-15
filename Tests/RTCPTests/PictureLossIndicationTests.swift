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

final class PictureLossIndicationTests: XCTestCase {
    func testPictureLossIndicationUnmarshal() throws {
        let tests = [
            (
                "valid",
                ByteBuffer(bytes: [
                    0x81, 0xce, 0x00, 0x02,  // v=2, p=0, FMT=1, PSFB, len=1
                    0x00, 0x00, 0x00, 0x00,  // ssrc=0x0
                    0x4b, 0xc4, 0xfc, 0xb4,  // ssrc=0x4bc4fcb4
                ]),
                PictureLossIndication(
                    senderSsrc: 0x0,
                    mediaSsrc: 0x4bc4_fcb4
                ),
                nil
            ),
            (
                "packet too short",
                ByteBuffer(bytes: [0x81, 0xce, 0x00, 0x00]),
                PictureLossIndication(),
                RtcpError.errPacketTooShort
            ),
            (
                "invalid header",
                ByteBuffer(bytes: [
                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                ]),
                PictureLossIndication(),
                RtcpError.errBadVersion
            ),
            (
                "wrong type",
                ByteBuffer(bytes: [
                    0x81, 0xc9, 0x00, 0x02,  // v=2, p=0, FMT=1, RR, len=1
                    0x00, 0x00, 0x00, 0x00,  // ssrc=0x0
                    0x4b, 0xc4, 0xfc, 0xb4,  // ssrc=0x4bc4fcb4
                ]),
                PictureLossIndication(),
                RtcpError.errWrongType
            ),
            (
                "wrong fmt",
                ByteBuffer(bytes: [
                    0x82, 0xc9, 0x00, 0x02,  // v=2, p=0, FMT=2, RR, len=1
                    0x00, 0x00, 0x00, 0x00,  // ssrc=0x0
                    0x4b, 0xc4, 0xfc, 0xb4,  // ssrc=0x4bc4fcb4
                ]),
                PictureLossIndication(),
                RtcpError.errWrongType
            ),
        ]

        for (name, data, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try PictureLossIndication.unmarshal(data)
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? PictureLossIndication.unmarshal(data)
                XCTAssertTrue(got != nil)
                let (actual, _) = got!
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testPictureLossIndicationRoundtrip() throws {
        let tests: [(String, PictureLossIndication, RtcpError?)] = [
            (
                "valid",
                PictureLossIndication(
                    senderSsrc: 1,
                    mediaSsrc: 2
                ),
                nil
            ),
            (
                "also valid",
                PictureLossIndication(
                    senderSsrc: 5000,
                    mediaSsrc: 6000
                ),
                nil
            ),
        ]

        for (name, want, wantError) in tests {
            if let wantError {
                do {
                    let _ = try want.marshal()
                    XCTFail("expect error")
                } catch let gotErr as RtcpError {
                    XCTAssertEqual(gotErr, wantError)
                } catch {
                    XCTFail("expect RtcpError")
                }
            } else {
                let got = try? want.marshal()
                XCTAssertTrue(got != nil)
                let data = got!
                let (actual, _) = try PictureLossIndication.unmarshal(data)
                XCTAssertEqual(
                    actual, want,
                    "Unmarshal \(name)"
                )
            }
        }
    }

    func testPictureLossIndicationUnmarshalHeader() throws {
        let tests = [
            (
                "valid header",
                ByteBuffer(bytes: [
                    0x81, 0xce, 0x00, 0x02,  // v=2, p=0, FMT=1, PSFB, len=1
                    0x00, 0x00, 0x00, 0x00,  // ssrc=0x0
                    0x4b, 0xc4, 0xfc, 0xb4,  // ssrc=0x4bc4fcb4
                ]),
                Header(
                    padding: false,
                    count: formatPli,
                    packetType: PacketType.payloadSpecificFeedback,
                    length: UInt16(pliLength)
                )
            )
        ]

        for (name, data, want) in tests {
            let (pli, _) = try PictureLossIndication.unmarshal(data)
            let h = pli.header()

            XCTAssertEqual(h, want, "Unmarshal header \(name)")
        }
    }
}
