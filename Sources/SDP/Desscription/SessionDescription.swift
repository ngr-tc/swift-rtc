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

/// Constants for SDP attributes used in JSEP
public let attrKeyCandidate: String = "candidate"
public let attrKeyEndOfCandidates: String = "end-of-candidates"
public let attrKeyIdentity: String = "identity"
public let attrKeyGroup: String = "group"
public let attrKeySsrc: String = "ssrc"
public let attrKeySsrcGroup: String = "ssrc-group"
public let attrKeyMsid: String = "msid"
public let attrKeyMsidSemantic: String = "msid-semantic"
public let attrKeyConnectionSetup: String = "setup"
public let attrKeyMid: String = "mid"
public let attrKeyIceLite: String = "ice-lite"
public let attrKeyRtcpMux: String = "rtcp-mux"
public let attrKeyRtcpRsize: String = "rtcp-rsize"
public let attrKeyInactive: String = "inactive"
public let attrKeyRecvOnly: String = "recvonly"
public let attrKeySendOnly: String = "sendonly"
public let attrKeySendRecv: String = "sendrecv"
public let attrKeyExtMap: String = "extmap"

/// Constants for semantic tokens used in JSEP
public let semanticTokenLipSynchronization: String = "LS"
public let semanticTokenFlowIdentification: String = "FID"
public let semanticTokenForwardErrorCorrection: String = "FEC"
public let semanticTokenWebrtcMediaStreams: String = "WMS"

/// Version describes the value provided by the "v=" field which gives
/// the version of the Session Description Protocol.
public typealias Version = Int

/// Origin defines the structure for the "o=" field which provides the
/// originator of the session plus a session identifier and version number.
public struct Origin: Equatable, CustomStringConvertible {
    var username: String
    var sessionId: UInt64
    var sessionVersion: UInt64
    var networkType: String
    var addressType: String
    var unicastAddress: String

    public var description: String {
        return
            "\(self.username) \(self.sessionId) \(self.sessionVersion) \(self.networkType) \(self.addressType) \(self.unicastAddress)"
    }
}

/// SessionName describes a structured representations for the "s=" field
/// and is the textual session name.
public typealias SessionName = String

/// EmailAddress describes a structured representations for the "e=" line
/// which specifies email contact information for the person responsible for
/// the conference.
public typealias EmailAddress = String

/// PhoneNumber describes a structured representations for the "p=" line
/// specify phone contact information for the person responsible for the
/// conference.
public typealias PhoneNumber = String

/// TimeZone defines the structured object for "z=" line which describes
/// repeated sessions scheduling.
public struct TimeZone: Equatable, CustomStringConvertible {
    var adjustmentTime: UInt64
    var offset: Int64

    public var description: String {
        return "\(self.adjustmentTime) \(self.offset)"
    }
}

/// Timing defines the "t=" field's structured representation for the start and
/// stop times.
public struct Timing: Equatable, CustomStringConvertible {
    var startTime: UInt64
    var stopTime: UInt64

    public var description: String {
        return "\(self.startTime) \(self.stopTime)"
    }
}

/// RepeatTime describes the "r=" fields of the session description which
/// represents the intervals and durations for repeated scheduled sessions.
public struct RepeatTime: Equatable, CustomStringConvertible {
    var interval: Int64
    var duration: Int64
    var offsets: [Int64]

    public var description: String {
        var output = "\(self.interval) \(self.duration)"
        if !offsets.isEmpty {
            output += " " + offsets.map { String($0) }.joined(separator: " ")
        }
        return output
    }
}

/// TimeDescription describes "t=", "r=" fields of the session description
/// which are used to specify the start and stop times for a session as well as
/// repeat intervals and durations for the scheduled session.
public struct TimeDescription: Equatable, CustomStringConvertible {
    /// `t=<start-time> <stop-time>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.9>
    var timing: Timing

    /// `r=<repeat interval> <active duration> <offsets from start-time>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.10>
    var repeatTimes: [RepeatTime]

    public var description: String {
        var result = keyValueBuild(key: "t=", value: self.timing.description)
        for repeatTime in self.repeatTimes {
            result += keyValueBuild(key: "r=", value: repeatTime.description)
        }
        return result
    }
}

/// https://tools.ietf.org/html/draft-ietf-rtcweb-jsep-26#section-5.2.1
/// Session ID is recommended to be constructed by generating a 64-bit
/// quantity with the highest bit set to zero and the remaining 63-bits
/// being cryptographically random.
func newSessionId() -> UInt64 {
    let c = UInt64.max ^ (UInt64(1) << 63)
    return UInt64.random(in: UInt64.min...UInt64.max) & c
}

/// SessionDescription is a a well-defined format for conveying sufficient
/// information to discover and participate in a multimedia session.
public struct SessionDescription: Equatable, CustomStringConvertible {
    /// `v=0`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.1>
    var version: Version

    /// `o=<username> <sess-id> <sess-version> <nettype> <addrtype> <unicast-address>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.2>
    var origin: Origin

    /// `s=<session name>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.3>
    var sessionName: SessionName

    /// `i=<session description>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.4>
    var sessionInformation: Information?

    /// `u=<uri>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.5>
    var uri: String?

    /// `e=<email-address>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.6>
    var emailAddress: EmailAddress?

    /// `p=<phone-number>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.6>
    var phoneNumber: PhoneNumber?

    /// `c=<nettype> <addrtype> <connection-address>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.7>
    var connectionInformation: ConnectionInformation?

    /// `b=<bwtype>:<bandwidth>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.8>
    var bandwidth: [Bandwidth]

    /// <https://tools.ietf.org/html/rfc4566#section-5.9>
    /// <https://tools.ietf.org/html/rfc4566#section-5.10>
    var timeDescriptions: [TimeDescription]

    /// `z=<adjustment time> <offset> <adjustment time> <offset> ...`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.11>
    var timeZones: [TimeZone]

    /// `k=<method>`
    ///
    /// `k=<method>:<encryption key>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.12>
    var encryptionKey: EncryptionKey?

    /// `a=<attribute>`
    ///
    /// `a=<attribute>:<value>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.13>
    var attributes: [Attribute]

    /// <https://tools.ietf.org/html/rfc4566#section-5.14>
    var mediaDescriptions: [MediaDescription]

    public var description: String {
        return self.marshal()
    }

    init(identity: Bool) {
        self.version = 0
        self.origin = Origin(
            username: "-",
            sessionId: newSessionId(),
            sessionVersion: NIODeadline.now().uptimeNanoseconds,
            networkType: "IN",
            addressType: "IP4",
            unicastAddress: "0.0.0.0"
        )
        self.sessionName = "-"
        self.sessionInformation = nil
        self.uri = nil
        self.emailAddress = nil
        self.phoneNumber = nil
        self.connectionInformation = nil
        self.bandwidth = []
        self.timeDescriptions = [
            TimeDescription(
                timing: Timing(
                    startTime: 0,
                    stopTime: 0
                ),
                repeatTimes: []
            )
        ]
        self.timeZones = []
        self.encryptionKey = nil
        self.attributes = identity ? [Attribute(key: attrKeyIdentity)] : []
        self.mediaDescriptions = []
    }

    /// adds a property attribute 'a=key' to the session description
    public mutating func withPropertyAttribute(key: String) -> SessionDescription {
        self.attributes.append(Attribute(key: key))
        return self
    }

    /// adds a value attribute 'a=key:value' to the session description
    public mutating func withValueAttribute(key: String, value: String) -> SessionDescription {
        self.attributes.append(Attribute(key: key, value: value))
        return self
    }

    /// adds a fingerprint to the session description
    public mutating func withFingerprint(algorithm: String, value: String) -> SessionDescription {
        return self.withValueAttribute(key: "fingerprint", value: algorithm + " " + value)
    }

    /// adds a media description to the session description
    public mutating func withMedia(md: MediaDescription) -> SessionDescription {
        self.mediaDescriptions.append(md)
        return self
    }

    func buildCodecMap() -> [UInt8: Codec] {
        var codecs: [UInt8: Codec] = [:]

        for m in self.mediaDescriptions {
            for a in m.attributes {
                let attr = a.description
                if attr.starts(with: "rtpmap:") {
                    if let codec = try? parseRtpMap(rtpMap: attr) {
                        mergeCodecs(codec: codec, codecs: &codecs)
                    }
                } else if attr.starts(with: "fmtp:") {
                    if let codec = try? parseFmtp(fmtp: attr) {
                        mergeCodecs(codec: codec, codecs: &codecs)
                    }
                } else if attr.starts(with: "rtcp-fb:") {
                    if let codec = try? parseRtcpFb(rtcpFb: attr) {
                        mergeCodecs(codec: codec, codecs: &codecs)
                    }
                }
            }
        }

        return codecs
    }

    /// scans the SessionDescription for the given payload type and returns the codec
    public func getCodecForPayloadType(payloadType: UInt8) -> Codec? {
        let codecs = self.buildCodecMap()
        return codecs[payloadType]
    }

    /// scans the SessionDescription for a codec that matches the provided codec
    /// as closely as possible and returns its payload type
    public func getPayloadTypeForCodec(wanted: Codec) -> UInt8? {
        let codecs = self.buildCodecMap()

        for (payloadType, codec) in codecs {
            if codecsMatch(wanted: wanted, got: codec) {
                return payloadType
            }
        }

        return nil
    }

    /// Attribute returns the value of an attribute and if it exists
    public func attribute(key: String) -> (Bool, String?) {
        for attribute in attributes {
            if attribute.key == key {
                return (true, attribute.value)
            }
        }
        return (false, nil)
    }

    /// Marshal takes a SDP struct to text
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5>
    ///
    /// Session description
    ///    v=  (protocol version)
    ///    o=  (originator and session identifier)
    ///    s=  (session name)
    ///    i=* (session information)
    ///    u=* (URI of description)
    ///    e=* (email address)
    ///    p=* (phone number)
    ///    c=* (connection information -- not required if included in
    ///         all media)
    ///    b=* (zero or more bandwidth information lines)
    ///    One or more time descriptions ("t=" and "r=" lines; see below)
    ///    z=* (time zone adjustments)
    ///    k=* (encryption key)
    ///    a=* (zero or more session attribute lines)
    ///    Zero or more media descriptions
    ///
    /// Time description
    ///    t=  (time the session is active)
    ///    r=* (zero or more repeat times)
    ///
    /// Media description, if present
    ///    m=  (media name and transport address)
    ///    i=* (media title)
    ///    c=* (connection information -- optional if included at
    ///         session level)
    ///    b=* (zero or more bandwidth information lines)
    ///    k=* (encryption key)
    ///    a=* (zero or more media attribute lines)
    public func marshal() -> String {
        var result = ""

        result += keyValueBuild(key: "v=", value: String(self.version))
        result += keyValueBuild(key: "o=", value: self.origin.description)
        result += keyValueBuild(key: "s=", value: self.sessionName)

        result += keyValueBuild(key: "i=", value: self.sessionInformation)

        if let uri = self.uri {
            result += keyValueBuild(key: "u=", value: uri)
        }
        result += keyValueBuild(key: "e=", value: self.emailAddress)
        result += keyValueBuild(key: "p=", value: self.phoneNumber)
        if let connectionInformation = self.connectionInformation {
            result += keyValueBuild(key: "c=", value: connectionInformation.description)
        }

        for bandwidth in self.bandwidth {
            result += keyValueBuild(key: "b=", value: bandwidth.description)
        }
        for timeDescription in self.timeDescriptions {
            result += keyValueBuild(key: "t=", value: timeDescription.timing.description)
            for repeatTime in timeDescription.repeatTimes {
                result += keyValueBuild(key: "r=", value: repeatTime.description)
            }
        }
        if !self.timeZones.isEmpty {
            result += keyValueBuild(
                key: "z=", value: self.timeZones.map { $0.description }.joined(separator: " "))
        }
        result += keyValueBuild(key: "k=", value: self.encryptionKey)
        for attribute in self.attributes {
            result += keyValueBuild(key: "a=", value: attribute.description)
        }

        for mediaDescription in self.mediaDescriptions {
            result += keyValueBuild(key: "m=", value: mediaDescription.mediaName.description)
            result += keyValueBuild(key: "i=", value: mediaDescription.mediaTitle)
            if let connectionInformation = mediaDescription.connectionInformation {
                result += keyValueBuild(key: "c=", value: connectionInformation.description)
            }
            for bandwidth in mediaDescription.bandwidth {
                result += keyValueBuild(key: "b=", value: bandwidth.description)
            }
            result += keyValueBuild(key: "k=", value: mediaDescription.encryptionKey)
            for attribute in mediaDescription.attributes {
                result += keyValueBuild(key: "a=", value: attribute.description)
            }
        }

        return result
    }
}
