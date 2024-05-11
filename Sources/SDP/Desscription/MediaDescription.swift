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

/// RangedPort supports special format for the media field "m=" port value. If
/// it may be necessary to specify multiple transport ports, the protocol allows
/// to write it as: <port>/<number of ports> where number of ports is a an
/// offsetting range.
public struct RangedPort: Equatable, CustomStringConvertible {
    var value: Int
    var range: Int?

    public var description: String {
        if let range = self.range {
            return "\(self.value)/\(range)"
        } else {
            return "\(self.value)"
        }
    }

    init(value: Int, range: Int? = nil) {
        self.value = value
        self.range = range
    }
}

/// MediaName describes the "m=" field storage structure.
public struct MediaName: Equatable, CustomStringConvertible {
    var media: String
    var port: RangedPort
    var protos: [String]
    var formats: [String]

    public var description: String {
        let s = [
            self.media,
            self.port.description,
            self.protos.joined(separator: "/"),
            self.formats.joined(separator: " "),
        ]
        return s.joined(separator: " ")
    }

    init() {
        self.media = ""
        self.port = RangedPort(value: 0)
        self.protos = []
        self.formats = []
    }

    init(media: String, port: RangedPort, protos: [String], formats: [String]) {
        self.media = media
        self.port = port
        self.protos = protos
        self.formats = formats
    }
}

/// MediaDescription represents a media type.
/// <https://tools.ietf.org/html/rfc4566#section-5.14>
public struct MediaDescription: Equatable {
    /// `m=<media> <port>/<number of ports> <proto> <fmt> ...`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.14>
    var mediaName: MediaName

    /// `i=<session description>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.4>
    var mediaTitle: Information?

    /// `c=<nettype> <addrtype> <connection-address>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.7>
    var connectionInformation: ConnectionInformation?

    /// `b=<bwtype>:<bandwidth>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.8>
    var bandwidth: [Bandwidth]

    /// `k=<method>`
    ///
    /// `k=<method>:<encryption key>`
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.12>
    var encryptionKey: EncryptionKey?

    /// Attributes are the primary means for extending SDP.  Attributes may
    /// be defined to be used as "session-level" attributes, "media-level"
    /// attributes, or both.
    ///
    /// <https://tools.ietf.org/html/rfc4566#section-5.12>
    var attributes: [Attribute]

    /// attribute returns the value of an attribute and if it exists
    public func attribute(key: String) -> (Bool, String?) {
        for attribute in attributes {
            if attribute.key == key {
                return (true, attribute.value)
            }
        }
        return (false, nil)
    }

    init() {
        self.mediaName = MediaName()
        self.mediaTitle = nil
        self.connectionInformation = nil
        self.bandwidth = []
        self.encryptionKey = nil
        self.attributes = []
    }

    init(
        mediaName: MediaName,
        mediaTitle: Information? = nil,
        connectionInformation: ConnectionInformation? = nil,
        bandwidth: [Bandwidth] = [],
        encryptionKey: EncryptionKey? = nil,
        attributes: [Attribute] = []
    ) {
        self.mediaName = mediaName
        self.mediaTitle = mediaTitle
        self.connectionInformation = connectionInformation
        self.bandwidth = bandwidth
        self.encryptionKey = encryptionKey
        self.attributes = attributes
    }

    /// creates a new MediaName with
    /// some settings that are required by the JSEP spec.
    init(codecType: String, _codecPrefs: [String]) {
        self.mediaName = MediaName(
            media: codecType,
            port: RangedPort(value: 9),
            protos: [
                "UDP",
                "TLS",
                "RTP",
                "SAVPF",
            ],
            formats: [])
        self.mediaTitle = nil
        self.connectionInformation = ConnectionInformation(
            networkType: "IN",
            addressType: "IP4",
            address: Address(
                address: "0.0.0.0",
                ttl: nil,
                range: nil)
        )
        self.bandwidth = []
        self.encryptionKey = nil
        self.attributes = []
    }

    /// adds a property attribute 'a=key' to the media description
    public mutating func withPropertyAttribute(key: String) -> MediaDescription {
        self.attributes.append(Attribute(key: key))
        return self
    }

    /// adds a value attribute 'a=key:value' to the media description
    public mutating func withValueAttribute(key: String, value: String) -> MediaDescription {
        self.attributes.append(Attribute(key: key, value: value))
        return self
    }

    /// adds a fingerprint to the media description
    public mutating func withFingerprint(algorithm: String, value: String) -> MediaDescription {
        return self.withValueAttribute(key: "fingerprint", value: algorithm + " " + value)
    }

    /// adds ICE credentials to the media description
    public mutating func withIceCredentials(username: String, password: String) -> MediaDescription
    {
        self = self.withValueAttribute(key: "ice-ufrag", value: username)
        return self.withValueAttribute(key: "ice-pwd", value: password)
    }

    /// adds codec information to the media description
    public mutating func withCodec(
        payloadType: UInt8,
        name: String,
        clockrate: UInt32,
        channels: UInt16,
        fmtp: String
    ) -> MediaDescription {
        self.mediaName.formats.append(String(payloadType))
        var rtpmap = "\(payloadType) \(name)/\(clockrate)"
        if channels > 0 {
            rtpmap += "/\(channels)"
        }

        if !fmtp.isEmpty {
            self = self.withValueAttribute(key: "rtpmap", value: rtpmap)
            return self.withValueAttribute(key: "fmtp", value: "\(payloadType) \(fmtp)")
        } else {
            return self.withValueAttribute(key: "rtpmap", value: rtpmap)
        }
    }

    /// adds media source information to the media description
    public mutating func withMediaSource(
        ssrc: UInt32,
        cname: String,
        streamLabel: String,
        label: String
    ) -> MediaDescription {
        self = self.withValueAttribute(key: "ssrc", value: "\(ssrc) cname:\(cname)")
        self = self.withValueAttribute(key: "ssrc", value: "\(ssrc) msid:\(streamLabel) \(label)")
        self = self.withValueAttribute(key: "ssrc", value: "\(ssrc) mslabel:\(streamLabel)")
        return self.withValueAttribute(key: "ssrc", value: "\(ssrc) label:\(label)")
    }

    /// adds an ICE candidate to the media description
    /// Deprecated: use WithICECandidate instead
    public mutating func withCandidate(value: String) -> MediaDescription {
        return self.withValueAttribute(key: "candidate", value: value)
    }

    public mutating func withExtMap(extmap: ExtMap) -> MediaDescription {
        return self.withPropertyAttribute(key: extmap.marshal())
    }

    /// adds an extmap to the media description
    public mutating func withTransportCcExtMap() -> MediaDescription {
        let extmap = ExtMap(
            value: defaultExtMapValueTransportCc,
            direction: nil,
            uri: transportCcUri,
            extAttr: nil)

        return self.withExtMap(extmap: extmap)
    }
}
