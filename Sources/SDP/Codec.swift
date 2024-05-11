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

/// Codec represents a codec parsed from
/// a=rtpmap:<payload type> <encoding name>/<clock rate>[/<encoding parameters>]
/// a=fmtp:<format> <format specific parameters>
/// a=ftcp-fb:<payload type> <RTCP feedback type> [<RTCP feedback parameter>]
public struct Codec: Equatable, CustomStringConvertible {
    var payloadType: UInt8
    var name: String
    var clockRate: UInt32
    var encodingParameters: String
    var fmtp: String
    var rtcpFeedbacks: [String]

    public var description: String {
        return
            "\(self.payloadType) \(self.name)/\(self.clockRate)/\(self.encodingParameters) (\(self.fmtp)) [\(self.rtcpFeedbacks.joined(separator: ", "))]"
    }

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
        throw SDPError.parseInt(String(ptSplit[1]), rtpMap)
    }

    let split = components[1].split(separator: "/")
    let name = String(split[0])
    let clockRate: UInt32 = try {
        if split.count > 1 {
            guard let clockRate = UInt32(split[1]) else {
                throw SDPError.parseInt(String(split[1]), rtpMap)
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
        throw SDPError.parseInt(String(split[1]), fmtp)
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
    let components = rtcpFb.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
    if components.count != 2 {
        throw SDPError.missingWhitespace
    }

    let ptSplit = components[0].split(separator: ":")
    if ptSplit.count != 2 {
        throw SDPError.missingColon
    }
    guard let payloadType = UInt8(ptSplit[1]) else {
        throw SDPError.parseInt(String(ptSplit[1]), rtcpFb)
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
        var rtcpFeedbacks = savedCodec.rtcpFeedbacks
        rtcpFeedbacks.append(contentsOf: codec.rtcpFeedbacks)

        codecs[codec.payloadType] = Codec(
            payloadType: savedCodec.payloadType == 0
                ? codec.payloadType
                : savedCodec.payloadType,
            name: savedCodec.name.isEmpty
                ? codec.name
                : savedCodec.name,
            clockRate: savedCodec.clockRate == 0
                ? codec.clockRate
                : savedCodec.clockRate,
            encodingParameters: savedCodec.encodingParameters.isEmpty
                ? codec.encodingParameters
                : savedCodec.encodingParameters,
            fmtp: savedCodec.fmtp.isEmpty
                ? codec.fmtp
                : savedCodec.fmtp,
            rtcpFeedbacks: rtcpFeedbacks)
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
