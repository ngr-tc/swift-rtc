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

/// The type of server used in the ice.URL structure.
public enum SchemeType: Equatable {
    /// The URL represents a STUN server.
    case stun

    /// The URL represents a STUNS (secure) server.
    case stuns

    /// The URL represents a TURN server.
    case turn

    /// The URL represents a TURNS (secure) server.
    case turns

    /// Defines a procedure for creating a new `SchemeType` from a raw
    /// string naming the scheme type.
    public init?(rawValue: String) {
        switch rawValue {
        case "stun":
            self = .stun
        case "stuns":
            self = .stuns
        case "turn":
            self = .turn
        case "turns":
            self = .turns
        default:
            return nil
        }
    }
}

extension SchemeType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .stun:
            return "stun"
        case .stuns:
            return "stuns"
        case .turn:
            return "turn"
        case .turns:
            return "turns"
        }
    }
}

/// The transport protocol type that is used in the `ice::url::Url` structure.
public enum ProtoType: Equatable {
    /// The URL uses a UDP transport.
    case udp

    /// The URL uses a TCP transport.
    case tcp

    // NewSchemeType defines a procedure for creating a new SchemeType from a raw
    // string naming the scheme type.
    public init?(rawValue: String) {
        switch rawValue {
        case "udp":
            self = .udp
        case "tcp":
            self = .tcp
        default:
            return nil
        }
    }
}

extension ProtoType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .udp:
            return "udp"
        case .tcp:
            return "tcp"
        }
    }
}

public enum UrlError: Error, Equatable {
    case errUrlParse
    case errSchemeType
    case errHost
    case errPort
    case errStunQuery
    case errInvalidQuery
    case errProtoType
}

extension UrlError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .errUrlParse:
            return "url parse fail"
        case .errSchemeType:
            return "invalid scheme type"
        case .errHost:
            return "invalid host"
        case .errPort:
            return "invalid port"
        case .errStunQuery:
            return "invalid stun query"
        case .errInvalidQuery:
            return "invalid query"
        case .errProtoType:
            return "invalid proto type"
        }
    }
}

/// Represents a STUN (rfc7064) or TURN (rfc7065) URL.
public struct Url: Equatable {
    public var scheme: SchemeType
    public var host: String
    public var port: UInt16
    public var username: String
    public var password: String
    public var proto: ProtoType

    /// Parses a STUN or TURN urls following the ABNF syntax described in
    /// [IETF rfc-7064](https://tools.ietf.org/html/rfc7064) and
    /// [IETF rfc-7065](https://tools.ietf.org/html/rfc7065) respectively.
    public init(_ raw: String) throws {
        guard let schemePos = raw.firstIndex(of: ":") else {
            throw UrlError.errSchemeType
        }

        guard let scheme = SchemeType(rawValue: String(raw[raw.startIndex..<schemePos])) else {
            throw UrlError.errSchemeType
        }
        self.scheme = scheme

        let transportPos = raw.lastIndex(of: "?")

        switch scheme {
        case .stun, .stuns:
            if transportPos != nil {
                throw UrlError.errStunQuery
            }
            if scheme == .stun {
                self.proto = ProtoType.udp
            } else {
                self.proto = ProtoType.tcp
            }
        case .turn, .turns:
            if let transportPos {
                guard let protoPos = raw.lastIndex(of: "=") else {
                    throw UrlError.errInvalidQuery
                }

                guard
                    raw[raw.index(after: transportPos)..<protoPos]
                        == "transport"
                else {
                    throw UrlError.errInvalidQuery
                }

                guard
                    let proto = ProtoType(
                        rawValue: String(raw[raw.index(after: protoPos)...]))
                else {
                    throw UrlError.errProtoType
                }
                self.proto = proto
            } else if scheme == .turn {
                self.proto = ProtoType.udp
            } else {
                self.proto = ProtoType.tcp
            }
        }

        let hostport: Substring
        if let transportPos {
            hostport = raw[raw.index(after: schemePos)..<transportPos]
        } else {
            hostport = raw[raw.index(after: schemePos)...]
        }

        if let ipv6Start = hostport.firstIndex(of: "[") {
            guard let ipv6End = hostport.firstIndex(of: "]") else {
                throw UrlError.errHost
            }
            self.host = String(hostport[hostport.index(after: ipv6Start)..<ipv6End])
            let portStr = hostport[hostport.index(after: ipv6End)...]
            if let portPos = portStr.lastIndex(of: ":") {
                guard let port = UInt16(hostport[hostport.index(after: portPos)...]) else {
                    throw UrlError.errPort
                }
                self.port = port
            } else {
                if scheme == SchemeType.stun || scheme == SchemeType.turn {
                    self.port = 3478
                } else {
                    self.port = 5349
                }
            }
        } else if let portPos = hostport.lastIndex(of: ":") {
            self.host = String(hostport[..<portPos])
            guard let port = UInt16(hostport[hostport.index(after: portPos)...]) else {
                throw UrlError.errPort
            }
            self.port = port
        } else {
            self.host = String(hostport)
            if scheme == SchemeType.stun || scheme == SchemeType.turn {
                self.port = 3478
            } else {
                self.port = 5349
            }
        }

        if self.host.isEmpty {
            throw UrlError.errHost
        }

        self.username = ""
        self.password = ""
    }

    /// Returns whether the this URL's scheme describes secure scheme or not.
    public func isSecure() -> Bool {
        self.scheme == SchemeType.stuns || self.scheme == SchemeType.turns
    }
}

extension Url: CustomStringConvertible {
    public var description: String {
        let host: String
        if self.host.contains("::") {
            host = "[" + self.host + "]"
        } else {
            host = self.host
        }
        if self.scheme == SchemeType.turn || self.scheme == SchemeType.turns {
            return "\(self.scheme):\(host):\(self.port)?transport=\(self.proto)"
        } else {
            return "\(self.scheme):\(host):\(self.port)"
        }
    }
}
