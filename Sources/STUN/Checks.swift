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

/// check_size returns ErrAttrSizeInvalid if got is not equal to expected.
public func checkSize(_ at: AttrType, got: Int, expected: Int) throws {
    if got != expected {
        throw StunError.errAttributeSizeInvalid
    }
}

// is_attr_size_invalid returns true if error means that attribute size is invalid.
//public func isAttrSizeInvalid(err: &Error) -> bool {
//    Error::ErrAttributeSizeInvalid == *err
//}

func checkHmac(got: ByteBufferView, expected: ByteBufferView) throws {
    if got != expected {
        throw StunError.errIntegrityMismatch
    }
}

func checkFingerprint(got: UInt32, expected: UInt32) throws {
    if got != expected {
        throw StunError.errFingerprintMismatch
    }
}

// checkOverflow returns ErrAttributeSizeOverflow if got is bigger that max.
public func checkOverflow(_ at: AttrType, _ got: Int, _ max: Int) throws {
    if got > max {
        throw StunError.errAttributeSizeOverflow
    }
}

// is_attr_size_overflow returns true if error means that attribute size is too big.
//public func is_attr_size_overflow(err: &Error) -> bool {
//    Error::ErrAttributeSizeOverflow == *err
//}
