import SDP
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

final class MediaDescriptionTests: XCTestCase {
    func testAttributeMissing() throws {
        let mediaDescription = MediaDescription()
        let (exist, value) = mediaDescription.attribute(key: "recvonly")
        XCTAssertEqual(false, exist)
        XCTAssertEqual(nil, value)
    }

    func testAttributePresentWithNoValue() throws {
        var mediaDescription = MediaDescription()
        mediaDescription = mediaDescription.withPropertyAttribute(key: "recvonly")
        let (exist, value) = mediaDescription.attribute(key: "recvonly")
        XCTAssertEqual(true, exist)
        XCTAssertEqual(nil, value)
    }

    func testAttributePresentWithValue() throws {
        var mediaDescription = MediaDescription()
        mediaDescription = mediaDescription.withValueAttribute(key: "ptime", value: "1")
        let (exist, value) = mediaDescription.attribute(key: "ptime")
        XCTAssertEqual(true, exist)
        XCTAssertEqual("1", value)
    }
}
