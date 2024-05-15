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

/// Information describes the "i=" field which provides textual information
/// about the session.
public typealias Information = String

/// Address describes a structured address token from within the "c=" field.
public struct Address: Equatable, CustomStringConvertible {
    var address: String
    var ttl: Int?
    var range: Int?

    public var description: String {
        var output = self.address
        if let ttl = self.ttl {
            output += "/\(ttl)"
        }
        if let range = self.range {
            output += "/\(range)"
        }
        return output
    }

    public init(address: String, ttl: Int? = nil, range: Int? = nil) {
        self.address = address
        self.ttl = ttl
        self.range = range
    }
}

/// ConnectionInformation defines the representation for the "c=" field
/// containing connection data.
public struct ConnectionInformation: Equatable, CustomStringConvertible {
    var networkType: String
    var addressType: String
    var address: Address?

    public var description: String {
        if let address = self.address {
            return "\(self.networkType) \(self.addressType) \(address)"
        } else {
            return "\(self.networkType) \(self.addressType)"
        }
    }

    public init(networkType: String, addressType: String, address: Address? = nil) {
        self.networkType = networkType
        self.addressType = addressType
        self.address = address
    }
}

/// Bandwidth describes an optional field which denotes the proposed bandwidth
/// to be used by the session or media.
public struct Bandwidth: Equatable, CustomStringConvertible {
    var experimental: Bool
    var bandwidthType: String
    var bandwidth: UInt64

    public var description: String {
        let output = self.experimental ? "X-" : ""
        return "\(output)\(self.bandwidthType):\(self.bandwidth)"
    }

    public init(experimental: Bool, bandwidthType: String, bandwidth: UInt64) {
        self.experimental = experimental
        self.bandwidthType = bandwidthType
        self.bandwidth = bandwidth
    }
}

/// EncryptionKey describes the "k=" which conveys encryption key information.
public typealias EncryptionKey = String

/// ConnectionRole indicates which of the end points should initiate the connection establishment
public enum ConnectionRole: String, Equatable, CustomStringConvertible {
    case active, passive, actpass, holdconn

    public var description: String {
        self.rawValue
    }
}

/// Direction is a marker for transmission direction of an endpoint
public enum Direction: String, Equatable, CustomStringConvertible {
    case sendrecv, sendonly, recvonly, inactive

    public var description: String {
        self.rawValue
    }
}

public let attributeKey: String = "a="

/// Attribute describes the "a=" field which represents the primary means for
/// extending SDP.
public struct Attribute: Equatable, CustomStringConvertible {
    var key: String
    var value: String?

    public var description: String {
        if let value = self.value {
            return "\(self.key):\(value)"
        } else {
            return "\(self.key)"
        }
    }

    /// init constructs a new attribute
    public init(key: String, value: String? = nil) {
        self.key = key
        self.value = value
    }

    /// isIceCandidate returns true if the attribute key equals "candidate".
    public func isIceCandidate() -> Bool {
        return self.key == "candidate"
    }
}

/// Default ext values
public let defaultExtMapValueAbsSendTime: Int = 1
public let defaultExtMapValueTransportCc: Int = 2
public let defaultExtMapValueSdesMid: Int = 3
public let defaultExtMapValueSdesRtpStreamId: Int = 4

public let absSendTimeUri: String = "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time"
public let transportCcUri: String =
    "http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01"
public let sdesMidUri: String = "urn:ietf:params:rtp-hdrext:sdes:mid"
public let sdesRtpStreamIdUri: String = "urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id"
public let sdesRepairRtpStreamIdUri: String =
    "urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id"

public let audioLevelUri: String = "urn:ietf:params:rtp-hdrext:ssrc-audio-level"
public let videoOrientationUri: String = "urn:3gpp:video-orientation"

/// ExtMap represents the activation of a single RTP header extension
public struct ExtMap: Equatable, CustomStringConvertible {
    var value: Int
    var direction: Direction?
    var uri: String?
    var extAttr: String?

    public var description: String {
        var output = String(self.value)
        if let direction = self.direction {
            output += "/\(direction)"
        }

        if let uri = self.uri {
            output += " \(uri)"
        }

        if let extAttr = self.extAttr {
            output += " \(extAttr)"
        }

        return output
    }

    public init(value: Int, direction: Direction? = nil, uri: String? = nil, extAttr: String? = nil)
    {
        self.value = value
        self.direction = direction
        self.uri = uri
        self.extAttr = extAttr
    }

    /// converts ExtMap to an Attribute
    public func convert() -> Attribute {
        return Attribute(key: "extmap", value: self.description)
    }

    /// marshal creates a string from an ExtMap
    public func marshal() -> String {
        return "extmap:" + self.description
    }

    /// unmarshal creates an Extmap from a string
    public static func unmarshal(line: String) throws -> ExtMap {
        let parts = line.trimmingWhitespace().split(separator: ":", maxSplits: 1)
        if parts.count != 2 {
            throw SDPError.parseExtMap(line)
        }

        let fields = parts[1].split(separator: " ", omittingEmptySubsequences: true)
        if fields.count < 2 {
            throw SDPError.parseExtMap(line)
        }

        let valdir = fields[0].split(separator: "/")
        guard let value = Int(valdir[0]) else {
            throw SDPError.parseExtMap(line)
        }
        if value < 1 || value > 246 {
            throw SDPError.parseExtMap("\(valdir[0]) -- extmap key must be in the range 1-246")
        }

        var direction: Direction? = nil
        if valdir.count == 2 {
            direction = Direction(rawValue: String(valdir[1]))
            if direction == nil {
                throw SDPError.parseExtMap("unknown direction from \(valdir[1])")
            }
        }

        let uri: String? = String(fields[1])
        let extAttr = fields.count == 3 ? String(fields[2]) : nil

        return ExtMap(
            value: value,
            direction: direction,
            uri: uri,
            extAttr: extAttr)
    }

    static func transportCcExtMapUri() -> [Int: String] {
        return [defaultExtMapValueTransportCc: transportCcUri]
    }
}

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
    public init(
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
