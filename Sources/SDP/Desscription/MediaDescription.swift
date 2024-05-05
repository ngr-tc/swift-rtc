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
public struct RangedPort: Equatable {
    var value: Int
    var range: Int?

    init(value: Int, range: Int? = nil) {
        self.value = value
        self.range = range
    }
}

/// MediaName describes the "m=" field storage structure.
public struct MediaName: Equatable {
    var media: String
    var port: RangedPort
    var protos: [String]
    var formats: [String]
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
}
