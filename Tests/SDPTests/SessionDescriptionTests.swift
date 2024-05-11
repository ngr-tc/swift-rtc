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

@testable import SDP

final class SessionDescriptionTests: XCTestCase {

    let canonicalMashalSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        i=A Seminar on the session description protocol\r\n\
        u=http://www.example.com/seminars/sdp.pdf\r\n\
        e=j.doe@example.com (Jane Doe)\r\n\
        p=+1 617 555-6011\r\n\
        c=IN IP4 224.2.17.12/127\r\n\
        b=X-YZ:128\r\n\
        b=AS:12345\r\n\
        t=2873397496 2873404696\r\n\
        t=3034423619 3042462419\r\n\
        r=604800 3600 0 90000\r\n\
        z=2882844526 -3600 2898848070 0\r\n\
        k=prompt\r\n\
        a=candidate:0 1 UDP 2113667327 203.0.113.1 54400 typ host\r\n\
        a=recvonly\r\n\
        m=audio 49170 RTP/AVP 0\r\n\
        i=Vivamus a posuere nisl\r\n\
        c=IN IP4 203.0.113.1\r\n\
        b=X-YZ:128\r\n\
        k=prompt\r\n\
        a=sendrecv\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        a=rtpmap:99 h263-1998/90000\r\n
        """

    func testUnmarshalMarshal() throws {
        let input = canonicalMashalSdp
        let sdp = try SessionDescription.unmarshal(input: input)
        let output = sdp.marshal()
        XCTAssertEqual(output, input)
    }

    func testMarshal() throws {
        let sd = SessionDescription(
            version: 0,
            origin: Origin(
                username: "jdoe",
                sessionId: 2_890_844_526,
                sessionVersion: 2_890_842_807,
                networkType: "IN",
                addressType: "IP4",
                unicastAddress: "10.47.16.5"),
            sessionName: "SDP Seminar",
            sessionInformation: "A Seminar on the session description protocol",
            uri: "http://www.example.com/seminars/sdp.pdf",
            emailAddress: "j.doe@example.com (Jane Doe)",
            phoneNumber: "+1 617 555-6011",
            connectionInformation: ConnectionInformation(
                networkType: "IN",
                addressType: "IP4",
                address: Address(
                    address: "224.2.17.12",
                    ttl: 127,
                    range: nil
                )),
            bandwidth: [
                Bandwidth(
                    experimental: true,
                    bandwidthType: "YZ",
                    bandwidth: 128
                ),
                Bandwidth(
                    experimental: false,
                    bandwidthType: "AS",
                    bandwidth: 12345
                ),
            ],
            timeDescriptions: [
                TimeDescription(
                    timing: Timing(
                        startTime: 2_873_397_496,
                        stopTime: 2_873_404_696
                    ),
                    repeatTimes: []
                ),
                TimeDescription(
                    timing: Timing(
                        startTime: 3_034_423_619,
                        stopTime: 3_042_462_419
                    ),
                    repeatTimes: [
                        RepeatTime(
                            interval: 604800,
                            duration: 3600,
                            offsets: [0, 90000]
                        )
                    ]
                ),
            ],
            timeZones: [
                TimeZone(
                    adjustmentTime: 2_882_844_526,
                    offset: -3600
                ),
                TimeZone(
                    adjustmentTime: 2_898_848_070,
                    offset: 0
                ),
            ],
            encryptionKey: "prompt",
            attributes: [
                Attribute(
                    key: "candidate",
                    value: "0 1 UDP 2113667327 203.0.113.1 54400 typ host"
                ),
                Attribute(key: "recvonly"),
            ],
            mediaDescriptions: [
                MediaDescription(
                    mediaName: MediaName(
                        media: "audio",
                        port: RangedPort(
                            value: 49170,
                            range: nil
                        ),
                        protos: ["RTP", "AVP"],
                        formats: ["0"]
                    ),
                    mediaTitle: "Vivamus a posuere nisl",
                    connectionInformation: ConnectionInformation(
                        networkType: "IN",
                        addressType: "IP4",
                        address: Address(
                            address: "203.0.113.1",
                            ttl: nil,
                            range: nil
                        )
                    ),
                    bandwidth: [
                        Bandwidth(
                            experimental: true,
                            bandwidthType: "YZ",
                            bandwidth: 128
                        )
                    ],
                    encryptionKey: "prompt",
                    attributes: [Attribute(key: "sendrecv")]
                ),
                MediaDescription(
                    mediaName: MediaName(
                        media: "video",
                        port: RangedPort(
                            value: 51372,
                            range: nil
                        ),
                        protos: ["RTP", "AVP"],
                        formats: ["99"]
                    ),
                    mediaTitle: nil,
                    connectionInformation: nil,
                    bandwidth: [],
                    encryptionKey: nil,
                    attributes: [
                        Attribute(
                            key: "rtpmap",
                            value: "99 h263-1998/90000"
                        )
                    ]
                ),
            ]
        )

        let actual = sd.marshal()
        XCTAssertEqual(canonicalMashalSdp, actual)
    }
}
