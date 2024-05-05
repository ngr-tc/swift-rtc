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
import Utils

public class Codec {
    var payloadType: UInt8
    var name: String
    var clockRate: UInt32
    var encodingParameters: String
    var fmtp: String
    var rtcpFeedbacks: [String]

    // Initialize the Codec object with default values for its properties
    init(
        payloadType: UInt8 = 0, name: String = "", clockRate: UInt32 = 0,
        encodingParameters: String = "", fmtp: String = "", rtcpFeedbacks: [String] = []
    ) {
        self.payloadType = payloadType
        self.name = name
        self.clockRate = clockRate
        self.encodingParameters = encodingParameters
        self.fmtp = fmtp
        self.rtcpFeedbacks = rtcpFeedbacks
    }
}

func parseRtpMap(rtpMap: String) throws -> Codec {
    // a=rtpmap:<payload type> <encoding name>/<clock rate>[/<encoding parameters>]
    let components = rtpMap.split(separator: " ", omittingEmptySubsequences: true)
    if components.count != 2 {
        throw SDPError.codecNotFound
    }

    let ptSplit = components[0].split(separator: ":")
    if ptSplit.count != 2 {
        throw SDPError.missingColon
    }
    guard let payloadType = UInt8(ptSplit[1]) else {
        throw SDPError.parseExtMap("invalid payload type")
    }

    let split = components[1].split(separator: "/")
    let name = String(split[0])
    let clockRate: UInt32 = try {
        if split.count > 1 {
            guard let clockRate = UInt32(split[1]) else {
                throw SDPError.parseExtMap("invalid clock rate")
            }
            return clockRate
        } else {
            return 0
        }
    }()
    let encodingParameters = split.count > 2 ? String(split[2]) : ""

    return Codec(
        payloadType: payloadType,
        name: name,
        clockRate: clockRate,
        encodingParameters: encodingParameters,
        fmtp: "",
        rtcpFeedbacks: [])

}

func parseFmtp(fmtp: String) throws -> Codec {
    // a=fmtp:<format> <format specific parameters>
    let components = fmtp.split(separator: " ", omittingEmptySubsequences: true)
    if components.count != 2 {
        throw SDPError.missingWhitespace
    }

    let fmtp = String(components[1])

    let split = components[0].split(separator: ":")
    if split.count != 2 {
        throw SDPError.missingColon
    }
    guard let payloadType = UInt8(split[1]) else {
        throw SDPError.parseExtMap("invalid payload type")
    }

    return Codec(
        payloadType: payloadType,
        name: "",
        clockRate: 0,
        encodingParameters: "",
        fmtp: fmtp,
        rtcpFeedbacks: [])
}

func parseRtcpFb(rtcpFb: String) throws -> Codec {
    // a=ftcp-fb:<payload type> <RTCP feedback type> [<RTCP feedback parameter>]
    let components = rtcpFb.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
    if components.count != 2 {
        throw SDPError.missingWhitespace
    }

    let ptSplit = components[0].split(separator: ":")
    if ptSplit.count != 2 {
        throw SDPError.missingColon
    }
    guard let payloadType = UInt8(ptSplit[1]) else {
        throw SDPError.parseExtMap("invalid payload type")
    }

    return Codec(
        payloadType: payloadType,
        name: "",
        clockRate: 0,
        encodingParameters: "",
        fmtp: "",
        rtcpFeedbacks: [String(components[1])])
}

func mergeCodecs(codec: Codec, codecs: inout [UInt8: Codec]) {
    if let savedCodec = codecs[codec.payloadType] {
        if savedCodec.payloadType == 0 {
            savedCodec.payloadType = codec.payloadType
        }
        if savedCodec.name.isEmpty {
            savedCodec.name = codec.name
        }
        if savedCodec.clockRate == 0 {
            savedCodec.clockRate = codec.clockRate
        }
        if savedCodec.encodingParameters.isEmpty {
            savedCodec.encodingParameters = codec.encodingParameters
        }
        if savedCodec.fmtp.isEmpty {
            savedCodec.fmtp = codec.fmtp
        }
        savedCodec.rtcpFeedbacks.append(contentsOf: codec.rtcpFeedbacks)
    } else {
        codecs[codec.payloadType] = codec
    }
}

func equivalentFmtp(want: String, got: String) -> Bool {
    let wantSplit = want.split(separator: ";").map { String($0) }
    let gotSplit = got.split(separator: ";").map { String($0) }

    if wantSplit.count != gotSplit.count {
        return false
    }

    let trimmedWant = wantSplit.map { $0.trimmingWhitespace() }
    let trimmedGot = gotSplit.map { $0.trimmingWhitespace() }

    let sortedWant = trimmedWant.sorted()
    let sortedGot = trimmedGot.sorted()

    for (i, wantPart) in sortedWant.enumerated() {
        let gotPart = sortedGot[i]
        if gotPart != wantPart {
            return false
        }
    }

    return true
}

func codecsMatch(wanted: Codec, got: Codec) -> Bool {
    if !wanted.name.isEmpty && wanted.name.lowercased() != got.name.lowercased() {
        return false
    }
    if wanted.clockRate != 0 && wanted.clockRate != got.clockRate {
        return false
    }
    if !wanted.encodingParameters.isEmpty
        && wanted.encodingParameters != got.encodingParameters
    {
        return false
    }
    if !wanted.fmtp.isEmpty && !equivalentFmtp(want: wanted.fmtp, got: got.fmtp) {
        return false
    }

    return true
}