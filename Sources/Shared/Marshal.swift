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

public protocol Unmarshal {
    static func unmarshal(_ buf: ByteBuffer) throws -> (Self, Int)
}

public protocol MarshalSize {
    func marshalSize() -> Int
}

public protocol Marshal: MarshalSize {
    func marshalTo(_ buf: inout ByteBuffer) throws -> Int
}

extension Marshal {
    public func marshal() throws -> ByteBuffer {
        var buf = ByteBuffer()
        let _ = try self.marshalTo(&buf)
        return buf
    }
}
