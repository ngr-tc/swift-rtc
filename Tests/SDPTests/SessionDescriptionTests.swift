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

    let baseSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n
        """

    let sessionInformationSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        i=A Seminar on the session description protocol\r\n\
        t=3034423619 3042462419\r\n
        """

    // https://tools.ietf.org/html/rfc4566#section-5
    // Parsers SHOULD be tolerant and also accept records terminated
    // with a single newline character.
    let sessionInformationSdpLfOnly: String = """
        v=0\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\n\
        s=SDP Seminar\n\
        i=A Seminar on the session description protocol\n\
        t=3034423619 3042462419\n
        """

    // SessionInformationSDPCROnly = "v=0\r" +
    //     "o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r" +
    //     "s=SDP Seminar\r"
    //     "i=A Seminar on the session description protocol\r" +
    //     "t=3034423619 3042462419\r"

    // Other SDP parsers (e.g. one in VLC media player) allow
    // empty lines.
    let sessionInformationSdpExtraCrLf: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        \r\n\
        s=SDP Seminar\r\n\
        \r\n\
        i=A Seminar on the session description protocol\r\n\
        \r\n\
        t=3034423619 3042462419\r\n\
        \r\n
        """

    let uriSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        u=http://www.example.com/seminars/sdp.pdf\r\n\
        t=3034423619 3042462419\r\n
        """

    let emailAddressSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        e=j.doe@example.com (Jane Doe)\r\n\
        t=3034423619 3042462419\r\n
        """

    let phoneNumberSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        p=+1 617 555-6011\r\n\
        t=3034423619 3042462419\r\n
        """

    let sessionConnectionInformationSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        c=IN IP4 224.2.17.12/127\r\n\
        t=3034423619 3042462419\r\n
        """

    let sessionBandwithSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        b=X-YZ:128\r\n\
        b=AS:12345\r\n\
        t=3034423619 3042462419\r\n
        """

    let timingSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n
        """

    // Short hand time notation is converted into NTP timestamp format in
    // seconds. Because of that unittest comparisons will fail as the same time
    // will be expressed in different units.
    let repeatTimesSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        r=604800 3600 0 90000\r\n\
        r=3d 2h 0 21h\r\n
        """

    let repeatTimesSdpExpected: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        r=604800 3600 0 90000\r\n\
        r=259200 7200 0 75600\r\n
        """

    let repeatTimesOverflowSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        r=604800 3600 0 90000\r\n\
        r=106751991167301d 2h 0 21h\r\n
        """

    let repeatTimesSdpExtraCrLf: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        r=604800 3600 0 90000\r\n\
        r=259200 7200 0 75600\r\n\
        \r\n
        """

    // The expected value looks a bit different for the same reason as mentioned
    // above regarding RepeatTimes.
    let timeZonesSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        r=2882844526 -1h 2898848070 0\r\n
        """

    let timeZonesSdpExpected: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        r=2882844526 -3600 2898848070 0\r\n
        """

    let timeZonesSdp2: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        z=2882844526 -3600 2898848070 0\r\n
        """

    let timeZonesSdp2ExtraCrLf: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        z=2882844526 -3600 2898848070 0\r\n\
        \r\n
        """

    let sessionEncryptionKeySdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        k=prompt\r\n
        """

    let sessionEncryptionKeySdpExtraCrLf: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        k=prompt\r\n
        \r\n
        """

    let sessionAttributesSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        a=rtpmap:96 opus/48000\r\n
        """

    let mediaNameSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n
        """

    let mediaNameSdpExtraCrLf: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n
        \r\n
        """

    let mediaTitleSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n\
        i=Vivamus a posuere nisl\r\n
        """

    let mediaConnectionInformationSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n\
        c=IN IP4 203.0.113.1\r\n
        """

    let mediaConnectionInformationSdpExtraCrLf: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n\
        c=IN IP4 203.0.113.1\r\n\
        \r\n
        """

    let mediaDescriptionOutOfOrderSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n\
        a=rtpmap:99 h263-1998/90000\r\n\
        a=candidate:0 1 UDP 2113667327 203.0.113.1 54400 typ host\r\n\
        c=IN IP4 203.0.113.1\r\n\
        i=Vivamus a posuere nisl\r\n
        """

    let mediaDescriptionOutOfOrderSdpActual: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n\
        i=Vivamus a posuere nisl\r\n\
        c=IN IP4 203.0.113.1\r\n\
        a=rtpmap:99 h263-1998/90000\r\n\
        a=candidate:0 1 UDP 2113667327 203.0.113.1 54400 typ host\r\n
        """

    let mediaBandwidthSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n\
        b=X-YZ:128\r\n\
        b=AS:12345\r\n
        """

    let mediaEncryptionKeySdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n\
        k=prompt\r\n
        """

    let mediaEncryptionKeySdpExtraCrLf: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n\
        k=prompt\r\n\
        \r\n
        """

    let mediaAttributesSdp: String = """
        v=0\r\n\
        o=jdoe 2890844526 2890842807 IN IP4 10.47.16.5\r\n\
        s=SDP Seminar\r\n\
        t=2873397496 2873404696\r\n\
        m=video 51372 RTP/AVP 99\r\n\
        m=audio 54400 RTP/SAVPF 0 96\r\n\
        a=rtpmap:99 h263-1998/90000\r\n\
        a=candidate:0 1 UDP 2113667327 203.0.113.1 54400 typ host\r\n\
        a=rtcp-fb:97 ccm fir\r\n\
        a=rtcp-fb:97 nack\r\n\
        a=rtcp-fb:97 nack pli\r\n
        """

    let canonicalUnmarshalSdp: String = """
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

    func testRoundTrip() throws {
        let tests = [
            (
                "SessionInformationSDPLFOnly",
                sessionInformationSdpLfOnly,
                sessionInformationSdp
            ),
            (
                "SessionInformationSDPExtraCRLF",
                sessionInformationSdpExtraCrLf,
                sessionInformationSdp
            ),
            ("SessionInformation", sessionInformationSdp, nil),
            ("URI", uriSdp, nil),
            ("EmailAddress", emailAddressSdp, nil),
            ("PhoneNumber", phoneNumberSdp, nil),
            (
                "RepeatTimesSDPExtraCRLF",
                repeatTimesSdpExtraCrLf,
                repeatTimesSdpExpected
            ),
            (
                "SessionConnectionInformation",
                sessionConnectionInformationSdp,
                nil
            ),
            ("SessionBandwidth", sessionBandwithSdp, nil),
            ("SessionEncryptionKey", sessionEncryptionKeySdp, nil),
            (
                "SessionEncryptionKeyExtraCRLF",
                sessionEncryptionKeySdpExtraCrLf,
                sessionEncryptionKeySdp
            ),
            ("SessionAttributes", sessionAttributesSdp, nil),
            (
                "TimeZonesSDP2ExtraCRLF",
                timeZonesSdp2ExtraCrLf,
                timeZonesSdp2
            ),
            ("MediaName", mediaNameSdp, nil),
            (
                "MediaNameExtraCRLF",
                mediaNameSdpExtraCrLf,
                mediaNameSdp
            ),
            ("MediaTitle", mediaTitleSdp, nil),
            (
                "MediaConnectionInformation",
                mediaConnectionInformationSdp,
                nil
            ),
            (
                "MediaConnectionInformationExtraCRLF",
                mediaConnectionInformationSdpExtraCrLf,
                mediaConnectionInformationSdp
            ),
            (
                "MediaDescriptionOutOfOrder",
                mediaDescriptionOutOfOrderSdp,
                mediaDescriptionOutOfOrderSdpActual
            ),
            ("MediaBandwidth", mediaBandwidthSdp, nil),
            ("MediaEncryptionKey", mediaEncryptionKeySdp, nil),
            (
                "MediaEncryptionKeyExtraCRLF",
                mediaEncryptionKeySdpExtraCrLf,
                mediaEncryptionKeySdp
            ),
            ("MediaAttributes", mediaAttributesSdp, nil),
            ("CanonicalUnmarshal", canonicalUnmarshalSdp, nil),
        ]

        for (name, sdp_str, expected) in tests {
            let sdp = try? SessionDescription.unmarshal(input: sdp_str)
            XCTAssertNotNil(sdp, "\(name)\n\(sdp_str)")
            let actual = sdp?.marshal()
            if let expected = expected {
                XCTAssertEqual(expected, actual, "\(name)\n\(sdp_str)")
            } else {
                XCTAssertEqual(sdp_str, actual, "\(name)\n\(sdp_str)")
            }
        }
    }

    func testUnmarshalRepeatTimes() throws {
        let sdp = try SessionDescription.unmarshal(input: repeatTimesSdp)
        let actual = sdp.marshal()
        XCTAssertEqual(repeatTimesSdpExpected, actual)
    }

    func testUnmarshalRepeatTimesOverflow() throws {
        do {
            let _ = try SessionDescription.unmarshal(input: repeatTimesOverflowSdp)
            XCTAssertTrue(false, "unmarshal should be failed")
        } catch SDPError.sdpInvalidValue(let value) {
            XCTAssertEqual("106751991167301d", value)
        } catch {
            XCTAssertTrue(false, "unexpected error")
        }
    }

    func testUnmarshalTimeZones() throws {
        let sdp = try SessionDescription.unmarshal(input: timeZonesSdp)
        let actual = sdp.marshal()
        XCTAssertEqual(timeZonesSdpExpected, actual)
    }

    func testUnmarshalNonNilAddress() throws {
        let input = "v=0\r\no=0 0 0 IN IP4 0\r\ns=0\r\nc=IN IP4\r\nt=0 0\r\n"
        let sdp = try? SessionDescription.unmarshal(input: input)
        XCTAssertNotNil(sdp, "sdp shouldn't be nil")
        let output = sdp?.marshal()
        XCTAssertEqual(input, output)
    }
}
