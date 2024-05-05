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
import XCTest

@testable import Utils

final class UtilsTests: XCTestCase {
    func testTrimmingWhitespace() throws {
        let str = "  Hello, World!  "
        let trimmed = str.trimmingWhitespace()
        XCTAssertEqual("Hello, World!", trimmed)
    }
}
