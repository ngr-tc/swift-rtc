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

func keyValueBuild(key: String, value: String?) -> String {
    if let val = value {
        return "\(key)\(val)\(endLine)"
    } else {
        return ""
    }
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

    init() {
        self.version = 0
        self.origin = Origin(
            username: "",
            sessionId: 0,
            sessionVersion: 0,
            networkType: "",
            addressType: "",
            unicastAddress: ""
        )
        self.sessionName = ""
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
        self.attributes = []
        self.mediaDescriptions = []
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

    /// Unmarshal is the primary function that deserializes the session description
    /// message and stores it inside of a structured SessionDescription object.
    ///
    /// The States Transition Table describes the computation flow between functions
    /// (namely s1, s2, s3, ...) for a parsing procedure that complies with the
    /// specifications laid out by the rfc4566#section-5 as well as by JavaScript
    /// Session Establishment Protocol draft. Links:
    ///     <https://tools.ietf.org/html/rfc4566#section-5>
    ///     <https://tools.ietf.org/html/draft-ietf-rtcweb-jsep-24>
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
    ///
    /// In order to generate the following state table and draw subsequent
    /// deterministic finite-state automota ("DFA") the following regex was used to
    /// derive the DFA:
    ///    vosi?u?e?p?c?b*(tr*)+z?k?a*(mi?c?b*k?a*)*
    /// possible place and state to exit:
    ///                    **   * * *  ** * * * *
    ///                    99   1 1 1  11 1 1 1 1
    ///                         3 1 1  26 5 5 4 4
    ///
    /// Please pay close attention to the `k`, and `a` parsing states. In the table
    /// below in order to distinguish between the states belonging to the media
    /// description as opposed to the session description, the states are marked
    /// with an asterisk ("a*", "k*").
    ///
    /// ```text
    /// +--------+----+-------+----+-----+----+-----+---+----+----+---+---+-----+---+---+----+---+----+
    /// | STATES | a* | a*,k* | a  | a,k | b  | b,c | e | i  | m  | o | p | r,t | s | t | u  | v | z  |
    /// +--------+----+-------+----+-----+----+-----+---+----+----+---+---+-----+---+---+----+---+----+
    /// |   s1   |    |       |    |     |    |     |   |    |    |   |   |     |   |   |    | 2 |    |
    /// |   s2   |    |       |    |     |    |     |   |    |    | 3 |   |     |   |   |    |   |    |
    /// |   s3   |    |       |    |     |    |     |   |    |    |   |   |     | 4 |   |    |   |    |
    /// |   s4   |    |       |    |     |    |   5 | 6 |  7 |    |   | 8 |     |   | 9 | 10 |   |    |
    /// |   s5   |    |       |    |     |  5 |     |   |    |    |   |   |     |   | 9 |    |   |    |
    /// |   s6   |    |       |    |     |    |   5 |   |    |    |   | 8 |     |   | 9 |    |   |    |
    /// |   s7   |    |       |    |     |    |   5 | 6 |    |    |   | 8 |     |   | 9 | 10 |   |    |
    /// |   s8   |    |       |    |     |    |   5 |   |    |    |   |   |     |   | 9 |    |   |    |
    /// |   s9   |    |       |    |  11 |    |     |   |    | 12 |   |   |   9 |   |   |    |   | 13 |
    /// |   s10  |    |       |    |     |    |   5 | 6 |    |    |   | 8 |     |   | 9 |    |   |    |
    /// |   s11  |    |       | 11 |     |    |     |   |    | 12 |   |   |     |   |   |    |   |    |
    /// |   s12  |    |    14 |    |     |    |  15 |   | 16 | 12 |   |   |     |   |   |    |   |    |
    /// |   s13  |    |       |    |  11 |    |     |   |    | 12 |   |   |     |   |   |    |   |    |
    /// |   s14  | 14 |       |    |     |    |     |   |    | 12 |   |   |     |   |   |    |   |    |
    /// |   s15  |    |    14 |    |     | 15 |     |   |    | 12 |   |   |     |   |   |    |   |    |
    /// |   s16  |    |    14 |    |     |    |  15 |   |    | 12 |   |   |     |   |   |    |   |    |
    /// +--------+----+-------+----+-----+----+-----+---+----+----+---+---+-----+---+---+----+---+----+
    /// ```
    public static func unmarshal(input: String) throws -> SessionDescription {
        let desc = SessionDescription()
        let lexer = Lexer(desc: desc, input: input)
        var state: StateFn? = StateFn(f: s1)
        while let s = state {
            state = try (s.f)(lexer)
        }
        return lexer.desc
    }
}

func s1(lexer: Lexer) throws -> StateFn? {
    let key = try lexer.readKey()
    if key != "v=" {
        throw SDPError.sdpInvalidSyntax(key)
    }
    return StateFn(f: unmarshalProtocolVersion)
}

func s2(lexer: Lexer) throws -> StateFn? {
    let key = try lexer.readKey()
    if key != "o=" {
        throw SDPError.sdpInvalidSyntax(key)
    }
    return StateFn(f: unmarshalOrigin)
}

func s3(lexer: Lexer) throws -> StateFn? {
    let key = try lexer.readKey()
    if key != "s=" {
        throw SDPError.sdpInvalidSyntax(key)
    }
    return StateFn(f: unmarshalSessionName)
}

func s4(lexer: Lexer) throws -> StateFn? {
    let key = try lexer.readKey()
    switch key {
    case "i=":
        return StateFn(f: unmarshalSessionInformation)
    /*case "u=":
        return StateFn(f: unmarshalUri)
    case "e=":
        return StateFn(f: unmarshalEmail)
    case "p=":
        return StateFn(f: unmarshalPhone)
    case "c=":
        return StateFn(f: unmarshalSessionConnectionInformation)
    case "b=":
        return StateFn(f: unmarshalSessionBandwidth)
    case "t=":
        return StateFn(f: unmarshalTiming)*/
    default:
        throw SDPError.sdpInvalidSyntax(key)
    }
}

func unmarshalProtocolVersion(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()

    guard let version = UInt32(value) else {
        throw SDPError.parseInt(value)
    }

    // As off the latest draft of the rfc this value is required to be 0.
    // https://tools.ietf.org/html/draft-ietf-rtcweb-jsep-24#section-5.8.1
    if version != 0 {
        throw SDPError.sdpInvalidSyntax(value)
    }

    return StateFn(f: s2)
}

func unmarshalOrigin(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()

    let fields = value.split(separator: " ", omittingEmptySubsequences: true).map { String($0) }
    if fields.count != 6 {
        throw SDPError.sdpInvalidSyntax("`o=\(value)`")
    }

    guard let sessionId = UInt64(fields[1]) else {
        throw SDPError.parseInt(fields[1])
    }
    guard let sessionVersion = UInt64(fields[2]) else {
        throw SDPError.parseInt(fields[2])
    }

    // Set according to currently registered with IANA
    // https://tools.ietf.org/html/rfc4566#section-8.2.6
    if indexOf(element: fields[3], dataSet: ["IN"]) == nil {
        throw SDPError.sdpInvalidValue(fields[3])
    }

    // Set according to currently registered with IANA
    // https://tools.ietf.org/html/rfc4566#section-8.2.7
    if indexOf(element: fields[4], dataSet: ["IP4", "IP6"]) == nil {
        throw SDPError.sdpInvalidValue(fields[4])
    }

    // TODO validated UnicastAddress

    lexer.desc.origin = Origin(
        username: fields[0],
        sessionId: sessionId,
        sessionVersion: sessionVersion,
        networkType: fields[3],
        addressType: fields[4],
        unicastAddress: fields[5]
    )

    return StateFn(f: s3)
}

func unmarshalSessionName(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()
    lexer.desc.sessionName = value
    return StateFn(f: s4)
}

func unmarshalSessionInformation(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()
    lexer.desc.sessionInformation = value
    return nil  //TODO: StateFn(f: s7)
}

func unmarshalUri(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()
    lexer.desc.uri = value
    return nil  //TODO: StateFn(f: s10)
}

func unmarshalEmail(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()
    lexer.desc.emailAddress = value
    return nil  //TODO: StateFn { f: s6 }))
}

func unmarshalPhone(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()
    lexer.desc.phoneNumber = value
    return nil  //TODO: StateFn { f: s8 }))
}

func unmarshalSessionConnectionInformation(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()
    lexer.desc.connectionInformation = try unmarshalConnectionInformation(value: value)
    return nil  //TODO: StateFn { f: s5 }))
}

func unmarshalConnectionInformation(value: String) throws -> ConnectionInformation? {
    let fields = value.split(separator: " ", omittingEmptySubsequences: true).map { String($0) }
    if fields.count < 2 {
        throw SDPError.sdpInvalidSyntax("`c=\(value)`")
    }

    // Set according to currently registered with IANA
    // https://tools.ietf.org/html/rfc4566#section-8.2.6
    if indexOf(element: fields[0], dataSet: ["IN"]) == nil {
        throw SDPError.sdpInvalidValue(fields[0])
    }

    // Set according to currently registered with IANA
    // https://tools.ietf.org/html/rfc4566#section-8.2.7
    if indexOf(element: fields[1], dataSet: ["IP4", "IP6"]) == nil {
        throw SDPError.sdpInvalidValue(fields[1])
    }

    let address: Address? =
        if fields.count > 2 {
            Address(
                address: fields[2],
                ttl: nil,
                range: nil
            )
        } else {
            nil
        }

    return ConnectionInformation(
        networkType: fields[0],
        addressType: fields[1],
        address: address
    )
}

func unmarshalSessionBandwidth(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()
    lexer.desc.bandwidth.append(try unmarshalBandwidth(value: value))
    return nil  //TODO: StateFn { f: s5 }))
}

func unmarshalBandwidth(value: String) throws -> Bandwidth {
    let parts = value.split(separator: ":").map { String($0) }
    if parts.count != 2 {
        throw SDPError.sdpInvalidSyntax("`b=\(value)`")
    }

    var bandwidthType = parts[0]
    let experimental = bandwidthType.starts(with: "X-")
    if experimental {
        bandwidthType = bandwidthType.trimmingPrefix("X-")
    } else {
        // Set according to currently registered with IANA
        // https://tools.ietf.org/html/rfc4566#section-5.8
        if indexOf(element: bandwidthType, dataSet: ["CT", "AS"]) == nil {
            throw SDPError.sdpInvalidValue(bandwidthType)
        }
    }

    guard let bandwidth = UInt64(parts[1]) else {
        throw SDPError.parseInt(parts[1])
    }

    return Bandwidth(
        experimental: experimental,
        bandwidthType: bandwidthType,
        bandwidth: bandwidth)
}

func unmarshalTiming(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()

    let fields = value.split(separator: " ", omittingEmptySubsequences: true).map { String($0) }
    if fields.count < 2 {
        throw SDPError.sdpInvalidSyntax("`t=\(value)`")
    }

    guard let startTime = UInt64(fields[0]) else {
        throw SDPError.parseInt(fields[0])
    }
    guard let stopTime = UInt64(fields[1]) else {
        throw SDPError.parseInt(fields[1])
    }

    lexer.desc.timeDescriptions.append(
        TimeDescription(
            timing: Timing(startTime: startTime, stopTime: stopTime),
            repeatTimes: []))

    return nil  //TODO: StateFn { f: s9 }))
}

func unmarshalRepeatTimes(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()

    let fields = value.split(separator: " ", omittingEmptySubsequences: true).map { String($0) }
    if fields.count < 3 {
        throw SDPError.sdpInvalidSyntax("`r=\(value)`")
    }

    if lexer.desc.timeDescriptions.isEmpty {
        throw SDPError.sdpEmptyTimeDescription
    }

    let interval = try parseTimeUnits(value: fields[0])
    let duration = try parseTimeUnits(value: fields[1])
    var offsets: [Int64] = []
    for i in 2..<fields.count {
        let offset = try parseTimeUnits(value: fields[i])
        offsets.append(offset)
    }
    lexer.desc.timeDescriptions[lexer.desc.timeDescriptions.count - 1].repeatTimes.append(
        RepeatTime(
            interval: interval,
            duration: duration,
            offsets: offsets))

    return nil  //TODO: StateFn { f: s9 }))
}

func unmarshalTimeZones(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()

    // These fields are transimitted in pairs
    // z=<adjustment time> <offset> <adjustment time> <offset> ....
    // so we are making sure that there are actually multiple of 2 total.
    let fields = value.split(separator: " ", omittingEmptySubsequences: true).map { String($0) }
    if fields.count % 2 != 0 {
        throw SDPError.sdpInvalidSyntax("`t=\(value)`")
    }

    for i in stride(from: 0, to: fields.count, by: 2) {
        guard let adjustmentTime = UInt64(fields[i]) else {
            throw SDPError.parseInt(fields[i])
        }
        let offset = try parseTimeUnits(value: fields[i + 1])

        lexer.desc.timeZones.append(
            TimeZone(
                adjustmentTime: adjustmentTime,
                offset: offset))
    }

    return nil  //TODO: StateFn { f: s13 }))
}

func unmarshalSessionEncryptionKey(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()
    lexer.desc.encryptionKey = value
    return nil  //TODO: StateFn { f: s11 }))
}

func unmarshalSessionAttribute(lexer: Lexer) throws -> StateFn? {
    let value = try lexer.readValue()

    let fields = value.split(separator: ":", maxSplits: 1).map { String($0) }
    let attribute =
        if fields.count == 2 {
            Attribute(
                key: fields[0],
                value: fields[1]
            )
        } else {
            Attribute(
                key: fields[0])
        }
    lexer.desc.attributes.append(attribute)

    return nil  //TODO:StateFn { f: s11 }))
}
/*
 fn unmarshal_media_description<'a, R: io::BufRead + io::Seek>(
     lexer: &mut Lexer<'a, R>,
 ) -> Result<Option<StateFn<'a, R>>> {
     let (value, _) = read_value(lexer.reader)?;

     let fields: Vec<&str> = value.split_whitespace().collect();
     if fields.len() < 4 {
         return Err(Error::SdpInvalidSyntax(format!("`m={value}`")));
     }

     // <media>
     // Set according to currently registered with IANA
     // https://tools.ietf.org/html/rfc4566#section-5.14
     let i = index_of(
         fields[0],
         &["audio", "video", "text", "application", "message"],
     );
     if i == -1 {
         return Err(Error::SdpInvalidValue(fields[0].to_owned()));
     }

     // <port>
     let parts: Vec<&str> = fields[1].split('/').collect();
     let port_value = parts[0].parse::<u16>()? as isize;
     let port_range = if parts.len() > 1 {
         Some(parts[1].parse::<i32>()? as isize)
     } else {
         None
     };

     // <proto>
     // Set according to currently registered with IANA
     // https://tools.ietf.org/html/rfc4566#section-5.14
     let mut protos = vec![];
     for proto in fields[2].split('/').collect::<Vec<&str>>() {
         let i = index_of(
             proto,
             &[
                 "UDP", "RTP", "AVP", "SAVP", "SAVPF", "TLS", "DTLS", "SCTP", "AVPF",
             ],
         );
         if i == -1 {
             return Err(Error::SdpInvalidValue(fields[2].to_owned()));
         }
         protos.push(proto.to_owned());
     }

     // <fmt>...
     let mut formats = vec![];
     for field in fields.iter().skip(3) {
         formats.push(field.to_string());
     }

     lexer.desc.media_descriptions.push(MediaDescription {
         media_name: MediaName {
             media: fields[0].to_owned(),
             port: RangedPort {
                 value: port_value,
                 range: port_range,
             },
             protos,
             formats,
         },
         media_title: None,
         connection_information: None,
         bandwidth: vec![],
         encryption_key: None,
         attributes: vec![],
     });

     Ok(Some(StateFn { f: s12 }))
 }

 fn unmarshal_media_title<'a, R: io::BufRead + io::Seek>(
     lexer: &mut Lexer<'a, R>,
 ) -> Result<Option<StateFn<'a, R>>> {
     let (value, _) = read_value(lexer.reader)?;

     if let Some(latest_media_desc) = lexer.desc.media_descriptions.last_mut() {
         latest_media_desc.media_title = Some(value);
         Ok(Some(StateFn { f: s16 }))
     } else {
         Err(Error::SdpEmptyTimeDescription)
     }
 }

 fn unmarshal_media_connection_information<'a, R: io::BufRead + io::Seek>(
     lexer: &mut Lexer<'a, R>,
 ) -> Result<Option<StateFn<'a, R>>> {
     let (value, _) = read_value(lexer.reader)?;

     if let Some(latest_media_desc) = lexer.desc.media_descriptions.last_mut() {
         latest_media_desc.connection_information = unmarshal_connection_information(&value)?;
         Ok(Some(StateFn { f: s15 }))
     } else {
         Err(Error::SdpEmptyTimeDescription)
     }
 }

 fn unmarshal_media_bandwidth<'a, R: io::BufRead + io::Seek>(
     lexer: &mut Lexer<'a, R>,
 ) -> Result<Option<StateFn<'a, R>>> {
     let (value, _) = read_value(lexer.reader)?;

     if let Some(latest_media_desc) = lexer.desc.media_descriptions.last_mut() {
         let bandwidth = unmarshal_bandwidth(&value)?;
         latest_media_desc.bandwidth.push(bandwidth);
         Ok(Some(StateFn { f: s15 }))
     } else {
         Err(Error::SdpEmptyTimeDescription)
     }
 }

 fn unmarshal_media_encryption_key<'a, R: io::BufRead + io::Seek>(
     lexer: &mut Lexer<'a, R>,
 ) -> Result<Option<StateFn<'a, R>>> {
     let (value, _) = read_value(lexer.reader)?;

     if let Some(latest_media_desc) = lexer.desc.media_descriptions.last_mut() {
         latest_media_desc.encryption_key = Some(value);
         Ok(Some(StateFn { f: s14 }))
     } else {
         Err(Error::SdpEmptyTimeDescription)
     }
 }

 fn unmarshal_media_attribute<'a, R: io::BufRead + io::Seek>(
     lexer: &mut Lexer<'a, R>,
 ) -> Result<Option<StateFn<'a, R>>> {
     let (value, _) = read_value(lexer.reader)?;

     let fields: Vec<&str> = value.splitn(2, ':').collect();
     let attribute = if fields.len() == 2 {
         Attribute {
             key: fields[0].to_owned(),
             value: Some(fields[1].to_owned()),
         }
     } else {
         Attribute {
             key: fields[0].to_owned(),
             value: None,
         }
     };

     if let Some(latest_media_desc) = lexer.desc.media_descriptions.last_mut() {
         latest_media_desc.attributes.push(attribute);
         Ok(Some(StateFn { f: s14 }))
     } else {
         Err(Error::SdpEmptyTimeDescription)
     }
 }

 */
func parseTimeUnits(value: String) throws -> Int64 {
    // Some time offsets in the protocol can be provided with a shorthand
    // notation. This code ensures to convert it to NTP timestamp format.
    let (num, factor) =
        if let last = value.last {
            switch last {
            case "d":
                (String(value.dropLast()), 86400)  // days
            case "h":
                (String(value.dropLast()), 3600)  // hours
            case "m":
                (String(value.dropLast()), 60)  // minutes
            case "s":
                (String(value.dropLast()), 1)  // seconds (allowed for completeness)
            default:
                (value, 1)
            }
        } else {
            (value, 1)
        }

    guard let parsedNum = Int64(num) else {
        throw SDPError.sdpInvalidValue(value)
    }

    let result = parsedNum.multipliedReportingOverflow(by: Int64(factor))
    if result.overflow {
        throw SDPError.sdpInvalidValue(value)
    }

    return result.partialValue
}
