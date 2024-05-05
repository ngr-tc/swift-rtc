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
extension StringProtocol {
    public func trimmingWhitespace() -> SubSequence {
        var start = startIndex
        while start < endIndex && self[start].isWhitespace {
            formIndex(after: &start)
        }

        var end = endIndex
        while end > start && self[index(before: end)].isWhitespace {
            formIndex(before: &end)
        }

        return self[start..<end]
    }
}
