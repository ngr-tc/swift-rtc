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
import Shared

/// URI as defined in RFC 7064.
public struct Uri: Equatable {
    var scheme: SchemeType
    var host: String
    var port: UInt16?

    public init(scheme: SchemeType, host: String, port: UInt16? = nil) {
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    /// parse_uri parses URI from string.
    public static func parseUri(_ raw: String) throws -> Self {
        let url = try Url(raw)
        if url.scheme != SchemeType.stun && url.scheme != SchemeType.stuns {
            throw StunError.errSchemeType
        }

        return Uri(scheme: url.scheme, host: url.host, port: url.port)
    }
}

extension Uri: CustomStringConvertible {
    public var description: String {
        let host = self.host.contains(":") ? "[\(self.host)]" : self.host
        if let port = self.port {
            return "\(self.scheme):\(host):\(port)"
        } else {
            return "\(self.scheme):\(host)"
        }
    }
}
