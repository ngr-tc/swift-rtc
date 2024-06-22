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

extension ByteBufferView {
    @inlinable
    public func byte(zeroBasedPosition: Index) -> UInt8 {
        guard zeroBasedPosition >= 0 && zeroBasedPosition < self.count else {
            preconditionFailure("index \(zeroBasedPosition) out of range")
        }
        return self[zeroBasedPosition + self.startIndex]
    }

    @inlinable
    public func subview(zeroBasedRange: Range<Index>) -> ByteBufferView {
        let lowerBound = Swift.min(self.startIndex + zeroBasedRange.lowerBound, self.endIndex)
        let upperBound = Swift.min(self.startIndex + zeroBasedRange.upperBound, self.endIndex)
        return self[lowerBound..<upperBound]
    }
}
