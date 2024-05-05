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
public struct Address {
    var address: String
    var ttl: Int?
    var range: Int?
}

/// ConnectionInformation defines the representation for the "c=" field
/// containing connection data.
public struct ConnectionInformation {
    var networkType: String
    var addressType: String
    var address: Address?
}

/// Bandwidth describes an optional field which denotes the proposed bandwidth
/// to be used by the session or media.
public struct Bandwidth {
    var experimental: Bool
    var bandwidthType: String
    var bandwidth: UInt64
}

/// EncryptionKey describes the "k=" which conveys encryption key information.
public typealias EncryptionKey = String

/// ConnectionRole indicates which of the end points should initiate the connection establishment
public enum ConnectionRole: String {
    case active, passive, actpass, holdconn
}

/// Direction is a marker for transmission direction of an endpoint
public enum Direction: String {
    case sendrecv, sendonly, recvonly, inactive
}
