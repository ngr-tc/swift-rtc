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

public let attributeKey: String = "a="

/// Attribute describes the "a=" field which represents the primary means for
/// extending SDP.
public struct Attribute: Equatable {
    var key: String
    var value: String?

    /// init constructs a new attribute
    init(key: String, value: String? = nil) {
        self.key = key
        self.value = value
    }

    /// isIceCandidate returns true if the attribute key equals "candidate".
    public func isIceCandidate() -> Bool {
        return self.key == "candidate"
    }
}
