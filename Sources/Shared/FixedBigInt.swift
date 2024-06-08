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

// FixedBigInt is the fix-sized multi-word integer.
struct FixedBigInt {
    var bits: [UInt64]
    var n: UInt
    var msbMask: UInt64

    init(n: UInt) {
        var chunkSize = Int((n + 63) / 64)
        if chunkSize == 0 {
            chunkSize = 1
        }

        self.bits = Array(repeating: 0, count: chunkSize)
        self.n = n
        self.msbMask = n % 64 == 0 ? UInt64.max : (1 << (64 - n % 64)) - 1
    }

    // lsh is the left shift operation.
    mutating func lsh(_ n: UInt) {
        if n == 0 {
            return
        }
        let nChunk = Int(n / 64)
        let nN = Int(n % 64)

        for i in (0..<self.bits.count).reversed() {
            var carry: UInt64 = 0
            if i - nChunk >= 0 {
                carry = nN >= 64 ? 0 : self.bits[i - nChunk] << nN
                if i - nChunk > 0 {
                    carry |= nN == 0 ? 0 : (self.bits[i - nChunk - 1] >> (64 - nN))
                }
            }
            self.bits[i] = n >= 64 ? carry : ((self.bits[i] << n) | carry)
        }

        let last = self.bits.count - 1
        self.bits[last] &= self.msbMask
    }

    // bit returns i-th bit of the fixedBigInt.
    func bit(_ i: UInt) -> UInt64 {
        if i >= self.n {
            return 0
        }
        let chunk = Int(i / 64)
        let pos = Int(i % 64)
        return (self.bits[chunk] & (1 << pos)) != 0 ? 1 : 0
    }

    // set_bit sets i-th bit to 1.
    mutating func setBit(_ i: UInt) {
        if i >= self.n {
            return
        }
        let chunk = Int(i / 64)
        let pos = Int(i % 64)
        self.bits[chunk] |= 1 << pos
    }
}

extension FixedBigInt: CustomStringConvertible {
    var description: String {
        var out = String()
        for i in (0..<self.bits.count).reversed() {
            out += String(format: "%016llX", self.bits[i])
        }
        return out
    }
}
