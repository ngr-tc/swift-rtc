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

/// getPadding Returns the padding required to make the length a multiple of 4
public func getPadding(_ len: Int) -> Int {
    if len % 4 == 0 {
        return 0
    } else {
        return 4 - (len % 4)
    }
}

public func putPadding(_ buf: inout ByteBuffer, _ len: Int) {
    let paddingSize = getPadding(len)
    for i in 0..<paddingSize {
        if i == paddingSize - 1 {
            buf.writeInteger(UInt8(paddingSize))
        } else {
            buf.writeInteger(UInt8(0))
        }
    }
}

/// setNbitsOfUInt16 will truncate the value to size, left-shift to start_index position and set
public func setNbitsOfUInt16(
    _ src: UInt16,
    _ size: UInt16,
    _ startIndex: UInt16,
    _ val: UInt16
) -> UInt16? {
    if startIndex + size > 16 {
        return nil
    }

    // truncate val to size bits
    let v = val & ((1 << size) - 1)

    return src | (v << (16 - size - startIndex))
}

/// appendNbitsToUInt32 will left-shift and append n bits of val
public func appendNbitsToUInt32(_ src: UInt32, _ n: UInt32, _ val: UInt32) -> UInt32 {
    (src << n) | (val & (0xFFFF_FFFF >> (32 - n)))
}

/// getNbitsFromByte get n bits from 1 byte, begin with a position
public func getNbitsFromByte(_ b: UInt8, _ begin: UInt16, _ n: UInt16) -> UInt16 {
    let endShift = 8 - (begin + n)
    let mask = UInt8((0xFF >> begin) & (0xFF << endShift))
    return UInt16(b & mask) >> endShift
}

/// get24BitFromBytes get 24bits from `[3]byte` slice
public func get24BitsFromBytes(_ b: ByteBufferView) -> UInt32 {
    return (UInt32(b.byte(0)) << 16) + (UInt32(b.byte(1)) << 8) + UInt32(b.byte(2))
}
