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

/// ReplayDetector is the interface of sequence replay detector.
public protocol ReplayDetector {
    /// Check returns true if given sequence number is not replayed.
    mutating func check(seq: UInt64) -> Bool

    /// Call accept() to mark the packet is received properly.
    mutating func accept()
}

public struct SlidingWindowDetector {
    var accepted: Bool
    var seq: UInt64
    var latestSeq: UInt64
    var maxSeq: UInt64
    var windowSize: UInt
    var mask: FixedBigInt

    /// Created ReplayDetector doesn't allow wrapping.
    /// It can handle monotonically increasing sequence number up to
    /// full 64bit number. It is suitable for DTLS replay protection.
    public init(windowSize: UInt, maxSeq: UInt64) {
        self.accepted = false
        self.seq = 0
        self.latestSeq = 0
        self.maxSeq = maxSeq
        self.windowSize = windowSize
        self.mask = FixedBigInt(n: windowSize)
    }
}

extension SlidingWindowDetector: ReplayDetector {
    public mutating func check(seq: UInt64) -> Bool {
        self.accepted = false

        if seq > self.maxSeq {
            // Exceeded upper limit.
            return false
        }

        if seq <= self.latestSeq {
            if self.latestSeq >= UInt64(self.windowSize) + seq {
                return false
            }
            if self.mask.bit(UInt(self.latestSeq - seq)) != 0 {
                // The sequence number is duplicated.
                return false
            }
        }

        self.accepted = true
        self.seq = seq
        return true
    }

    public mutating func accept() {
        if !self.accepted {
            return
        }

        if self.seq > self.latestSeq {
            // Update the head of the window.
            self.mask.lsh(UInt(self.seq - self.latestSeq))
            self.latestSeq = self.seq
        }
        let diff = (self.latestSeq - self.seq) % self.maxSeq
        self.mask.setBit(UInt(diff))
    }
}

public struct WrappedSlidingWindowDetector {
    var accepted: Bool
    var seq: UInt64
    var latestSeq: UInt64
    var maxSeq: UInt64
    var windowSize: UInt
    var mask: FixedBigInt
    var initValue: Bool

    /// WithWrap creates ReplayDetector allowing sequence wrapping.
    /// This is suitable for short bitwidth counter like SRTP and SRTCP.
    public init(windowSize: UInt, maxSeq: UInt64) {
        self.accepted = false
        self.seq = 0
        self.latestSeq = 0
        self.maxSeq = maxSeq
        self.windowSize = windowSize
        self.mask = FixedBigInt(n: windowSize)
        self.initValue = false
    }
}

extension WrappedSlidingWindowDetector: ReplayDetector {
    public mutating func check(seq: UInt64) -> Bool {
        self.accepted = false

        if seq > self.maxSeq {
            // Exceeded upper limit.
            return false
        }
        if !self.initValue {
            if seq != 0 {
                self.latestSeq = seq - 1
            } else {
                self.latestSeq = self.maxSeq
            }
            self.initValue = true
        }

        var diff = Int64(self.latestSeq) - Int64(seq)
        // Wrap the number.
        if diff > Int64(self.maxSeq) / 2 {
            diff -= Int64(self.maxSeq + 1)
        } else if diff <= -Int64(self.maxSeq / 2) {
            diff += Int64(self.maxSeq + 1)
        }

        if diff >= Int64(self.windowSize) {
            // Too old.
            return false
        }
        if diff >= 0 && self.mask.bit(UInt(diff)) != 0 {
            // The sequence number is duplicated.
            return false
        }

        self.accepted = true
        self.seq = seq
        return true
    }

    public mutating func accept() {
        if !self.accepted {
            return
        }

        var diff = Int64(self.latestSeq) - Int64(self.seq)
        // Wrap the number.
        if diff > Int64(self.maxSeq) / 2 {
            diff -= Int64(self.maxSeq + 1)
        } else if diff <= -Int64(self.maxSeq / 2) {
            diff += Int64(self.maxSeq + 1)
        }

        //assert!(diff < Int64(self.window_size));

        if diff < 0 {
            // Update the head of the window.
            self.mask.lsh(UInt(-diff))
            self.latestSeq = self.seq
        }
        self.mask
            .setBit(UInt(bitPattern: Int(self.latestSeq) - Int(self.seq)))
    }
}

public struct NoOpReplayDetector {
}

extension NoOpReplayDetector: ReplayDetector {
    public mutating func check(seq: UInt64) -> Bool {
        return true
    }
    public mutating func accept() {}
}
