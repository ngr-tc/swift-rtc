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
import Shared

public typealias ContextOption = () -> ReplayDetector

let maxSequenceNumber: UInt16 = 65535
let maxSrtcpIndex: Int = 0x7FFF_FFFF

/// srtp_replay_protection sets SRTP replay protection window size.
public func srtpReplayProtection(windowSize: UInt) -> ContextOption {
    return { () -> ReplayDetector in
        return WrappedSlidingWindowDetector(
            windowSize: windowSize,
            maxSeq: UInt64(maxSequenceNumber)
        )
    }
}

/// Sets SRTCP replay protection window size.
public func srtcpReplayProtection(windowSize: UInt) -> ContextOption {
    return { () -> ReplayDetector in
        return WrappedSlidingWindowDetector(
            windowSize: windowSize,
            maxSeq: UInt64(maxSrtcpIndex)
        )
    }
}

/// srtp_no_replay_protection disables SRTP replay protection.
public func srtpNoReplayProtection() -> ContextOption {
    return { () -> ReplayDetector in
        return NoOpReplayDetector()
    }
}

/// srtcp_no_replay_protection disables SRTCP replay protection.
public func srtcpNoReplayProtection() -> ContextOption {
    return { () -> ReplayDetector in
        return NoOpReplayDetector()
    }
}
