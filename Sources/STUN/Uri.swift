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
import WebURL

/// SCHEME definitions from RFC 7064 Section 3.2.
public let stunScheme: String = "stun"
public let stunSchemeSecure: String = "stuns"

/// URI as defined in RFC 7064.
public struct Uri: Equatable {
    var scheme: String
    var host: String
    var port: UInt16?

    public init(scheme: String, host: String, port: UInt16? = nil) {
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    /// parse_uri parses URI from string.
    public static func parseUri(_ raw: String) throws -> Self {
        // work around for url crate
        if raw.contains("//") {
            throw STUNError.errInvalidUrl
        }

        var s = raw
        if let p = s.firstIndex(of: ":") {
            s.replaceSubrange(p..<s.index(after: p), with: "://")
        } else {
            throw STUNError.errSchemeType
        }

        guard let url = WebURL(s) else {
            throw STUNError.errInvalidUrl
        }

        if url.scheme != stunScheme && url.scheme != stunSchemeSecure {
            throw STUNError.errSchemeType
        }

        guard let hostname = url.hostname else {
            throw STUNError.errHost
        }

        let host = hostname.trimmingWhitespace()
            .trimmingPrefix("[")
            .trimmingSuffix("]")

        let port: UInt16? =
            if let port = url.port {
                UInt16(port)
            } else {
                nil
            }

        return Uri(scheme: url.scheme, host: String(host), port: port)
    }
}

extension Uri: CustomStringConvertible {
    public var description: String {
        let host =
            if self.host.contains(":") {
                "[\(self.host)]"
            } else {
                self.host
            }

        if let port = self.port {
            return "\(self.scheme):\(host):\(port)"
        } else {
            return "\(self.scheme):\(host)"
        }
    }
}
