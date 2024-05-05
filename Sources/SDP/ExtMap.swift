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

    init(value: Int, direction: Direction? = nil, uri: String? = nil, extAttr: String? = nil) {
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
