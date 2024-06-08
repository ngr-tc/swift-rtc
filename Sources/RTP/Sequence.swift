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

/// Sequencer generates sequential sequence numbers for building RTP packets
public protocol Sequencer {
    mutating func nextSequenceNumber() -> UInt16
    mutating func getRollOverCount() -> UInt64
}

/// NewRandomSequencer returns a new sequencer starting from a random sequence
/// number
public func newRandomSequencer() -> Sequencer {
    return SequencerImpl(
        sequenceNumber: UInt16.random(in: UInt16.min...UInt16.max), rollOverCount: 0)
}

/// NewFixedSequencer returns a new sequencer starting from a specific
/// sequence number
public func newFixedSequencer(s: UInt16) -> Sequencer {
    let sequenceNumber = s == 0 ? UInt16.max : s - 1
    return SequencerImpl(sequenceNumber: sequenceNumber, rollOverCount: 0)
}

struct SequencerImpl {
    var sequenceNumber: UInt16
    var rollOverCount: UInt64
}

extension SequencerImpl: Sequencer {
    /// NextSequenceNumber increment and returns a new sequence number for
    /// building RTP packets
    public mutating func nextSequenceNumber() -> UInt16 {
        if self.sequenceNumber == UInt16.max {
            self.rollOverCount += 1
            self.sequenceNumber = 0
        } else {
            self.sequenceNumber += 1
        }
        return self.sequenceNumber
    }

    /// RollOverCount returns the amount of times the 16bit sequence number
    /// has wrapped
    public mutating func getRollOverCount() -> UInt64 {
        return self.rollOverCount
    }
}
