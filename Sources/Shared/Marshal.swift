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

public protocol MarshalSize {
    func marshalSize() -> Int
}

public protocol Marshal: MarshalSize {
    func marshal(_ buf: inout ByteBuffer) throws -> Int
}

public protocol Unmarshal: MarshalSize {
    init(_ buf: inout ByteBuffer) throws
}
