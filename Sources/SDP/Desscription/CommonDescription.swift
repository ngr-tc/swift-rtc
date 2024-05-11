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
