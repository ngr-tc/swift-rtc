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

// This is a simplified vendored version from:
// https://github.com/tayloraswift/swift-hash/blob/v0.5.0/

@frozen
public
    struct CRC32: Hashable, Sendable
{
    public static
        let table: [UInt32] = (0..<256).map {
            (i: UInt32) in
            (0..<8).reduce(i) { (c, _) in (c & 1 * 0xed_b8_83_20) ^ c >> 1 }
        }

    public
        var checksum: UInt32

    @inlinable
    public
        init(checksum: UInt32 = 0)
    {
        self.checksum = checksum
    }
    @inlinable
    public
        init<Message>(hashing message: Message)
    where Message: Sequence, Message.Element == UInt8 {
        self.init()
        self.update(with: message)
    }

    @inlinable
    public
        func updated<Message>(with message: Message) -> Self
    where Message: Sequence, Message.Element == UInt8 {
        var checksum: Self = self
        checksum.update(with: message)
        return checksum
    }
    @inlinable
    public mutating
        func update<Message>(with message: Message)
    where Message: Sequence, Message.Element == UInt8 {
        self.checksum = ~message.reduce(~self.checksum) {
            (state: UInt32, byte: UInt8) in
            Self.table[Int.init(UInt8.init(truncatingIfNeeded: state) ^ byte)] ^ state >> 8
        }
    }
}
extension CRC32: ExpressibleByIntegerLiteral {
    @inlinable
    public
        init(integerLiteral: UInt32)
    {
        self.init(checksum: integerLiteral)
    }
}
