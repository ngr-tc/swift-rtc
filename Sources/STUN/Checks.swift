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

/*
// check_size returns ErrAttrSizeInvalid if got is not equal to expected.
pub fn check_size(_at: AttrType, got: usize, expected: usize) -> Result<()> {
    if got == expected {
        Ok(())
    } else {
        Err(Error::ErrAttributeSizeInvalid)
    }
}

// is_attr_size_invalid returns true if error means that attribute size is invalid.
pub fn is_attr_size_invalid(err: &Error) -> bool {
    Error::ErrAttributeSizeInvalid == *err
}

pub(crate) fn check_hmac(got: &[u8], expected: &[u8]) -> Result<()> {
    if got.ct_eq(expected).unwrap_u8() != 1 {
        Err(Error::ErrIntegrityMismatch)
    } else {
        Ok(())
    }
}

pub(crate) fn check_fingerprint(got: u32, expected: u32) -> Result<()> {
    if got == expected {
        Ok(())
    } else {
        Err(Error::ErrFingerprintMismatch)
    }
}
*/
// checkOverflow returns ErrAttributeSizeOverflow if got is bigger that max.
public func checkOverflow(_ at: AttrType, _ got: Int, _ max: Int) throws {
    if got > max {
        throw STUNError.errAttributeSizeOverflow
    }
}
/*
// is_attr_size_overflow returns true if error means that attribute size is too big.
pub fn is_attr_size_overflow(err: &Error) -> bool {
    Error::ErrAttributeSizeOverflow == *err
}
*/
