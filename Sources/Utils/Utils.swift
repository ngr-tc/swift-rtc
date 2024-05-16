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

extension UTF8.CodeUnit {
    var isASCIIWhitespace: Bool {
        switch self {
        case UInt8(ascii: " "),
            UInt8(ascii: "\t"):
            return true

        default:
            return false
        }
    }

    var isASCIINewline: Bool {
        switch self {
        case UInt8(ascii: "\r"),
            UInt8(ascii: "\n"):
            return true

        default:
            return false
        }
    }
}

extension String {
    public func trimmingWhitespace() -> Substring {
        return Substring(self).trimmingWhitespace()
    }

    public func trimmingPrefix(_ prefix: String) -> String {
        var result = self
        while result.hasPrefix(prefix) {
            result = String(result.dropFirst(prefix.count))
        }
        return result
    }

    public func trimmingNewline() -> Substring {
        return Substring(self).trimmingNewline()
    }
}

extension Substring {
    public func trimmingWhitespace() -> Substring {
        guard let firstNonWhitespace = self.utf8.firstIndex(where: { !$0.isASCIIWhitespace }) else {
            // The whole substring is ASCII whitespace.
            return Substring()
        }

        // There must be at least one non-ascii whitespace character, so banging here is safe.
        let lastNonWhitespace = self.utf8.lastIndex(where: { !$0.isASCIIWhitespace })!
        return Substring(self.utf8[firstNonWhitespace...lastNonWhitespace])
    }

    public func trimmingNewline() -> Substring {
        // There must be at least one non-ascii newline character, so banging here is safe.
        let lastNonNewline = self.utf8.lastIndex(where: { !$0.isASCIINewline })!
        return Substring(self.utf8[...lastNonNewline])
    }
}

extension UInt32 {
    public static func fromBeBytes(byte1: UInt8, byte2: UInt8, byte3: UInt8, byte4: UInt8) -> UInt32
    {
        return (UInt32(byte1) << 24) | (UInt32(byte2) << 16) | (UInt32(byte3) << 8) | UInt32(byte4)
    }
}
