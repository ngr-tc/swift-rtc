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

/// This protocol sits here to avoid getting a direct dependency between
/// the dtls and srtp crates.
public protocol KeyingMaterialExporter {
    /// extract keying material
    func exportKeyingMaterial(label: String, context: ByteBufferView, length: Int) throws
        -> ByteBuffer
}
