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

    public func trimmingPrefix(_ prefix: String) -> Substring {
        return Substring(self).trimmingPrefix(prefix)
    }

    public func trimmingSuffix(_ suffix: String) -> Substring {
        return Substring(self).trimmingSuffix(suffix)
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

    public func trimmingPrefix(_ prefix: String) -> Substring {
        var result = self
        while result.hasPrefix(prefix) {
            result = result.dropFirst(prefix.count)
        }
        return result
    }

    public func trimmingSuffix(_ suffix: String) -> Substring {
        var result = self
        while result.hasSuffix(suffix) {
            result = result.dropLast(suffix.count)
        }
        return result
    }

    public func trimmingNewline() -> Substring {
        // There must be at least one non-ascii newline character, so banging here is safe.
        let lastNonNewline = self.utf8.lastIndex(where: { !$0.isASCIINewline })!
        return Substring(self.utf8[...lastNonNewline])
    }
}

extension UInt32 {
    public static func fromBeBytes(_ byte1: UInt8, _ byte2: UInt8, _ byte3: UInt8, _ byte4: UInt8)
        -> UInt32
    {
        return (UInt32(byte1) << 24) | (UInt32(byte2) << 16) | (UInt32(byte3) << 8) | UInt32(byte4)
    }

    public func toBeBytes() -> [UInt8] {
        return [
            UInt8((self >> 24) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 8) & 0xFF),
            UInt8(self & 0xFF),
        ]
    }

    public static func fromLeBytes(_ byte1: UInt8, _ byte2: UInt8, _ byte3: UInt8, _ byte4: UInt8)
        -> UInt32
    {
        return (UInt32(byte4) << 24) | (UInt32(byte3) << 16) | (UInt32(byte2) << 8) | UInt32(byte1)
    }

    public func toLeBytes() -> [UInt8] {
        return [
            UInt8((self >> 0) & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF),
            UInt8((self >> 24) & 0xFF),
        ]
    }
}

extension UInt16 {
    public static func fromBeBytes(_ byte1: UInt8, _ byte2: UInt8) -> UInt16 {
        return (UInt16(byte1) << 8) | UInt16(byte2)
    }

    public func toBeBytes() -> [UInt8] {
        return [UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)]
    }

    public static func fromLeBytes(_ byte1: UInt8, _ byte2: UInt8) -> UInt16 {
        return (UInt16(byte2) << 8) | UInt16(byte1)
    }

    public func toLeBytes() -> [UInt8] {
        return [UInt8((self >> 0) & 0xFF), UInt8((self >> 8) & 0xFF)]
    }
}

extension Result {
    public func isSuccess() -> Bool {
        switch self {
        case .success(_):
            return true
        case .failure(_):
            return false
        }
    }

    public func isFailure() -> Bool {
        switch self {
        case .success(_):
            return false
        case .failure(_):
            return true
        }
    }
}
